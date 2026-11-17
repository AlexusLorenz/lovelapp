import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../session/session_controller.dart';
import 'auth_repository.dart';
import 'auth_validation.dart';
import 'welcome_screen.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _accepted = false;
  bool _showAcceptError = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  /// Gesetzt, wenn die Bestätigungsmail verschickt wurde.
  String? _confirmationSentTo;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formOk = _formKey.currentState!.validate();
    setState(() => _showAcceptError = !_accepted);
    if (!formOk || !_accepted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final outcome = await ref
          .read(authRepositoryProvider)
          .signUp(email: _email.text, password: _password.text);
      if (outcome == SignUpOutcome.confirmEmail && mounted) {
        setState(() => _confirmationSentTo = _email.text.trim());
      }
      // Bei signedIn leitet der Router zum Onboarding weiter.
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Konto erstellen')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _confirmationSentTo != null
                  ? _CheckYourMail(email: _confirmationSentTo!)
                  : _buildForm(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return AutofillGroup(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const DemoModeBanner(),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              decoration: const InputDecoration(
                labelText: 'E-Mail',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              validator: validateEmail,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              decoration: InputDecoration(
                labelText: 'Passwort',
                helperText: 'Mindestens $minPasswordLength Zeichen',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: _obscure
                      ? 'Passwort anzeigen'
                      : 'Passwort verbergen',
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              obscureText: _obscure,
              autofillHints: const [AutofillHints.newPassword],
              textInputAction: TextInputAction.next,
              validator: validatePassword,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _repeat,
              decoration: const InputDecoration(
                labelText: 'Passwort wiederholen',
                border: OutlineInputBorder(),
              ),
              obscureText: _obscure,
              validator: (v) => validatePasswordRepeat(v, _password.text),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _accepted,
              onChanged: (v) => setState(() {
                _accepted = v ?? false;
                if (_accepted) _showAcceptError = false;
              }),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Ich bin mindestens 18 Jahre alt und akzeptiere die AGB '
                'und die Datenschutzerklärung.',
              ),
              subtitle: _showAcceptError
                  ? Text(
                      'Bitte bestätigen.',
                      style: TextStyle(color: errorColor),
                    )
                  : null,
            ),
            Wrap(
              spacing: 8,
              children: [
                TextButton(
                  onPressed: () => context.push(Routes.terms),
                  child: const Text('AGB lesen'),
                ),
                TextButton(
                  onPressed: () => context.push(Routes.privacy),
                  child: const Text('Datenschutz lesen'),
                ),
              ],
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: errorColor)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Konto erstellen'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckYourMail extends StatelessWidget {
  const _CheckYourMail({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        const Icon(
          Icons.mark_email_unread_outlined,
          size: 72,
          color: LovelColors.terracotta,
        ),
        const SizedBox(height: 16),
        Text('Fast geschafft!', style: theme.textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(
          'Wir haben dir eine E-Mail an $email geschickt. '
          'Klick auf den Link darin, um dein Konto zu bestätigen. '
          'Danach kannst du dich anmelden.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // Supabase verrät aus Datenschutzgründen nicht, ob es die Adresse
        // schon gibt – dann kommt auch keine Mail. Darauf hinweisen.
        Text(
          'Keine Mail bekommen? Schau im Spam-Ordner nach. Wenn du schon ein '
          'Konto hast – auch über Google oder Apple –, melde dich einfach '
          'darüber an.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => context.go(Routes.signIn),
          child: const Text('Zur Anmeldung'),
        ),
      ],
    );
  }
}
