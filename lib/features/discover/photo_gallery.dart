import 'package:material_ui/material_ui.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/placeholder_photo.dart';

/// Bilder eines Profils; Tippen links/rechts blättert, Balken oben zeigen
/// die Position.
class PhotoGallery extends StatefulWidget {
  const PhotoGallery({super.key, required this.photos});

  final List<PhotoArt> photos;

  @override
  State<PhotoGallery> createState() => _PhotoGalleryState();
}

class _PhotoGalleryState extends State<PhotoGallery> {
  int _index = 0;

  void _onTap(TapUpDetails details, double width) {
    final count = widget.photos.length;
    if (count < 2) return;
    setState(() {
      if (details.localPosition.dx < width / 3) {
        _index = (_index - 1).clamp(0, count - 1);
      } else {
        _index = (_index + 1).clamp(0, count - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.isEmpty) {
      return const ColoredBox(color: LovelColors.slate);
    }
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (d) => _onTap(d, constraints.maxWidth),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PlaceholderPhoto(art: photos[_index]),
            if (photos.length > 1)
              Positioned(
                top: 10,
                left: 12,
                right: 12,
                child: Row(
                  children: [
                    for (var i = 0; i < photos.length; i++)
                      Expanded(
                        child: Container(
                          height: 4,
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: LovelColors.cream.withValues(
                              alpha: i == _index ? 0.95 : 0.4,
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
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
