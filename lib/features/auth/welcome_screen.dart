import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/env.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/lovel_logo.dart';
import '../session/session_controller.dart';
import 'auth_repository.dart';
import 'test_account_picker.dart';
import 'test_accounts.dart';

/// Hinweis, dass im Demo-Modus nichts gespeichert wird.
class DemoModeBanner extends StatelessWidget {
  const DemoModeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    if (Env.hasSupabase) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: LovelColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: LovelColors.slate),
      ),
      child: const Row(
        children: [
          Icon(Icons.science_outlined, color: LovelColors.umber),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Demo-Modus: Du kannst alles ausprobieren, '
              'es wird aber nichts gespeichert.',
            ),
          ),
        ],
      ),
    );
  }
}

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  SocialProvider? _busy;
  String? _busyTestEmail;
  String? _error;

  Future<void> _testLogin(TestAccount account) async {
    setState(() {
      _busyTestEmail = account.email;
      _error = null;
    });
    try {
      await ref
          .read(authRepositoryProvider)
          .signIn(email: account.email, password: Env.testLoginPassword);
      // Weiter geht es über die Router-Weiterleitung.
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busyTestEmail = null);
    }
  }

  Future<void> _social(SocialProvider provider) async {
    setState(() {
      _busy = provider;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithProvider(provider);
      // Weiter geht es, sobald die Sitzung da ist (Router-Weiterleitung).
    } on AuthFailure catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const padding = EdgeInsets.symmetric(vertical: 16);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Spacer(),
                          const Center(child: LovelLogo(size: 64)),
                          const SizedBox(height: 12),
                          Text(
                            'Erst spielen, dann daten.',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: LovelColors.umber,
                            ),
                          ),
                          const Spacer(),
                          const SizedBox(height: 24),
                          const DemoModeBanner(),
                          if (testAccountsEnabled) ...[
                            TestAccountPicker(
                              busyEmail: _busyTestEmail,
                              onPick: _testLogin,
                            ),
                            const SizedBox(height: 16),
                          ],
                          const SizedBox(height: 16),
                          if (Env.appleLoginEnabled) ...[
                            // Apple-Vorgaben: schwarzer Button mit Apple-Symbol.
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                padding: padding,
                                backgroundColor: Colors.black,
                                foregroundColor: Colors.white,
                              ),
                              icon: _busy == SocialProvider.apple
                                  ? const _Spinner(color: Colors.white)
                                  : const Icon(Icons.apple),
                              label: const Text('Mit Apple fortfahren'),
                              onPressed: _busy == null
                                  ? () => _social(SocialProvider.apple)
                                  : null,
                            ),
                            const SizedBox(height: 8),
                          ],
                          // TODO(branding): Offizielles Google-Logo laut
                          // Google-Branding-Richtlinien einsetzen.
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: padding,
                              backgroundColor: Colors.white,
                              foregroundColor: LovelColors.ink,
                              side: const BorderSide(color: LovelColors.slate),
                            ),
                            icon: _busy == SocialProvider.google
                                ? const _Spinner(color: LovelColors.ink)
                                : const SizedBox.shrink(),
                            label: const Text('Mit Google fortfahren'),
                            onPressed: _busy == null
                                ? () => _social(SocialProvider.google)
                                : null,
                          ),
                          const SizedBox(height: 16),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 12),
                                child: Text('oder'),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 16),
                          if (Env.inviteOnly)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Geschlossene Testphase: Anmeldung nur mit Einladung.',
                                textAlign: TextAlign.center,
                              ),
                            )
                          else ...[
                            FilledButton(
                              style: FilledButton.styleFrom(padding: padding),
                              onPressed: () => context.push(Routes.signUp),
                              child: const Text('Mit E-Mail registrieren'),
                            ),
                            const SizedBox(height: 8),
                          ],
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: padding,
                              foregroundColor: LovelColors.umber,
                            ),
                            onPressed: () => context.push(Routes.signIn),
                            child: const Text('Ich habe schon ein Konto'),
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Text.rich(
                            TextSpan(
                              text:
                                  'Mit dem Fortfahren bestätigst du, dass du '
                                  'mindestens 18 Jahre alt bist, und akzeptierst '
                                  'die ',
                              children: [
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: _InlineLink(
                                    text: 'AGB',
                                    onTap: () => context.push(Routes.terms),
                                  ),
                                ),
                                const TextSpan(text: ' und die '),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: _InlineLink(
                                    text: 'Datenschutzerklärung',
                                    onTap: () => context.push(Routes.privacy),
                                  ),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 18,
    child: CircularProgressIndicator(strokeWidth: 2, color: color),
  );
}

class _InlineLink extends StatelessWidget {
  const _InlineLink({required this.text, required this.onTap});

  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      child: GestureDetector(
        onTap: onTap,
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: LovelColors.terracotta,
            decoration: TextDecoration.underline,
            decorationColor: LovelColors.terracotta,
          ),
        ),
      ),
    );
  }
}
