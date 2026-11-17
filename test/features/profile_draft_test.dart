import 'package:flutter_test/flutter_test.dart';
import 'package:lovelapp/features/onboarding/profile_draft.dart';
import 'package:lovelapp/features/profile/profile_basics.dart';
import 'package:lovelapp/features/profile/profile_prompts.dart';

void main() {
  final today = DateTime(2026, 11, 17);

  group('Alter', () {
    test('Geburtstag noch nicht gehabt', () {
      expect(ageOn(DateTime(2008, 11, 18), today), 17);
    });
    test('Geburtstag heute', () {
      expect(ageOn(DateTime(2008, 11, 17), today), 18);
    });
  });

  group('Datum TT.MM.JJJJ', () {
    test('gültig', () {
      expect(parseGermanDate('24.05.1998'), DateTime(1998, 5, 24));
      expect(parseGermanDate('1.2.2000'), DateTime(2000, 2, 1));
    });
    test('ungültig', () {
      expect(parseGermanDate('31.02.2000'), isNull);
      expect(parseGermanDate('2000-01-01'), isNull);
      expect(parseGermanDate(''), isNull);
    });
  });

  test('Geburtsdatum: 18+ und plausibel', () {
    expect(validateBirthdate('18.11.2008', today: today), contains('18'));
    expect(validateBirthdate('17.11.2008', today: today), isNull);
    expect(validateBirthdate('01.01.2030', today: today), contains('Zukunft'));
    expect(validateBirthdate('1.1.1800', today: today), isNotNull);
    expect(validateBirthdate('Quatsch', today: today), contains('TT.MM.JJJJ'));
  });

  test('Name', () {
    expect(validateDisplayName('  '), isNotNull);
    expect(validateDisplayName('x' * 41), isNotNull);
    expect(validateDisplayName('Mia'), isNull);
  });

  group('toInsertJson', () {
    ProfileDraft complete() => ProfileDraft()
      ..displayName = ' Mia '
      ..birthdate = DateTime(1998, 5, 4)
      ..gender = Gender.woman
      ..interestedIn.addAll({Gender.nonbinary, Gender.man})
      ..sensitiveConsentAt = DateTime.utc(2026, 11, 17, 12)
      ..city = ' Leipzig '
      ..bio = 'Hallo'
      ..basics = const ProfileBasics(smoking: Smoking.never, heightCm: 170)
      ..prompts = const [
        PromptAnswer('perfect_sunday', ' Brunch '),
        PromptAnswer('green_flag', 'Ehrlich'),
        PromptAnswer('superpower', 'Kaffee'),
      ];

    test('liefert die DB-Spalten', () {
      expect(complete().toInsertJson(), {
        'display_name': 'Mia',
        'birthdate': '1998-05-04',
        'gender': 'woman',
        'interested_in': ['man', 'nonbinary'],
        'sensitive_consent_at': '2026-11-17T12:00:00.000Z',
        'city': 'Leipzig',
        'bio': 'Hallo',
        'relationship_goal': null,
        'children': null,
        'smoking': 'never',
        'drinking': null,
        'exercise': null,
        'height_cm': 170,
      });
      expect(complete().promptRows().first, {
        'position': 0,
        'prompt_key': 'perfect_sunday',
        'answer': 'Brunch',
      });
    });

    test('ohne Einwilligung keine Orientierungsdaten', () {
      final draft = complete()..sensitiveConsentAt = null;
      expect(draft.isComplete, isFalse);
      expect(draft.toInsertJson, throwsStateError);
    });

    test('ohne drei Fragen nicht vollständig', () {
      final draft = complete()..prompts = const [];
      expect(draft.isComplete, isFalse);
    });

    test('leere Stadt wird null', () {
      expect((complete()..city = '  ').toInsertJson()['city'], isNull);
    });
  });
}
