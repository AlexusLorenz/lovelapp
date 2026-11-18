import 'quiz_models.dart';
import 'quiz_rules.dart';

/// 2-gegen-2-Spiele (Quizduell, Schätzduell, Emoji-Rätsel, Seelenverwandt). Die Spielregeln setzt der Server durch; der Client
/// zeigt nur an und schickt Aktionen.
abstract interface class QuizRepository {
  Future<List<QuizCategory>> categories();

  /// Laufende und kürzlich beendete Spiele aller eigenen Matches.
  Future<List<QuizGameSummary>> myGames();

  Future<QuizGameState> state(String gameId);

  /// Startet ein Spiel der Art [kind] für das Team [matchId]. [invite]: mit
  /// Einladungscode statt Zufallsgegner.
  Future<String> start(
    String matchId, {
    bool invite = false,
    QuizKind kind = QuizKind.quiz,
  });

  /// Tritt mit [matchId] einem Spiel per Code bei.
  Future<String> join(String matchId, String code);

  Future<void> chooseCategory(String gameId, String category);

  /// Zeigt Frage [index] der aktuellen Runde; ab jetzt läuft die Zeit.
  Future<QuizQuestionView> showQuestion(String gameId, int index);

  /// [choice]: Index der Antwort, -1 = keine. [number]: Schätzung
  /// (Schätzduell), null = keine.
  Future<QuizAnswerReply> answer(
    String gameId,
    int index, {
    int choice = -1,
    num? number,
  });

  Future<void> giveUp(String gameId);

  /// Meldet Änderungen an eigenen Spielen (für Neuladen).
  Stream<void> changes();
}
