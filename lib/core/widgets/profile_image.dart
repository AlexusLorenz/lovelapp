import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../theme/app_theme.dart';
import 'placeholder_photo.dart';

/// Ein Profilbild – egal, woher es kommt.
///
/// * [PhotoArt]: gezeichneter Platzhalter (Demo-Modus)
/// * [NetworkProfileImage]: hochgeladenes Foto (signierte URL aus Supabase Storage)
/// * [MemoryProfileImage]: Foto im Speicher (Demo-Upload, gerade gewählt)
abstract class ProfileImage {
  const ProfileImage();
}

class NetworkProfileImage extends ProfileImage {
  const NetworkProfileImage(this.url);

  final String url;
}

class MemoryProfileImage extends ProfileImage {
  const MemoryProfileImage(this.bytes);

  final Uint8List bytes;
}

/// Zeigt ein [ProfileImage] formatfüllend (BoxFit.cover), oben ausgerichtet,
/// damit bei Hochformat-Porträts der Kopf nicht abgeschnitten wird.
class ProfileImageView extends StatelessWidget {
  const ProfileImageView({super.key, required this.image});

  final ProfileImage image;

  @override
  Widget build(BuildContext context) {
    final img = image;
    if (img is PhotoArt) return PlaceholderPhoto(art: img);
    if (img is MemoryProfileImage) {
      return Image.memory(
        img.bytes,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        gaplessPlayback: true,
      );
    }
    if (img is NetworkProfileImage) {
      return Image.network(
        img.url,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        gaplessPlayback: true,
        loadingBuilder: (context, child, progress) => progress == null
            ? child
            : const ColoredBox(color: LovelColors.mist),
        errorBuilder: (_, _, _) => const ColoredBox(
          color: LovelColors.mist,
          child: Center(
            child: Icon(Icons.broken_image_outlined, color: LovelColors.slate),
          ),
        ),
      );
    }
    return const ColoredBox(color: LovelColors.slate);
  }
}
