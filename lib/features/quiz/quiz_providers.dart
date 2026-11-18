import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_controller.dart';
import 'quiz_models.dart';

export 'quiz_models.dart';
export 'quiz_rules.dart';

final quizGamesProvider = FutureProvider<List<QuizGameSummary>>(
  (ref) => ref.watch(quizRepositoryProvider).myGames(),
);

final quizGameProvider = FutureProvider.family<QuizGameState, String>(
  (ref, id) => ref.watch(quizRepositoryProvider).state(id),
);

final quizCategoriesProvider = FutureProvider<Map<String, QuizCategory>>((
  ref,
) async {
  final list = await ref.watch(quizRepositoryProvider).categories();
  return {for (final c in list) c.key: c};
});

/// Spiele, in denen ich gerade etwas tun muss (Badge am Spiele-Tab).
final quizTurnCountProvider = Provider<int>(
  (ref) =>
      ref
          .watch(quizGamesProvider)
          .value
          ?.where((g) => g.action.isMyTurn)
          .length ??
      0,
);

/// Hält die Live-Verbindung und lädt bei Änderungen neu (in der App-Shell).
final quizLiveProvider = Provider<void>((ref) {
  if (ref.watch(sessionProvider.select((s) => s.user?.id)) == null) return;
  Timer? debounce;
  final sub = ref.read(quizRepositoryProvider).changes().listen((_) {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 250), () {
      ref
        ..invalidate(quizGamesProvider)
        ..invalidate(quizGameProvider);
    });
  });
  ref.onDispose(() {
    debounce?.cancel();
    sub.cancel();
  });
});
