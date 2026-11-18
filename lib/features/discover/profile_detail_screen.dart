import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../profile/profile_basics.dart';
import '../profile/profile_prompts.dart';
import 'discover_providers.dart';
import 'photo_gallery.dart';
import 'public_profile.dart';
import 'swipe_card.dart';
import '../../core/widgets/pinch_zoom.dart';
import '../interests/extras_providers.dart';
import '../safety/safety_actions.dart';
import '../session/session_controller.dart';
import '../interests/extras_view.dart';
import '../../core/widgets/profile_image.dart';

/// Ganzes Profil: Bilder, Text, Fragen und Steckbrief.
///
/// Mit [showActions] gibt es unten „Weiter“ und „Like“; die Wahl kommt per
/// `context.pop(SwipeDirection)` zurück an den Entdecken-Feed.
class ProfileDetailScreen extends ConsumerWidget {
  const ProfileDetailScreen({
    super.key,
    required this.profileId,
    this.showActions = false,
    this.preview,
  });

  final String profileId;
  final bool showActions;

  /// Fertiges Profil statt Laden über die ID – z. B. die eigene Vorschau.
  final AsyncValue<PublicProfile?>? preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PublicProfile?> async =
        preview ?? ref.watch(profileByIdProvider(profileId));
    if (async.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profile = async.value;
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Profil nicht gefunden.')),
      );
    }
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: MediaQuery.sizeOf(context).height * 0.6,
                pinned: true,
                backgroundColor: LovelColors.mist,
                leading: IconButton.filledTonal(
                  tooltip: 'Schließen',
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: () => context.pop(),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: profile.photos.isEmpty
                      ? PhotoGallery(photos: const [], name: profile.name)
                      : PinchZoom(
                          child: ProfileImageView(image: profile.photos.first),
                        ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  showActions ? 120 : 32,
                ),
                sliver: SliverList.list(
                  children: [
                    ..._content(
                      context,
                      profile,
                      ref.watch(profileExtrasProvider(profile.id)).value ??
                          ProfileExtras.empty,
                    ),
                    // Nicht beim eigenen Profil.
                    if (profile.id !=
                        ref.watch(sessionProvider.select((s) => s.user?.id)))
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.flag_outlined),
                          label: Text('${profile.name} melden'),
                          onPressed: () => reportProfile(context, ref, profile),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (showActions)
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    FloatingActionButton.large(
                      heroTag: 'detail-pass',
                      tooltip: 'Weiter',
                      backgroundColor: LovelColors.cream,
                      foregroundColor: LovelColors.umber,
                      onPressed: () => context.pop(SwipeDirection.left),
                      child: const Icon(Icons.close),
                    ),
                    FloatingActionButton.large(
                      heroTag: 'detail-like',
                      tooltip: 'Like',
                      backgroundColor: LovelColors.terracotta,
                      foregroundColor: LovelColors.cream,
                      onPressed: () => context.pop(SwipeDirection.right),
                      child: const Icon(Icons.favorite),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    PublicProfile profile,
    ProfileExtras extras,
  ) {
    final theme = Theme.of(context);
    final photos = profile.photos.skip(1).iterator;
    final prompts = profile.prompts.iterator;

    // Reihenfolge: Interessen · Foto · Spiele · Musik · Foto, danach immer
    // abwechselnd Frage und Foto. Leere Bereiche fallen weg.
    final blocks = <Widget>[];
    void photo() {
      if (photos.moveNext()) blocks.add(_PhotoTile(art: photos.current));
    }

    if (extras.interests.isNotEmpty) {
      blocks.add(InterestsBlock(keys: extras.interests));
    }
    photo();
    final hasFavorites = extras.games.isNotEmpty || extras.artists.isNotEmpty;
    if (extras.games.isNotEmpty) blocks.add(GamesBlock(games: extras.games));
    if (extras.artists.isNotEmpty) {
      blocks.add(MusicBlock(artists: extras.artists));
    }
    if (hasFavorites) photo();
    var morePrompts = prompts.moveNext();
    var morePhotos = true;
    while (morePrompts || morePhotos) {
      if (morePrompts) {
        blocks.add(_PromptCard(answer: prompts.current));
        morePrompts = prompts.moveNext();
      }
      morePhotos = photos.moveNext();
      if (morePhotos) blocks.add(_PhotoTile(art: photos.current));
    }

    return [
      Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              '${profile.name}, ${profile.age}',
              style: theme.textTheme.displaySmall,
            ),
          ),
          Chip(label: Text('Level ${profile.level}')),
        ],
      ),
      const SizedBox(height: 4),
      Row(
        children: [
          const Icon(Icons.place_outlined, size: 18, color: LovelColors.umber),
          const SizedBox(width: 4),
          Text(
            profile.distanceKm == null
                ? profile.city
                : '${profile.locationLabel} entfernt',
          ),
        ],
      ),
      if (profile.bio.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text(profile.bio, style: theme.textTheme.bodyLarge),
      ],
      if (!profile.basics.isEmpty) ...[
        const SizedBox(height: 24),
        Text('Steckbrief', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        BasicsChips(basics: profile.basics),
      ],
      const SizedBox(height: 24),
      for (final w in blocks) ...[w, const SizedBox(height: 24)],
    ];
  }
}

class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.answer});

  final PromptAnswer answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              answer.question,
              style: theme.textTheme.titleSmall?.copyWith(
                color: LovelColors.umber,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              answer.answer,
              style: theme.textTheme.titleLarge?.copyWith(
                color: LovelColors.ink,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.art});

  final ProfileImage art;

  @override
  Widget build(BuildContext context) {
    return PinchZoom(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: ProfileImageView(image: art),
        ),
      ),
    );
  }
}

/// Steckbrief als Chips mit Symbolen.
class BasicsChips extends StatelessWidget {
  const BasicsChips({super.key, required this.basics});

  final ProfileBasics basics;

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String)>[
      if (basics.heightCm != null) (Icons.straighten, '${basics.heightCm} cm'),
      if (basics.relationshipGoal != null)
        (Icons.favorite_border, basics.relationshipGoal!.label),
      if (basics.children != null)
        (Icons.child_friendly_outlined, basics.children!.label),
      if (basics.smoking != null)
        (Icons.smoking_rooms_outlined, basics.smoking!.label),
      if (basics.drinking != null)
        (Icons.local_bar_outlined, basics.drinking!.label),
      if (basics.exercise != null)
        (Icons.fitness_center, basics.exercise!.label),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (icon, label) in items)
          Chip(
            avatar: Icon(icon, size: 18, color: LovelColors.umber),
            label: Text(label),
          ),
      ],
    );
  }
}
