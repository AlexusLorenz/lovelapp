import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'quiz_models.dart';
import 'quiz_repository.dart';
import 'quiz_rules.dart';

typedef BankQuestion = ({
  int id,
  String category,
  String question,
  List<String> answers,
  num? number,
  String? unit,
});

/// Fragenkatalog (assets/quiz/questions.json, erzeugt von
/// tool/quiz_questions.py). Bei Quiz/Emoji ist die erste Antwort richtig.
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
            QuizKind.parse(c['kind'] as String?),
          ),
      ],
      [
        for (final q in (j['questions']! as List<Object?>).map(m))
          (
            id: q['id']! as int,
            category: q['category']! as String,
            question: q['question']! as String,
            answers: (q['answers']! as List<Object?>).cast<String>(),
            number: q['number'] as num?,
            unit: q['unit'] as String?,
          ),
      ],
    );
  }

  final List<QuizCategory> categories;
  final List<BankQuestion> questions;

  BankQuestion byId(int id) => questions.firstWhere((q) => q.id == id);
}

class _Answer {
  int? proposal;
  num? proposalNumber;
  int? finalChoice;
  num? finalNumber;
  int? points;
  DateTime? proposalShown;
  DateTime? finalShown;

  bool get done => finalChoice != null;
}

class _Round {
  _Round(this.chooserIsMe, this.options);

  final bool chooserIsMe;
  final List<String> options;
  String? category;
  List<int> questionIds = const [];
  final mine = List.generate(quizQuestionsPerRound, (_) => _Answer());
  final theirs = List.generate(quizQuestionsPerRound, (_) => _Answer());

  bool get myDone => mine.every((a) => a.done);
  bool get theirDone => theirs.every((a) => a.done);
}

class _Game {
  _Game({
    required this.id,
    required this.kind,
    required this.myTeam,
    required this.iAmTeamA,
    this.inviteCode,
  });

  final String id;
  final QuizKind kind;
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

  int _sum(Iterable<_Answer> answers) =>
      answers.fold(0, (s, a) => s + (a.points ?? 0));
  int get myScore => _sum(rounds.expand((r) => r.mine));
  int get theirScore => _sum(rounds.expand((r) => r.theirs));
}

