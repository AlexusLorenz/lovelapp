import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'quiz_models.dart';
import 'quiz_repository.dart';
import 'quiz_rules.dart';

/// Fragenkatalog (assets/quiz/questions.json, erzeugt von
/// tool/quiz_questions.py). Erste Antwort ist richtig.
class QuizBank {
  QuizBank(this.categories, this.questions);

  factory QuizBank.fromJson(String source) {
    final j = jsonDecode(source) as Map<String, Object?>;
    Map<String, Object?> m(Object? v) => Map<String, Object?>.from(v! as Map);
    return QuizBank(
      [
        for (final c in (j['categories']! as List<Object?>).map(m))
          QuizCategory(
            c['key']! as String,
            c['emoji']! as String,
            c['label']! as String,
          ),
      ],
      [
        for (final q in (j['questions']! as List<Object?>).map(m))
          (
            id: q['id']! as int,
            category: q['category']! as String,
            question: q['question']! as String,
            answers: (q['answers']! as List<Object?>).cast<String>(),
          ),
      ],
    );
  }

  final List<QuizCategory> categories;
  final List<({int id, String category, String question, List<String> answers})>
  questions;
}

class _Answer {
  int? proposal;
  int? finalChoice;
  bool? correct;
  DateTime? proposalShown;
  DateTime? finalShown;
}

class _Round {
  _Round(this.chooserIsMe, this.options);

  final bool chooserIsMe;
  final List<String> options;
  String? category;
  List<int> questionIds = const [];
  final mine = List.generate(quizQuestionsPerRound, (_) => _Answer());
  final theirs = List.generate(quizQuestionsPerRound, (_) => _Answer());

  bool get myDone => mine.every((a) => a.finalChoice != null);
  bool get theirDone => theirs.every((a) => a.finalChoice != null);
}

class _Game {
  _Game({
    required this.id,
    required this.myTeam,
    required this.iAmTeamA,
    this.inviteCode,
  });

  final String id;
  final QuizTeam myTeam;

  /// Team A wählt in ungeraden Runden die Kategorie.
  final bool iAmTeamA;
  QuizTeam? opponent;
  String? inviteCode;
  String status = 'searching';
  int round = 1;

  /// true = mein Team, false = Gegner, null = wartet auf Gegner/Ende
  bool? myTurn = true;
  final rounds = <_Round>[];
  bool? won;
  DateTime updatedAt = DateTime.now();

  int get myScore => rounds.fold(
    0,
    (s, r) => s + r.mine.where((a) => a.correct ?? false).length,
  );
  int get theirScore => rounds.fold(
    0,
    (s, r) => s + r.theirs.where((a) => a.correct ?? false).length,
  );
}

/// Demo: Partner:in und Gegnerteam sind Bots, die sofort reagieren.
class DemoQuizRepository implements QuizRepository {
  DemoQuizRepository({
    required this.loadBank,
    required this.myUserId,
    required this.teamFor,
    Random? random,
  }) : _random = random ?? Random(7);

  /// Lädt den Fragenkatalog (in der App aus den Assets).
  final Future<QuizBank> Function() loadBank;
  final String Function() myUserId;

  /// Team zu einer Match-ID (ich + Match-Partner:in).
  final QuizTeam? Function(String matchId) teamFor;
  final Random _random;

  QuizBank? _bank;
  final _games = <String, _Game>{};
  final _changes = StreamController<void>.broadcast();
  int _ids = 0;

  static const _botTeams = [
    ['Lea', 'Tom'],
    ['Nina', 'Paul'],
    ['Emma', 'Jan'],
  ];

  Future<QuizBank> _loadBank() async => _bank ??= await loadBank();

  _Game _game(String id) =>
      _games[id] ?? (throw const QuizFailure('Spiel nicht gefunden'));

  QuizTeam _botTeam() {
    final names = _botTeams[_random.nextInt(_botTeams.length)];
    return QuizTeam(
      matchId: 'bot-${_ids++}',
      players: [for (final n in names) QuizPlayer(id: 'bot-$n', name: n)],
    );
  }

  /// Bin ich in Runde [round] die Person, die vorschlägt?
  bool _iPropose(_Game g, int round) {
    final partner = g.myTeam.partner?.id ?? '';
    return isProposerInRound(
      round,
      iAmUserA: myUserId().compareTo(partner) < 0,
    );
  }

