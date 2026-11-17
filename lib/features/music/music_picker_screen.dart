import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/env.dart';
import '../../core/widgets/remote_image.dart';
import '../interests/extras_providers.dart';
import '../interests/favorites_picker.dart';
import '../session/session_controller.dart';
import 'spotify_auth.dart';
import 'spotify_browser.dart';

const _pendingKey = 'lovel.spotify.pending';
const _resultKey = 'lovel.spotify.result';

/// Lieblingskünstler:innen: per Spotify-Verbindung (Top-Liste) oder Suche.
class MusicPickerScreen extends ConsumerStatefulWidget {
  const MusicPickerScreen({super.key});

  @override
  ConsumerState<MusicPickerScreen> createState() => _MusicPickerScreenState();
}

class _MusicPickerScreenState extends ConsumerState<MusicPickerScreen> {
  List<FavoriteArtist> _top = const [];
  bool _loadingTop = false;
  String? _spotifyError;

  @override
  void initState() {
    super.initState();
    _finishSpotifyLogin();
  }

  /// Nach dem Rücksprung von Spotify: Ergebnis aus dem Browser holen.
  Future<void> _finishSpotifyLogin() async {
    final raw = readStorage(_resultKey);
    final pendingRaw = readStorage(_pendingKey);
    if (raw == null) return;
    removeStorage(_resultKey);
    removeStorage(_pendingKey);
    if (pendingRaw == null) return;
    setState(() => _loadingTop = true);
    try {
      final top = await fetchSpotifyTopArtists(
        callback: SpotifyCallback.fromJson(
          jsonDecode(raw) as Map<String, Object?>,
        ),
        pending: SpotifyPending.fromJson(
          jsonDecode(pendingRaw) as Map<String, Object?>,
        ),
        clientId: Env.spotifyClientId,
        redirectUri: Env.spotifyRedirectUrl,
      );
      if (!mounted) return;
      setState(() {
        _top = top;
        _spotifyError = top.isEmpty
            ? 'Spotify kennt noch keine Lieblingskünstler:innen von dir.'
            : null;
      });
    } on SpotifyFailure catch (e) {
      if (mounted) setState(() => _spotifyError = e.message);
    } on Exception {
      if (mounted) {
        setState(() => _spotifyError = 'Spotify gerade nicht erreichbar.');
      }
    } finally {
      if (mounted) setState(() => _loadingTop = false);
    }
  }

  void _connectSpotify() {
    final pending = SpotifyPending.create();
    writeStorage(_pendingKey, jsonEncode(pending.toJson()));
    redirectTo(
      spotifyAuthorizeUrl(
        clientId: Env.spotifyClientId,
        redirectUri: Env.spotifyRedirectUrl,
        pending: pending,
      ).toString(),
    );
  }

  Widget _spotifyHeader() {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Mit Spotify verbinden', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Wir lesen einmalig deine meistgehörten Künstler:innen als '
              'Vorschlag. Danach speichern wir nur, was du auswählst – keinen '
              'Zugang zu deinem Konto.',
            ),
            const SizedBox(height: 12),
            if (_loadingTop)
              const LinearProgressIndicator()
            else
              FilledButton.icon(
                onPressed: _connectSpotify,
                icon: const Icon(Icons.graphic_eq),
                label: Text(
                  _top.isEmpty ? 'Spotify verbinden' : 'Erneut abrufen',
                ),
              ),
            if (_spotifyError != null) ...[
              const SizedBox(height: 8),
              Text(_spotifyError!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        // Neu aufbauen, sobald die Spotify-Vorschläge da sind.
        key: ValueKey(_top.length),
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
        header: Env.spotifyConnectEnabled ? _spotifyHeader() : null,
        suggestions: _top,
        suggestionsTitle: 'Deine Top-Künstler:innen auf Spotify',
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
