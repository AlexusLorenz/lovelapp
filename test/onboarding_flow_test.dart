import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:lovelapp/features/profile/widgets/completion_avatar.dart';

import 'helpers.dart';

Finder field(String label) => find.widgetWithText(TextFormField, label);

/// Scrollt die (senkrechte) Hauptliste, bis [finder] sichtbar ist – etwas
/// weiter, damit nichts am Rand unter der Navigationsleiste liegt.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  final vertical = find.byWidgetPredicate(
    (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
  );
  // .first: die Liste selbst; mehrzeilige Textfelder sind auch Scrollables.
  await tester.scrollUntilVisible(finder, 150, scrollable: vertical.first);
  await tester.drag(vertical.first, const Offset(0, -120));
  await tester.pumpAndSettle();
}

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

    // Fragen (freiwillig)
    expect(find.text('Fragen über dich'), findsOneWidget);
    expect(tester.widget<FilledButton>(weiter).onPressed, isNotNull);
    const picks = ['Mein perfekter Sonntag …', 'Meine heimliche Superkraft:'];
    for (var i = 0; i < picks.length; i++) {
      await tapAndSettle(tester, find.text('Frage ${i + 1} auswählen'));
      await tester.scrollUntilVisible(
        find.text(picks[i]),
        100,
        scrollable: find.byType(Scrollable).last,
      );
      await tapAndSettle(tester, find.text(picks[i]));
      // Gewählt, aber unbeantwortet → noch nicht weiter
      expect(tester.widget<FilledButton>(weiter).onPressed, isNull);
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
    await scrollTo(tester, find.text('Abmelden'));
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

  testWidgets('Profil bearbeiten: Steckbrief und Fragen ändern', (
    tester,
  ) async {
    await pumpLovelApp(tester);
    await tapAndSettle(tester, find.text('Profil'));
    await scrollTo(tester, find.text('Profil bearbeiten'));
    await tapAndSettle(tester, find.text('Profil bearbeiten'));

    expect(find.text('Profil bearbeiten'), findsOneWidget);
    await scrollTo(tester, field('Über mich'));
    await tester.enterText(field('Über mich'), 'Neu hier.');
    await scrollTo(tester, find.text('Frage 1 auswählen'));
    await tapAndSettle(tester, find.text('Frage 1 auswählen'));
    await tapAndSettle(tester, find.text('Mein perfekter Sonntag …'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Antwort 1'),
      'Lange schlafen',
    );
    await scrollTo(tester, find.text('Trinke gesellig'));
    await tapAndSettle(tester, find.text('Trinke gesellig'));
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Speichern'));

    expect(find.text('Profil gespeichert.'), findsOneWidget);

    // Erneut öffnen: Werte sind da
    await tapAndSettle(tester, find.text('Profil bearbeiten'));
    expect(find.text('Neu hier.'), findsOneWidget);
    await scrollTo(tester, find.text('Lange schlafen'));
    expect(find.text('Lange schlafen'), findsOneWidget);
    await scrollTo(tester, find.text('Trinke gesellig'));
    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'Trinke gesellig'),
    );
    expect(chip.selected, isTrue);
  });

  testWidgets('Chat: Feld bleibt nach dem Senden fokussiert', (tester) async {
    await pumpLovelApp(tester);
    await tapAndSettle(tester, find.text('Chats'));
    await tapAndSettle(tester, find.text('Mia'));

    final input = find.widgetWithText(TextField, 'Nachricht schreiben');
    await tester.enterText(input, 'Hallo Mia!');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pumpAndSettle();

    expect(find.text('Hallo Mia!'), findsOneWidget);
    final field = tester.widget<TextField>(input);
    expect(field.focusNode!.hasFocus, isTrue);
    expect(field.controller!.text, isEmpty);

    await tester.enterText(input, 'Noch was');
    await tapAndSettle(tester, find.byTooltip('Senden'));
    expect(find.text('Noch was'), findsOneWidget);
    expect(tester.widget<TextField>(input).focusNode!.hasFocus, isTrue);
  });

  testWidgets('Fotos hochladen, Vervollständigung steigt, Vorschau zeigt sie', (
    tester,
  ) async {
    await pumpLovelApp(tester);
    await tapAndSettle(tester, find.text('Profil'));
    // Demo-Profil: Stadt + 1 Steckbrief-Angabe = 10 %
    expect(find.text('10 %'), findsOneWidget);

    await scrollTo(tester, find.text('Profil bearbeiten'));
    await tapAndSettle(tester, find.text('Profil bearbeiten'));

    // Zwei Fotos hinzufügen (Bildaufbereitung läuft wirklich)
    for (var i = 0; i < 2; i++) {
      await tester.runAsync(() async {
        await tester.tap(find.text('Foto hinzufügen'));
        await Future<void>.delayed(const Duration(seconds: 2));
      });
      await tester.pumpAndSettle();
    }
    expect(find.text('Hauptbild'), findsOneWidget);
    expect(find.byTooltip('Foto 2 löschen'), findsOneWidget);

    // Eines löschen
    await tapAndSettle(tester, find.byTooltip('Foto 2 löschen'));
    await tapAndSettle(tester, find.widgetWithText(FilledButton, 'Löschen'));
    expect(find.byTooltip('Foto 2 löschen'), findsNothing);
    expect(find.byTooltip('Foto 1 löschen'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    // Nach oben zurück zum Profilkopf
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    // 1 Foto (+20) → 30 %
    expect(find.text('30 %'), findsOneWidget);

    // Profilbild antippen → „So sehen dich andere“
    await tapAndSettle(tester, find.byType(CompletionAvatar));
    expect(find.text('Du, 28'), findsOneWidget);
    await scrollTo(tester, find.text('Nichtraucher:in'));
    expect(find.text('Nichtraucher:in'), findsOneWidget);
  });
}
