import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/widgets/remote_image.dart';
import '../interests/extras_providers.dart';
import '../interests/favorites_picker.dart';
import '../session/session_controller.dart';

/// Lieblingskünstler:innen selbst auswählen (Suche über Spotify).
class MusicPickerScreen extends ConsumerWidget {
  const MusicPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = ref.watch(ownExtrasProvider);
    final userId = ref.watch(sessionProvider.select((s) => s.user?.id));
    return extras.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('Lieblingsmusik')),
        body: Center(child: Text('$e')),
      ),
      data: (e) => FavoritesPicker<FavoriteArtist>(
        title: 'Lieblingsmusik',
        initial: e?.artists ?? const [],
        max: maxFavoriteArtists,
        searchHint: 'Künstler:in oder Band suchen',
        search: ref.read(catalogSearchProvider).searchArtists,
        nameOf: (a) => a.name,
        thumbnail: (a) => RemoteImage(url: a.imageUrl, fallbackLabel: a.name),
        onSave: (artists) async {
          if (userId == null) return;
          await ref.read(extrasRepositoryProvider).saveArtists(userId, artists);
          ref.invalidate(profileExtrasProvider(userId));
        },
        attribution: const SpotifyAttribution(),
      ),
    );
  }
}

/// Spotify verlangt eine sichtbare Quellenangabe mit Link.
class SpotifyAttribution extends StatelessWidget {
  const SpotifyAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        icon: const Icon(Icons.open_in_new, size: 16),
        label: const Text('Künstlerdaten und Bilder von Spotify'),
        onPressed: () => launchUrl(
          Uri.parse('https://open.spotify.com'),
          mode: LaunchMode.externalApplication,
        ),
      ),
    );
  }
}
