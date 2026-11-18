import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../auth/auth_repository.dart';
import '../auth/auth_validation.dart';
import '../session/session_controller.dart';
import 'account_providers.dart';

/// Neues Passwort setzen – nach „Passwort vergessen“ oder aus dem Profil.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() =>
      _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      ref.read(passwordRecoveryProvider.notifier).done();
      messenger.showSnackBar(
        const SnackBar(content: Text('Neues Passwort gespeichert.')),
      );
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(Routes.discover);
      }
    } on AuthFailure catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recovering = ref.watch(passwordRecoveryProvider);
    final hasPassword = ref.watch(authRepositoryProvider).hasPasswordLogin;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          recovering || hasPassword ? 'Neues Passwort' : 'Passwort festlegen',
        ),
        leading: recovering
            ? IconButton(
                tooltip: 'Später',
                icon: const Icon(Icons.close),
                onPressed: () {
                  ref.read(passwordRecoveryProvider.notifier).done();
                  context.go(Routes.discover);
                },
              )
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              recovering
                  ? 'Du bist über den Link angemeldet. Wähle jetzt ein neues '
                        'Passwort.'
                  : hasPassword
                  ? 'Mindestens 10 Zeichen.'
                  : 'Damit kannst du dich zusätzlich mit E-Mail und Passwort '
                        'anmelden.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _password,
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Neues Passwort',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Anzeigen' : 'Verbergen',
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => validatePassword(v ?? ''),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _repeat,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Wiederholen',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v == _password.text
                  ? null
                  : 'Die Passwörter stimmen nicht überein.',
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );
  }
}
