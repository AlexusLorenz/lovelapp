import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../session/session_controller.dart';
import 'quiz_providers.dart';
import 'quiz_start_sheet.dart';
import 'quiz_widgets.dart';

/// Spielstand eines Quizduells: Punkte, Runden, nächster Schritt.
class QuizGameScreen extends ConsumerWidget {
  const QuizGameScreen({super.key, required this.gameId});

  final String gameId;

  Future<void> _giveUp(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aufgeben?'),
        content: const Text(
          'Das andere Team gewinnt. Das gilt für dein ganzes Team.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Weiterspielen'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Aufgeben'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(quizRepositoryProvider).giveUp(gameId);
    } on QuizFailure catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
    ref
      ..invalidate(quizGameProvider(gameId))
      ..invalidate(quizGamesProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(quizGameProvider(gameId));
    final categories = ref.watch(quizCategoriesProvider).value ?? const {};
    return Scaffold(
      appBar: AppBar(
        title: Text(game.value?.summary.kind.title ?? 'Spiel'),
        leading: BackButton(onPressed: () => context.go(Routes.games)),
        actions: [
          if (game.value?.summary.action.isOver == false)
            PopupMenuButton<String>(
              tooltip: 'Mehr',
              onSelected: (_) => _giveUp(context, ref),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'give_up', child: Text('Aufgeben')),
              ],
            ),
        ],
      ),
      body: game.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (state) => RefreshIndicator(
          onRefresh: () => ref.refresh(quizGameProvider(gameId).future),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              _ScoreHeader(state: state),
              const SizedBox(height: 16),
              _NextStep(state: state),
              if (state.summary.inviteCode != null &&
                  state.summary.opponent == null &&
                  state.summary.action != QuizAction.searching)
                _InviteCode(code: state.summary.inviteCode!),
              const SizedBox(height: 16),
              for (var r = 1; r <= quizRounds; r++)
                _RoundRow(
                  kind: state.summary.kind,
                  number: r,
                  round: r <= state.rounds.length ? state.rounds[r - 1] : null,
                  categories: categories,
                  isCurrent:
                      r == state.summary.round && !state.summary.action.isOver,
                ),
              const SizedBox(height: 8),
              Text(
                'Tippe auf eine gespielte Runde, um Fragen und Antworten zu sehen.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreHeader extends StatelessWidget {
  const _ScoreHeader({required this.state});

  final QuizGameState state;

  @override
  Widget build(BuildContext context) {
    final s = state.summary;
    Widget team(String label, String names) => Expanded(
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 4),
          Text(
            names,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            team('Ihr', s.myTeam.names),
            Text(
              '${s.myScore} : ${s.opponentScore}',
              style: const TextStyle(
                fontFamily: AppTheme.displayFont,
                fontSize: 44,
                color: LovelColors.terracotta,
              ),
            ),
            team('Gegner', s.opponent?.names ?? '…'),
          ],
        ),
      ),
    );
  }
}

class _NextStep extends ConsumerWidget {
  const _NextStep({required this.state});

  final QuizGameState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final s = state.summary;
    final partner = s.myTeam.partner?.name ?? 'Partner:in';
    final round = state.currentRound;

