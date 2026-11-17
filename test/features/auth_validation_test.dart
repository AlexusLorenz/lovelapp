import 'package:flutter_test/flutter_test.dart';
import 'package:lovelapp/features/auth/auth_validation.dart';
import 'package:lovelapp/features/auth/supabase_auth_repository.dart';

void main() {
  test('E-Mail', () {
    expect(validateEmail(''), isNotNull);
    expect(validateEmail('mia'), isNotNull);
    expect(validateEmail('mia@lovel'), isNotNull);
    expect(validateEmail(' mia@lovel.app '), isNull);
  });

  test('Passwort: mindestens 10 Zeichen, keine Leerzeichen am Rand', () {
    expect(validatePassword('kurz'), isNotNull);
    expect(validatePassword('123456789'), isNotNull);
    expect(validatePassword('1234567890'), isNull);
    expect(validatePassword(' 1234567890'), isNotNull);
    expect(validatePasswordRepeat('a', 'b'), isNotNull);
    expect(validatePasswordRepeat('abc', 'abc'), isNull);
  });

  test('Supabase-Fehlercodes werden übersetzt', () {
    expect(
      messageForAuthError('invalid_credentials', '400'),
      contains('Passwort stimmt nicht'),
    );
    expect(messageForAuthError('unbekannt', '500'), contains('nicht geklappt'));
  });
}
