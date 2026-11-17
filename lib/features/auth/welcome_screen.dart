import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/env.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';

/// Schriftzug „LOVEL“.
class LovelLogo extends StatelessWidget {
  const LovelLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      'LOVEL',
      semanticsLabel: 'Lovel',
      style: TextStyle(
        fontFamily: AppTheme.displayFont,
        fontSize: size,
        height: 1,
        letterSpacing: size * 0.06,
        color: LovelColors.terracotta,
      ),
    );
  }
}

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

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(),
                  const Center(child: LovelLogo()),
                  const SizedBox(height: 12),
                  Text(
                    'Erst spielen, dann daten.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: LovelColors.umber,
                    ),
                  ),
                  const Spacer(),
                  const DemoModeBanner(),
                  const SizedBox(height: 16),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () => context.push(Routes.signUp),
                    child: const Text('Konto erstellen'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      foregroundColor: LovelColors.umber,
                    ),
                    onPressed: () => context.push(Routes.signIn),
                    child: const Text('Ich habe schon ein Konto'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
