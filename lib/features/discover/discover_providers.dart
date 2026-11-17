import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../matches/matches_repository.dart';
import '../onboarding/profile_repository.dart';
import '../session/session_controller.dart';
import 'public_profile.dart';

String? _userId(Ref ref) =>
    ref.watch(sessionProvider.select((s) => s.user?.id));

/// Warteschlange im Entdecken-Feed. Die oberste Karte ist `state.first`.
class DiscoverFeedController extends AsyncNotifier<List<PublicProfile>> {
  @override
  Future<List<PublicProfile>> build() async {
    if (_userId(ref) == null) return const [];
    return ref.read(discoverRepositoryProvider).fetchFeed();
  }

  /// Entfernt die oberste Karte; lädt nach, wenn die Schlange leer ist.
  Future<void> dismiss(String profileId) async {
    final rest = [
      for (final p in state.value ?? const <PublicProfile>[])
        if (p.id != profileId) p,
    ];
    state = AsyncData(rest);
    if (rest.isEmpty) await reload();
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(discoverRepositoryProvider).fetchFeed(),
    );
  }
}

final discoverFeedProvider =
    AsyncNotifierProvider<DiscoverFeedController, List<PublicProfile>>(
      DiscoverFeedController.new,
    );

/// Eigener Anzeigename und ob ein Standort hinterlegt ist.
final ownSummaryProvider = FutureProvider<OwnProfileSummary?>((ref) async {
  final id = _userId(ref);
  if (id == null) return null;
  return ref.read(profileRepositoryProvider).fetchOwnSummary(id);
});

/// Ein Profil für die Detailseite.
final profileByIdProvider = FutureProvider.family<PublicProfile?, String>((
  ref,
  id,
) async {
  // Schon im Feed? Dann ohne Netz.
  final feed = ref.read(discoverFeedProvider).value ?? const [];
  final likes = ref.read(receivedLikesProvider).value ?? const [];
  for (final p in [...feed, ...likes]) {
    if (p.id == id) return p;
  }
  return ref.read(discoverRepositoryProvider).fetchProfile(id);
});

/// Wer mich geliked hat und noch auf meine Antwort wartet.
final receivedLikesProvider = FutureProvider<List<PublicProfile>>((ref) async {
  if (_userId(ref) == null) return const [];
  return ref.read(discoverRepositoryProvider).fetchReceivedLikes();
});

final matchesProvider = FutureProvider<List<MatchSummary>>((ref) async {
  if (_userId(ref) == null) return const [];
  return ref.read(matchesRepositoryProvider).fetchMatches();
});

final messagesProvider = StreamProvider.family<List<ChatMessage>, String>(
  (ref, matchId) => ref.read(matchesRepositoryProvider).watchMessages(matchId),
);

/// Summe ungelesener Nachrichten – für das Badge am Chats-Tab.
final unreadMessagesCountProvider = Provider<int>((ref) {
  final matches = ref.watch(matchesProvider).value ?? const <MatchSummary>[];
  return matches.fold(0, (sum, m) => sum + m.unreadCount);
});

/// Offene Likes – für das Badge am Likes-Tab.
final openLikesCountProvider = Provider<int>(
  (ref) => ref.watch(receivedLikesProvider).value?.length ?? 0,
);

/// Hört live auf neue Nachrichten, Likes und Matches und lädt dann die
/// betroffenen Listen neu. Läuft, solange die App-Shell sichtbar ist.
final inboxListenerProvider = Provider<void>((ref) {
  if (_userId(ref) == null) return;
  Timer? debounce;
  final sub = ref.read(matchesRepositoryProvider).watchInbox().listen((_) {
    // Mehrere Ereignisse kurz hintereinander nur einmal verarbeiten.
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 300), () {
      ref
        ..invalidate(matchesProvider)
        ..invalidate(receivedLikesProvider);
    });
  });
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
  });
});
