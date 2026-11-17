import 'package:flutter_test/flutter_test.dart';
import 'package:lovelapp/features/games/this_or_that/this_or_that.dart';

void main() {
  const questions = [
    ThisOrThatQuestion('Berge', 'Meer'),
    ThisOrThatQuestion('Kaffee', 'Tee'),
    ThisOrThatQuestion('Hund', 'Katze'),
    ThisOrThatQuestion('Pizza', 'Sushi'),
  ];

  test('berechnet Übereinstimmung und gemeinsame Antworten', () {
    final round = ThisOrThatRound(questions);
    for (final c in [Choice.a, Choice.a, Choice.b, Choice.b]) {
      round.answer('anna', c);
    }
    for (final c in [Choice.a, Choice.b, Choice.b, Choice.a]) {
      round.answer('ben', c);
    }
    expect(round.matchPercent('anna', 'ben'), 50);
    expect(round.sharedPicks('anna', 'ben'), ['Berge', 'Katze']);
  });

  test('Ergebnis erst, wenn beide fertig sind', () {
    final round = ThisOrThatRound(questions)..answer('anna', Choice.a);
    expect(() => round.matchPercent('anna', 'ben'), throwsStateError);
  });

  test('keine Antwort über die letzte Frage hinaus', () {
    final round = ThisOrThatRound(questions);
    for (var i = 0; i < questions.length; i++) {
      round.answer('anna', Choice.a);
    }
    expect(() => round.answer('anna', Choice.a), throwsStateError);
  });
}
