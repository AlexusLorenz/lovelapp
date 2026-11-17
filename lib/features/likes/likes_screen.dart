import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../discover/discover_providers.dart';
import '../discover/discover_repository.dart';
import '../discover/like_actions.dart';
import '../discover/photo_gallery.dart';
import '../discover/public_profile.dart';
import '../discover/swipe_card.dart';

/// Wer hat mich geliked? Für alle kostenlos sichtbar (kein Pay-to-win).
class LikesScreen extends ConsumerWidget {
  const LikesScreen({super.key});

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    PublicProfile profile,
  ) async {
    final choice = await context.push<SwipeDirection>(
      Routes.person(profile.id, withActions: true),
    );
    if (!context.mounted || choice == null) return;
    if (choice == SwipeDirection.right) {
      await likeProfile(context, ref, profile);
    } else {
      await passProfile(ref, profile);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likes = ref.watch(receivedLikesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Likes')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(receivedLikesProvider.future),
        child: likes.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Hint(
            text: e is DiscoverFailure
                ? e.message
                : 'Likes konnten nicht geladen werden.',
          ),
          data: (list) => list.isEmpty
              ? const _Hint(
                  icon: Icons.favorite_border,
                  text:
                      'Noch keine neuen Likes. Sobald dich jemand liked, '
                      'siehst du es hier – und kannst direkt zurückliken.',
                )
              : CustomScrollView(
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          list.length == 1
                              ? '1 Person mag dich'
                              : '${list.length} Personen mögen dich',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      sliver: SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 220,
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 3 / 4,
                            ),
                        itemCount: list.length,
                        itemBuilder: (context, i) => _LikeCard(
                          profile: list[i],
                          onTap: () => _open(context, ref, list[i]),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _LikeCard extends StatelessWidget {
  const _LikeCard({required this.profile, required this.onTap});

  final PublicProfile profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            IgnorePointer(
              child: PhotoGallery(
                photos: profile.photos.take(1).toList(),
                name: profile.name,
              ),
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 90,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xA6000000)],
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: Text(
                '${profile.name}, ${profile.age}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: LovelColors.cream,
                ),
              ),
            ),
            const Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: LovelColors.terracotta,
                child: Icon(Icons.favorite, size: 16, color: LovelColors.cream),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    // ListView, damit „nach unten ziehen zum Aktualisieren“ funktioniert.
    return ListView(
      padding: const EdgeInsets.all(32),
      children: [
        const SizedBox(height: 60),
        if (icon != null) Icon(icon, size: 56, color: LovelColors.slate),
        const SizedBox(height: 16),
        Text(text, textAlign: TextAlign.center),
      ],
    );
  }
}
