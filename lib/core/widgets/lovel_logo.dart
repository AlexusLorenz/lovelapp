import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Bildmarke: Herz als Gamecontroller (Design „LovelApp Logo“).
///
/// Formen identisch zu tool/brand/brand_icons.py (Favicon/Web-Icons) – bei
/// Änderungen beide anpassen.
class LovelMark extends StatelessWidget {
  const LovelMark({
    super.key,
    this.width = 120,
    this.heart = LovelColors.terracotta,
    this.detail = LovelColors.cream,
  });

  /// Breite; die Höhe ergibt sich aus dem Seitenverhältnis 240 : 220.
  final double width;
  final Color heart;
  final Color detail;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Lovel-Logo',
      image: true,
      child: CustomPaint(
        size: Size(width, width * 220 / 240),
        painter: _MarkPainter(heart, detail),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.heart, this.detail);

  final Color heart;
  final Color detail;

  // Herz im Koordinatensystem 240 × 220.
  static final Path _heart = Path()
    ..moveTo(120, 200)
    ..cubicTo(120, 200, 20, 138, 20, 76)
    ..cubicTo(20, 42, 46, 18, 78, 18)
    ..cubicTo(98, 18, 112, 28, 120, 44)
    ..cubicTo(128, 28, 142, 18, 162, 18)
    ..cubicTo(194, 18, 220, 42, 220, 76)
    ..cubicTo(220, 138, 120, 200, 120, 200)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 240, size.height / 220);
    final fill = Paint()..color = heart;
    canvas
      ..drawPath(_heart, fill)
      ..drawPath(
        _heart,
        Paint()
          ..color = heart
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..strokeJoin = StrokeJoin.round,
      );
    final d = Paint()..color = detail;
    const r = Radius.circular(5);
    // Steuerkreuz
    canvas
      ..drawRRect(RRect.fromLTRBR(51, 73, 107, 91, r), d)
      ..drawRRect(RRect.fromLTRBR(70, 54, 88, 110, r), d)
      // Knöpfe
      ..drawCircle(const Offset(150, 95), 11, d)
      ..drawCircle(const Offset(176, 69), 11, d);
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.heart != heart || old.detail != detail;
}

/// Logo: Bildmarke über dem Schriftzug „LOVELAPP“ (Staatliches).
class LovelLogo extends StatelessWidget {
  const LovelLogo({super.key, this.size = 96, this.showMark = true});

  /// Schriftgröße des Schriftzugs; die Bildmarke skaliert mit.
  final double size;
  final bool showMark;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: AppTheme.displayFont,
      fontSize: size,
      height: 1,
      letterSpacing: size * 0.04,
      color: LovelColors.umber,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showMark) ...[
          LovelMark(width: size * 300 / 128),
          SizedBox(height: size * 28 / 128),
        ],
        Text.rich(
          const TextSpan(
            text: 'LOVEL',
            children: [
              TextSpan(
                text: 'APP',
                style: TextStyle(color: LovelColors.terracotta),
              ),
            ],
          ),
          semanticsLabel: 'LovelApp',
          style: style,
        ),
      ],
    );
  }
}
