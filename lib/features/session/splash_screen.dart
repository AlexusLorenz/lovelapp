import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/widgets/lovel_logo.dart';
import 'session_controller.dart';

/// Wird gezeigt, während die Sitzung geprüft wird – oder wenn das scheitert.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final failed = session.status == SessionStatus.error;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LovelLogo(size: 48),
              const SizedBox(height: 32),
              if (!failed)
                const CircularProgressIndicator()
              else ...[
                const Text(
                  'Wir erreichen den Server gerade nicht.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.read(sessionProvider.notifier).reload(),
                  child: const Text('Noch mal versuchen'),
                ),
                TextButton(
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                  child: const Text('Abmelden'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
