import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import 'push_providers.dart';

String _subtitle(PushStatus? status) => switch (status) {
  PushStatus.on => 'An – du erfährst, wenn du dran bist',
  PushStatus.blocked =>
    'Im Browser blockiert – in den Website-Einstellungen erlauben',
  PushStatus.unsupported =>
    'Auf diesem Gerät noch nicht verfügbar '
        '(iPhone: App zum Home-Bildschirm hinzufügen)',
  _ => 'Neue Matches, Nachrichten und wenn du im Spiel dran bist',
};

/// Schalter in den Einstellungen.
class PushSettingTile extends ConsumerWidget {
  const PushSettingTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final push = ref.watch(pushProvider);
    final status = push.value;
    final usable =
        !push.isLoading &&
        status != PushStatus.unsupported &&
        status != PushStatus.blocked;
    return SwitchListTile(
      secondary: const Icon(Icons.notifications_outlined),
      title: const Text('Benachrichtigungen'),
      subtitle: Text(push.hasError ? push.error.toString() : _subtitle(status)),
      value: status == PushStatus.on,
      onChanged: usable
          ? (on) => ref.read(pushProvider.notifier).setEnabled(on)
          : null,
    );
  }
}

/// Hinweis im Spiele-Tab, solange Push aus ist: Ohne Push schlafen die
/// 2-gegen-2-Spiele ein.
class PushPromptCard extends ConsumerWidget {
  const PushPromptCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final push = ref.watch(pushProvider);
    if (push.value != PushStatus.off) return const SizedBox.shrink();
    return Card(
      color: LovelColors.cream,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(
              Icons.notifications_active_outlined,
              color: LovelColors.terracotta,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Benachrichtigungen an? Dann weißt du sofort, '
                'wann du im Spiel dran bist.',
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: push.isLoading
                  ? null
                  : () => ref.read(pushProvider.notifier).setEnabled(true),
              child: const Text('Aktivieren'),
            ),
          ],
        ),
      ),
    );
  }
}
