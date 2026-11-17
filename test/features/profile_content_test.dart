import 'package:flutter_test/flutter_test.dart';
import 'package:lovelapp/features/discover/swipe_card.dart';
import 'package:lovelapp/features/profile/profile_basics.dart';
import 'package:lovelapp/features/profile/profile_prompts.dart';

void main() {
  group('Fragen', () {
    const a = PromptAnswer('perfect_sunday', 'Brunch');
    const b = PromptAnswer('green_flag', 'Ehrlichkeit');
    const c = PromptAnswer('superpower', 'Parkplätze finden');

    test('genau drei verschiedene, beantwortete Fragen', () {
      expect(validatePromptSelection([a, b, c]), isNull);
      expect(validatePromptSelection([a, b]), isNotNull);
      expect(validatePromptSelection([a, a, c]), contains('nur einmal'));
      expect(
        validatePromptSelection([a, b, const PromptAnswer('superpower', ' ')]),
        isNotNull,
      );
      expect(
        validatePromptSelection([a, b, const PromptAnswer('gibts_nicht', 'x')]),
        isNotNull,
      );
    });

    test('Katalog hat eindeutige, DB-taugliche Schlüssel', () {
      final keys = promptCatalog.map((p) => p.key).toList();
      expect(keys.toSet().length, keys.length);
      for (final k in keys) {
        expect(RegExp(r'^[a-z0-9_]{2,40}$').hasMatch(k), isTrue, reason: k);
      }
      expect(promptCatalog.length, greaterThanOrEqualTo(promptsPerProfile));
    });
  });

  group('Steckbrief', () {
    test('Größe optional, aber plausibel', () {
      expect(validateHeight(''), isNull);
      expect(validateHeight('172'), isNull);
      expect(validateHeight('99'), isNotNull);
      expect(validateHeight('abc'), isNotNull);
    });

    test('JSON hin und zurück', () {
      const basics = ProfileBasics(
        relationshipGoal: RelationshipGoal.longTerm,
        children: ChildrenPlan.notSure,
        smoking: Smoking.never,
        drinking: Drinking.socially,
        exercise: Exercise.often,
        heightCm: 180,
      );
      final back = ProfileBasics.fromJson(basics.toJson());
      expect(back.labels, basics.labels);
      expect(basics.toJson()['smoking'], 'never');
      expect(const ProfileBasics().isEmpty, isTrue);
    });

    test('copyWith kann Werte auch löschen', () {
      const b = ProfileBasics(smoking: Smoking.never);
      expect(b.copyWith(smoking: () => null).smoking, isNull);
      expect(b.copyWith(heightCm: () => 170).smoking, Smoking.never);
    });
  });

  group('Wisch-Entscheidung', () {
    test('weit genug oder schnell genug', () {
      expect(
        decideSwipe(dx: 150, velocityX: 0, width: 400),
        SwipeDirection.right,
      );
      expect(
        decideSwipe(dx: -150, velocityX: 0, width: 400),
        SwipeDirection.left,
      );
      expect(
        decideSwipe(dx: 40, velocityX: 1200, width: 400),
        SwipeDirection.right,
      );
      expect(decideSwipe(dx: 60, velocityX: 0, width: 400), isNull);
      // Schleudern gegen die Zugrichtung zählt nicht
      expect(decideSwipe(dx: 40, velocityX: -1200, width: 400), isNull);
    });
  });
}
