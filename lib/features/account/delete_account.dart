import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../auth/auth_repository.dart';
import '../session/session_controller.dart';

/// Fragt nach und löscht dann das Konto mit allen Daten.
Future<void> confirmAndDeleteAccount(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => const _DeleteDialog(),
  );
  if (confirmed != true || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(authRepositoryProvider).deleteAccount();
    messenger.showSnackBar(
      const SnackBar(content: Text('Dein Konto wurde gelöscht.')),
    );
  } on AuthFailure catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog();

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  static const _word = 'LÖSCHEN';
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _input.text.trim().toUpperCase() == _word;
    return AlertDialog(
      title: const Text('Konto löschen?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dein Profil, deine Fotos, Matches, Chats und Spielstände werden '
            'endgültig gelöscht. Das lässt sich nicht rückgängig machen.',
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _input,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Zum Bestätigen „$_word“ eingeben',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: LovelColors.unread),
          onPressed: ok ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Endgültig löschen'),
        ),
      ],
    );
  }
}
