// Datenmodelle fürs Quizduell. Reine Logik ohne Flutter-Import.

import 'quiz_rules.dart';

class QuizCategory {
  const QuizCategory(
    this.key,
    this.emoji,
    this.label, [
    this.kind = QuizKind.quiz,
  ]);

  final String key;
  final String emoji;
  final String label;
  final QuizKind kind;

  String get display => '$emoji $label';
}

class QuizPlayer {
  const QuizPlayer({required this.id, required this.name, this.isMe = false});

  factory QuizPlayer.fromJson(Map<String, Object?> j) => QuizPlayer(
    id: j['id']! as String,
    name: j['name'] as String? ?? '?',
    isMe: j['is_me'] as bool? ?? false,
  );

  final String id;
  final String name;
  final bool isMe;
}

class QuizTeam {
  const QuizTeam({required this.matchId, required this.players});

  factory QuizTeam.fromJson(Map<String, Object?> j) => QuizTeam(
    matchId: j['id']! as String,
    players: [
      for (final p in j['players']! as List<Object?>)
        QuizPlayer.fromJson(Map<String, Object?>.from(p! as Map)),
    ],
  );

  final String matchId;
  final List<QuizPlayer> players;

  /// „Anna & Arne“
  String get names => players.map((p) => p.name).join(' & ');

  /// Die andere Person im eigenen Team.
  QuizPlayer? get partner {
    for (final p in players) {
      if (!p.isMe) return p;
    }
    return null;
  }
}

/// Eintrag in der Spielübersicht.
class QuizGameSummary {
  const QuizGameSummary({
    required this.id,
    required this.status,
    required this.round,
    required this.action,
    required this.myTeam,
    required this.myScore,
    required this.opponentScore,
    required this.updatedAt,
    this.kind = QuizKind.quiz,
    this.opponent,
    this.inviteCode,
    this.won,
  });

  factory QuizGameSummary.fromJson(Map<String, Object?> j) => QuizGameSummary(
    id: j['id']! as String,
    kind: QuizKind.parse(j['kind'] as String?),
    status: j['status']! as String,
    round: (j['round'] as num?)?.toInt() ?? 1,
    action: QuizAction.parse(j['action'] as String?),
    myTeam: QuizTeam.fromJson(Map<String, Object?>.from(j['my_team']! as Map)),
    opponent: j['opponent'] == null
        ? null
        : QuizTeam.fromJson(Map<String, Object?>.from(j['opponent']! as Map)),
    myScore: (j['my_score'] as num?)?.toInt() ?? 0,
    opponentScore: (j['opponent_score'] as num?)?.toInt() ?? 0,
    inviteCode: j['invite_code'] as String?,
    won: j['won'] as bool?,
    updatedAt: DateTime.parse(j['updated_at']! as String),
  );

  final String id;
  final QuizKind kind;
  final String status;
  final int round;
  final QuizAction action;
  final QuizTeam myTeam;
  final QuizTeam? opponent;
  final int myScore;
  final int opponentScore;
  final String? inviteCode;
  final bool? won;
  final DateTime updatedAt;
}

/// Ergebnis eines Teams bei einer Frage.
class QuizAnswerResult {
  const QuizAnswerResult({
    this.correct,
    this.points,
    this.finalChoice,
    this.proposal,
    this.finalNumber,
    this.proposalNumber,
  });

  factory QuizAnswerResult.fromJson(Map<String, Object?> j) => QuizAnswerResult(
    correct: j['correct'] as bool?,
    points: (j['points'] as num?)?.toInt(),
    finalChoice: (j['final'] as num?)?.toInt(),
    proposal: (j['proposal'] as num?)?.toInt(),
    finalNumber: j['final_number'] as num?,
    proposalNumber: j['proposal_number'] as num?,
  );

  final bool? correct;

  /// 0–3 im Schätzduell, sonst 0/1.
  final int? points;
  final int? finalChoice;
  final int? proposal;
  final num? finalNumber;
  final num? proposalNumber;
}

