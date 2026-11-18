import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../session/session_controller.dart';
import 'quiz_providers.dart';
import 'quiz_widgets.dart';

enum _Phase { loading, choose, question, proposed, results, nothingToDo }

/// Eine Runde spielen: Kategorie wählen, vorschlagen oder entscheiden.
class QuizPlayScreen extends ConsumerStatefulWidget {
  const QuizPlayScreen({super.key, required this.gameId});

  final String gameId;

  @override
  ConsumerState<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends ConsumerState<QuizPlayScreen>
    with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.loading;
  QuizGameState? _game;
  QuizQuestionView? _view;
  final _views = <QuizQuestionView>[];
  List<QuizRoundOutcome> _results = const [];
  int? _picked;
  bool _sending = false;
  String? _error;
  Timer? _timeout;
  late final AnimationController _clock = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _timeout?.cancel();
    _clock.dispose();
    super.dispose();
  }

  String get _partner => _game?.summary.myTeam.partner?.name ?? 'Partner:in';

  Future<void> _guard(Future<void> Function() run) async {
    try {
      await run();
    } on QuizFailure catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _load() => _guard(() async {
    final game = await ref.read(quizRepositoryProvider).state(widget.gameId);
    if (!mounted) return;
    _game = game;
    final round = game.currentRound;
    switch (game.summary.action) {
      case QuizAction.choose:
        setState(() => _phase = _Phase.choose);
      case QuizAction.propose:
        await _show(round?.myProposed ?? 0);
      case QuizAction.decide:
        await _show(round?.myDecided ?? 0);
      default:
        setState(() => _phase = _Phase.nothingToDo);
    }
  });

  Future<void> _choose(String category) => _guard(() async {
    setState(() => _phase = _Phase.loading);
    await ref
        .read(quizRepositoryProvider)
        .chooseCategory(widget.gameId, category);
    await _show(0);
  });

  Future<void> _show(int index) async {
    final view = await ref
        .read(quizRepositoryProvider)
        .showQuestion(widget.gameId, index);
    if (!mounted) return;
    _timeout?.cancel();
    final left = view.secondsLeft.clamp(0, quizSecondsPerQuestion);
    _clock
      ..duration = const Duration(seconds: quizSecondsPerQuestion)
      ..value = 1 - left / quizSecondsPerQuestion
      ..forward();
    // Zeit abgelaufen → keine Antwort.
    _timeout = Timer(
      Duration(seconds: left),
      () => _answer(-1, timedOut: true),
    );
    setState(() {
      _view = view;
      _picked = null;
      _phase = _Phase.question;
      _views.add(view);
    });
  }

  /// [choice]: gewählte Antwort; [number]: Schätzung. Bei abgelaufener Zeit
  /// wird im Schätzduell die bis dahin eingetippte Zahl nicht gewertet.
  Future<void> _answer(int choice, {num? number, bool timedOut = false}) async {
    final view = _view;
    if (view == null || _sending) return;
    _timeout?.cancel();
    _clock.stop();
    setState(() {
      _sending = true;
      _picked = choice;
    });
    await _guard(() async {
      final reply = await ref
          .read(quizRepositoryProvider)
          .answer(
            widget.gameId,
            view.index,
            choice: choice,
            number: timedOut ? null : number,
          );
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      if (view.index < quizQuestionsPerRound - 1) {
        await _show(view.index + 1);
      } else {
        ref
          ..invalidate(quizGameProvider(widget.gameId))
          ..invalidate(quizGamesProvider);
        setState(() {
          _results = reply.results;
          _phase = view.role == QuizAction.decide
              ? _Phase.results
              : _Phase.proposed;
        });
      }
    });
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(quizCategoriesProvider).value ?? const {};
    return Scaffold(
      appBar: AppBar(
        title: Text('Runde ${_game?.summary.round ?? ''}'),
        leading: IconButton(
          tooltip: 'Schließen',
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _error != null
            ? _Message(
                title: 'Hoppla',
                text: _error!,
                actions: [
                  FilledButton(
                    onPressed: () => context.pop(),
                    child: const Text('Zurück'),
                  ),
                ],
              )
            : switch (_phase) {
                _Phase.loading => const Center(
                  child: CircularProgressIndicator(),
                ),
                _Phase.nothingToDo => _Message(
                  title: 'Gerade nichts zu tun',
                  text: 'Ihr seid gerade nicht an der Reihe.',
                  actions: [
                    FilledButton(
                      onPressed: () => context.pop(),
                      child: const Text('Zurück'),
                    ),
                  ],
                ),
                _Phase.choose => _ChooseCategory(
                  options: _game?.currentRound?.options ?? const [],
                  categories: categories,
                  partner: _partner,
                  onChoose: _choose,
                ),
                _Phase.question => _QuestionView(
                  view: _view!,
                  clock: _clock,
                  picked: _picked,
                  partner: _partner,
                  category: categories[_view!.category],
                  onAnswer: _sending ? null : (i) => _answer(i),
                  onEstimate: _sending
                      ? null
                      : (n) => _answer(n == null ? -1 : 0, number: n),
                ),
                _Phase.proposed => _Message(
                  title: _game?.summary.kind == QuizKind.soulmate
                      ? 'Antworten abgegeben!'
                      : 'Vorschläge abgegeben!',
                  text: _game?.summary.kind == QuizKind.soulmate
                      ? 'Jetzt ist $_partner dran und muss deine Antworten '
                            'erraten. Die Auflösung seht ihr danach in der '
                            'Spielübersicht.'
                      : '$_partner sieht jetzt deine Vorschläge und entscheidet. '
                            'Die Auflösung seht ihr danach in der Spielübersicht.',
                  actions: [
                    FilledButton(
                      onPressed: () => context.pop(),
                      child: const Text('Zur Übersicht'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        final match = _game?.summary.myTeam.matchId;
                        context.pop();
                        if (match != null) context.go(Routes.chat(match));
                      },
                      icon: const Icon(Icons.chat_bubble_outline),
                      label: Text('$_partner Bescheid sagen'),
                    ),
                  ],
                ),
                _Phase.results => _Results(
                  views: _views,
                  results: _results,
                  partner: _partner,
                  onDone: () => context.pop(),
                ),
              },
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.title,
    required this.text,
    this.actions = const [],
  });

  final String title;
  final String text;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTheme.displayFont,
              fontSize: 34,
              color: LovelColors.umber,
            ),
          ),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
          const SizedBox(height: 24),
          for (final a in actions)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: a),
        ],
      ),
    ),
  );
}

