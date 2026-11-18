import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lovelapp/features/quiz/demo_quiz_repository.dart';
import 'package:lovelapp/features/quiz/quiz_models.dart';
import 'package:lovelapp/features/quiz/quiz_play_screen.dart';
import 'package:lovelapp/features/quiz/quiz_rules.dart';

import '../helpers.dart';

QuizBank loadBank() =>
    QuizBank.fromJson(File('assets/quiz/questions.json').readAsStringSync());

DemoQuizRepository demoRepo() => DemoQuizRepository(
  loadBank: () async => loadBank(),
  myUserId: () => 'a-me',
  teamFor: (id) => QuizTeam(
    matchId: id,
    players: const [
      QuizPlayer(id: 'a-me', name: 'Ich', isMe: true),
      QuizPlayer(id: 'b-partner', name: 'Mia'),
    ],
  ),
);

/// Erst in den sichtbaren Bereich scrollen, dann tippen.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    // Noch nicht gebaut (lange Liste) → hinscrollen.
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Pumpt ohne auf das Ende des 30-Sekunden-Timers zu warten.
Future<void> settleShort(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('Fragenkatalog', () {
    test('Jede Kategorie hat genug Fragen, Antworten sind eindeutig', () {
      final bank = loadBank();
      expect(
        bank.categories.where((c) => c.kind == QuizKind.quiz),
        hasLength(13),
      );
      for (final kind in QuizKind.values) {
        expect(
          bank.categories.where((c) => c.kind == kind).length,
          greaterThanOrEqualTo(quizCategoryOptions),
          reason: kind.key,
        );
      }
      for (final c in bank.categories) {
        final n = bank.questions.where((q) => q.category == c.key).length;
        // 6 Runden × 3 Fragen könnten im Extremfall dieselbe Kategorie
        // brauchen – mindestens 2 Runden pro Kategorie müssen gehen.
        expect(
          n,
          greaterThanOrEqualTo(2 * quizQuestionsPerRound),
          reason: c.key,
        );
      }
      final kindOf = {for (final c in bank.categories) c.key: c.kind};
      for (final q in bank.questions) {
        switch (kindOf[q.category]!) {
          case QuizKind.estimate:
            expect(q.answers, isEmpty);
            expect(q.number, isNotNull, reason: q.question);
            expect(q.unit, isNotNull, reason: q.question);
          case QuizKind.soulmate:
            expect(q.answers.length, inInclusiveRange(2, 4));
            expect(q.answers.toSet(), hasLength(q.answers.length));
          case QuizKind.quiz || QuizKind.emoji:
            expect(q.answers.toSet(), hasLength(4), reason: q.question);
        }
      }
    });

    test('Datenbank-Seed passt zum Katalog', () {
      // Alle Seeds zusammen (Quiz + weitere Spiele).
      final sql = Directory('supabase/migrations')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.contains('questions'))
          .map((f) => f.readAsStringSync())
          .join('\n');
      final bank = loadBank();
      for (final q in bank.questions) {
        expect(
          sql.contains("(${q.id}, '${q.category}', "),
          isTrue,
          reason:
              'Frage ${q.id} fehlt im Seed – tool/quiz_questions.py ausführen',
        );
      }
    });
  });

  for (final kind in QuizKind.values) {
    test('Demo: ${kind.title} komplett bis zum Ende', () async {
      final repo = demoRepo();
      final id = await repo.start('m1', kind: kind);
      for (var guard = 0; guard < 100; guard++) {
        final s = await repo.state(id);
        final action = s.summary.action;
        if (action.isOver) break;
        expect(action.isMyTurn, isTrue, reason: 'Bots spielen sofort');
        if (action == QuizAction.choose) {
          final options = s.currentRound!.options!;
          final cats = {for (final c in await repo.categories()) c.key: c};
          expect(options.every((o) => cats[o]!.kind == kind), isTrue);
          await repo.chooseCategory(id, options.first);
          continue;
        }
        final start = action == QuizAction.propose
            ? s.currentRound!.myProposed
            : s.currentRound!.myDecided;
        for (var i = start; i < quizQuestionsPerRound; i++) {
          final q = await repo.showQuestion(id, i);
          expect(q.kind, kind);
          if (action == QuizAction.decide) {
            switch (kind) {
              case QuizKind.estimate:
                expect(q.proposalNumber, isNotNull);
              case QuizKind.soulmate:
                expect(q.proposal, isNull, reason: 'Antwort bleibt verborgen');
              case _:
                expect(q.proposal, isNotNull);
            }
          }
          if (kind == QuizKind.estimate) {
            expect(q.answers, isEmpty);
            await repo.answer(id, i, number: 100);
          } else {
            await repo.answer(id, i, choice: 0);
          }
        }
      }
      final end = await repo.state(id);
      expect(end.summary.action, QuizAction.finished);
      expect(end.summary.kind, kind);
      expect(end.rounds, hasLength(quizRounds));
      final mine = end.rounds
          .expand((r) => r.questions)
          .fold(0, (sum, q) => sum + (q.mine?.points ?? 0));
      expect(end.summary.myScore, mine);
      final texts = end.rounds
          .expand((r) => r.questions)
          .map((q) => q.review!.question)
          .toSet();
      expect(texts, hasLength(quizRounds * quizQuestionsPerRound));
    });
  }

  group('Schätzduell', () {
    test('Punkte wie in der Datenbank', () {
      expect(estimatePoints(330, 330, 'm'), 3);
      expect(estimatePoints(345, 330, 'm'), 3);
      expect(estimatePoints(390, 330, 'm'), 2);
      expect(estimatePoints(480, 330, 'm'), 1);
      expect(estimatePoints(150, 330, 'm'), 0);
      expect(estimatePoints(1990, 1989, 'Jahr'), 3);
      expect(estimatePoints(1980, 1989, 'Jahr'), 1);
      expect(estimatePoints(1950, 1989, 'Jahr'), 0);
      expect(estimatePoints(null, 1989, 'Jahr'), 0);
    });

    test('Zahlen deutsch lesen und schreiben', () {
      expect(parseQuizNumber('8.849'), 8849);
      expect(parseQuizNumber('5,5'), 5.5);
      expect(parseQuizNumber('1.234,5'), 1234.5);
      expect(parseQuizNumber('357600'), 357600);
      expect(parseQuizNumber('2.5'), 2.5);
      expect(parseQuizNumber(''), isNull);
      expect(parseQuizNumber('viel'), isNull);
      expect(formatQuizNumber(8849), '8.849');
      expect(formatQuizNumber(148000), '148.000');
      expect(formatQuizNumber(5.5), '5,5');
      expect(formatQuizNumber(330), '330');
    });
  });

  test('Demo: Rollen wechseln jede Runde', () async {
    final repo = demoRepo();
    final id = await repo.start('m1');
    var s = await repo.state(id);
    expect(
      s.summary.action,
      QuizAction.choose,
      reason: 'Runde 1: ich schlage vor',
    );
    await repo.chooseCategory(id, s.currentRound!.options!.first);
    for (var i = 0; i < 3; i++) {
      await repo.showQuestion(id, i);
      await repo.answer(id, i, choice: 1);
    }
    s = await repo.state(id);
    expect(s.summary.round, 2);
    expect(
      s.summary.action,
      QuizAction.decide,
      reason: 'Runde 2: Mia schlägt vor',
    );
  });

  testWidgets('Quizduell: starten, vorschlagen, später entscheiden', (
    tester,
  ) async {
    await pumpLovelApp(tester);
    await tester.tap(find.text('Spiele').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Quizduell').first);
    await tapVisible(tester, find.text('Mia'));
    await tapVisible(tester, find.text('Zufälliges Gegnerteam'));

    expect(find.text('Runde 1: Du wählst die Kategorie'), findsOneWidget);
    await tester.tap(find.text('Kategorie wählen'));
    await tester.pumpAndSettle();
    expect(find.text('Wähle eine Kategorie'), findsOneWidget);
    await tester.tap(find.byType(FilledButton).first);
    await settleShort(tester);

    for (var i = 0; i < 3; i++) {
      expect(find.text('Du schlägst vor'), findsOneWidget);
      await tester.tap(find.byType(InkWell).at(1));
      await settleShort(tester);
    }
    expect(find.text('Vorschläge abgegeben!'), findsOneWidget);
    await tester.tap(find.text('Zur Übersicht'));
    await tester.pumpAndSettle();

    // Mia hat entschieden, die Gegner haben gespielt → Runde 2, ich entscheide
    expect(find.text('Runde 2: Du entscheidest'), findsOneWidget);
    await tester.tap(find.text('Jetzt entscheiden'));
    await settleShort(tester);
    expect(find.byType(QuizPlayScreen), findsOneWidget);
    expect(find.textContaining('Vorschlag von Mia'), findsWidgets);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byType(InkWell).at(1));
      await settleShort(tester);
    }
    expect(find.textContaining('von 3 richtig'), findsOneWidget);
    await tester.tap(find.text('Zur Übersicht'));
    await tester.pumpAndSettle();
    expect(find.text('Quizduell'), findsOneWidget);
  });

  testWidgets('Zeit abgelaufen zählt als keine Antwort', (tester) async {
    await pumpLovelApp(tester);
    await tester.tap(find.text('Spiele').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Quizduell').first);
    await tapVisible(tester, find.text('Mia'));
    await tapVisible(tester, find.text('Zufälliges Gegnerteam'));
    await tester.tap(find.text('Kategorie wählen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton).first);
    await settleShort(tester);
    expect(find.textContaining('Frage 1/3'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    await settleShort(tester);
    expect(find.textContaining('Frage 2/3'), findsOneWidget);
    // Sauber schließen (Timer stoppen)
    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();
  });

  testWidgets('Aus dem Chat ein Quizduell mit diesem Match starten', (
    tester,
  ) async {
    await pumpLovelApp(tester);
    await tester.tap(find.text('Chats').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Mia'));
    await tester.tap(find.byTooltip('Quizduell zusammen spielen'));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Befreundetes Paar per Code einladen'));

    expect(find.text('Euer Einladungscode'), findsOneWidget);
    expect(find.text('DEMO42'), findsOneWidget);
  });

  testWidgets('Schätzduell: schätzen, später Schätzung übernehmen', (
    tester,
  ) async {
    await pumpLovelApp(tester);
    await tester.tap(find.text('Spiele').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Schätzduell'));
    await tapVisible(tester, find.text('Mia'));
    await tapVisible(tester, find.text('Zufälliges Gegnerteam'));
    expect(find.text('Schätzduell'), findsWidgets, reason: 'Titel');
    await tester.tap(find.text('Kategorie wählen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton).first);
    await settleShort(tester);

    for (var i = 0; i < 3; i++) {
      await tester.enterText(find.byType(TextField), '1.000');
      await tester.tap(find.text('Schätzung abgeben'));
      await settleShort(tester);
    }
    expect(find.text('Vorschläge abgegeben!'), findsOneWidget);
    await tester.tap(find.text('Zur Übersicht'));
    await tester.pumpAndSettle();

    // Runde 2: Mia hat geschätzt, ich entscheide – Feld ist vorbefüllt.
    await tester.tap(find.text('Jetzt entscheiden'));
    await settleShort(tester);
    expect(find.textContaining('Mia schätzt'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, isNotEmpty);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Schätzung abgeben'));
      await settleShort(tester);
    }
    expect(find.textContaining('von 9 Punkten'), findsOneWidget);
    expect(find.textContaining('Richtig:'), findsNWidgets(3));
    await tester.tap(find.text('Zur Übersicht'));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'Seelenverwandt: Antwort der Partnerin bleibt beim Raten verborgen',
    (tester) async {
      await pumpLovelApp(tester);
      await tester.tap(find.text('Spiele').last);
      await tester.pumpAndSettle();
      await tapVisible(tester, find.text('Seelenverwandt'));
      await tapVisible(tester, find.text('Mia'));
      await tapVisible(tester, find.text('Zufälliges Gegnerteam'));
      expect(find.text('Runde 1: Du wählst die Kategorie'), findsOneWidget);
      await tester.tap(find.text('Kategorie wählen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FilledButton).first);
      await settleShort(tester);
      expect(find.textContaining('Antworte ehrlich über dich'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byType(InkWell).at(1));
        await settleShort(tester);
      }
      expect(find.text('Antworten abgegeben!'), findsOneWidget);
      await tester.tap(find.text('Zur Übersicht'));
      await tester.pumpAndSettle();

      expect(find.text('Runde 2: Du rätst'), findsOneWidget);
      await tester.tap(find.text('Jetzt raten'));
      await settleShort(tester);
      expect(find.textContaining('Rate!'), findsOneWidget);
      expect(
        find.byType(Chip),
        findsNothing,
        reason: 'kein Vorschlag markiert',
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byType(InkWell).at(1));
        await settleShort(tester);
      }
      expect(find.textContaining('Treffern'), findsOneWidget);
      expect(find.textContaining('Dein Tipp:'), findsNWidgets(3));
    },
  );

  testWidgets('Emoji-Rätsel zeigt die Emojis groß', (tester) async {
    await pumpLovelApp(tester);
    await tester.tap(find.text('Spiele').last);
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Emoji-Rätsel'));
    await tapVisible(tester, find.text('Mia'));
    await tapVisible(tester, find.text('Zufälliges Gegnerteam'));
    await tester.tap(find.text('Kategorie wählen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilledButton).first);
    await settleShort(tester);
    expect(find.text('Was ist gemeint?'), findsOneWidget);
    await tester.tap(find.byTooltip('Schließen'));
    await tester.pumpAndSettle();
  });
}
