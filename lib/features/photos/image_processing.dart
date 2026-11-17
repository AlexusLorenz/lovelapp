import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Bereitet ein gewähltes Bild für den Upload vor:
/// * dreht es nach der EXIF-Ausrichtung richtig herum,
/// * verkleinert es auf höchstens [maxSide] Pixel an der langen Seite,
/// * speichert es neu als JPEG – **ohne Metadaten** (kein GPS-Standort,
///   keine Kameradaten). Datenschutz!
///
/// Wirft [FormatException], wenn das Bild nicht lesbar ist.
Uint8List prepareProfileJpeg(
  Uint8List input, {
  int maxSide = 1440,
  int quality = 85,
}) {
  img.Image? decoded;
  try {
    decoded = img.decodeImage(input);
  } on Object {
    decoded = null; // kaputte oder unbekannte Daten
  }
  if (decoded == null) {
    throw const FormatException('Bildformat wird nicht unterstützt.');
  }
  var image = img.bakeOrientation(decoded);
  final longSide = image.width > image.height ? image.width : image.height;
  if (longSide > maxSide) {
    image = image.width >= image.height
        ? img.copyResize(
            image,
            width: maxSide,
            interpolation: img.Interpolation.average,
          )
        : img.copyResize(
            image,
            height: maxSide,
            interpolation: img.Interpolation.average,
          );
  }
  // Ohne Metadaten neu kodieren.
  image.exif = img.ExifData();
  return img.encodeJpg(image, quality: quality);
}
