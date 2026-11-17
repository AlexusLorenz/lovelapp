import 'package:material_ui/material_ui.dart';

import '../progress/level.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  /// Demo-Wert, später aus `profiles.xp`.
  static const _demoXp = 240;

  @override
  Widget build(BuildContext context) {
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
          const ListTile(
            leading: Icon(Icons.edit),
            title: Text('Profil bearbeiten'),
          ),
          const ListTile(leading: Icon(Icons.tune), title: Text('Suchfilter')),
          const ListTile(
            leading: Icon(Icons.privacy_tip_outlined),
            title: Text('Privatsphäre & Einwilligungen'),
          ),
        ],
      ),
    );
  }
}