  bool _iChoose(_Game g, int round) => teamAChooses(round) == g.iAmTeamA;

  void _openRound(_Game g) {
    final used = g.rounds.map((r) => r.category).toSet();
    final cats = [..._bank!.categories]..shuffle(_random);
    cats.sort(
      (a, b) => (used.contains(a.key) ? 1 : 0).compareTo(
        used.contains(b.key) ? 1 : 0,
      ),
    );
    g.rounds.add(
      _Round(_iChoose(g, g.round), [
        for (final c in cats.take(quizCategoryOptions)) c.key,
      ]),
    );
  }

  _Round _current(_Game g) => g.rounds[g.round - 1];

  /// Gezeigte Reihenfolge: Positionen der Antworten, je Spiel/Frage fest.
  List<int> _order(_Game g, int questionId) =>
      [0, 1, 2, 3]..shuffle(Random(Object.hash(g.id, questionId)));

  int _correctIndex(_Game g, int questionId) =>
      _order(g, questionId).indexOf(0);

  void _choose(_Game g, String category) {
    final round = _current(g);
    final used = {for (final r in g.rounds) ...r.questionIds};
    final pool = [
      for (final q in _bank!.questions)
        if (q.category == category && !used.contains(q.id)) q.id,
    ]..shuffle(_random);
    round
      ..category = category
      ..questionIds = pool.take(quizQuestionsPerRound).toList();
  }

  QuizAction _action(_Game g) {
    if (g.status == 'finished') return QuizAction.finished;
    if (g.status == 'abandoned') return QuizAction.abandoned;
    if (g.myTurn == null) return QuizAction.searching;
    if (g.myTurn == false) return QuizAction.waitOpponent;
    final round = _current(g);
    final iPropose = _iPropose(g, g.round);
    if (round.category == null) {
      return iPropose ? QuizAction.choose : QuizAction.waitPartner;
    }
    if (round.mine.any((a) => a.proposal == null)) {
      return iPropose ? QuizAction.propose : QuizAction.waitPartner;
    }
    return iPropose ? QuizAction.waitPartner : QuizAction.decide;
  }

  /// Bot-Antwort: mit Wahrscheinlichkeit [skill] richtig.
  int _botChoice(_Game g, int questionId, double skill) {
    final correct = _correctIndex(g, questionId);
    return _random.nextDouble() < skill
        ? correct
        : (correct + 1 + _random.nextInt(3)) % 4;
  }

  /// Nach dem Ende einer Teamrunde weiterziehen (wie quiz_answer im Server).
  void _teamFinished(_Game g, {required bool mine}) {
    final round = _current(g);
    final chooserIsMe = round.chooserIsMe;
    if (mine == chooserIsMe) {
      g.myTurn = mine ? (g.opponent == null ? null : false) : true;
    } else if (g.round == quizRounds) {
      g
        ..status = 'finished'
        ..myTurn = null
        ..won = g.myScore == g.theirScore ? null : g.myScore > g.theirScore;
    } else {
      g
        ..round += 1
        ..myTurn = mine;
      _openRound(g);
    }
    g.updatedAt = DateTime.now();
  }

  /// Bots spielen, bis ich wieder dran bin (oder das Spiel endet).
  void _runBots(_Game g) {
    for (var guard = 0; guard < 50; guard++) {
      if (g.status != 'active' && g.status != 'searching') return;
      if (g.myTurn == false) {
        final round = _current(g);
        if (round.category == null) {
          _choose(g, round.options[_random.nextInt(round.options.length)]);
        }
        for (var i = 0; i < quizQuestionsPerRound; i++) {
          final c = _botChoice(g, round.questionIds[i], 0.55);
          round.theirs[i]
            ..proposal = c
            ..finalChoice = c
            ..correct = c == _correctIndex(g, round.questionIds[i]);
        }
        _teamFinished(g, mine: false);
        continue;
      }
      if (g.myTurn != true) return;
      final round = _current(g);
      switch (_action(g)) {
        case QuizAction.waitPartner when round.category == null:
          _choose(g, round.options.first);
        case QuizAction.waitPartner
            when round.mine.any((a) => a.proposal == null):
          for (var i = 0; i < quizQuestionsPerRound; i++) {
            round.mine[i].proposal = _botChoice(g, round.questionIds[i], 0.65);
          }
        case QuizAction.waitPartner:
          // Partner:in entscheidet; folgt meinem Vorschlag meistens.
          for (var i = 0; i < quizQuestionsPerRound; i++) {
            final a = round.mine[i];
            final choice = (a.proposal ?? -1) >= 0 && _random.nextDouble() < 0.8
                ? a.proposal!
                : _botChoice(g, round.questionIds[i], 0.6);
            a
              ..finalChoice = choice
              ..correct = choice == _correctIndex(g, round.questionIds[i]);
          }
          _teamFinished(g, mine: true);
        default:
          return;
      }
    }
  }

