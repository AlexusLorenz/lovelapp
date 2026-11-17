import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/env.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/demo_data.dart';
import '../economy/like_quota.dart';
import '../economy/like_quota_controller.dart';
import '../location/location_prompt.dart';
import '../session/session_controller.dart';
import 'discover_providers.dart';
import 'discover_repository.dart';
import 'match_overlay.dart';
import 'photo_gallery.dart';
import 'public_profile.dart';
import 'swipe_card.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  /// Neu pro Karte, damit jede Karte frisch (ungedreht) startet.
  GlobalKey<SwipeCardState> _cardKey = GlobalKey();
  String? _cardFor;

  bool _canSwipe(SwipeDirection direction) =>
      direction == SwipeDirection.left || ref.read(likeQuotaProvider).canLike;

  void _showSnack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));

  void _onSwiped(PublicProfile profile, SwipeDirection direction) {
    // Karte sofort weg – der Server-Aufruf läuft im Hintergrund.
    ref.read(discoverFeedProvider.notifier).dismiss(profile.id);
    if (direction == SwipeDirection.right) {
      _like(profile);
    } else {
      ref.read(discoverRepositoryProvider).pass(profile.id).catchError((_) {});
    }
  }

  Future<void> _like(PublicProfile profile) async {
    final quota = ref.read(likeQuotaProvider.notifier);
    try {
      final result = await ref
          .read(discoverRepositoryProvider)
          .like(profile.id);
      if (result.remaining != null) {
        quota.applyServerRemaining(result.remaining!);
      } else {
        quota.tryUseLike();
      }
      if (result.matched && mounted) {
        ref.invalidate(matchesProvider);
        await _showMatch(profile);
      }
    } on DiscoverFailure catch (e) {
      if (e.quotaExhausted) quota.markExhausted();
      if (mounted) _showSnack(e.message);
    }
  }

  Future<void> _showMatch(PublicProfile profile) async {
    final me = ref.read(ownSummaryProvider).value;
    final result = await showMatchOverlay(
      context,
      myName: me?.displayName ?? demoMyName,
      myPhoto: Env.hasSupabase ? null : demoMyPhoto,
      matchName: profile.name,
      matchPhoto: profile.photos.isEmpty ? null : profile.photos.first,
    );
    if (!mounted) return;
    if (result == MatchOverlayResult.playGame) {
      context.push(Routes.games);
    }
  }

  Future<void> _openProfile(PublicProfile profile) async {
    final choice = await context.push<SwipeDirection>(
      Routes.person(profile.id, withActions: true),
    );
    if (choice != null && mounted) {
      await _cardKey.currentState?.swipe(choice);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quota = ref.watch(likeQuotaProvider);
    final feed = ref.watch(discoverFeedProvider);
    final hasLocation = ref.watch(
      ownSummaryProvider.select((s) => s.value?.hasLocation ?? true),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entdecken'),
        actions: [
          _QuotaChip(quota: quota),
          const SizedBox(width: 12),
        ],
      ),
      body: !hasLocation
          ? LocationPrompt(
              onSaved: () {
                ref.invalidate(ownSummaryProvider);
                ref.read(discoverFeedProvider.notifier).reload();
              },
            )
          : feed.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Message(
                text: e is DiscoverFailure
                    ? e.message
                    : 'Profile konnten nicht geladen werden.',
                onRetry: () => ref.read(discoverFeedProvider.notifier).reload(),
              ),
              data: (profiles) => profiles.isEmpty
                  ? _Message(
                      text:
                          'Das war’s für heute in deiner Nähe. '
                          'Schau später wieder vorbei!',
                      onRetry: () =>
                          ref.read(discoverFeedProvider.notifier).reload(),
                    )
                  : _buildDeck(profiles, quota),
            ),
    );
  }

  Widget _buildDeck(List<PublicProfile> profiles, LikeQuota quota) {
    final current = profiles.first;
    final next = profiles.length > 1 ? profiles[1] : null;
    if (_cardFor != current.id) {
      _cardFor = current.id;
      _cardKey = GlobalKey();
    }
    final demoBonus = ref.read(likeQuotaProvider.notifier).canGrantDemoBonus;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Nächste Karte liegt leicht verkleinert dahinter.
                if (next != null)
                  Positioned.fill(
                    child: Transform.scale(
                      scale: 0.95,
                      child: IgnorePointer(
                        child: _ProfileCard(
                          key: ValueKey('next-${next.id}'),
                          profile: next,
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: SwipeCard(
                    key: _cardKey,
                    canSwipe: _canSwipe,
                    onBlocked: (_) =>
                        _showSnack('Für heute sind deine Likes aufgebraucht.'),
                    onSwiped: (d) => _onSwiped(current, d),
                    child: _ProfileCard(
                      key: ValueKey(current.id),
                      profile: current,
                      onOpenProfile: () => _openProfile(current),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              FloatingActionButton.large(
                heroTag: 'pass',
                tooltip: 'Weiter',
                backgroundColor: LovelColors.cream,
                foregroundColor: LovelColors.umber,
                elevation: 1,
                onPressed: () =>
                    _cardKey.currentState?.swipe(SwipeDirection.left),
                child: const Icon(Icons.close),
              ),
              FloatingActionButton.large(
                heroTag: 'like',
                tooltip: 'Like',
                backgroundColor: quota.canLike
                    ? LovelColors.terracotta
                    : LovelColors.slate,
                foregroundColor: LovelColors.cream,
                elevation: 1,
                onPressed: quota.canLike
                    ? () => _cardKey.currentState?.swipe(SwipeDirection.right)
                    : null,
                child: const Icon(Icons.favorite),
              ),
            ],
          ),
          if (!quota.canLike && demoBonus)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: TextButton.icon(
                icon: const Icon(Icons.play_circle_outline),
                label: Text(
                  'Kurzes Video ansehen: '
                  '+${LikeQuotaRules.likesPerRewardedAd} Likes',
                ),
                // TODO(ads): AdMob Rewarded Ad anzeigen.
                onPressed: () =>
                    ref.read(likeQuotaProvider.notifier).grantRewardedAdBonus(),
              ),
            ),
        ],
      ),
    );
  }
}

