import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import 'quiz_providers.dart';

const quizGreen = Color(0xFF3F8F5B);

/// Ein Punkt pro Frage: grün richtig, rot falsch, grau offen/verdeckt.
class QuizDot extends StatelessWidget {
  const QuizDot({super.key, this.correct, this.hidden = false});

  final bool? correct;

  /// Gegner hat gespielt, aber ich sehe es erst nach meiner Runde.
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final color = switch (correct) {
      true => quizGreen,
      false => LovelColors.unread,
      null => hidden ? LovelColors.slate : LovelColors.mist,
    };
    return Container(
      width: 18,
      height: 18,
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: LovelColors.slate.withValues(alpha: 0.5)),
      ),
      child: hidden && correct == null
          ? const Icon(Icons.question_mark, size: 12, color: LovelColors.cream)
          : null,
    );
  }
}

/// Kurztext zur nächsten Aktion für Listen.
String quizStatusText(QuizGameSummary g) {
  final partner = g.myTeam.partner?.name ?? 'Partner:in';
  return switch (g.action) {
    QuizAction.choose => 'Du bist dran: Kategorie wählen',
    QuizAction.propose => 'Du bist dran: Antworten vorschlagen',
    QuizAction.decide => 'Du bist dran: $partner hat vorgeschlagen',
    QuizAction.waitPartner => 'Wartet auf $partner',
    QuizAction.waitOpponent => '${g.opponent?.names ?? 'Gegner'} sind dran',
    QuizAction.searching =>
      g.inviteCode != null
          ? 'Einladungscode: ${g.inviteCode}'
          : 'Suche Gegnerteam …',
    QuizAction.finished => switch (g.won) {
      true => 'Gewonnen!',
      false => 'Verloren',
      null => 'Unentschieden',
    },
    QuizAction.abandoned => g.won == true ? 'Gegner hat aufgegeben' : 'Beendet',
  };
}

class QuizGameTile extends StatelessWidget {
  const QuizGameTile({super.key, required this.game, required this.onTap});

  final QuizGameSummary game;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final myTurn = game.action.isMyTurn;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: myTurn ? LovelColors.terracotta : LovelColors.mist,
          foregroundColor: myTurn ? LovelColors.cream : LovelColors.umber,
          child: const Icon(Icons.quiz_outlined),
        ),
        title: Text(
          '${game.myTeam.names} vs. ${game.opponent?.names ?? '?'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          quizStatusText(game),
          style: myTurn
              ? const TextStyle(
                  color: LovelColors.terracotta,
                  fontWeight: FontWeight.w600,
                )
              : null,
        ),
        trailing: Text(
          '${game.myScore} : ${game.opponentScore}',
          style: theme.textTheme.titleLarge?.copyWith(
            fontFamily: AppTheme.displayFont,
          ),
        ),
      ),
    );
  }
}
