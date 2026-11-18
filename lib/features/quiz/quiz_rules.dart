// Regeln des Quizduells (2 gegen 2). Reine Logik ohne Flutter-Import.
//
// MÜSSEN zu supabase/migrations/20261118161147_quiz_duel.sql passen.

const quizRounds = 6;
const quizQuestionsPerRound = 3;
const quizCategoryOptions = 3;
const quizSecondsPerQuestion = 30;

/// Was die angemeldete Person in einem Spiel gerade tun soll
/// (private.quiz_action in der Datenbank).
enum QuizAction {
  searching,
  choose,
  propose,
  decide,
  waitPartner,
  waitOpponent,
  finished,
  abandoned;

  static QuizAction parse(String? value) => switch (value) {
    'searching' => searching,
    'choose' => choose,
    'propose' => propose,
    'decide' => decide,
    'wait_partner' => waitPartner,
    'wait_opponent' => waitOpponent,
    'abandoned' => abandoned,
    _ => finished,
  };

  /// Muss ich jetzt etwas tun?
  bool get isMyTurn => this == choose || this == propose || this == decide;

  bool get isOver => this == finished || this == abandoned;
}

/// Wer im Team in Runde [round] vorschlägt: ungerade Runden das Mitglied
/// mit der kleineren ID (matches.user_a), gerade das andere.
bool isProposerInRound(int round, {required bool iAmUserA}) =>
    round.isOdd == iAmUserA;

/// Team, das in Runde [round] die Kategorie wählt: ungerade Team A.
bool teamAChooses(int round) => round.isOdd;
