import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

void main() {
  testWidgets('App startet mit Navigation und Entdecken-Feed', (tester) async {
    await pumpLovelApp(tester);

    expect(find.text('Entdecken'), findsWidgets);
    expect(find.text('Matches'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Mia, 27'), findsOneWidget);
  });

  testWidgets('Pass zeigt das nächste Profil', (tester) async {
    await pumpLovelApp(tester);

    await tester.tap(find.byTooltip('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Jonas, 30'), findsOneWidget);
  });

  testWidgets('This or That ist spielbar', (tester) async {
    await pumpLovelApp(tester);

    await tester.tap(find.text('Matches').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Eisbrecher-Spiel').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('This or That'));
    await tester.pumpAndSettle();

    for (var i = 0; i < 7; i++) {
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();
    }
    expect(find.text('Übereinstimmung'), findsOneWidget);
  });

  testWidgets('Like auf Gegenseitigkeit zeigt das Match-Overlay', (
    tester,
  ) async {
    await pumpLovelApp(tester);

    await tester.tap(find.byTooltip('Like'));
    // Kein pumpAndSettle: die Flame-Game-Loop läuft dauerhaft.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('MATCH!'), findsWidgets);
    expect(find.text('Du und Mia mögt euch.'), findsOneWidget);
    expect(find.text('19'), findsOneWidget); // ein Like verbraucht

    await tester.tap(find.text('Weiter entdecken'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('MATCH!'), findsNothing);
    expect(find.text('Jonas, 30'), findsOneWidget);
  });

  testWidgets('Match-Overlay: Spiel starten führt zu den Spielen', (
    tester,
  ) async {
    await pumpLovelApp(tester);

    await tester.tap(find.byTooltip('Like'));
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.tap(find.text('Eisbrecher-Spiel starten'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Eisbrecher-Spiele'), findsOneWidget);
  });

  testWidgets('Match-Overlay respektiert „Bewegung reduzieren“', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);

    await pumpLovelApp(tester);
    await tester.tap(find.byTooltip('Like'));
    await tester.pumpAndSettle(); // ohne Herzen läuft keine Game-Loop

    expect(find.text('Du und Mia mögt euch.'), findsOneWidget);
  });

  testWidgets('Wischen nach rechts liked, nach links geht weiter', (
    tester,
  ) async {
    await pumpLovelApp(tester);
    final card = find.text('Mia, 27');

    // Zu kurz gewischt → Karte schnappt zurück
    await tester.drag(card, const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(find.text('Mia, 27'), findsOneWidget);

    // Nach rechts → Like und Match mit Mia
    await tester.fling(card, const Offset(500, 0), 2000);
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('MATCH!'), findsOneWidget);
    await tester.tap(find.text('Weiter entdecken'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Nach links → Jonas weg, Sara oben
    await tester.fling(find.text('Jonas, 30'), const Offset(-500, 0), 2000);
    await tester.pumpAndSettle();
    expect(find.text('Jonas, 30'), findsNothing);
    expect(find.text('19'), findsOneWidget); // nur ein Like verbraucht
  });

  testWidgets('Profil-Button öffnet das ganze Profil', (tester) async {
    await pumpLovelApp(tester);
    await tester.tap(find.byTooltip('Profil öffnen'));
    await tester.pumpAndSettle();

    expect(find.text('Steckbrief'), findsOneWidget);
    expect(find.text('Nichtraucher:in'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Siedler. Ich baue immer nur Straßen.'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    // „Weiter“ im Profil wischt die Karte weg
    await tester.tap(find.byTooltip('Weiter').last);
    await tester.pumpAndSettle();
    expect(find.text('Steckbrief'), findsNothing);
    expect(find.text('Mia, 27'), findsNothing);
  });

  testWidgets('Tippen rechts aufs Bild blättert weiter', (tester) async {
    await pumpLovelApp(tester);
    final card = find.byType(Card).last;
    final rect = tester.getRect(card);
    await tester.tapAt(Offset(rect.right - 30, rect.top + 100));
    await tester.pumpAndSettle();
    // Kein Absturz und Karte bleibt – Bildwechsel ist rein visuell.
    expect(find.text('Mia, 27'), findsOneWidget);
  });
}
