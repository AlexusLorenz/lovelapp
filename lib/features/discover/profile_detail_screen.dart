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
                      : ProfileImageView(image: profile.photos.first),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  20,
                  20,
                  showActions ? 120 : 32,
                ),
                sliver: SliverList.list(children: _content(context, profile)),
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

  List<Widget> _content(BuildContext context, PublicProfile profile) {
    final theme = Theme.of(context);
    final extraPhotos = profile.photos.skip(1).toList();
    final prompts = profile.prompts;

    // Fragen und weitere Bilder abwechselnd, damit es lebendig bleibt.
    final mixed = <Widget>[];
    final count = prompts.length > extraPhotos.length
        ? prompts.length
        : extraPhotos.length;
    for (var i = 0; i < count; i++) {
      if (i < prompts.length) mixed.add(_PromptCard(answer: prompts[i]));
      if (i < extraPhotos.length) mixed.add(_PhotoTile(art: extraPhotos[i]));
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
      const SizedBox(height: 16),
      for (final w in mixed) ...[w, const SizedBox(height: 16)],
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: ProfileImageView(image: art),
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