/// Demo: Partner:in und Gegnerteam sind Bots, die sofort reagieren.
/// Bildet die Regeln der Datenbank nach (quiz_duel/party_games).
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
  QuizBank get _b => _bank!;

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
    final cats = [
      for (final c in _b.categories)
        if (c.kind == g.kind) c,
    ]..shuffle(_random);
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

  /// Gezeigte Reihenfolge der Antworten (Positionen in `answers`).
  /// Gemischt nur bei Spielen mit richtiger Antwort.
  List<int> _order(_Game g, BankQuestion q) {
    final order = [for (var i = 0; i < q.answers.length; i++) i];
    if (g.kind.hasRightAnswer) order.shuffle(Random(Object.hash(g.id, q.id)));
    return order;
  }

  int? _correctIndex(_Game g, BankQuestion q) =>
      g.kind.hasRightAnswer ? _order(g, q).indexOf(0) : null;

  void _choose(_Game g, String category) {
    final round = _current(g);
    final used = {for (final r in g.rounds) ...r.questionIds};
    final pool = [
      for (final q in _b.questions)
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

  /// Entscheidung werten (wie quiz_answer in der Datenbank).
  void _decide(
    _Game g,
    _Answer a,
    BankQuestion q, {
    int choice = -1,
    num? number,
  }) {
    switch (g.kind) {
      case QuizKind.estimate:
        final n = number ?? a.proposalNumber;
        a
          ..finalNumber = n
          ..finalChoice = n == null ? -1 : 0
          ..points = estimatePoints(n, q.number!, q.unit);
      case QuizKind.soulmate:
        a
          ..finalChoice = choice
          ..points = choice >= 0 && choice == a.proposal ? 1 : 0;
      case QuizKind.quiz || QuizKind.emoji:
        final c = choice == -1 ? (a.proposal ?? -1) : choice;
        a
          ..finalChoice = c
          ..points = c == _correctIndex(g, q) ? 1 : 0;
    }
  }

  /// Bot-Antwort: Auswahl oder Schätzung, mit [skill] gut.
  void _botPropose(_Game g, _Answer a, BankQuestion q, double skill) {
    if (g.kind == QuizKind.estimate) {
      final factor = 1 + (_random.nextDouble() - 0.5) * (1.2 - skill);
      final guess = q.number! * factor;
      a
        ..proposalNumber = q.unit == 'Jahr' || q.number! >= 20
            ? guess.round()
            : double.parse(guess.toStringAsFixed(1))
        ..proposal = 0;
      return;
    }
    if (g.kind == QuizKind.soulmate) {
      a.proposal = _random.nextInt(q.answers.length);
      return;
    }
    final correct = _correctIndex(g, q)!;
    a.proposal = _random.nextDouble() < skill
        ? correct
        : (correct + 1 + _random.nextInt(q.answers.length - 1)) %
              q.answers.length;
  }

  void _botDecide(_Game g, _Answer a, BankQuestion q, double skill) {
    switch (g.kind) {
      case QuizKind.estimate:
        _decide(g, a, q); // übernimmt den Vorschlag
      case QuizKind.soulmate:
        // Rät richtig mit Wahrscheinlichkeit [skill].
        final guess = _random.nextDouble() < skill && (a.proposal ?? -1) >= 0
            ? a.proposal!
            : _random.nextInt(q.answers.length);
        _decide(g, a, q, choice: guess);
      case QuizKind.quiz || QuizKind.emoji:
        final follow = (a.proposal ?? -1) >= 0 && _random.nextDouble() < 0.8;
        if (follow) {
          _decide(g, a, q);
        } else {
          final tmp = _Answer();
          _botPropose(g, tmp, q, skill);
          _decide(g, a, q, choice: tmp.proposal!);
        }
    }
  }

  /// Nach dem Ende einer Teamrunde weiterziehen (wie quiz_answer im Server).
  void _teamFinished(_Game g, {required bool mine}) {
    final round = _current(g);
    if (mine == round.chooserIsMe) {
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
          final q = _b.byId(round.questionIds[i]);
          _botPropose(g, round.theirs[i], q, 0.55);
          _botDecide(g, round.theirs[i], q, 0.55);
        }
        _teamFinished(g, mine: false);
        continue;
      }
      if (g.myTurn != true) return;
      final round = _current(g);
      if (_action(g) != QuizAction.waitPartner) return;
      if (round.category == null) {
        _choose(g, round.options.first);
      } else if (round.mine.any((a) => a.proposal == null)) {
        for (var i = 0; i < quizQuestionsPerRound; i++) {
          _botPropose(g, round.mine[i], _b.byId(round.questionIds[i]), 0.65);
        }
      } else {
        for (var i = 0; i < quizQuestionsPerRound; i++) {
          _botDecide(g, round.mine[i], _b.byId(round.questionIds[i]), 0.6);
        }
        _teamFinished(g, mine: true);
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
    kind: g.kind,
    status: g.status,
    round: g.round,
    action: _action(g),
    myTeam: g.myTeam,
    opponent: g.opponent,
    myScore: g.myScore,
    opponentScore: g.rounds
        .where((r) => r.myDone || g.status == 'finished')
        .expand((r) => r.theirs)
        .fold(0, (s, a) => s + (a.points ?? 0)),
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
    await _loadBank();
    final over = g.status == 'finished' || g.status == 'abandoned';
    QuizAnswerResult? mine(_Answer a) => !a.done
        ? null
        : QuizAnswerResult(
            correct: (a.points ?? 0) > 0,
            points: a.points,
            finalChoice: a.finalChoice,
            proposal: a.proposal,
            finalNumber: a.finalNumber,
            proposalNumber: a.proposalNumber,
          );
    QuizAnswerResult? theirs(_Answer a) => !a.done
        ? null
        : QuizAnswerResult(
            correct: (a.points ?? 0) > 0,
            points: a.points,
            // Antworten über sich selbst bleiben privat (Seelenverwandt).
            finalChoice: g.kind.hasRightAnswer ? a.finalChoice : null,
            finalNumber: a.finalNumber,
          );
    QuizReview review(int id) {
      final q = _b.byId(id);
      return QuizReview(
        question: q.question,
        answers: [for (final o in _order(g, q)) q.answers[o]],
        correctIndex: _correctIndex(g, q),
        numberAnswer: q.number,
        unit: q.unit,
      );
    }

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
                ? g.myTeam.players.firstWhere((p) => p.isMe).name
                : (g.myTeam.partner?.name ?? ''),
            myDone: r.myDone,
            opponentDone: r.theirDone,
            myProposed: r.mine.where((a) => a.proposal != null).length,
            myDecided: r.mine.where((a) => a.done).length,
            questions: r.category == null
                ? const []
                : [
                    for (var q = 0; q < quizQuestionsPerRound; q++)
                      QuizQuestionSlot(
                        mine: mine(r.mine[q]),
                        opponent: (r.myDone || over)
                            ? theirs(r.theirs[q])
                            : null,
                        review: r.myDone ? review(r.questionIds[q]) : null,
                      ),
                  ],
          ),
      ],
    );
  }

  @override
  Future<String> start(
    String matchId, {
    bool invite = false,
    QuizKind kind = QuizKind.quiz,
  }) async {
    await _loadBank();
    final team = teamFor(matchId);
    if (team == null) throw const QuizFailure('Kein aktives Match');
    if (!invite) {
      for (final g in _games.values) {
        if (g.myTeam.matchId == matchId &&
            g.kind == kind &&
            g.status == 'searching' &&
            g.inviteCode == null) {
          return g.id;
        }
      }
    }
    final g = _Game(
      id: 'quiz-${_ids++}',
      kind: kind,
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
    final g =
        _Game(
            id: 'quiz-${_ids++}',
            kind: QuizKind.quiz,
            myTeam: team,
            iAmTeamA: false,
          )
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
    await _loadBank();
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
    final q = _b.byId(round.questionIds[index]);
    final deciding = action == QuizAction.decide;
    return QuizQuestionView(
      kind: g.kind,
      round: g.round,
      index: index,
      role: action,
      category: round.category!,
      question: q.question,
      answers: [for (final o in _order(g, q)) q.answers[o]],
      unit: q.unit,
      secondsLeft: max(
        0,
        quizSecondsPerQuestion - now.difference(shown).inSeconds,
      ),
      proposal: deciding && g.kind.hasRightAnswer ? a.proposal : null,
      proposalNumber: deciding && g.kind == QuizKind.estimate
          ? a.proposalNumber
          : null,
    );
  }

  @override
  Future<QuizAnswerReply> answer(
    String gameId,
    int index, {
    int choice = -1,
    num? number,
  }) async {
    final g = _game(gameId);
    final action = _action(g);
    final round = _current(g);
    final a = round.mine[index];
    final q = _b.byId(round.questionIds[index]);
    if (action == QuizAction.propose) {
      if (g.kind == QuizKind.estimate) {
        a
          ..proposalNumber = number
          ..proposal = number == null ? -1 : 0;
      } else {
        a.proposal = choice;
      }
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
    _decide(g, a, q, choice: choice, number: number);
    if (index < quizQuestionsPerRound - 1) {
      _changed(g);
      return const QuizAnswerReply(done: false);
    }
    final results = [
      for (var i = 0; i < quizQuestionsPerRound; i++)
        () {
          final r = round.mine[i];
          final rq = _b.byId(round.questionIds[i]);
          return QuizRoundOutcome(
            index: i,
            finalChoice: r.finalChoice!,
            proposal: r.proposal,
            points: r.points ?? 0,
            correctIndex: _correctIndex(g, rq),
            finalNumber: r.finalNumber,
            proposalNumber: r.proposalNumber,
            numberAnswer: rq.number,
            unit: rq.unit,
          );
        }(),
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
