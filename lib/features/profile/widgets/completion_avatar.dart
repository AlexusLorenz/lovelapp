import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/profile_image.dart';

/// Profilbild mit rotem Ring, der zeigt, wie vollständig das Profil ist.
class CompletionAvatar extends StatelessWidget {
  const CompletionAvatar({
    super.key,
    required this.name,
    required this.percent,
    this.image,
    this.onTap,
    this.size = 104,
  });

  final String name;
  final ProfileImage? image;

  /// 0 bis 100.
  final int percent;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    const ring = 5.0;
    final inner = size - 2 * (ring + 4);
    return Semantics(
      button: onTap != null,
      label:
          'Dein Profilbild, Profil zu $percent Prozent vollständig. '
          'Antippen zeigt, wie andere dich sehen.',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size + 10,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              SizedBox.square(
                dimension: size,
                child: CustomPaint(
                  painter: _RingPainter(percent / 100, ring),
                  child: Center(
                    child: ClipOval(
                      child: SizedBox.square(
                        dimension: inner,
                        child: image != null
                            ? ProfileImageView(image: image!)
                            : ColoredBox(
                                color: LovelColors.slate,
                                child: Center(
                                  child: Text(
                                    name.isEmpty
                                        ? '?'
                                        : name.characters.first.toUpperCase(),
                                    style: TextStyle(
                                      fontFamily: AppTheme.displayFont,
                                      fontSize: inner * 0.45,
                                      color: LovelColors.cream,
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: LovelColors.unread,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: LovelColors.cream, width: 2),
                  ),
                  child: Text(
                    '$percent %',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.fraction, this.stroke);

  final double fraction;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final deflated = rect.deflate(stroke / 2);
    canvas.drawArc(
      deflated,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = LovelColors.unread.withValues(alpha: 0.15),
    );
    if (fraction > 0) {
      canvas.drawArc(
        deflated,
        -math.pi / 2,
        2 * math.pi * fraction.clamp(0.0, 1.0),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round
          ..color = LovelColors.unread,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.fraction != fraction || old.stroke != stroke;
}
