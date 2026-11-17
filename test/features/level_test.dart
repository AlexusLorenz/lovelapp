import 'package:flutter_test/flutter_test.dart';
import 'package:lovelapp/features/progress/level.dart';

void main() {
  test('Level-Schwellen', () {
    expect(LevelProgress.fromXp(0).level, 1);
    expect(LevelProgress.fromXp(99).level, 1);
    expect(LevelProgress.fromXp(100).level, 2);
    expect(LevelProgress.fromXp(300).level, 3);
    expect(LevelProgress.fromXp(599).level, 3);
    expect(LevelProgress.fromXp(600).level, 4);
  });

  test('Fortschritt innerhalb des Levels', () {
    final p = LevelProgress.fromXp(200); // Level 2: 100..300
    expect(p.level, 2);
    expect(p.xpIntoLevel, 100);
    expect(p.xpNeededForNext, 100);
    expect(p.fraction, closeTo(0.5, 1e-9));
  });

  test('negative XP werden wie 0 behandelt', () {
    expect(LevelProgress.fromXp(-5).level, 1);
  });

  test('XP-Gründe haben eindeutige Schlüssel', () {
    final keys = XpReason.values.map((r) => r.key).toSet();
    expect(keys.length, XpReason.values.length);
  });
}