class _ChooseCategory extends StatelessWidget {
  const _ChooseCategory({
    required this.options,
    required this.categories,
    required this.partner,
    required this.onChoose,
  });

  final List<String> options;
  final Map<String, QuizCategory> categories;
  final String partner;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const Text(
        'Wähle eine Kategorie',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: AppTheme.displayFont,
          fontSize: 34,
          color: LovelColors.umber,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        'Das andere Team spielt danach dieselben Fragen. '
        'Wähl was, worin ihr – also auch $partner – gut seid.',
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 24),
      for (final key in options)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SizedBox(
            height: 72,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: LovelColors.umber,
                foregroundColor: LovelColors.cream,
                textStyle: const TextStyle(fontSize: 20),
              ),
              onPressed: () => onChoose(key),
              child: Text(categories[key]?.display ?? key),
            ),
          ),
        ),
    ],
  );
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    required this.view,
    required this.clock,
    required this.picked,
    required this.partner,
    required this.category,
    required this.onAnswer,
    required this.onEstimate,
  });

  final QuizQuestionView view;
  final Animation<double> clock;
  final int? picked;
  final String partner;
  final QuizCategory? category;
  final ValueChanged<int>? onAnswer;
  final ValueChanged<num?>? onEstimate;

  /// Hinweis unter der Frage – je nach Spiel und Rolle.
  String? _hint() {
    final deciding = view.role == QuizAction.decide;
    switch (view.kind) {
      case QuizKind.soulmate:
        return deciding
            ? 'Was hat $partner über sich geantwortet? Rate!'
            : 'Antworte ehrlich über dich – $partner muss es erraten.';
      case QuizKind.estimate:
        if (!deciding) {
          return 'Deine Schätzung – $partner kann sie noch ändern.';
        }
        return view.proposalNumber == null
            ? '$partner hatte keine Zeit mehr für eine Schätzung.'
            : '$partner schätzt ${formatQuizNumber(view.proposalNumber)} '
                  '${view.unit ?? ''}. Übernimm oder ändere die Zahl.';
      case QuizKind.quiz || QuizKind.emoji:
        if (!deciding) return null;
        return (view.proposal ?? -1) < 0
            ? '$partner hatte keine Zeit mehr für einen Vorschlag.'
            : 'Markiert: der Vorschlag von $partner. '
                  'Ohne Auswahl zählt der Vorschlag.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final deciding = view.role == QuizAction.decide;
    final hint = _hint();
    final roleLabel = switch ((view.kind, deciding)) {
      (QuizKind.soulmate, false) => 'Über dich',
      (QuizKind.soulmate, true) => 'Du rätst',
      (_, true) => 'Du entscheidest',
      _ => 'Du schlägst vor',
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${category?.display ?? ''} · Frage ${view.index + 1}/'
                '$quizQuestionsPerRound',
                style: theme.textTheme.labelLarge,
              ),
            ),
            Text(
              roleLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: LovelColors.terracotta,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedBuilder(
          animation: clock,
          builder: (context, _) {
            final left = ((1 - clock.value) * quizSecondsPerQuestion).ceil();
            return Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: 1 - clock.value,
                      minHeight: 10,
                      color: left <= 5
                          ? LovelColors.unread
                          : LovelColors.terracotta,
                      backgroundColor: LovelColors.mist,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 32,
                  child: Text(
                    '$left',
                    textAlign: TextAlign.right,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                if (view.kind == QuizKind.emoji)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Was ist gemeint?',
                      style: theme.textTheme.labelLarge,
                    ),
                  ),
                Text(
                  view.question,
                  textAlign: TextAlign.center,
                  style: view.kind == QuizKind.emoji
                      ? const TextStyle(fontSize: 52, height: 1.2)
                      : theme.textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ),
        if (hint != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              hint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: 16),
        if (view.kind == QuizKind.estimate)
          _EstimateInput(
            unit: view.unit,
            initial: deciding ? view.proposalNumber : null,
            onSubmit: onEstimate,
          ),
        for (final (i, answer) in view.answers.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _AnswerButton(
              text: answer,
              picked: picked == i,
              proposedBy:
                  deciding && view.kind.showsProposal && view.proposal == i
                  ? partner
                  : null,
              onTap: onAnswer == null || picked != null
                  ? null
                  : () => onAnswer!(i),
            ),
          ),
      ],
    );
  }
}

