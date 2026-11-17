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
import 'package:lovelapp/features/matches/supabase_matches_repository.dart';
import 'package:lovelapp/features/onboarding/supabase_profile_repository.dart';
import 'package:lovelapp/core/widgets/profile_image.dart';
import 'package:lovelapp/features/photos/image_processing.dart';
import 'package:lovelapp/features/photos/supabase_photos_repository.dart';
import 'package:image/image.dart' as img;
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

    // Reste früherer Läufe wegräumen (Fotos von B)
    for (final p in await SupabasePhotosRepository(b).fetchOwn(idB)) {
      await SupabasePhotosRepository(b).delete(idB, p);
    }

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

    // Feed von A enthält B mit Fragen und gerundeter Entfernung
    final discoverA = SupabaseDiscoverRepository(
      a,
      SupabasePhotosRepository(a),
    );
    final feed = await discoverA.fetchFeed();
    final ben = feed.singleWhere((p) => p.id == idB);
    expect(ben.prompts.length, 3);
    expect(ben.prompts.first.question, 'Mein perfekter Sonntag …');
    expect(ben.distanceKm, greaterThanOrEqualTo(1));

    // Detail über get_public_profiles
    final detail = await discoverA.fetchProfile(idB);
    expect(detail!.name, ben.name);

    // B hört live auf seinen Posteingang (Likes, Matches, Nachrichten)
    final inboxB = SupabaseMatchesRepository(b, SupabasePhotosRepository(b));
    var pingsB = 0;
    final inboxSubB = inboxB.watchInbox().listen((_) => pingsB++);
    await Future<void>.delayed(const Duration(seconds: 4));

    // Kontingent und Like
    expect((await discoverA.fetchQuota()).remaining, 20);
    final first = await discoverA.like(idB);
    expect(first.matched, isFalse);
    expect(first.remaining, 19);
    expect((await discoverA.fetchFeed()).any((p) => p.id == idB), isFalse);

    // B sieht den Like live und in „Likes“
    await _waitFor(() => pingsB > 0, 'Like kommt live bei B an');
    final likesB = await SupabaseDiscoverRepository(
      b,
      SupabasePhotosRepository(b),
    ).fetchReceivedLikes();
    expect(likesB.single.id, idA);

    // B liked zurück → Match
    final second = await SupabaseDiscoverRepository(
      b,
      SupabasePhotosRepository(b),
    ).like(idA);
    expect(second.matched, isTrue);

    // Matches und Chat
    final matchesA = SupabaseMatchesRepository(a, SupabasePhotosRepository(a));
    final matchesB = SupabaseMatchesRepository(b, SupabasePhotosRepository(b));
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

    // Ungelesen bei A, nach dem Lesen nicht mehr; B erfährt es live
    expect((await matchesA.fetchMatches()).single.unreadCount, 1);
    final before = pingsB;
    await matchesA.markRead(matchId);
    expect((await matchesA.fetchMatches()).single.unreadCount, 0);
    await _waitFor(() => pingsB > before, 'Gelesen-Status kommt live bei B an');
    expect(
      (await SupabaseDiscoverRepository(
        b,
        SupabasePhotosRepository(b),
      ).fetchReceivedLikes()),
      isEmpty,
    );

    // A antwortet → Vorschau aktualisiert
    await matchesA.sendMessage(matchId, 'Hallo zurück!');
    expect((await matchesB.fetchMatches()).single.lastMessage, 'Hallo zurück!');

    // Fotos: B lädt zwei hoch, sortiert um; A sieht sie in Bs Profil
    final photosB = SupabasePhotosRepository(b);
    final jpeg1 = prepareProfileJpeg(
      img.encodePng(img.Image(width: 800, height: 1000)),
    );
    final jpeg2 = prepareProfileJpeg(
      img.encodePng(
        img.fill(
          img.Image(width: 600, height: 600),
          color: img.ColorRgb8(200, 90, 60),
        ),
      ),
    );
    final p1 = await photosB.upload(idB, jpeg1, position: 0);
    final p2 = await photosB.upload(idB, jpeg2, position: 1);
    await photosB.reorder(idB, [p2.id, p1.id]);
    final ownPhotos = await photosB.fetchOwn(idB);
    expect(ownPhotos.map((p) => p.id), [p2.id, p1.id]);

    final seenByA = await SupabasePhotosRepository(a).imagesFor([idB]);
    expect(seenByA[idB], hasLength(2));
    final photoUrl = (seenByA[idB]!.first as NetworkProfileImage).url;
    final response = await HttpClient()
        .getUrl(Uri.parse(photoUrl))
        .then((r) => r.close());
    expect(response.statusCode, 200, reason: 'Signierte URL lädt das Bild');
    await response.drain<void>();

    // A darf Bs Fotos nicht löschen
    await SupabasePhotosRepository(a).delete(idA, ownPhotos.first);
    expect(await photosB.fetchOwn(idB), hasLength(2));

    // Aufräumen: B löscht seine Fotos (Datei + Eintrag)
    for (final p in ownPhotos) {
      await photosB.delete(idB, p);
    }
    expect(await photosB.fetchOwn(idB), isEmpty);

    await inboxSubB.cancel();
    await a.dispose();
    await b.dispose();
  }, timeout: const Timeout(Duration(minutes: 2)));
}

Future<void> _waitFor(bool Function() condition, String what) async {
  for (var i = 0; i < 40; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  fail('Zeitüberschreitung: $what');
}
