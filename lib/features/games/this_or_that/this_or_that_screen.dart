import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'this_or_that.dart';

/// Spielbare Demo von „This or That“ gegen einen simulierten Match-Partner.
///
/// TODO(backend): Echte Runde über `game_sessions`/`game_moves` + Realtime.
class ThisOrThatScreen extends StatefulWidget {
  const ThisOrThatScreen({super.key});

  @override
  State<ThisOrThatScreen> createState() => _ThisOrThatScreenState();
}

class _ThisOrThatScreenState extends State<ThisOrThatScreen> {
  static const _me = 'me';
  static const _partner = 'partner';

  late ThisOrThatRound _round;

  @override
  void initState() {
    super.initState();
    _newRound();
  }

  void _newRound() {
    _round = ThisOrThatRound(defaultThisOrThatQuestions);
    // Demo-Partner antwortet zufällig.
    final random = math.Random();
    for (var i = 0; i < _round.questions.length; i++) {
      _round.answer(_partner, random.nextBool() ? Choice.a : Choice.b);
    }
  }

  void _pick(Choice choice) => setState(() => _round.answer(_me, choice));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = _round.isFinishedFor(_me);
    final step = _round.answersOf(_me).length;

    return Scaffold(
      appBar: AppBar(title: const Text('This or That')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: done ? _buildResult(theme) : _buildQuestion(theme, step),
      ),
    );
  }

  Widget _buildQuestion(ThemeData theme, int step) {
    final question = _round.questions[step];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LinearProgressIndicator(value: step / _round.questions.length),
        const SizedBox(height: 32),
        Text(
          'Frage ${step + 1} von ${_round.questions.length}',
          textAlign: TextAlign.center,
        ),
        const Spacer(),
        _OptionButton(label: question.optionA, onTap: () => _pick(Choice.a)),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            'oder',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
        ),
        _OptionButton(label: question.optionB, onTap: () => _pick(Choice.b)),
        const Spacer(),
      ],
    );
  }

  Widget _buildResult(ThemeData theme) {
    final percent = _round.matchPercent(_me, _partner);
    final shared = _round.sharedPicks(_me, _partner);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Text(
          '$percent %',
          textAlign: TextAlign.center,
          style: theme.textTheme.displayMedium,
        ),
        const Text('Übereinstimmung', textAlign: TextAlign.center),
        const SizedBox(height: 24),
        if (shared.isNotEmpty) ...[
          Text('Ihr seid euch einig bei:', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final s in shared) Chip(label: Text(s))],
          ),
        ],
        const Spacer(),
        FilledButton(
          onPressed: () => setState(_newRound),
          child: const Text('Nochmal spielen'),
        ),
      ],
    );
  }
}

class _OptionButton extends StatelessWidget {
  const _OptionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonal(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 28),
        textStyle: Theme.of(context).textTheme.headlineSmall,
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }
}