/// Zahleneingabe fürs Schätzduell.
class _EstimateInput extends StatefulWidget {
  const _EstimateInput({
    required this.unit,
    required this.initial,
    required this.onSubmit,
  });

  final String? unit;
  final num? initial;
  final ValueChanged<num?>? onSubmit;

  @override
  State<_EstimateInput> createState() => _EstimateInputState();
}

class _EstimateInputState extends State<_EstimateInput> {
  late final _controller = TextEditingController(
    text: widget.initial == null ? '' : formatQuizNumber(widget.initial),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = parseQuizNumber(_controller.text);
    if (_controller.text.trim().isNotEmpty && value == null) {
      setState(() => _error = 'Bitte nur eine Zahl eingeben.');
      return;
    }
    widget.onSubmit?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTheme.displayFont,
            fontSize: 36,
            color: LovelColors.umber,
          ),
          decoration: InputDecoration(
            hintText: '?',
            suffixText: widget.unit,
            errorText: _error,
            filled: true,
            fillColor: LovelColors.cream,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: widget.onSubmit == null ? null : _submit,
          child: const Text('Schätzung abgeben'),
        ),
      ],
    );
  }
}

class _AnswerButton extends StatelessWidget {
  const _AnswerButton({
    required this.text,
    required this.picked,
    required this.proposedBy,
    required this.onTap,
  });