/// Frage zum Nachlesen (erst nach der eigenen Runde verfügbar).
class QuizReview {
  const QuizReview({
    required this.question,
    required this.answers,
    this.correctIndex,
    this.numberAnswer,
    this.unit,
  });

  factory QuizReview.fromJson(Map<String, Object?> j) => QuizReview(
    question: j['question']! as String,
    answers: [
      for (final a in (j['answers'] as List<Object?>? ?? const []))
        a! as String,
    ],
    correctIndex: (j['correct_index'] as num?)?.toInt(),
    numberAnswer: j['number_answer'] as num?,
    unit: j['unit'] as String?,
  );

  final String question;
  final List<String> answers;

  /// Nur bei Spielen mit richtiger Antwort (Quiz, Emoji).
  final int? correctIndex;

  /// Nur im Schätzduell.
  final num? numberAnswer;
  final String? unit;
}

class QuizQuestionSlot {
  const QuizQuestionSlot({this.mine, this.opponent, this.review});

  factory QuizQuestionSlot.fromJson(Map<String, Object?> j) {
    Map<String, Object?>? m(Object? v) =>
        v == null ? null : Map<String, Object?>.from(v as Map);
    return QuizQuestionSlot(
      mine: m(j['mine']) == null
          ? null
          : QuizAnswerResult.fromJson(m(j['mine'])!),
      opponent: m(j['opponent']) == null
          ? null
          : QuizAnswerResult.fromJson(m(j['opponent'])!),
      review: m(j['review']) == null
          ? null
          : QuizReview.fromJson(m(j['review'])!),
    );
  }

  final QuizAnswerResult? mine;
  final QuizAnswerResult? opponent;
  final QuizReview? review;
}

class QuizRoundState {
  const QuizRoundState({
    required this.round,
    required this.chooserIsMe,
    required this.myProposer,
    required this.myDone,
    required this.opponentDone,
    this.myProposed = 0,
    this.myDecided = 0,
    this.category,
    this.options,
    this.questions = const [],
  });

  factory QuizRoundState.fromJson(Map<String, Object?> j) => QuizRoundState(
    round: (j['round']! as num).toInt(),
    chooserIsMe: j['chooser_is_me'] as bool? ?? false,
    category: j['category'] as String?,
    options: (j['options'] as List<Object?>?)?.cast<String>(),
    myProposer: j['my_proposer'] as String? ?? '',
    myDone: j['my_done'] as bool? ?? false,
    myProposed: (j['my_proposed'] as num?)?.toInt() ?? 0,
    myDecided: (j['my_decided'] as num?)?.toInt() ?? 0,
    opponentDone: j['opponent_done'] as bool? ?? false,
    questions: [
      for (final q in (j['questions'] as List<Object?>? ?? const []))
        QuizQuestionSlot.fromJson(Map<String, Object?>.from(q! as Map)),
    ],
  );

  final int round;
  final bool chooserIsMe;
  final String? category;

  /// Nur gesetzt, wenn ich gerade die Kategorie wählen soll.
  final List<String>? options;

  /// Vorname der Person, die in dieser Runde für mein Team vorschlägt.
  final String myProposer;
  final bool myDone;
  final bool opponentDone;

  /// Wie viele Fragen mein Team in dieser Runde schon vorgeschlagen/entschieden hat.
  final int myProposed;
  final int myDecided;
  final List<QuizQuestionSlot> questions;
}

class QuizGameState {
  const QuizGameState({required this.summary, required this.rounds});

  factory QuizGameState.fromJson(Map<String, Object?> j) => QuizGameState(
    summary: QuizGameSummary.fromJson(j),
    rounds: [
      for (final r in (j['rounds'] as List<Object?>? ?? const []))
        QuizRoundState.fromJson(Map<String, Object?>.from(r! as Map)),
    ],
  );

  final QuizGameSummary summary;
  final List<QuizRoundState> rounds;