    Widget box(
      String title,
      String text, {
      List<Widget> actions = const [],
    }) => Card(
      color: s.action.isMyTurn ? LovelColors.blush : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(text),
            if (actions.isNotEmpty) ...[const SizedBox(height: 12), ...actions],
          ],
        ),
      ),
    );

    final play = FilledButton.icon(
      onPressed: () => context.push(Routes.quizPlay(s.id)),
      icon: const Icon(Icons.play_arrow),
      label: Text(switch ((s.action, s.kind)) {
        (QuizAction.choose, _) => 'Kategorie wählen',
        (QuizAction.propose, QuizKind.estimate) => 'Jetzt schätzen',
        (QuizAction.propose, QuizKind.soulmate) => 'Fragen beantworten',
        (QuizAction.propose, _) => 'Antworten vorschlagen',
        (_, QuizKind.soulmate) => 'Jetzt raten',
        _ => 'Jetzt entscheiden',
      }),
    );
    final soulmate = s.kind == QuizKind.soulmate;
    final toChat = OutlinedButton.icon(
      onPressed: () => context.go(Routes.chat(s.myTeam.matchId)),
      icon: const Icon(Icons.chat_bubble_outline),
      label: Text('$partner schreiben'),
    );

    return switch (s.action) {
      QuizAction.choose => box(
        'Runde ${s.round}: Du wählst die Kategorie',
        soulmate
            ? 'Danach beantwortest du drei Fragen ehrlich über dich – '
                  '$partner muss deine Antworten erraten.'
            : 'Danach schlägst du für alle drei Fragen eine Antwort vor, '
                  '$partner entscheidet. 30 Sekunden pro Frage.',
        actions: [play],
      ),
      QuizAction.propose => box(
        soulmate
            ? 'Runde ${s.round}: Du antwortest über dich'
            : 'Runde ${s.round}: Du schlägst vor',
        soulmate
            ? 'Beantworte drei Fragen ehrlich. $partner sieht deine '
                  'Antworten nicht und muss sie erraten.'
            : '$partner sieht deine Vorschläge und trifft die Entscheidung. '
                  '30 Sekunden pro Frage.',
        actions: [play],
      ),
      QuizAction.decide => box(
        soulmate
            ? 'Runde ${s.round}: Du rätst'
            : 'Runde ${s.round}: Du entscheidest',
        soulmate
            ? '$partner hat drei Fragen über sich beantwortet. Wie gut '
                  'kennst du $partner?'
            : '$partner hat Antworten vorgeschlagen. Übernimm sie oder wähle '
                  'selbst – deine Antwort zählt.',
        actions: [play],
      ),
      QuizAction.waitPartner => box(
        'Wartet auf $partner',
        round?.category == null ||
                (round?.myProposed ?? 0) < quizQuestionsPerRound
            ? (soulmate
                  ? '$partner beantwortet gerade Fragen über sich.'
                  : '$partner wählt die Kategorie und schlägt Antworten vor.')
            : (soulmate
                  ? '$partner rät gerade deine Antworten.'
                  : '$partner entscheidet gerade über deine Vorschläge.'),
        actions: [toChat],
      ),
      QuizAction.waitOpponent => box(
        '${s.opponent?.names ?? 'Das andere Team'} ist dran',
        'Ihr bekommt Bescheid, sobald ihr wieder spielen könnt.',
      ),
      QuizAction.searching when s.inviteCode != null => Column(
        children: [
          box(
            'Wartet auf das andere Paar',
            'Eure erste Runde ist gespielt. Sobald das eingeladene Paar den '
                'Code eingibt, geht es weiter.',
          ),
          _InviteCode(code: s.inviteCode!),
        ],
      ),
      QuizAction.searching => box(
        'Wir suchen ein Gegnerteam',
        'Eure erste Runde ist gespielt. Sobald sich ein anderes Paar meldet, '
            'geht es weiter.',
      ),
      QuizAction.finished || QuizAction.abandoned => box(
        quizStatusText(s),
        s.action == QuizAction.abandoned
            ? 'Das Spiel wurde vorzeitig beendet.'
            : 'Endstand ${s.myScore} : ${s.opponentScore}. '
                  'Lust auf eine Revanche?',
        actions: [
          FilledButton.icon(
            onPressed: () => showQuizStartSheet(
              context,
              matchId: s.myTeam.matchId,
              kind: s.kind,
            ),
            icon: const Icon(Icons.replay),
            label: const Text('Neues Spiel'),
          ),
        ],
      ),
    };
  }
}

class _RoundRow extends StatelessWidget {
  const _RoundRow({
    required this.kind,
    required this.number,
    required this.round,
    required this.categories,
    required this.isCurrent,
  });

  final QuizKind kind;
  final int number;
  final QuizRoundState? round;
  final Map<String, QuizCategory> categories;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final r = round;
    final category = r?.category == null ? null : categories[r!.category];
    final slots = r?.questions ?? const <QuizQuestionSlot>[];
    QuizQuestionSlot? slot(int i) => i < slots.length ? slots[i] : null;

