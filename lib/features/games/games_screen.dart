import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import 'game_catalog.dart';

class GamesScreen extends StatelessWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Eisbrecher-Spiele')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final game in GameCatalog.all)
            Card(
              child: ListTile(
                leading: Icon(game.icon, size: 32),
                title: Text(game.title),
                subtitle: Text(
                  game.available ? game.tagline : 'Bald verfügbar',
                ),
                enabled: game.available,
                onTap: game.available
                    ? () => context.push(Routes.game(game.key))
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}
