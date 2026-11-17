import 'package:flame/game.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/router/app_router.dart';
import '../../data/demo_data.dart';
import '../economy/like_quota.dart';
import '../economy/like_quota_controller.dart';
import '../games/flame/hearts_game.dart';

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

  void _showMatch(DemoProfile profile) {
    showDialog<void>(
      context: context,
      builder: (context) => _MatchDialog(profile: profile),
    );
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
                        onPressed: _next,
                        child: const Icon(Icons.close),
                      ),
                      FloatingActionButton.large(
                        heroTag: 'like',
                        tooltip: 'Like',
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
            child: ColoredBox(
              color: theme.colorScheme.primaryContainer,
              child: Center(
                child: Text(
                  profile.name.characters.first,
                  style: theme.textTheme.displayLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
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

class _MatchDialog extends StatefulWidget {
  const _MatchDialog({required this.profile});

  final DemoProfile profile;

  @override
  State<_MatchDialog> createState() => _MatchDialogState();
}

class _MatchDialogState extends State<_MatchDialog> {
  final _game = HeartsGame();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 360,
        child: Stack(
          children: [
            Positioned.fill(child: GameWidget(game: _game)),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Es ist ein Match!',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text('Du und ${widget.profile.name} mögt euch.'),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.sports_esports),
                    label: const Text('Eisbrecher-Spiel starten'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.push(Routes.games);
                    },
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Weiter entdecken'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
