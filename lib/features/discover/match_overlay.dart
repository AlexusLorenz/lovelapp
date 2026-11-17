import 'package:flame/game.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/placeholder_photo.dart';
import '../../core/widgets/profile_photo.dart';
import '../games/flame/hearts_game.dart';

/// Was der Nutzer im Match-Overlay gewählt hat.
enum MatchOverlayResult { playGame, keepDiscovering }

/// Zeigt den Match-Moment als Vollbild-Overlay.
///
/// Ablauf: dunkles Overlay (50 %) → mein Bild fällt herein → das Bild des
/// Matches fällt darauf → „MATCH!“ fällt obendrauf → Text und Buttons
/// erscheinen. Dahinter fliegen Herzen über den ganzen Bildschirm.
Future<MatchOverlayResult?> showMatchOverlay(
  BuildContext context, {
  required String myName,
  required String matchName,
  PhotoArt? myPhoto,
  PhotoArt? matchPhoto,
}) {
  return showGeneralDialog<MatchOverlayResult>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Match',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 250),
    transitionBuilder: (context, animation, _, child) =>
        FadeTransition(opacity: animation, child: child),
    pageBuilder: (context, _, _) => MatchOverlay(
      myName: myName,
      matchName: matchName,
      myPhoto: myPhoto,
      matchPhoto: matchPhoto,
    ),
  );
}

class MatchOverlay extends StatefulWidget {
  const MatchOverlay({
    super.key,
    required this.myName,
    required this.matchName,
    this.myPhoto,
    this.matchPhoto,
  });

  final String myName;
  final String matchName;
  final PhotoArt? myPhoto;
  final PhotoArt? matchPhoto;

  /// Gesamtdauer der Choreografie.
  static const duration = Duration(milliseconds: 2200);

  @override
  State<MatchOverlay> createState() => _MatchOverlayState();
}

class _MatchOverlayState extends State<MatchOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MatchOverlay.duration,
  );

  final _hearts = HeartsGame(
    colors: const [
      LovelColors.terracotta,
      LovelColors.cream,
      LovelColors.slate,
      LovelColors.blush,
    ],
  );

  // Zeitfenster innerhalb der Gesamtdauer (0 … 1).
  late final _myPhoto = _interval(0.00, 0.40, Curves.bounceOut);
  late final _theirPhoto = _interval(0.18, 0.58, Curves.bounceOut);
  late final _matchDrop = _interval(0.52, 0.82, Curves.bounceOut);
  late final _matchScale = _interval(0.52, 0.90, Curves.elasticOut);
  late final _details = _interval(0.80, 1.00, Curves.easeOut);

  bool _started = false;

  Animation<double> _interval(double begin, double end, Curve curve) =>
      CurvedAnimation(
        parent: _controller,
        curve: Interval(begin, end, curve: curve),
      );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Barrierefreiheit: Bei „Bewegung reduzieren“ direkt den Endzustand zeigen.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close(MatchOverlayResult result) => Navigator.of(context).pop(result);

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (!reduceMotion) IgnorePointer(child: GameWidget(game: _hearts)),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 320,
                      height: 300,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          _Falling(
                            animation: _myPhoto,
                            fromY: -screenHeight,
                            offset: const Offset(-55, 10),
                            angle: -0.14,
                            child: ProfilePhoto(
                              name: widget.myName,
                              art: widget.myPhoto,
                            ),
                          ),
                          _Falling(
                            animation: _theirPhoto,
                            fromY: -screenHeight,
                            offset: const Offset(55, -5),
                            angle: 0.12,
                            child: ProfilePhoto(
                              name: widget.matchName,
                              variant: 1,
                              art: widget.matchPhoto,
                            ),
                          ),
                          _Falling(
                            animation: _matchDrop,
                            fromY: -screenHeight * 0.6,
                            offset: const Offset(0, 95),
                            angle: -0.07,
                            child: ScaleTransition(
                              scale: Tween<double>(
                                begin: 1.8,
                                end: 1,
                              ).animate(_matchScale),
                              child: const _MatchLettering(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    FadeTransition(
                      opacity: _details,
                      child: SlideTransition(
                        position: Tween(
                          begin: const Offset(0, 0.3),
                          end: Offset.zero,
                        ).animate(_details),
                        child: _Details(
                          matchName: widget.matchName,
                          onPlay: () => _close(MatchOverlayResult.playGame),
                          onContinue: () =>
                              _close(MatchOverlayResult.keepDiscovering),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lässt ein Kind von oben herabfallen und an [offset] landen.
class _Falling extends StatelessWidget {
  const _Falling({
    required this.animation,
    required this.fromY,
    required this.offset,
    required this.angle,
    required this.child,
  });

  final Animation<double> animation;
  final double fromY;
  final Offset offset;
  final double angle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final t = animation.value;
        return Transform.translate(
          offset: Offset(offset.dx, offset.dy + (1 - t) * fromY),
          child: Transform.rotate(
            // Im Fallen leicht stärker gedreht, beim Landen auf Endwinkel.
            angle: angle * (1 + (1 - t) * 0.8),
            child: Opacity(opacity: t == 0 ? 0 : 1, child: child),
          ),
        );
      },
    );
  }
}

class _MatchLettering extends StatelessWidget {
  const _MatchLettering();

  @override
  Widget build(BuildContext context) {
    // Komplett in Terrakotta; nur ein weicher Schatten hebt ihn von den
    // Bildern ab.
    return Semantics(
      label: 'Match!',
      child: const Text(
        'MATCH!',
        style: TextStyle(
          fontFamily: AppTheme.displayFont,
          fontSize: 104,
          height: 1,
          letterSpacing: 3,
          color: LovelColors.terracotta,
          shadows: [
            Shadow(
              color: Color(0x80000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({
    required this.matchName,
    required this.onPlay,
    required this.onContinue,
  });

  final String matchName;
  final VoidCallback onPlay;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Du und $matchName mögt euch.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              color: LovelColors.cream,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.sports_esports),
            label: const Text('Eisbrecher-Spiel starten'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: onPlay,
          ),
          const SizedBox(height: 8),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: LovelColors.cream),
            onPressed: onContinue,
            child: const Text('Weiter entdecken'),
          ),
        ],
      ),
    );
  }
}