class _QuotaChip extends StatelessWidget {
  const _QuotaChip({required this.quota});

  final LikeQuota quota;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.favorite, size: 18),
      label: Text('${quota.remaining}'),
    );
  }
}

/// Karte im Feed: Bilder formatfüllend, Name unten, Profil-Button unten rechts.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({super.key, required this.profile, this.onOpenProfile});

  final PublicProfile profile;
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subtitle = [
      if (profile.locationLabel.isNotEmpty) profile.locationLabel,
      'Level ${profile.level}',
    ].join(' · ');
    return Card(
      elevation: 2,
      shadowColor: const Color(0x33000000),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PhotoGallery(photos: profile.photos, name: profile.name),
          // Verlauf, damit der Text auf jedem Bild lesbar ist
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 200,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x00000000), Color(0xB3000000)],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 84,
            bottom: 20,
            child: IgnorePointer(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${profile.name}, ${profile.age}',
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: LovelColors.cream,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: LovelColors.cream,
                    ),
                  ),
                  if (profile.bio.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      profile.bio,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: LovelColors.cream,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (onOpenProfile != null)
            Positioned(
              right: 16,
              bottom: 16,
              child: IconButton.filled(
                tooltip: 'Profil öffnen',
                style: IconButton.styleFrom(
                  backgroundColor: LovelColors.cream,
                  foregroundColor: LovelColors.umber,
                  fixedSize: const Size.square(52),
                ),
                icon: const Icon(Icons.keyboard_arrow_up, size: 30),
                onPressed: onOpenProfile,
              ),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Neu laden')),
          ],
        ),
      ),
    );
  }
}
