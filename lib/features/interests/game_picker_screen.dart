import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/remote_image.dart';
import '../session/session_controller.dart';
import 'extras_providers.dart';
import 'favorites_picker.dart';

/// Lieblingsspiele aus der RAWG-Datenbank (mit Covern).
class GamePickerScreen extends ConsumerWidget {
  const GamePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = ref.watch(ownExtrasProvider);
    final userId = ref.watch(sessionProvider.select((s) => s.user?.id));
    return extras.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Lieblingsspiele')),
        body: Center(child: Text('$e')),
      ),
      data: (e) => FavoritesPicker<FavoriteGame>(
        title: 'Lieblingsspiele',
        initial: e?.games ?? const [],
        max: maxFavoriteGames,
        searchHint: 'Spiel suchen, z. B. Zelda',
        search: ref.read(catalogSearchProvider).searchGames,
        nameOf: (g) => g.name,
        thumbnail: (g) => RemoteImage(url: g.coverUrl, fallbackLabel: g.name),
        onSave: (games) async {
          if (userId == null) return;
          await ref.read(extrasRepositoryProvider).saveGames(userId, games);
          ref.invalidate(profileExtrasProvider(userId));
        },
        attribution: const RawgAttribution(),
      ),
    );
  }
}

/// RAWG verlangt einen sichtbaren Link als Quellenangabe.
class RawgAttribution extends StatelessWidget {
  const RawgAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('Spieldaten und Bilder von RAWG'),
        onPressed: () => launchUrl(
          Uri.parse('https://rawg.io'),
          mode: LaunchMode.externalApplication,
        ),
      ),
    );
  }
}
