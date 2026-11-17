import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../data/demo_data.dart';

class MatchesScreen extends StatelessWidget {
  const MatchesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Matches')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: demoMatches.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          final match = demoMatches[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Text(match.profile.name.characters.first),
              ),
              title: Text('${match.profile.name}, ${match.profile.age}'),
              subtitle: Text(
                match.gamePending
                    ? 'Wartet auf dich: This or That'
                    : 'Level ${match.profile.level}',
              ),
              trailing: IconButton(
                tooltip: 'Eisbrecher-Spiel',
                icon: const Icon(Icons.sports_esports),
                onPressed: () => context.push(Routes.games),
              ),
              onTap: () => context.go(Routes.chat(match.id)),
            ),
          );
        },
      ),
    );
  }
}
