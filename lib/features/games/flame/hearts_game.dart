import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/game.dart';

/// Flame-Szene: Herzen fliegen über den ganzen Bildschirm, z. B. beim Match.
///
/// Dient gleichzeitig als Vorlage für Minispiele, die eine Game-Loop brauchen.
class HeartsGame extends FlameGame {
  HeartsGame({
    this.colors = const [Color(0xFFBB5B3E)],
    this.initialBurst = 24,
    int? seed,
  }) : _random = math.Random(seed);

  final List<Color> colors;

  /// Herzen, die beim Start sofort überall auf dem Bildschirm erscheinen.
  final int initialBurst;

  final math.Random _random;
  bool _burstDone = false;

  @override
  Color backgroundColor() => const Color(0x00000000);

  @override
  Future<void> onLoad() async {
    add(TimerComponent(period: 0.08, repeat: true, onTick: _spawnFromBottom));
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    if (!_burstDone && size.x > 0 && size.y > 0) {
      _burstDone = true;
      for (var i = 0; i < initialBurst; i++) {
        _spawn(
          Vector2(
            _random.nextDouble() * size.x,
            size.y * (0.2 + _random.nextDouble() * 0.9),
          ),
        );
      }
    }
  }

  void _spawnFromBottom() {
    if (size.x <= 0 || size.y <= 0) return;
    _spawn(Vector2(_random.nextDouble() * size.x, size.y + 30));
  }

  void _spawn(Vector2 position) {
    final heartSize = 16 + _random.nextDouble() * 30;
    // Ein Herz braucht etwa 3–5 s für die ganze Bildschirmhöhe.
    final speed = size.y / (3 + _random.nextDouble() * 2);
    add(
      HeartComponent(
        color: colors[_random.nextInt(colors.length)],
        position: position,
        velocity: Vector2((_random.nextDouble() - 0.5) * 60, -speed),
        lifetime: 5,
        size: Vector2.all(heartSize),
        wobbleOffset: _random.nextDouble() * math.pi * 2,
      ),
    );
  }
}

class HeartComponent extends PositionComponent {
  HeartComponent({
    required this.color,
    required this.velocity,
    required this.lifetime,
    this.wobbleOffset = 0,
    super.position,
    super.size,
  }) : super(anchor: Anchor.center);

  final Color color;
  final Vector2 velocity;
  final double lifetime;
  final double wobbleOffset;
  double _age = 0;

  @override
  void update(double dt) {
    super.update(dt);
    _age += dt;
    position += velocity * dt;
    position.x += math.sin(_age * 2 + wobbleOffset) * 0.6;
    angle = math.sin(_age * 3 + wobbleOffset) * 0.25;
    if (_age >= lifetime || position.y < -size.y) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    // Kurz einblenden, gegen Ende ausblenden.
    final fadeIn = (_age / 0.3).clamp(0.0, 1.0);
    final fadeOut = (lifetime - _age).clamp(0.0, 1.0);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.9 * fadeIn * fadeOut);
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
