import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/env.dart';
import '../../core/router/app_router.dart';
import '../discover/discover_providers.dart';
import '../location/location_prompt.dart';
import '../progress/level.dart';
import '../session/session_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  /// Demo-Wert, später aus `profiles.xp`.
  static const _demoXp = 240;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final progress = LevelProgress.fromXp(_demoXp);

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Level ${progress.level}',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress.fraction),
                  const SizedBox(height: 8),
                  Text(
                    'Noch ${progress.xpNeededForNext} XP bis Level '
                    '${progress.level + 1}',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('So sammelst du XP', style: theme.textTheme.titleMedium),
          for (final reason in XpReason.values)
            ListTile(
              dense: true,
              leading: const Icon(Icons.star_outline),
              title: Text(reason.label),
              trailing: Text('+${reason.amount} XP'),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Profil bearbeiten'),
            subtitle: const Text('Fragen, Steckbrief, Über mich'),
            onTap: () => context.push(Routes.editProfile),
          ),
          // Im Demo-Modus gibt es kein eigenes öffentliches Profil.
          if (Env.hasSupabase)
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('So sehen dich andere'),
              onTap: () {
                final id = ref.read(sessionProvider).user?.id;
                if (id != null) context.push(Routes.person(id));
              },
            ),
          const ListTile(leading: Icon(Icons.tune), title: Text('Suchfilter')),
          ListTile(
            leading: const Icon(Icons.near_me_outlined),
            title: const Text('Standort aktualisieren'),
            onTap: () => showModalBottomSheet<void>(
              context: context,
              showDragHandle: true,
              builder: (_) => Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                child: LocationPrompt(
                  compact: true,
                  onSaved: () {
                    ref.invalidate(ownSummaryProvider);
                    ref.read(discoverFeedProvider.notifier).reload();
                  },
                ),
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Privatsphäre & Einwilligungen'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Abmelden'),
            onTap: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }
}
