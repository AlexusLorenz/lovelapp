// Regeln der 2-gegen-2-Spiele. Reine Logik ohne Flutter-Import.
//
// MÜSSEN zu supabase/migrations/20261118161147_quiz_duel.sql und
// 20261118210000_party_games.sql passen.

const quizRounds = 6;
const quizQuestionsPerRound = 3;
const quizCategoryOptions = 3;
const quizSecondsPerQuestion = 30;

/// Spielarten auf derselben Team-Engine (quiz_games.kind).
enum QuizKind {
  quiz(
    'quiz',
    'Quizduell',
    '🧠',
    'Wissensfragen aus 13 Kategorien – wer weiß mehr?',
    'Eine:r schlägt Antworten vor, die andere Person entscheidet.',
  ),
  estimate(
    'estimate',
    'Schätzduell',
    '📏',
    'Wie hoch? Wie viele? Wann? Je näher dran, desto mehr Punkte.',
    'Eine:r schätzt, die andere Person korrigiert. Bis zu 3 Punkte pro Frage.',
  ),
  emoji(
    'emoji',
    'Emoji-Rätsel',
    '🧩',
    'Filme, Sprichwörter, Märchen – nur in Emojis.',
    'Eine:r schlägt eine Lösung vor, die andere Person entscheidet.',
  ),
  soulmate(
    'soulmate',
    'Seelenverwandt',
    '💞',
    'Wie gut kennt ihr euch? Das Paar mit mehr Treffern gewinnt.',
    'Eine:r beantwortet ehrlich eine Frage über sich, die andere Person '
        'rät – ohne die Antwort zu sehen.',
  );

  const QuizKind(this.key, this.title, this.symbol, this.tagline, this.howTo);

  final String key;
  final String title;

  /// Emoji als Symbol des Spiels.
  final String symbol;
  final String tagline;
  final String howTo;

  static QuizKind parse(String? key) =>
      values.firstWhere((k) => k.key == key, orElse: () => quiz);

  /// Höchstpunktzahl pro Frage.
  int get maxPointsPerQuestion => this == estimate ? 3 : 1;

  /// Wird beim Entscheiden der Vorschlag angezeigt?
  bool get showsProposal => this != soulmate;

  /// Gibt es eine richtige Antwort?
  bool get hasRightAnswer => this == quiz || this == emoji;
}

/// Punkte im Schätzduell (private.quiz_estimate_points): Jahreszahlen nach
/// Jahren (±1/±5/±15), sonst relativ (5 %/20 %/50 %).
int estimatePoints(num? guess, num truth, String? unit) {
  if (guess == null) return 0;
  final diff = (guess - truth).abs();
  if (unit == 'Jahr') {
    if (diff <= 1) return 3;
    if (diff <= 5) return 2;
    if (diff <= 15) return 1;
    return 0;
  }
  final base = truth.abs();
  if (diff <= 0.05 * base) return 3;
  if (diff <= 0.20 * base) return 2;
  if (diff <= 0.50 * base) return 1;
  return 0;
}

/// Zahl für die Anzeige: 8849 → „8.849“, 5.5 → „5,5“.
String formatQuizNumber(num? value) {
  if (value == null) return '–';
  final isInt = value == value.roundToDouble();
  final text = isInt ? value.round().toString() : value.toString();
  final parts = text.split('.');
  final grouped = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+$)'),
    (m) => '${m[1]}.',
  );
  return parts.length > 1 ? '$grouped,${parts[1]}' : grouped;
}

/// „1.234,5“ oder „1234.5“ → 1234.5; leer/ungültig → null.
num? parseQuizNumber(String input) {
  final cleaned = input.trim().replaceAll(' ', '');
  if (cleaned.isEmpty) return null;
  // Deutsch: Punkt = Tausender, Komma = Dezimal. Nur Punkt ohne Komma und
  // genau eine Nachkommastelle-Gruppe ≠ 3 Ziffern → als Dezimalpunkt lesen.
  String normalized;
  if (cleaned.contains(',')) {
    normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(cleaned)) {
    normalized = cleaned.replaceAll('.', '');
  } else {
    normalized = cleaned;
  }
  return num.tryParse(normalized);
}

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
