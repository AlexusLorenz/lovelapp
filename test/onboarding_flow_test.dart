import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'helpers.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Registrieren und Onboarding führen in die App', (tester) async {
    await pumpLovelApp(tester, signedIn: false, hasProfile: false);
    expect(find.text('Erst spielen, dann daten.'), findsOneWidget);

    await tapAndSettle(tester, find.text('Mit E-Mail registrieren'));
    await tester.enterText(field('E-Mail'), 'neu@lovel.app');
    await tester.enterText(field('Passwort'), 'geheim12345');
    await tester.enterText(field('Passwort wiederholen'), 'geheim12345');

    // Ohne Haken geht es nicht weiter.
    await tapAndSettle(
      tester,
      find.widgetWithText(FilledButton, 'Konto erstellen'),
    );
    expect(find.text('Bitte bestätigen.'), findsOneWidget);

    await tapAndSettle(tester, find.byType(Checkbox));
    await tapAndSettle(
      tester,
      find.widgetWithText(FilledButton, 'Konto erstellen'),
    );

    // Onboarding
    expect(find.text('Wie heißt du?'), findsOneWidget);
    await tester.enterText(field('Vorname'), 'Alex');
    await tapAndSettle(tester, find.text('Weiter'));

    // Nur Ziffern tippen – die Punkte setzt die App.
    await tester.enterText(field('Geburtsdatum'), '24051998');
    await tester.pump();
    expect(find.text('24.05.1998'), findsOneWidget);
    await tapAndSettle(tester, find.text('Weiter'));

    expect(find.text('Ich bin …'), findsOneWidget);
    await tapAndSettle(tester, find.text('Nicht-binär'));
    await tapAndSettle(tester, find.text('Weiter'));

    expect(find.text('Wen möchtest du kennenlernen?'), findsOneWidget);
    await tapAndSettle(tester, find.text('Frauen'));
    // Ohne Einwilligung bleibt „Weiter“ gesperrt.
    final weiter = find.widgetWithText(FilledButton, 'Weiter');
    expect(tester.widget<FilledButton>(weiter).onPressed, isNull);
    await tapAndSettle(tester, find.byType(Checkbox));
    expect(tester.widget<FilledButton>(weiter).onPressed, isNotNull);
    await tapAndSettle(tester, weiter);

    // Steckbrief (freiwillig)
    expect(find.text('Dein Steckbrief'), findsOneWidget);
    await tapAndSettle(tester, find.text('Nichtraucher:in'));
    await tester.enterText(field('Größe (cm)'), '178');
    await tapAndSettle(tester, find.text('Weiter'));

    // Drei Fragen
    expect(find.text('Drei Fragen über dich'), findsOneWidget);
    expect(tester.widget<FilledButton>(weiter).onPressed, isNull);
    const picks = [
      'Mein perfekter Sonntag …',
      'Meine heimliche Superkraft:',
      'Meine unpopuläre Meinung:',
    ];
    for (var i = 0; i < 3; i++) {
      await tapAndSettle(tester, find.text('Frage ${i + 1} auswählen'));
      await tester.scrollUntilVisible(
        find.text(picks[i]),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tapAndSettle(tester, find.text(picks[i]));
      await tester.enterText(
        find.widgetWithText(TextField, 'Antwort ${i + 1}'),
        'Antwort Nummer ${i + 1}',
      );
      await tester.pump();
    }
    expect(tester.widget<FilledButton>(weiter).onPressed, isNotNull);
    await tapAndSettle(tester, weiter);

    // Standort (Demo: fester Ort)
    expect(find.text('Wo bist du ungefähr?'), findsOneWidget);
    await tapAndSettle(tester, find.text('Standort freigeben'));
    expect(find.text('Standort übernommen'), findsOneWidget);
    await tapAndSettle(tester, weiter);

    expect(find.text('Fast fertig!'), findsOneWidget);
    await tapAndSettle(tester, find.text('Los geht’s'));

    expect(find.text('Mia, 27'), findsOneWidget); // Entdecken-Feed
  });

  testWidgets('Unter 18 kommt nicht weiter', (tester) async {
    await pumpLovelApp(tester, hasProfile: false);
    await tester.enterText(field('Vorname'), 'Kim');
    await tapAndSettle(tester, find.text('Weiter'));

    final now = DateTime.now();
    final young = '${now.day}.${now.month}.${now.year - 15}';
    await tester.enterText(field('Geburtsdatum'), young);
    await tapAndSettle(tester, find.text('Weiter'));

    expect(find.text('Lovel ist erst ab 18 Jahren.'), findsOneWidget);
    expect(find.text('Ich bin …'), findsNothing);
  });

  testWidgets('Abmelden führt zur Startseite', (tester) async {
    await pumpLovelApp(tester);
    await tapAndSettle(tester, find.text('Profil'));
    await tester.scrollUntilVisible(
      find.text('Abmelden'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tapAndSettle(tester, find.text('Abmelden'));
    expect(find.text('Erst spielen, dann daten.'), findsOneWidget);
  });

  testWidgets('Anmelden mit bestehendem Profil führt direkt in die App', (
    tester,
  ) async {
    await pumpLovelApp(tester, signedIn: false);
    await tapAndSettle(tester, find.text('Ich habe schon ein Konto'));
    await tester.enterText(field('E-Mail'), 'test@lovel.app');
    await tester.enterText(field('Passwort'), 'irgendwas123');
    await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Anmelden'));
    expect(find.text('Mia, 27'), findsOneWidget);
  });

  testWidgets('Login mit Google (Demo) führt ins Onboarding', (tester) async {
    await pumpLovelApp(tester, signedIn: false, hasProfile: false);
    // Social Login (Demo) → Onboarding
    await tapAndSettle(tester, find.text('Mit Google fortfahren'));
    expect(find.text('Wie heißt du?'), findsOneWidget);
  });
}
