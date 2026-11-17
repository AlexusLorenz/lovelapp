import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../discover/discover_providers.dart';
import '../location/location_prompt.dart';
import '../../core/theme/app_theme.dart';
import '../photos/photos_repository.dart';
import '../progress/level.dart';
import 'own_profile_providers.dart';
import 'widgets/completion_avatar.dart';
import '../session/session_controller.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final own = ref.watch(ownProfileProvider).value;
    final photos = ref.watch(ownPhotosProvider).value ?? const <OwnPhoto>[];
    final completion = ref.watch(profileCompletionProvider);
    final progress = LevelProgress.fromXp(own?.xp ?? 0);
    final name = own?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Profil')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      CompletionAvatar(
                        name: name,
                        image: photos.isEmpty ? null : photos.first.image,
                        percent: completion?.percent ?? 0,
                        onTap: () => context.push(Routes.ownPreview),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              [
                                if (name.isNotEmpty) name,
                                if (own?.age != null) '${own!.age}',
                              ].join(', '),
                              style: theme.textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Level ${progress.level}',
                              style: theme.textTheme.titleMedium,
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: progress.fraction,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Noch ${progress.xpNeededForNext} XP bis Level '
                              '${progress.level + 1}',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (completion?.nextTip != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          Icons.lightbulb_outline,
                          color: LovelColors.umber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(completion!.nextTip!)),
                        TextButton(
                          onPressed: () => context.push(Routes.editProfile),
                          child: const Text('Los'),
                        ),
                      ],
                    ),
                  ],
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
            subtitle: const Text('Fotos, Fragen, Steckbrief, Über mich'),
            onTap: () => context.push(Routes.editProfile),
          ),
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('So sehen dich andere'),
            onTap: () => context.push(Routes.ownPreview),
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
