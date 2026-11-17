/// Spiellogik für „This or That“ – ohne UI, damit sie testbar ist und später
/// 1:1 serverseitig (Edge Function) gespiegelt werden kann.
library;

enum Choice { a, b }

class ThisOrThatQuestion {
  const ThisOrThatQuestion(this.optionA, this.optionB);

  final String optionA;
  final String optionB;

  String label(Choice choice) => choice == Choice.a ? optionA : optionB;
}

class ThisOrThatRound {
  ThisOrThatRound(this.questions)
    : assert(questions.isNotEmpty, 'Mindestens eine Frage nötig');

  final List<ThisOrThatQuestion> questions;
  final Map<String, List<Choice>> _answers = {};

  /// Speichert die Antwort eines Spielers für die nächste offene Frage.
  void answer(String playerId, Choice choice) {
    final list = _answers.putIfAbsent(playerId, () => []);
    if (list.length >= questions.length) {
      throw StateError('Spieler $playerId hat schon alle Fragen beantwortet.');
    }
    list.add(choice);
  }

  List<Choice> answersOf(String playerId) =>
      List.unmodifiable(_answers[playerId] ?? const []);

  bool isFinishedFor(String playerId) =>
      answersOf(playerId).length == questions.length;

  /// Übereinstimmung in Prozent (0–100), sobald beide fertig sind.
  int matchPercent(String playerA, String playerB) {
    if (!isFinishedFor(playerA) || !isFinishedFor(playerB)) {
      throw StateError('Beide Spieler müssen alle Fragen beantworten.');
    }
    final a = answersOf(playerA);
    final b = answersOf(playerB);
    var same = 0;
    for (var i = 0; i < questions.length; i++) {
      if (a[i] == b[i]) same++;
    }
    return (same * 100 / questions.length).round();
  }

  /// Fragen, bei denen beide gleich geantwortet haben – gute Gesprächsthemen.
  List<String> sharedPicks(String playerA, String playerB) {
    final a = answersOf(playerA);
    final b = answersOf(playerB);
    final picks = <String>[];
    for (var i = 0; i < questions.length && i < a.length && i < b.length; i++) {
      if (a[i] == b[i]) picks.add(questions[i].label(a[i]));
    }
    return picks;
  }
}

/// Startfragen fürs MVP. Später aus der Datenbank laden.
const defaultThisOrThatQuestions = [
  ThisOrThatQuestion('Berge', 'Meer'),
  ThisOrThatQuestion('Kaffee', 'Tee'),
  ThisOrThatQuestion('Frühaufsteher:in', 'Nachteule'),
  ThisOrThatQuestion('Hund', 'Katze'),
  ThisOrThatQuestion('Pizza', 'Sushi'),
  ThisOrThatQuestion('Festival', 'Couch & Serie'),
  ThisOrThatQuestion('Spontan', 'Durchgeplant'),
];
