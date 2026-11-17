import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';

/// Dezentes Hintergrundmuster für den Chat, wie man es aus Messengern kennt:
/// kleine, selbst gezeichnete Spiele-Symbole (Controller, Joystick, Würfel,
/// Pixel-Herz …) in Terrakotta, kaum sichtbar.
class ChatBackground extends StatelessWidget {
  const ChatBackground({super.key, required this.child, this.opacity = 0.09});

  final Widget child;

  /// Deckkraft der Symbole – bewusst niedrig, damit Text lesbar bleibt.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DoodlePainter(
        color: LovelColors.terracotta.withValues(alpha: opacity),
      ),
      child: child,
    );
  }
}

typedef _Doodle = void Function(Canvas canvas, Paint stroke, Paint fill);

class _DoodlePainter extends CustomPainter {
  _DoodlePainter({required this.color});

  final Color color;

  /// Abstand der Rasterzellen – eng, damit das Muster die Fläche füllt.
  static const _cell = 44.0;
  static const _size = 26.0; // Symbole zeichnen in einem 26×26-Raster

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color;

    final doodles = <_Doodle>[
      _gamepad,
      _joystick,
      _star,
      _pixelHeart,
      _die,
      _trophy,
      _potion,
      _coin,
      _crown,
      _dpad,
      _sparkle,
      _cartridge,
    ];

    final cols = (size.width / _cell).ceil() + 1;
    final rows = (size.height / _cell).ceil() + 1;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        // Fester Zufall je Zelle → Muster bleibt beim Scrollen gleich.
        final rnd = math.Random(r * 7919 + c * 104729);
        final dx =
            c * _cell +
            (r.isOdd ? _cell / 2 : 0) +
            (rnd.nextDouble() - 0.5) * 14;
        final dy = r * _cell + (rnd.nextDouble() - 0.5) * 16;
        // Unterschiedlich groß: 60 % bis 130 % – kleine füllen die Lücken.
        final scale = 0.6 + rnd.nextDouble() * 0.7;
        canvas.save();
        canvas.translate(dx, dy);
        canvas.rotate((rnd.nextDouble() - 0.5) * 0.9);
        canvas.scale(scale);
        canvas.translate(-_size / 2, -_size / 2);
        doodles[(r * 5 + c * 3 + rnd.nextInt(3)) % doodles.length](
          canvas,
          stroke,
          fill,
        );
        canvas.restore();
      }
    }
  }

  // --- Symbole (Koordinaten im 26×26-Raster) ---

  static void _gamepad(Canvas c, Paint s, Paint f) {
    c.drawRRect(RRect.fromLTRBR(1, 7, 25, 21, const Radius.circular(7)), s);
    c.drawLine(const Offset(6, 14), const Offset(10, 14), s);
    c.drawLine(const Offset(8, 12), const Offset(8, 16), s);
    c.drawCircle(const Offset(17, 12.5), 1.4, f);
    c.drawCircle(const Offset(20, 15.5), 1.4, f);
  }

  static void _joystick(Canvas c, Paint s, Paint f) {
    c.drawRRect(RRect.fromLTRBR(4, 18, 22, 24, const Radius.circular(2)), s);
    c.drawLine(const Offset(13, 18), const Offset(13, 8), s);
    c.drawCircle(const Offset(13, 6), 3.5, f);
  }

  static void _star(Canvas c, Paint s, Paint f) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final r = i.isEven ? 12.0 : 5.0;
      final a = -math.pi / 2 + i * math.pi / 5;
      final p = Offset(13 + r * math.cos(a), 13 + r * math.sin(a));
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    c.drawPath(path..close(), s);
  }

  static void _pixelHeart(Canvas c, Paint s, Paint f) {
    const rows = [
      '.XX.XX.',
      'XXXXXXX',
      'XXXXXXX',
      '.XXXXX.',
      '..XXX..',
      '...X...',
    ];
    const px = 3.4;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        if (rows[y][x] == 'X') {
          c.drawRect(Rect.fromLTWH(1 + x * px, 3 + y * px, px, px), f);
        }
      }
    }
  }

  static void _die(Canvas c, Paint s, Paint f) {
    c.drawRRect(RRect.fromLTRBR(3, 3, 23, 23, const Radius.circular(4)), s);
    for (final o in const [Offset(8, 8), Offset(13, 13), Offset(18, 18)]) {
      c.drawCircle(o, 1.6, f);
    }
  }

  static void _trophy(Canvas c, Paint s, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(7, 3)
        ..lineTo(19, 3)
        ..quadraticBezierTo(19, 15, 13, 15)
        ..quadraticBezierTo(7, 15, 7, 3),
      s,
    );
    c.drawArc(const Rect.fromLTWH(2, 4, 7, 7), math.pi / 2, math.pi, false, s);
    c.drawArc(
      const Rect.fromLTWH(17, 4, 7, 7),
      -math.pi / 2,
      math.pi,
      false,
      s,
    );
    c.drawLine(const Offset(13, 15), const Offset(13, 20), s);
    c.drawLine(const Offset(8, 22), const Offset(18, 22), s);
  }

  static void _potion(Canvas c, Paint s, Paint f) {
    c.drawLine(const Offset(10, 2), const Offset(16, 2), s);
    c.drawLine(const Offset(11, 2), const Offset(11, 9), s);
    c.drawLine(const Offset(15, 2), const Offset(15, 9), s);
    c.drawArc(
      const Rect.fromLTWH(4, 8, 18, 17),
      -math.pi / 2 + 0.6,
      2 * math.pi - 1.2,
      false,
      s,
    );
    c.drawLine(const Offset(7, 17), const Offset(19, 17), s);
  }

  static void _coin(Canvas c, Paint s, Paint f) {
    c.drawCircle(const Offset(13, 13), 10, s);
    c.drawCircle(const Offset(13, 13), 6, s);
  }

  static void _crown(Canvas c, Paint s, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(3, 20)
        ..lineTo(3, 8)
        ..lineTo(8.5, 14)
        ..lineTo(13, 5)
        ..lineTo(17.5, 14)
        ..lineTo(23, 8)
        ..lineTo(23, 20)
        ..close(),
      s,
    );
  }

  static void _dpad(Canvas c, Paint s, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(9, 2)
        ..lineTo(17, 2)
        ..lineTo(17, 9)
        ..lineTo(24, 9)
        ..lineTo(24, 17)
        ..lineTo(17, 17)
        ..lineTo(17, 24)
        ..lineTo(9, 24)
        ..lineTo(9, 17)
        ..lineTo(2, 17)
        ..lineTo(2, 9)
        ..lineTo(9, 9)
        ..close(),
      s,
    );
  }

  static void _sparkle(Canvas c, Paint s, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(13, 2)
        ..quadraticBezierTo(14, 12, 24, 13)
        ..quadraticBezierTo(14, 14, 13, 24)
        ..quadraticBezierTo(12, 14, 2, 13)
        ..quadraticBezierTo(12, 12, 13, 2),
      f,
    );
  }

  static void _cartridge(Canvas c, Paint s, Paint f) {
    c.drawPath(
      Path()
        ..moveTo(4, 2)
        ..lineTo(22, 2)
        ..lineTo(22, 24)
        ..lineTo(4, 24)
        ..close(),
      s,
    );
    c.drawRect(const Rect.fromLTRB(8, 6, 18, 14), s);
    for (var x = 7.0; x <= 19; x += 3) {
      c.drawLine(Offset(x, 20), Offset(x, 24), s);
    }
  }

  @override
  bool shouldRepaint(_DoodlePainter old) => old.color != color;
}
