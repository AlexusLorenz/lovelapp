// Zeichnet die Profilbilder der Test-Konten als JPEG nach build/test_photos/.
//
// Aufruf: flutter test tool/render_test_photos.dart
// Danach: python3 tool/test_accounts.py extras (lädt sie hoch).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lovelapp/core/widgets/placeholder_photo.dart';
import 'package:lovelapp/features/auth/test_accounts.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets('Test-Fotos rendern', (tester) async {
    final out = Directory('build/test_photos')..createSync(recursive: true);
    const size = Size(600, 800);
    tester.view
      ..physicalSize = size
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final account in testAccounts) {
      for (final (i, art) in account.photos.indexed) {
        final key = GlobalKey();
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: SizedBox.fromSize(
                  size: size,
                  child: PlaceholderPhoto(art: art),
                ),
              ),
            ),
          ),
        );
        final bytes = await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final data = await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final decoded = img.Image.fromBytes(
            width: image.width,
            height: image.height,
            bytes: data!.buffer,
            numChannels: 4,
          );
          return img.encodeJpg(decoded, quality: 88);
        });
        File('${out.path}/${account.name.toLowerCase()}_$i.jpg')
            .writeAsBytesSync(bytes!);
      }
    }
  });
}
