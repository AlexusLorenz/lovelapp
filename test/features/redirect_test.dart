import 'package:flutter_test/flutter_test.dart';
import 'package:lovelapp/core/router/app_router.dart';
import 'package:lovelapp/features/session/session_controller.dart';

void main() {
  test('abgemeldet → Willkommen, Auth-Seiten erlaubt', () {
    expect(
      redirectFor(SessionStatus.signedOut, Routes.discover),
      Routes.welcome,
    );
    expect(redirectFor(SessionStatus.signedOut, Routes.signUp), isNull);
    expect(
      redirectFor(SessionStatus.signedOut, Routes.onboarding),
      Routes.welcome,
    );
  });

  test('ohne Profil → Onboarding', () {
    expect(
      redirectFor(SessionStatus.needsProfile, Routes.discover),
      Routes.onboarding,
    );
    expect(redirectFor(SessionStatus.needsProfile, Routes.onboarding), isNull);
  });

  test('fertig → raus aus Auth und Onboarding', () {
    expect(redirectFor(SessionStatus.ready, Routes.welcome), Routes.discover);
    expect(
      redirectFor(SessionStatus.ready, Routes.onboarding),
      Routes.discover,
    );
    expect(redirectFor(SessionStatus.ready, Routes.matches), isNull);
  });

  test('beim Laden → Splash; Rechtstexte immer erreichbar', () {
    expect(redirectFor(SessionStatus.loading, Routes.discover), Routes.splash);
    expect(redirectFor(SessionStatus.error, Routes.splash), isNull);
    expect(redirectFor(SessionStatus.signedOut, Routes.privacy), isNull);
    expect(redirectFor(SessionStatus.needsProfile, Routes.terms), isNull);
  });
}
