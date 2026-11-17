import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';

enum SwipeDirection { left, right }

/// Entscheidet am Ende einer Wischgeste. `null` = zurückschnappen.
///
/// Eine Karte gilt als gewischt, wenn sie weiter als 30 % der Breite gezogen
/// oder schnell genug geschleudert wurde.
SwipeDirection? decideSwipe({
  required double dx,
  required double velocityX,
  required double width,
}) {
  const flingVelocity = 800.0;
  final threshold = width * 0.3;
  if (dx > threshold || (velocityX > flingVelocity && dx > 0)) {
    return SwipeDirection.right;
  }
  if (dx < -threshold || (velocityX < -flingVelocity && dx < 0)) {
    return SwipeDirection.left;
  }
  return null;
}

/// Karte, die man nach links (weiter) oder rechts (Like) wischen kann.
///
/// Über einen `GlobalKey<SwipeCardState>` lässt sich auch per Button wischen.
class SwipeCard extends StatefulWidget {
  const SwipeCard({
    super.key,
    required this.child,
    required this.onSwiped,
    this.canSwipe,
    this.onBlocked,
  });

  final Widget child;
  final ValueChanged<SwipeDirection> onSwiped;

  /// Darf in diese Richtung gewischt werden? (z. B. keine Likes mehr)
  final bool Function(SwipeDirection direction)? canSwipe;

  /// Wird gerufen, wenn eine Geste an [canSwipe] scheitert.
  final ValueChanged<SwipeDirection>? onBlocked;

  @override
  State<SwipeCard> createState() => SwipeCardState();
}

class SwipeCardState extends State<SwipeCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this)
    ..addListener(_onTick);

  Offset _drag = Offset.zero;
  Tween<Offset>? _tween;
  Curve _curve = Curves.linear;
  bool _flying = false;

  void _onTick() {
    final tween = _tween;
    if (tween == null) return;
    setState(
      () => _drag = tween.transform(_curve.transform(_controller.value)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Breite aus dem letzten Layout (in build nicht über context.size lesbar).
  double _width = 360;

  /// Wischt die Karte per Code weg (z. B. über die Buttons).
  Future<void> swipe(SwipeDirection direction) async {
    if (_flying) return;
    if (!(widget.canSwipe?.call(direction) ?? true)) {
      widget.onBlocked?.call(direction);
      return;
    }
    await _flyOut(direction);
  }

  Future<void> _animateTo(Offset target, Duration duration, Curve curve) {
    _tween = Tween(begin: _drag, end: target);
    _curve = curve;
    _controller.duration = duration;
    return _controller.forward(from: 0);
  }

  Future<void> _flyOut(SwipeDirection direction) async {
    _flying = true;
    final sign = direction == SwipeDirection.right ? 1 : -1;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (!reduceMotion) {
      await _animateTo(
        Offset(sign * _width * 1.6, _drag.dy + 60),
        const Duration(milliseconds: 260),
        Curves.easeIn,
      );
    }
    if (mounted) widget.onSwiped(direction);
  }

  void _snapBack() {
    _animateTo(
      Offset.zero,
      const Duration(milliseconds: 350),
      Curves.easeOutBack,
    );
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_flying) return;
    _controller.stop();
    setState(() => _drag += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_flying) return;
    final direction = decideSwipe(
      dx: _drag.dx,
      velocityX: details.velocity.pixelsPerSecond.dx,
      width: _width,
    );
    if (direction == null) {
      _snapBack();
    } else if (!(widget.canSwipe?.call(direction) ?? true)) {
      _snapBack();
      widget.onBlocked?.call(direction);
    } else {
      _flyOut(direction);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.hasBoundedWidth) _width = constraints.maxWidth;
        return _buildCard(context, _width);
      },
    );
  }

  Widget _buildCard(BuildContext context, double width) {
    // -1 (ganz links) … 1 (ganz rechts), für Drehung und Stempel
    final progress = (_drag.dx / (width * 0.4)).clamp(-1.0, 1.0);
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _drag,
        child: Transform.rotate(
          angle: progress * math.pi / 18,
          alignment: const Alignment(0, 2),
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              if (progress > 0.05)
                Positioned(
                  top: 32,
                  left: 24,
                  child: _Stamp(
                    text: 'LIKE',
                    color: LovelColors.terracotta,
                    angle: -0.25,
                    opacity: progress,
                  ),
                ),
              if (progress < -0.05)
                Positioned(
                  top: 32,
                  right: 24,
                  child: _Stamp(
                    text: 'NOPE',
                    color: LovelColors.slate,
                    angle: 0.25,
                    opacity: -progress,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stamp extends StatelessWidget {
  const _Stamp({
    required this.text,
    required this.color,
    required this.angle,
    required this.opacity,
  });

  final String text;
  final Color color;
  final double angle;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: angle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: color, width: 4),
              borderRadius: BorderRadius.circular(10),
              color: LovelColors.cream.withValues(alpha: 0.85),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AppTheme.displayFont,
                fontSize: 44,
                height: 1.1,
                letterSpacing: 2,
                color: color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
