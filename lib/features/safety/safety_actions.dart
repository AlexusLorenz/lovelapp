import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../discover/discover_providers.dart';
import '../discover/public_profile.dart';
import '../session/session_controller.dart';
import 'safety_repository.dart';

/// Nach Blockieren: Listen neu laden und den Chat/das Profil verlassen.
void _afterBlock(BuildContext context, WidgetRef ref) {
  ref
    ..invalidate(matchesProvider)
    ..invalidate(receivedLikesProvider)
    ..invalidate(discoverFeedProvider);
  if (context.mounted) context.go(Routes.chats);
}

Future<void> blockProfile(
  BuildContext context,
  WidgetRef ref,
  PublicProfile profile,
) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('${profile.name} blockieren?'),
      content: Text(
        'Euer Match und der Chat enden. Ihr seht euch nicht mehr – '
        '${profile.name} erfährt nicht, dass du blockiert hast.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Blockieren'),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(safetyRepositoryProvider).block(profile.id);
    messenger.showSnackBar(
      SnackBar(content: Text('${profile.name} ist blockiert.')),
    );
    if (context.mounted) _afterBlock(context, ref);
  } on SafetyFailure catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

Future<void> reportProfile(
  BuildContext context,
  WidgetRef ref,
  PublicProfile profile,
) async {
  final result = await showModalBottomSheet<_ReportInput>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _ReportSheet(name: profile.name),
  );
  if (result == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final safety = ref.read(safetyRepositoryProvider);
  try {
    await safety.report(profile.id, result.reason, details: result.details);
    if (result.alsoBlock) await safety.block(profile.id);
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Danke für deine Meldung. Wir schauen sie uns an.'),
      ),
    );
    if (result.alsoBlock && context.mounted) _afterBlock(context, ref);
  } on SafetyFailure catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

class _ReportInput {
  const _ReportInput(this.reason, this.details, this.alsoBlock);

  final ReportReason reason;
  final String details;
  final bool alsoBlock;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.name});

  final String name;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
  bool _alsoBlock = true;
  final _details = TextEditingController();

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.name} melden', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            const Text('Was ist passiert? Deine Meldung bleibt anonym.'),
            const SizedBox(height: 8),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (r) => setState(() => _reason = r),
              child: Column(
                children: [
                  for (final r in ReportReason.values)
                    RadioListTile<ReportReason>(
                      value: r,
                      title: Text(r.label),
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            TextField(
              controller: _details,
              maxLength: 2000,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(
                labelText: 'Details (freiwillig)',
                border: OutlineInputBorder(),
              ),
            ),
            CheckboxListTile(
              value: _alsoBlock,
              onChanged: (v) => setState(() => _alsoBlock = v ?? false),
              title: Text('${widget.name} auch blockieren'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _reason == null
                    ? null
                    : () => Navigator.of(
                        context,
                      ).pop(_ReportInput(_reason!, _details.text, _alsoBlock)),
                child: const Text('Meldung senden'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
