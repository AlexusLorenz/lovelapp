import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

/// Kleine Flame-Szene: aufsteigende Herzen, z. B. für den „Match!“-Moment.
///
/// Dient gleichzeitig als Vorlage für Minispiele, die eine Game-Loop brauchen.
class HeartsGame extends FlameGame {
  HeartsGame({this.color = const Color(0xFFE8457A), int? seed})
    : _random = math.Random(seed);

  final Color color;
  final math.Random _random;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    add(TimerComponent(period: 0.12, repeat: true, onTick: _spawnHeart));
  }

  void _spawnHeart() {
    if (size.x <= 0 || size.y <= 0) return;
    final heartSize = 14 + _random.nextDouble() * 22;
    add(
      HeartComponent(
        color: color,
        position: Vector2(_random.nextDouble() * size.x, size.y + heartSize),
        velocity: Vector2(
          (_random.nextDouble() - 0.5) * 40,
          -(80 + _random.nextDouble() * 120),
        ),
        lifetime: 2 + _random.nextDouble() * 1.5,
        size: Vector2.all(heartSize),
      ),
    );
  }
}

class HeartComponent extends PositionComponent {
  HeartComponent({
    required this.color,
    required this.velocity,
    required this.lifetime,
    super.position,
    super.size,
  }) : super(anchor: Anchor.center);

  final Color color;
  final Vector2 velocity;
  final double lifetime;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position += velocity * dt;
    angle = math.sin(_age * 4) * 0.25;
    if (_age >= lifetime) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    final opacity = (1 - _age / lifetime).clamp(0.0, 1.0);
    final paint = Paint()..color = color.withValues(alpha: opacity);
    canvas.drawPath(heartPath(size.x, size.y), paint);
  }

  /// Herzform im Rechteck (0,0)–(w,h).
  static Path heartPath(double w, double h) {
    return Path()
      ..moveTo(w / 2, h * 0.9)
      ..cubicTo(w * -0.1, h * 0.55, w * 0.1, h * 0.05, w / 2, h * 0.3)
      ..cubicTo(w * 0.9, h * 0.05, w * 1.1, h * 0.55, w / 2, h * 0.9)
      ..close();
  }
}
