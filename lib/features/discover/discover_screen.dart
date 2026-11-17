import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../data/demo_data.dart';
import '../economy/like_quota.dart';
import '../economy/like_quota_controller.dart';
import 'match_overlay.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  int _index = 0;

  DemoProfile? get _current =>
      _index < demoProfiles.length ? demoProfiles[_index] : null;

  void _next() => setState(() => _index++);

  void _like() {
    final profile = _current;
    if (profile == null) return;
    final ok = ref.read(likeQuotaProvider.notifier).tryUseLike();
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Für heute sind deine Likes aufgebraucht.'),
        ),
      );
      return;
    }
    if (profile.likesYouBack) {
      _showMatch(profile);
    }
    _next();
  }

  Future<void> _showMatch(DemoProfile profile) async {
    final result = await showMatchOverlay(
      context,
      myName: demoMyName,
      matchName: profile.name,
    );
    if (!mounted) return;
    if (result == MatchOverlayResult.playGame) {
      context.push(Routes.games);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quota = ref.watch(likeQuotaProvider);
    final profile = _current;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entdecken'),
        actions: [
          _QuotaChip(quota: quota),
          const SizedBox(width: 12),
        ],
      ),
      body: profile == null
          ? const _EmptyState()
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Expanded(child: _ProfileCard(profile: profile)),
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
                        onPressed: _next,
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
                        onPressed: quota.canLike ? _like : null,
                        child: const Icon(Icons.favorite),
                      ),
                    ],
                  ),
                  if (!quota.canLike && quota.canWatchAdForBonus)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextButton.icon(
                        icon: const Icon(Icons.play_circle_outline),
                        label: Text(
                          'Kurzes Video ansehen: '
                          '+${LikeQuotaRules.likesPerRewardedAd} Likes',
                        ),
                        // TODO(ads): AdMob Rewarded Ad anzeigen.
                        onPressed: () => ref
                            .read(likeQuotaProvider.notifier)
                            .grantRewardedAdBonus(),
                      ),
                    ),
                ],
              ),
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile});

  final DemoProfile profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [LovelColors.slate, LovelColors.mist],
                ),
              ),
              child: Center(
                child: Text(
                  profile.name.characters.first,
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: LovelColors.cream,
                    fontSize: 120,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${profile.name}, ${profile.age}',
                        style: theme.textTheme.headlineSmall,
                      ),
                    ),
                    Chip(label: Text('Level ${profile.level}')),
                  ],
                ),
                Text('${profile.city} · ${profile.distanceKm} km entfernt'),
                const SizedBox(height: 8),
                Text(profile.bio),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Das war’s für heute in deiner Nähe. Schau morgen wieder vorbei!',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
