import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:lovelapp/features/photos/image_processing.dart';
import 'package:lovelapp/features/profile/profile_basics.dart';
import 'package:lovelapp/features/profile/profile_completion.dart';

void main() {
  group('Bildaufbereitung', () {
    test('verkleinert große Bilder und entfernt Metadaten (z. B. GPS)', () {
      final big = img.Image(width: 3000, height: 2000);
      big.exif.gpsIfd['GPSLatitude'] = img.IfdValueRational(51, 1);
      big.exif.imageIfd['Make'] = img.IfdValueAscii('Kamera');
      final input = img.encodeJpg(big);
      expect(
        img.decodeJpgExif(input)?.gpsIfd.isEmpty,
        isFalse,
        reason: 'Vorbedingung: Eingabe hat GPS-Daten',
      );

      final out = prepareProfileJpeg(input);
      final decoded = img.decodeJpg(out)!;
      expect(decoded.width, 1440);
      expect(decoded.height, 960);
      final exif = img.decodeJpgExif(out);
      expect(exif == null || exif.gpsIfd.isEmpty, isTrue);
      expect(exif == null || exif.imageIfd['Make'] == null, isTrue);
    });

    test('kleine Bilder bleiben in ihrer Größe', () {
      final small = img.encodePng(img.Image(width: 400, height: 600));
      final out = img.decodeJpg(prepareProfileJpeg(small))!;
      expect((out.width, out.height), (400, 600));
    });

    test('kaputte Daten → FormatException', () {
      expect(
        () => prepareProfileJpeg(
          img.encodePng(img.Image(width: 1, height: 1)).sublist(0, 10),
        ),
        throwsFormatException,
      );
    });
  });

  group('Profil-Vervollständigung', () {
    test('leeres Profil: 0 % und Foto-Tipp', () {
      final c = computeCompletion(
        photoCount: 0,
        bio: '',
        city: '',
        promptCount: 0,
        basics: const ProfileBasics(),
      );
      expect(c.percent, 0);
      expect(c.nextTip, contains('Foto'));
    });

    test('vollständiges Profil: 100 % ohne Tipp', () {
      final c = computeCompletion(
        photoCount: 4,
        bio: 'Hallo',
        city: 'Leipzig',
        promptCount: 3,
        basics: const ProfileBasics(
          smoking: Smoking.never,
          drinking: Drinking.socially,
          exercise: Exercise.often,
          heightCm: 180,
        ),
      );
      expect(c.percent, 100);
      expect(c.nextTip, isNull);
    });

    test('Teilweise: Gewichte addieren sich', () {
      final c = computeCompletion(
        photoCount: 1, // 20
        bio: 'x', // 15
        city: '',
        promptCount: 1, // 10
        basics: const ProfileBasics(smoking: Smoking.never), // 5
      );
      expect(c.percent, 50);
      expect(c.nextTip, contains('2 Fotos'));
    });
  });
}
