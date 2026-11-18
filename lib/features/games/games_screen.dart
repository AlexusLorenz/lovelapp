import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../quiz/quiz_providers.dart';
import '../quiz/quiz_start_sheet.dart';
import '../quiz/quiz_widgets.dart';
import 'game_catalog.dart';

class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final games = ref.watch(quizGamesProvider);
    final list = games.value ?? const <QuizGameSummary>[];
    final running =
        [
          for (final g in list)
            if (!g.action.isOver) g,
        ]..sort((a, b) {
          // Wo ich dran bin, zuerst.
          final turn =
              (b.action.isMyTurn ? 1 : 0) - (a.action.isMyTurn ? 1 : 0);
          return turn != 0 ? turn : b.updatedAt.compareTo(a.updatedAt);
        });
    final over = [
      for (final g in list)
        if (g.action.isOver) g,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Spiele')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(quizGamesProvider.future),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Card(
              color: LovelColors.umber,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '2 gegen 2',
                      style: TextStyle(
                        fontFamily: AppTheme.displayFont,
                        fontSize: 34,
                        color: LovelColors.cream,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Spielt mit einem Match als Team gegen ein anderes Paar. '
                      '6 Runden – und jede:r spielt, wann es passt.',
                      style: TextStyle(color: LovelColors.cream),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: LovelColors.cream,
                        side: const BorderSide(color: LovelColors.cream),
                      ),
                      onPressed: () => showQuizStartSheet(context, join: true),
                      icon: const Icon(Icons.vpn_key_outlined),
                      label: const Text('Code eingeben'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            for (final kind in QuizKind.values)
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  leading: Text(
                    kind.symbol,
                    style: const TextStyle(fontSize: 32),
                  ),
                  title: Text(
                    kind.title,
                    style: const TextStyle(
                      fontFamily: AppTheme.displayFont,
                      fontSize: 22,
                      color: LovelColors.umber,
                    ),
                  ),
                  subtitle: Text(kind.tagline),
                  trailing: FilledButton(
                    onPressed: () => showQuizStartSheet(context, kind: kind),
                    child: const Text('Spielen'),
                  ),
                  onTap: () => showQuizStartSheet(context, kind: kind),
                ),
              ),
            if (games.hasError)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Spiele nicht ladbar: ${games.error}'),
              ),
            if (running.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Laufende Spiele', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final g in running)
                QuizGameTile(
                  game: g,
                  onTap: () => context.go(Routes.quizGame(g.id)),
                ),
            ],
            if (over.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Beendet', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final g in over)
                QuizGameTile(
                  game: g,
                  onTap: () => context.go(Routes.quizGame(g.id)),
                ),
            ],
            const SizedBox(height: 24),
            Text('Weitere Spiele', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final game in GameCatalog.all)
              Card(
                child: ListTile(
                  leading: Icon(game.icon, size: 32),
                  title: Text(game.title),
                  subtitle: Text(
                    game.available ? game.tagline : 'Bald verfügbar',
                  ),
                  enabled: game.available,
                  onTap: game.available
                      ? () => context.go(Routes.game(game.key))
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
