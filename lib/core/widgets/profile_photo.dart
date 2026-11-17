import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';

/// Profilbild im Polaroid-Stil.
///
/// Solange es noch keine echten Fotos gibt, zeigt es einen Farbverlauf aus der
/// Palette mit der Initiale. Später: `imageUrl` aus dem Storage-Bucket.
class ProfilePhoto extends StatelessWidget {
  const ProfilePhoto({
    super.key,
    required this.name,
    this.width = 150,
    this.height = 200,
    this.variant = 0,
  });

  final String name;
  final double width;
  final double height;

  /// Wählt eine von mehreren Farbkombinationen, damit sich Bilder unterscheiden.
  final int variant;

  static const _gradients = [
    [LovelColors.slate, LovelColors.mist],
    [LovelColors.terracotta, LovelColors.umber],
    [LovelColors.umber, LovelColors.slate],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _gradients[variant % _gradients.length];
    final initial = name.isEmpty ? '?' : name.characters.first.toUpperCase();
    return Container(
      width: width,
      height: height,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 28),
      decoration: BoxDecoration(
        color: LovelColors.cream,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x55000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ),
        ),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(
              fontFamily: AppTheme.displayFont,
              fontSize: height * 0.35,
              color: LovelColors.cream,
            ),
          ),
        ),
      ),
    );
  }
}