  final String text;
  final bool picked;
  final String? proposedBy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final proposed = proposedBy != null;
    return Semantics(
      button: true,
      label: proposed ? '$text, Vorschlag von $proposedBy' : text,
      excludeSemantics: true,
      child: Material(
        color: picked
            ? LovelColors.terracotta
            : proposed
            ? LovelColors.blush
            : LovelColors.cream,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: proposed ? LovelColors.terracotta : LovelColors.mist,
                width: proposed ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 17,
                      color: picked ? LovelColors.cream : LovelColors.ink,
                    ),
                  ),
                ),
                if (proposed)
                  Chip(
                    label: Text('$proposedBy'),
                    avatar: const Icon(Icons.lightbulb_outline, size: 16),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.views,
    required this.results,
    required this.partner,
    required this.onDone,
  });

  final List<QuizQuestionView> views;
  final List<QuizRoundOutcome> results;
  final String partner;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kind = views.isEmpty ? QuizKind.quiz : views.last.kind;
    final points = results.fold(0, (s, r) => s + r.points);
    final headline = switch (kind) {
      QuizKind.estimate => '$points von ${results.length * 3} Punkten',
      QuizKind.soulmate =>
        '${results.where((r) => r.correct).length} von '
            '${results.length} Treffern',
      _ => '$points von ${results.length} richtig',
    };
    QuizQuestionView? viewFor(int i) {
      for (final v in views.reversed) {
        if (v.index == i) return v;
      }
      return null;
    }

    String choice(QuizQuestionView v, int? i) =>
        i == null || i < 0 || i >= v.answers.length
        ? 'keine Antwort'
        : v.answers[i];

    List<Widget> details(QuizQuestionView v, QuizRoundOutcome r) =>
        switch (kind) {
          QuizKind.estimate => [
            Text(
              'Richtig: ${formatQuizNumber(r.numberAnswer)} ${r.unit ?? ''}',
            ),
            Text(
              'Ihr: ${formatQuizNumber(r.finalNumber)} ${r.unit ?? ''} · '
              '+${r.points} ${r.points == 1 ? 'Punkt' : 'Punkte'}',
            ),
            if (r.proposalNumber != null && r.proposalNumber != r.finalNumber)
              Text(
                'Schätzung von $partner: ${formatQuizNumber(r.proposalNumber)}',
                style: theme.textTheme.bodySmall,
              ),
          ],
          QuizKind.soulmate => [
            Text('$partner: ${choice(v, r.proposal)}'),
            Text('Dein Tipp: ${choice(v, r.finalChoice)}'),
          ],
          _ => [
            if (r.correctIndex != null)
              Text('Richtig: ${choice(v, r.correctIndex)}'),
            if (!r.correct) Text('Ihr: ${choice(v, r.finalChoice)}'),
            if (r.proposal != null &&
                r.proposal! >= 0 &&
                r.proposal != r.finalChoice)
              Text(
                'Vorschlag von $partner: ${choice(v, r.proposal)}',
                style: theme.textTheme.bodySmall,
              ),
          ],
        };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          headline,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppTheme.displayFont,
            fontSize: 36,
            color: LovelColors.umber,
          ),
        ),
        const SizedBox(height: 16),
        for (final r in results)
          if (viewFor(r.index) case final v?)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          r.correct ? Icons.check_circle : Icons.cancel,
                          color: r.correct ? quizGreen : LovelColors.unread,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            v.question,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ...details(v, r),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 16),
        FilledButton(onPressed: onDone, child: const Text('Zur Übersicht')),
      ],
    );
  }
}
