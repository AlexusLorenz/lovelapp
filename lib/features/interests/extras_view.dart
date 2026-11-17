import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/remote_image.dart';
import 'extras_providers.dart';
import 'interest_catalog.dart';

/// Interessen, Lieblingsspiele und -musik auf der Profilseite.
/// Lädt selbst; zeigt nichts, solange (oder falls) nichts da ist.
class ProfileExtrasSection extends ConsumerWidget {
  const ProfileExtrasSection({super.key, required this.profileId});

  final String profileId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final extras = ref.watch(profileExtrasProvider(profileId)).value;
    if (extras == null || extras.isEmpty) return const SizedBox.shrink();
    return ProfileExtrasView(extras: extras);
  }
}

class ProfileExtrasView extends StatelessWidget {
  const ProfileExtrasView({super.key, required this.extras});

  final ProfileExtras extras;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final interests = [for (final k in extras.interests) ?interestByKey(k)];
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(text, style: theme.textTheme.headlineSmall),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (interests.isNotEmpty) ...[
          heading('Interessen'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final i in interests) Chip(label: Text(i.display))],
          ),
        ],
        if (extras.games.isNotEmpty) ...[
          heading('Lieblingsspiele'),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: extras.games.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _GameCard(game: extras.games[i]),
            ),
          ),
        ],
        if (extras.artists.isNotEmpty) ...[
          heading('Lieblingsmusik'),
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: extras.artists.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, i) =>
                  _ArtistBubble(artist: extras.artists[i]),
            ),
          ),
          Text('Künstlerdaten von Spotify', style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({required this.game});

  final FavoriteGame game;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 150,
              height: 96,
              child: RemoteImage(url: game.coverUrl, fallbackLabel: game.name),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              game.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ArtistBubble extends StatelessWidget {
  const _ArtistBubble({required this.artist});

  final FavoriteArtist artist;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${artist.name} auf Spotify öffnen',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => launchUrl(
          Uri.parse(artist.spotifyUrl),
          mode: LaunchMode.externalApplication,
        ),
        child: SizedBox(
          width: 84,
          child: Column(
            children: [
              ClipOval(
                child: SizedBox.square(
                  dimension: 72,
                  child: RemoteImage(
                    url: artist.imageUrl,
                    fallbackLabel: artist.name,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  artist.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Einstiege im Bearbeiten-Bildschirm.
class ExtrasEditTiles extends ConsumerWidget {
  const ExtrasEditTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final e = ref.watch(ownExtrasProvider).value ?? ProfileExtras.empty;
    String summary(List<String> names, String empty) => names.isEmpty
        ? empty
        : names.length <= 3
        ? names.join(', ')
        : '${names.take(3).join(', ')} +${names.length - 3}';

    Widget tile(IconData icon, String title, String subtitle, String route) =>
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Icon(icon, color: LovelColors.terracotta),
            title: Text(title),
            subtitle: Text(subtitle, maxLines: 2),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(route),
          ),
        );

    return Column(
      children: [
        tile(
          Icons.interests_outlined,
          'Interessen',
          summary([
            for (final k in e.interests) ?interestByKey(k)?.display,
          ], 'Wähle aus über 450 Hobbys und Vorlieben'),
          Routes.editInterests,
        ),
        tile(
          Icons.sports_esports_outlined,
          'Lieblingsspiele',
          summary([for (final g in e.games) g.name], 'Bis zu 6 mit Cover'),
          Routes.editGames,
        ),
        tile(
          Icons.music_note_outlined,
          'Lieblingsmusik',
          summary([
            for (final a in e.artists) a.name,
          ], 'Künstler:innen suchen oder per Spotify'),
          Routes.editMusic,
        ),
      ],
    );
  }
}
