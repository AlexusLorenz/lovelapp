import 'quiz_models.dart';

/// Quizduell 2 gegen 2. Die Spielregeln setzt der Server durch; der Client
/// zeigt nur an und schickt Aktionen.
abstract interface class QuizRepository {
  Future<List<QuizCategory>> categories();

  /// Laufende und kürzlich beendete Spiele aller eigenen Matches.
  Future<List<QuizGameSummary>> myGames();

  Future<QuizGameState> state(String gameId);

  /// Startet ein Spiel für das Team [matchId]. [invite]: mit Einladungscode
  /// statt Zufallsgegner.
  Future<String> start(String matchId, {bool invite = false});

  /// Tritt mit [matchId] einem Spiel per Code bei.
  Future<String> join(String matchId, String code);

  Future<void> chooseCategory(String gameId, String category);

  /// Zeigt Frage [index] der aktuellen Runde; ab jetzt läuft die Zeit.
  Future<QuizQuestionView> showQuestion(String gameId, int index);

  /// [choice]: 0–3, -1 = keine Antwort.
  Future<QuizAnswerReply> answer(String gameId, int index, int choice);

  Future<void> giveUp(String gameId);

  /// Meldet Änderungen an eigenen Spielen (für Neuladen).
  Stream<void> changes();
}
