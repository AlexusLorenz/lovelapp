import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:lovelapp/app.dart';
import 'package:lovelapp/features/auth/auth_repository.dart';
import 'package:lovelapp/features/onboarding/profile_repository.dart';
import 'package:lovelapp/features/profile/widgets/photo_editor.dart';
import 'package:lovelapp/features/session/session_controller.dart';

const testUser = AppUser(id: 'demo-test@lovel.app', email: 'test@lovel.app');

/// Startet die App im Demo-Modus.
///
/// [signedIn]: schon angemeldet; [hasProfile]: Onboarding schon erledigt.
/// Ein kleines Test-JPEG, wie es die Galerie liefern würde.
Uint8List testJpeg([int shade = 120]) => img.encodeJpg(
  img.fill(
    img.Image(width: 300, height: 400),
    color: img.ColorRgb8(shade, 90, 70),
  ),
);

Future<void> pumpLovelApp(
  WidgetTester tester, {
  bool signedIn = true,
  bool hasProfile = true,
  PickImages? pickImages,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          DemoAuthRepository(signedInAs: signedIn ? testUser : null),
        ),
        pickImagesProvider.overrideWithValue(
          pickImages ?? (limit) async => [testJpeg()],
        ),
        profileRepositoryProvider.overrideWithValue(
          DemoProfileRepository(existingUserIds: [if (hasProfile) testUser.id]),
        ),
      ],
      child: const LovelApp(),
    ),
  );
  await tester.pumpAndSettle();
}