  void _changed(_Game g) {
    g.updatedAt = DateTime.now();
    _changes.add(null);
  }

  // ---------------------------------------------------------------------------

  @override
  Future<List<QuizCategory>> categories() async =>
      (await _loadBank()).categories;

  QuizGameSummary _summary(_Game g) => QuizGameSummary(
    id: g.id,
    status: g.status,
    round: g.round,
    action: _action(g),
    myTeam: g.myTeam,
    opponent: g.opponent,
    myScore: g.myScore,
    opponentScore: g.rounds
        .where((r) => r.myDone || g.status == 'finished')
        .fold(
          0,
          (s, r) => s + r.theirs.where((a) => a.correct ?? false).length,
        ),
    inviteCode: g.inviteCode,
    won: g.won,
    updatedAt: g.updatedAt,
  );

  @override
  Future<List<QuizGameSummary>> myGames() async =>
      [for (final g in _games.values) _summary(g)]
        ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<QuizGameState> state(String gameId) async {
    final g = _game(gameId);
    final bank = await _loadBank();
    final over = g.status == 'finished' || g.status == 'abandoned';
    QuizAnswerResult? result(_Answer a) => a.finalChoice == null
        ? null
        : QuizAnswerResult(
            correct: a.correct,
            finalChoice: a.finalChoice,
            proposal: a.proposal,
          );
    final action = _action(g);
    return QuizGameState(
      summary: _summary(g),
      rounds: [
        for (final (i, r) in g.rounds.indexed)
          QuizRoundState(
            round: i + 1,
            chooserIsMe: r.chooserIsMe,
            category: r.category,
            options:
                i + 1 == g.round &&
                    r.category == null &&
                    action == QuizAction.choose
                ? r.options
                : null,
            myProposer: _iPropose(g, i + 1)
                ? (g.myTeam.players.firstWhere((p) => p.isMe).name)
                : (g.myTeam.partner?.name ?? ''),
            myDone: r.myDone,
            opponentDone: r.theirDone,
            myProposed: r.mine.where((a) => a.proposal != null).length,
            myDecided: r.mine.where((a) => a.finalChoice != null).length,
            questions: r.category == null
                ? const []
                : [
                    for (var q = 0; q < quizQuestionsPerRound; q++)
                      QuizQuestionSlot(
                        mine: result(r.mine[q]),
                        opponent: (r.myDone || over)
                            ? result(r.theirs[q])
                            : null,
                        review: r.myDone
                            ? () {
                                final question = bank.questions.firstWhere(
                                  (x) => x.id == r.questionIds[q],
                                );
                                final order = _order(g, question.id);
                                return QuizReview(
                                  question: question.question,
                                  answers: [
                                    for (final o in order) question.answers[o],
                                  ],
                                  correctIndex: order.indexOf(0),
                                );
                              }()
                            : null,
                      ),
                  ],
          ),
      ],
    );
  }

  @override
  Future<String> start(String matchId, {bool invite = false}) async {
    await _loadBank();
    final team = teamFor(matchId);
    if (team == null) throw const QuizFailure('Kein aktives Match');
    if (!invite) {
      for (final g in _games.values) {
        if (g.myTeam.matchId == matchId &&
            g.status == 'searching' &&
            g.inviteCode == null) {
          return g.id;
        }
      }
    }
    final g = _Game(
      id: 'quiz-${_ids++}',
      myTeam: team,
      iAmTeamA: true,
      inviteCode: invite ? 'DEMO42' : null,
    );
    _games[g.id] = g;
    _openRound(g);
    if (!invite) {
      // Demo: Gegnerteam ist sofort gefunden.
      g
        ..opponent = _botTeam()
        ..status = 'active';
    }
    _runBots(g);
    _changed(g);
    return g.id;
  }

