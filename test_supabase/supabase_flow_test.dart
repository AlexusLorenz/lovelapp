// Integrationstest gegen ein echtes Supabase-Projekt.
//
// NICHT Teil der normalen Tests/CI. Braucht zwei bestätigte Test-Konten
// (Frau sucht Mann / Mann sucht Frau, nah beieinander, mit Standort; Ben
// mit drei Fragen), die sich noch nicht geliked haben:
//
//   flutter test test_supabase \
//     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=... \
//     --dart-define=IT_EMAIL_A=... --dart-define=IT_EMAIL_B=... \
//     --dart-define=IT_PASSWORD=...
//
// Konten danach wieder löschen.
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lovelapp/features/auth/auth_repository.dart';
import 'package:lovelapp/features/auth/supabase_auth_repository.dart';
import 'package:lovelapp/features/discover/supabase_discover_repository.dart';
import 'package:lovelapp/features/location/approx_location.dart';
import 'package:lovelapp/features/matches/supabase_matches_repository.dart';
import 'package:lovelapp/features/onboarding/supabase_profile_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const url = String.fromEnvironment('SUPABASE_URL');
const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
const emailA = String.fromEnvironment('IT_EMAIL_A');
const emailB = String.fromEnvironment('IT_EMAIL_B');
const password = String.fromEnvironment('IT_PASSWORD');

/// Echte Netzwerkverbindungen erlauben (flutter_test blockiert sie sonst),
/// optional über einen Proxy aus der Umgebung.
class _RealHttp extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final bundle = Platform.environment['IT_CA_BUNDLE'];
    final ctx = SecurityContext(withTrustedRoots: true);
    if (bundle != null) ctx.setTrustedCertificates(bundle);
    return super.createHttpClient(ctx)
      ..findProxy = HttpClient.findProxyFromEnvironment;
  }
}

SupabaseClient newClient() => SupabaseClient(
  url,
  key,
  authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
);

void main() {
  setUpAll(() => HttpOverrides.global = _RealHttp());

  test('Anmelden, Feed, Like, Match, Chat', () async {
    expect(url, isNotEmpty, reason: 'SUPABASE_URL fehlt');
    final a = newClient();
    final b = newClient();

    // Anmelden
    await SupabaseAuthRepository(a).signIn(email: emailA, password: password);
    await SupabaseAuthRepository(b).signIn(email: emailB, password: password);
    final idA = a.auth.currentUser!.id;
    final idB = b.auth.currentUser!.id;

    // Falsches Passwort → verständlicher Fehler
    await expectLater(
      SupabaseAuthRepository(newClient())
          .signIn(email: emailA, password: 'falsch-123456'),
      throwsA(
        isA<AuthFailure>().having(
          (e) => e.message,
          'message',
          contains('Passwort'),
        ),
      ),
    );

    // Eigenes Profil
    final profilesA = SupabaseProfileRepository(a);
    expect(await profilesA.hasOwnProfile(idA), isTrue);
    final own = await profilesA.fetchOwnSummary(idA);
    expect(own!.hasLocation, isTrue);
    await profilesA.updateLocation(idA, ApproxLocation.rounded(51.341, 12.372));

    // Feed von A enthält B mit Fragen und gerundeter Entfernung
    final discoverA = SupabaseDiscoverRepository(a);
    final feed = await discoverA.fetchFeed();
    final ben = feed.singleWhere((p) => p.id == idB);
    expect(ben.prompts.length, 3);
    expect(ben.prompts.first.question, 'Mein perfekter Sonntag …');
    expect(ben.distanceKm, greaterThanOrEqualTo(1));

    // Detail über get_public_profiles
    final detail = await discoverA.fetchProfile(idB);
    expect(detail!.name, ben.name);

    // Kontingent und Like
    expect((await discoverA.fetchQuota()).remaining, 20);
    final first = await discoverA.like(idB);
    expect(first.matched, isFalse);
    expect(first.remaining, 19);
    expect((await discoverA.fetchFeed()).any((p) => p.id == idB), isFalse);

    // B liked zurück → Match
    final second = await SupabaseDiscoverRepository(b).like(idA);
    expect(second.matched, isTrue);

    // Matches und Chat
    final matchesA = SupabaseMatchesRepository(a);
    final matchesB = SupabaseMatchesRepository(b);
    final listA = await matchesA.fetchMatches();
    expect(listA.single.profile.id, idB);
    final matchId = listA.single.matchId;

    // A hört live zu, B schreibt
    final ready = Completer<void>();
    final received = Completer<String>();
    final sub = matchesA.watchMessages(matchId).listen((msgs) {
      if (!ready.isCompleted) ready.complete();
      if (msgs.isNotEmpty && !received.isCompleted) {
        received.complete(msgs.last.body);
      }
    });
    // Erst nach dem ersten Stand ist der Kanal abonniert; kurz Puffer lassen.
    await ready.future.timeout(const Duration(seconds: 15));
    await Future<void>.delayed(const Duration(seconds: 3));
    await matchesB.sendMessage(matchId, 'Hallo aus dem Integrationstest');
    expect(
      await received.future.timeout(const Duration(seconds: 20)),
      'Hallo aus dem Integrationstest',
    );
    await sub.cancel();

    // A antwortet → Vorschau aktualisiert
    await matchesA.sendMessage(matchId, 'Hallo zurück!');
    expect((await matchesB.fetchMatches()).single.lastMessage, 'Hallo zurück!');

    await a.dispose();
    await b.dispose();
  }, timeout: const Timeout(Duration(minutes: 2)));
}
