import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/remote_image.dart';
import 'extras_providers.dart';
import 'interest_catalog.dart';

/// Bausteine für die Profilseite. Die Reihenfolge (mit Fotos dazwischen)
/// legt die Profilseite fest.
class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
  );
}

class InterestsBlock extends StatelessWidget {
  const InterestsBlock({super.key, required this.keys});

  final List<String> keys;

  @override
  Widget build(BuildContext context) {
    final interests = [for (final k in keys) ?interestByKey(k)];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Heading('Interessen'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [for (final i in interests) Chip(label: Text(i.display))],
        ),
      ],
    );
  }
}

class GamesBlock extends StatelessWidget {
  const GamesBlock({super.key, required this.games});

  final List<FavoriteGame> games;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Heading('Lieblingsspiele'),
      SizedBox(
        height: 140,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: games.length,
          separatorBuilder: (_, _) => const SizedBox(width: 10),
          itemBuilder: (context, i) => _GameCard(game: games[i]),
        ),
      ),
    ],
  );
}

class MusicBlock extends StatelessWidget {
  const MusicBlock({super.key, required this.artists});

  final List<FavoriteArtist> artists;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _Heading('Lieblingsmusik'),
      SizedBox(
        height: 124,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: artists.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) => _ArtistBubble(artist: artists[i]),
        ),
      ),
      Text(
        'Künstlerdaten von Spotify',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
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
          ], 'Künstler:innen und Bands auswählen'),
          Routes.editMusic,
        ),
      ],
    );
  }
}