  @override
  Future<String> join(String matchId, String code) async {
    await _loadBank();
    final team = teamFor(matchId);
    if (team == null) throw const QuizFailure('Kein aktives Match');
    if (code.trim().length != 6) {
      throw const QuizFailure('Code ungültig oder schon benutzt');
    }
    // Demo: Code gehört immer einem Bot-Team, das Runde 1 schon gespielt hat.
    final g = _Game(id: 'quiz-${_ids++}', myTeam: team, iAmTeamA: false)
      ..opponent = _botTeam()
      ..status = 'active'
      ..myTurn = false;
    _games[g.id] = g;
    _openRound(g);
    _runBots(g);
    _changed(g);
    return g.id;
  }

  @override
  Future<void> chooseCategory(String gameId, String category) async {
    final g = _game(gameId);
    if (_action(g) != QuizAction.choose) {
      throw const QuizFailure('Du bist gerade nicht mit der Kategorie dran');
    }
    if (!_current(g).options.contains(category)) {
      throw const QuizFailure('Kategorie steht nicht zur Wahl');
    }
    _choose(g, category);
    _changed(g);
  }

  @override
  Future<QuizQuestionView> showQuestion(String gameId, int index) async {
    final g = _game(gameId);
    final bank = await _loadBank();
    final action = _action(g);
    if (action != QuizAction.propose && action != QuizAction.decide) {
      throw const QuizFailure('Du bist gerade nicht dran');
    }
    final round = _current(g);
    final a = round.mine[index];
    final now = DateTime.now();
    final shown = action == QuizAction.propose
        ? (a.proposalShown ??= now)
        : (a.finalShown ??= now);
    final question = bank.questions.firstWhere(
      (q) => q.id == round.questionIds[index],
    );
    final order = _order(g, question.id);
    return QuizQuestionView(
      round: g.round,
      index: index,
      role: action,
      category: round.category!,
      question: question.question,
      answers: [for (final o in order) question.answers[o]],
      secondsLeft: max(
        0,
        quizSecondsPerQuestion - now.difference(shown).inSeconds,
      ),
      proposal: action == QuizAction.decide ? a.proposal : null,
    );
  }

  @override
  Future<QuizAnswerReply> answer(String gameId, int index, int choice) async {
    final g = _game(gameId);
    final action = _action(g);
    final round = _current(g);
    final a = round.mine[index];
    if (action == QuizAction.propose) {
      a.proposal = choice;
      _changed(g);
      if (index < quizQuestionsPerRound - 1) {
        return const QuizAnswerReply(done: false);
      }
      _runBots(g); // Partner:in entscheidet
      _changed(g);
      return const QuizAnswerReply(done: true);
    }
    if (action != QuizAction.decide) {
      throw const QuizFailure('Du bist gerade nicht dran');
    }
    final finalChoice = choice == -1 ? (a.proposal ?? -1) : choice;
    a
      ..finalChoice = finalChoice
      ..correct = finalChoice == _correctIndex(g, round.questionIds[index]);
    if (index < quizQuestionsPerRound - 1) {
      _changed(g);
      return const QuizAnswerReply(done: false);
    }
    final results = [
      for (var i = 0; i < quizQuestionsPerRound; i++)
        QuizRoundOutcome(
          index: i,
          finalChoice: round.mine[i].finalChoice!,
          proposal: round.mine[i].proposal,
          correctIndex: _correctIndex(g, round.questionIds[i]),
        ),
    ];
    _teamFinished(g, mine: true);
    _runBots(g);
    _changed(g);
    return QuizAnswerReply(done: true, results: results);
  }

  @override
  Future<void> giveUp(String gameId) async {
    final g = _game(gameId);
    g
      ..status = 'abandoned'
      ..myTurn = null
      ..won = false;
    _changed(g);
  }

  @override
  Stream<void> changes() => _changes.stream;
}
