import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:lovelapp/app.dart';

void main() {
  testWidgets('App startet mit Navigation und Entdecken-Feed', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LovelApp()));
    await tester.pumpAndSettle();

    expect(find.text('Entdecken'), findsWidgets);
    expect(find.text('Matches'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Profil'), findsOneWidget);
    expect(find.text('Mia, 27'), findsOneWidget);
  });

  testWidgets('Pass zeigt das nächste Profil', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LovelApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Weiter'));
    await tester.pumpAndSettle();
    expect(find.text('Jonas, 30'), findsOneWidget);
  });

  testWidgets('This or That ist spielbar', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: LovelApp()));
    await tester.pumpAndSettle();

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

  testWidgets('Like auf Gegenseitigkeit zeigt Match mit Flame-Herzen', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: LovelApp()));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Like'));
    // Kein pumpAndSettle: die Flame-Game-Loop läuft dauerhaft.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Es ist ein Match!'), findsOneWidget);
    expect(find.text('19'), findsOneWidget); // ein Like verbraucht

    await tester.tap(find.text('Weiter entdecken'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Es ist ein Match!'), findsNothing);
    expect(find.text('Jonas, 30'), findsOneWidget);
  });
}
