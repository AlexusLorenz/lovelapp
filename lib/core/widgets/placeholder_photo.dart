import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'profile_image.dart';

/// Motiv eines gezeichneten Platzhalter-Fotos.
///
/// Bewusst keine Fotos echter Menschen: Bis zum Foto-Upload zeigen wir
/// Illustrationen in der Lovel-Palette.
enum PhotoMotif { portrait, mountains, sea, city, plants }

enum HairStyle { short, long, bun, curly }

class PhotoArt extends ProfileImage {
  const PhotoArt.portrait({
    required this.skin,
    required this.hair,
    required this.hairStyle,
    required this.shirt,
    required this.background,
  }) : motif = PhotoMotif.portrait;

  const PhotoArt.scene(this.motif)
    : skin = null,
      hair = null,
      hairStyle = null,
      shirt = null,
      background = null;

  final PhotoMotif motif;
  final Color? skin;
  final Color? hair;
  final HairStyle? hairStyle;
  final Color? shirt;
  final Color? background;
}

/// Zeichnet ein [PhotoArt] formatfüllend.
class PlaceholderPhoto extends StatelessWidget {
  const PlaceholderPhoto({super.key, required this.art});

  final PhotoArt art;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Platzhalter-Bild',
      child: CustomPaint(
        painter: _PhotoPainter(art),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _PhotoPainter extends CustomPainter {
  _PhotoPainter(this.art);

  final PhotoArt art;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    switch (art.motif) {
      case PhotoMotif.portrait:
        _portrait(canvas, size);
      case PhotoMotif.mountains:
        _mountains(canvas, size);
      case PhotoMotif.sea:
        _sea(canvas, size);
      case PhotoMotif.city:
        _city(canvas, size);
      case PhotoMotif.plants:
        _plants(canvas, size);
    }
  }

  static Paint _fill(Color c) => Paint()..color = c;

  static void _gradient(Canvas canvas, Size size, Color top, Color bottom) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(Offset.zero & size),
    );
  }

  void _portrait(Canvas canvas, Size s) {
    final bg = art.background!;
    _gradient(canvas, s, bg, Color.lerp(bg, LovelColors.cream, 0.45)!);

    final unit = math.min(s.width, s.height * 0.75);
    final cx = s.width / 2;
    final headCenter = Offset(cx, s.height * 0.42);
    final headW = unit * 0.34;
    final headH = unit * 0.43;
    final hair = _fill(art.hair!);

    // Dekorativer Kreis im Hintergrund
    canvas.drawCircle(
      Offset(s.width * 0.78, s.height * 0.2),
      unit * 0.22,
      _fill(LovelColors.cream.withValues(alpha: 0.35)),
    );

    // Lange Haare liegen hinter Kopf und Schultern
    if (art.hairStyle == HairStyle.long) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: headCenter.translate(0, headH * 0.45),
            width: headW * 1.45,
            height: headH * 1.9,
          ),
          Radius.circular(headW * 0.7),
        ),
        hair,
      );
    }

    // Schultern / Oberteil
    final shoulders = Rect.fromCenter(
      center: Offset(cx, s.height * 1.02),
      width: unit * 1.05,
      height: s.height * 0.62,
    );
    canvas.drawOval(shoulders, _fill(art.shirt!));

    // Hals
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: headCenter.translate(0, headH * 0.62),
          width: headW * 0.42,
          height: headH * 0.55,
        ),
        Radius.circular(headW * 0.15),
      ),
      _fill(Color.lerp(art.skin!, Colors.black, 0.12)!),
    );

    // Kopf
    canvas.drawOval(
      Rect.fromCenter(center: headCenter, width: headW, height: headH),
      _fill(art.skin!),
    );

    // Frisur oben
    final top = Rect.fromCenter(
      center: headCenter.translate(0, -headH * 0.18),
      width: headW * 1.1,
      height: headH * 0.78,
    );
    switch (art.hairStyle!) {
      case HairStyle.short:
      case HairStyle.long:
        canvas.drawArc(top, math.pi, math.pi, true, hair);
      case HairStyle.bun:
        canvas.drawArc(top, math.pi, math.pi, true, hair);
        canvas.drawCircle(
          headCenter.translate(0, -headH * 0.62),
          headW * 0.26,
          hair,
        );
      case HairStyle.curly:
        for (var i = 0; i < 9; i++) {
          final a = math.pi + i * math.pi / 8;
          canvas.drawCircle(
            headCenter.translate(
              math.cos(a) * headW * 0.5,
              math.sin(a) * headH * 0.45 - headH * 0.08,
            ),
            headW * 0.2,
            hair,
          );
        }
    }
  }

  void _mountains(Canvas canvas, Size s) {
    _gradient(canvas, s, LovelColors.slate, LovelColors.cream);
    canvas.drawCircle(
      Offset(s.width * 0.7, s.height * 0.3),
      s.width * 0.12,
      _fill(LovelColors.terracotta.withValues(alpha: 0.85)),
    );
    void peak(double x, double w, double h, Color c) {
      canvas.drawPath(
        Path()
          ..moveTo(x - w / 2, s.height)
          ..lineTo(x, s.height - h)
          ..lineTo(x + w / 2, s.height)
          ..close(),
        _fill(c),
      );
    }

    peak(s.width * 0.25, s.width * 0.9, s.height * 0.55, LovelColors.mist);
    peak(s.width * 0.8, s.width * 0.9, s.height * 0.5, LovelColors.blush);
    peak(s.width * 0.5, s.width * 1.1, s.height * 0.38, LovelColors.umber);
  }

  void _sea(Canvas canvas, Size s) {
    _gradient(canvas, s, LovelColors.blush, LovelColors.cream);
    final horizon = s.height * 0.58;
    canvas.drawCircle(
      Offset(s.width * 0.5, horizon),
      s.width * 0.18,
      _fill(LovelColors.terracotta),
    );
    canvas.drawRect(
      Rect.fromLTRB(0, horizon, s.width, s.height),
      _fill(LovelColors.slate),
    );
    final wave = Paint()
      ..color = LovelColors.cream.withValues(alpha: 0.6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 6; i++) {
      final y = horizon + 18 + i * (s.height - horizon) / 6;
      final inset = s.width * (0.1 + 0.05 * (i % 3));
      canvas.drawLine(Offset(inset, y), Offset(s.width - inset * 1.6, y), wave);
    }
  }

  void _city(Canvas canvas, Size s) {
    _gradient(canvas, s, LovelColors.umber, LovelColors.terracotta);
    canvas.drawCircle(
      Offset(s.width * 0.22, s.height * 0.18),
      s.width * 0.07,
      _fill(LovelColors.cream),
    );
    final random = math.Random(7);
    var x = 0.0;
    while (x < s.width) {
      final w = s.width * (0.12 + random.nextDouble() * 0.1);
      final h = s.height * (0.25 + random.nextDouble() * 0.4);
      final rect = Rect.fromLTWH(x, s.height - h, w - 4, h);
      canvas.drawRect(rect, _fill(const Color(0xFF3A2219)));
      for (var wy = rect.top + 12; wy < rect.bottom - 10; wy += 18) {
        for (var wx = rect.left + 8; wx < rect.right - 8; wx += 14) {
          if (random.nextDouble() < 0.45) {
            canvas.drawRect(
              Rect.fromLTWH(wx, wy, 6, 8),
              _fill(LovelColors.cream.withValues(alpha: 0.8)),
            );
          }
        }
      }
      x += w;
    }
  }

  void _plants(Canvas canvas, Size s) {
    _gradient(canvas, s, LovelColors.cream, LovelColors.mist);
    final potTop = s.height * 0.68;
    final cx = s.width / 2;
    final leaf = Paint()..color = LovelColors.slate;
    final leafDark = Paint()..color = const Color(0xFF6F7F96);
    for (var i = 0; i < 7; i++) {
      final angle = -math.pi / 2 + (i - 3) * 0.32;
      final len = s.height * (0.32 + (i % 2) * 0.08);
      canvas.save();
      canvas.translate(cx, potTop);
      canvas.rotate(angle + math.pi / 2);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(0, -len / 2),
          width: s.width * 0.11,
          height: len,
        ),
        i.isEven ? leaf : leafDark,
      );
      canvas.restore();
    }
    canvas.drawPath(
      Path()
        ..moveTo(cx - s.width * 0.2, potTop)
        ..lineTo(cx + s.width * 0.2, potTop)
        ..lineTo(cx + s.width * 0.15, s.height * 0.95)
        ..lineTo(cx - s.width * 0.15, s.height * 0.95)
        ..close(),
      _fill(LovelColors.terracotta),
    );
  }

  @override
  bool shouldRepaint(_PhotoPainter old) => old.art != art;
}