  QuizRoundState? get currentRound {
    for (final r in rounds) {
      if (r.round == summary.round) return r;
    }
    return null;
  }
}

/// Eine angezeigte Frage (Zeit läuft ab dem Anzeigen).
class QuizQuestionView {
  const QuizQuestionView({
    required this.round,
    required this.index,
    required this.role,
    required this.category,
    required this.question,
    required this.answers,
    required this.secondsLeft,
    this.kind = QuizKind.quiz,
    this.unit,
    this.proposal,
    this.proposalNumber,
  });

  factory QuizQuestionView.fromJson(Map<String, Object?> j) => QuizQuestionView(
    kind: QuizKind.parse(j['kind'] as String?),
    unit: j['unit'] as String?,
    proposalNumber: j['proposal_number'] as num?,
    round: (j['round']! as num).toInt(),
    index: (j['q_index']! as num).toInt(),
    role: QuizAction.parse(j['role'] as String?),
    category: j['category']! as String,
    question: j['question']! as String,
    answers: [
      for (final a in (j['answers'] as List<Object?>? ?? const []))
        a! as String,
    ],
    secondsLeft: (j['seconds_left']! as num).toInt(),
    proposal: (j['proposal'] as num?)?.toInt(),
  );

  final QuizKind kind;
  final int round;
  final int index;

  /// Einheit der Schätzung (Schätzduell).
  final String? unit;

  /// Vorschlag beim Entscheiden im Schätzduell.
  final num? proposalNumber;

  /// [QuizAction.propose] oder [QuizAction.decide].
  final QuizAction role;
  final String category;
  final String question;
  final List<String> answers;
  final int secondsLeft;

  /// Vorschlag der Partnerin/des Partners (nur beim Entscheiden; nicht bei
  /// Seelenverwandt), -1 = keiner.
  final int? proposal;
}

/// Auflösung nach der letzten Entscheidung einer Runde.
class QuizRoundOutcome {
  const QuizRoundOutcome({
    required this.index,
    required this.finalChoice,
    required this.points,
    this.correctIndex,
    this.proposal,
    this.finalNumber,
    this.proposalNumber,
    this.numberAnswer,
    this.unit,
  });

  factory QuizRoundOutcome.fromJson(Map<String, Object?> j) => QuizRoundOutcome(
    index: (j['q_index']! as num).toInt(),
    finalChoice: (j['final'] as num?)?.toInt() ?? -1,
    proposal: (j['proposal'] as num?)?.toInt(),
    points: (j['points'] as num?)?.toInt() ?? ((j['correct'] == true) ? 1 : 0),
    correctIndex: (j['correct_index'] as num?)?.toInt(),
    finalNumber: j['final_number'] as num?,
    proposalNumber: j['proposal_number'] as num?,
    numberAnswer: j['number_answer'] as num?,
    unit: j['unit'] as String?,
  );

  final int index;
  final int finalChoice;
  final int? proposal;
  final int points;

  /// Quiz/Emoji: richtige Antwort.
  final int? correctIndex;

  /// Schätzduell.
  final num? finalNumber;
  final num? proposalNumber;
  final num? numberAnswer;
  final String? unit;

  bool get correct => points > 0;
}

class QuizAnswerReply {
  const QuizAnswerReply({required this.done, this.results = const []});

  factory QuizAnswerReply.fromJson(Map<String, Object?> j) => QuizAnswerReply(
    done: j['done'] as bool? ?? false,
    results: [
      for (final r in (j['results'] as List<Object?>? ?? const []))
        QuizRoundOutcome.fromJson(Map<String, Object?>.from(r! as Map)),
    ],
  );

  final bool done;

  /// Nur nach der letzten Entscheidung der Runde gefüllt.
  final List<QuizRoundOutcome> results;
}

class QuizFailure implements Exception {
  const QuizFailure(this.message);
  final String message;

  @override
  String toString() => message;
}
