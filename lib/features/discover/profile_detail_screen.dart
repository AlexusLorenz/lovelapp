import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/placeholder_photo.dart';
import '../../data/demo_data.dart';
import '../profile/profile_basics.dart';
import '../profile/profile_prompts.dart';
import 'public_profile.dart';
import 'swipe_card.dart';

/// Ganzes Profil: Bilder, Text, Fragen und Steckbrief.
///
/// Mit [showActions] gibt es unten „Weiter“ und „Like“; die Wahl kommt per
/// `context.pop(SwipeDirection)` zurück an den Entdecken-Feed.
class ProfileDetailScreen extends StatelessWidget {
  const ProfileDetailScreen({
    super.key,
    required this.profileId,
    this.showActions = false,
  });

  final String profileId;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    // TODO(backend): über get_public_profiles + profile_prompts laden.
    final profile = demoProfileById(profileId);
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
                      ? const ColoredBox(color: LovelColors.slate)
                      : PlaceholderPhoto(art: profile.photos.first),
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
          Text('${profile.city} · ${profile.distanceKm} km entfernt'),
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
              style: theme.textTheme.headlineSmall?.copyWith(
                color: LovelColors.ink,
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

  final PhotoArt art;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: PlaceholderPhoto(art: art),
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