    final mine = [
      for (var i = 0; i < quizQuestionsPerRound; i++)
        QuizDot(
          correct: slot(i)?.mine?.correct,
          points: kind == QuizKind.estimate ? slot(i)?.mine?.points : null,
        ),
    ];
    final theirs = [
      for (var i = 0; i < quizQuestionsPerRound; i++)
        QuizDot(
          correct: slot(i)?.opponent?.correct,
          points: kind == QuizKind.estimate ? slot(i)?.opponent?.points : null,
          hidden: (r?.opponentDone ?? false) && slot(i)?.opponent == null,
        ),
    ];
    final canReview = r != null && r.myDone;

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      shape: isCurrent
          ? RoundedRectangleBorder(
              side: const BorderSide(color: LovelColors.terracotta, width: 2),
              borderRadius: BorderRadius.circular(12),
            )
          : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: canReview
            ? () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => _RoundReview(
                  kind: kind,
                  number: number,
                  round: r,
                  category: category,
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Row(mainAxisSize: MainAxisSize.min, children: mine),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      'Runde $number',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    Text(
                      category?.display ??
                          (r == null ? '–' : 'Kategorie offen'),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: theirs),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundReview extends StatelessWidget {
  const _RoundReview({
    required this.kind,
    required this.number,
    required this.round,
    required this.category,
  });

  final QuizKind kind;
  final int number;
  final QuizRoundState round;
  final QuizCategory? category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            'Runde $number · ${category?.display ?? ''}',
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          for (final slot in round.questions)
            if (slot.review case final review?)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.question,
                      style: kind == QuizKind.emoji
                          ? const TextStyle(fontSize: 32)
                          : theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    if (kind == QuizKind.estimate)
                      _EstimateReview(review: review, slot: slot)
                    else
                      for (final (i, answer) in review.answers.indexed)
                        _ReviewAnswer(
                          text: answer,
                          correct: kind.hasRightAnswer
                              ? i == review.correctIndex
                              // Seelenverwandt: „richtig“ = was die
                              // Partnerin über sich gesagt hat.
                              : i == slot.mine?.proposal,
                          ours: slot.mine?.finalChoice == i,
                          proposed:
                              kind.hasRightAnswer && slot.mine?.proposal == i,
                          theirs: slot.opponent?.finalChoice == i,
                          oursLabel: kind == QuizKind.soulmate
                              ? 'Tipp'
                              : 'eure Antwort',
                        ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _EstimateReview extends StatelessWidget {
  const _EstimateReview({required this.review, required this.slot});

  final QuizReview review;
  final QuizQuestionSlot slot;

  @override
  Widget build(BuildContext context) {
    final unit = review.unit ?? '';
    String pts(int? p) => p == null ? '' : ' · +$p';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Richtig: ${formatQuizNumber(review.numberAnswer)} $unit',
          style: const TextStyle(color: quizGreen, fontWeight: FontWeight.w600),
        ),
        Text(
          'Ihr: ${formatQuizNumber(slot.mine?.finalNumber)} $unit'
          '${pts(slot.mine?.points)}',
        ),
        if (slot.opponent != null)
          Text(
            'Gegner: ${formatQuizNumber(slot.opponent?.finalNumber)} $unit'
            '${pts(slot.opponent?.points)}',
          ),
      ],
    );
  }
}

class _ReviewAnswer extends StatelessWidget {
  const _ReviewAnswer({
    this.oursLabel = 'eure Antwort',
    required this.text,
    required this.correct,
    required this.ours,
    required this.proposed,
    required this.theirs,
  });

  final String oursLabel;
  final String text;
  final bool correct;
  final bool ours;
  final bool proposed;
  final bool theirs;

  @override
  Widget build(BuildContext context) {
    final tags = [
      if (ours) oursLabel,
      if (proposed && !ours) 'Vorschlag',
      if (theirs) 'Gegner',
    ];
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: correct
            ? quizGreen.withValues(alpha: 0.15)
            : ours
            ? LovelColors.unread.withValues(alpha: 0.12)
            : null,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: correct ? quizGreen : LovelColors.mist),
      ),
      child: Row(
        children: [
          Icon(
            correct ? Icons.check_circle : Icons.circle_outlined,
            size: 18,
            color: correct ? quizGreen : LovelColors.slate,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
          if (tags.isNotEmpty)
            Text(
              tags.join(' · '),
              style: Theme.of(context).textTheme.labelSmall,
            ),
        ],
      ),
    );
  }
}

class _InviteCode extends StatelessWidget {
  const _InviteCode({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Euer Einladungscode',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text(
            'Schick ihn an ein befreundetes Paar. Sie tippen ihn unter '
            '„Spiele → Code eingeben“ ein.',
            textAlign: TextAlign.center,
          ),
          SelectableText(
            code,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTheme.displayFont,
              fontSize: 40,
              letterSpacing: 6,
              color: LovelColors.umber,
            ),
          ),
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Code kopiert.')));
            },
            icon: const Icon(Icons.copy),
            label: const Text('Kopieren'),
          ),
        ],
      ),
    ),
  );
}
