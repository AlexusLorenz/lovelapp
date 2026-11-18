import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../discover/discover_providers.dart';
import '../matches/matches_repository.dart';
import '../session/session_controller.dart';
import 'quiz_providers.dart';

/// Neues Quizduell: Team (Match) wählen, dann Zufallsgegner oder Code.
/// [join]: statt neu zu starten einem Spiel per Code beitreten.
Future<void> showQuizStartSheet(
  BuildContext context, {
  String? matchId,
  bool join = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => _QuizStartSheet(matchId: matchId, join: join),
);

class _QuizStartSheet extends ConsumerStatefulWidget {
  const _QuizStartSheet({required this.matchId, required this.join});

  final String? matchId;
  final bool join;

  @override
  ConsumerState<_QuizStartSheet> createState() => _QuizStartSheetState();
}

class _QuizStartSheetState extends ConsumerState<_QuizStartSheet> {
  late String? _match = widget.matchId;
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _go({bool invite = false}) async {
    final match = _match;
    if (match == null || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(quizRepositoryProvider);
    try {
      final id = widget.join
          ? await repo.join(match, _code.text)
          : await repo.start(match, invite: invite);
      ref.invalidate(quizGamesProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      // Spielübersicht im Spiele-Tab öffnen.
      GoRouter.of(context).go(Routes.quizGame(id));
    } on QuizFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final matches = ref.watch(matchesProvider).value ?? const <MatchSummary>[];
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.join ? 'Mit Code beitreten' : 'Neues Quizduell',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            const Text(
              'Ihr spielt zu zweit als Team gegen ein anderes Paar. Jede Runde '
              'schlägt eine:r von euch Antworten vor, die andere Person '
              'entscheidet – ganz ohne gleichzeitig online sein zu müssen.',
            ),
            const SizedBox(height: 16),
            Text('Mit wem spielst du?', style: theme.textTheme.titleMedium),
            if (matches.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Du brauchst zuerst ein Match.'),
              ),
            RadioGroup<String>(
              groupValue: _match,
              onChanged: (v) => setState(() => _match = v),
              child: Column(
                children: [
                  for (final m in matches)
                    RadioListTile<String>(
                      value: m.matchId,
                      title: Text(m.profile.name),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            if (widget.join) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Code des anderen Teams',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 16),
            if (widget.join)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _match == null || _busy || _code.text.length != 6
                      ? null
                      : _go,
                  child: const Text('Beitreten'),
                ),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.shuffle),
                  onPressed: _match == null || _busy ? null : _go,
                  label: const Text('Zufälliges Gegnerteam'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.group_add_outlined),
                  onPressed: _match == null || _busy
                      ? null
                      : () => _go(invite: true),
                  label: const Text('Befreundetes Paar per Code einladen'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
