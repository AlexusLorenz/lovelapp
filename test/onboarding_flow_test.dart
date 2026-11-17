import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:lovelapp/features/profile/widgets/completion_avatar.dart';

import 'package:lovelapp/core/widgets/pinch_zoom.dart';
import 'package:lovelapp/features/discover/profile_detail_screen.dart';
import 'package:lovelapp/features/profile/edit_profile_screen.dart';

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
  // Nicht über den oberen Rand hinausschieben.
  final top = tester.getTopLeft(finder.first).dy;
  final shift = min(120.0, top - 100);
  if (shift > 0) {
    await tester.drag(vertical.first, Offset(0, -shift));
  }
  await tester.pumpAndSettle();
}

Future<void> tapAndSettle(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// Scrollt im Bearbeiten-Bildschirm zu [finder] und tippt ihn mittig an.
Future<void> tapInEditor(WidgetTester tester, Finder finder) async {
  final list = find
      .descendant(
        of: find.byType(EditProfileScreen),
        matching: find.byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        ),
      )
      .first;
  await tester.scrollUntilVisible(finder, 150, scrollable: list);
  await tester.pumpAndSettle();
  final y = tester.getCenter(finder).dy;
  if (y < 150 || y > 450) {
    await tester.drag(list, Offset(0, 300 - y));
    await tester.pumpAndSettle();
  }
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
    final requestedLimits = <int>[];
    await pumpLovelApp(
      tester,
      pickImages: (limit) async {
        requestedLimits.add(limit);
        return [testJpeg(), testJpeg()];
      },
    );
    await tapAndSettle(tester, find.text('Profil'));
    // Demo-Profil: Stadt + 1 Steckbrief-Angabe = 10 %
    expect(find.text('10 %'), findsOneWidget);

    await scrollTo(tester, find.text('Profil bearbeiten'));
    await tapAndSettle(tester, find.text('Profil bearbeiten'));

    // Zwei Fotos auf einmal auswählen (Bildaufbereitung läuft wirklich)
    await tester.runAsync(() async {
      await tester.tap(find.text('Foto hinzufügen'));
      await Future<void>.delayed(const Duration(seconds: 3));
    });
    await tester.pumpAndSettle();
    expect(requestedLimits, [6], reason: 'Auswahl auf freie Plätze begrenzt');
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

  testWidgets('Speichern oben rechts: Fehler sichtbar, danach zurück', (
    tester,
  ) async {
    await pumpLovelApp(tester);
    await tapAndSettle(tester, find.text('Profil'));
    await scrollTo(tester, find.text('Profil bearbeiten'));
    await tapAndSettle(tester, find.text('Profil bearbeiten'));

    // Frage ohne Antwort → Hinweis als Snackbar, Bearbeitung bleibt offen
    await tester.scrollUntilVisible(
      find.text('Frage 1 auswählen'),
      150,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Frage 1 auswählen'));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.text('Eine Green Flag bei dir wäre …'));
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Speichern'));
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.enterText(
      find
              .widgetWithText(TextField, 'Antwort 1')
              .hitTestable()
              .evaluate()
              .isEmpty
          ? find
                .byWidgetPredicate(
                  (w) =>
                      w is TextField &&
                      (w.controller?.text.isEmpty ?? false) &&
                      (w.decoration?.labelText?.startsWith('Antwort') ?? false),
                )
                .first
          : find.widgetWithText(TextField, 'Antwort 1'),
      'Ehrlich sein',
    );
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Speichern'));
    expect(find.byType(EditProfileScreen), findsNothing);
    expect(find.text('Profil gespeichert.'), findsOneWidget);
  });

  testWidgets('Chat: Profilbilder öffnen die Profile', (tester) async {
    await pumpLovelApp(tester);
    await tapAndSettle(tester, find.text('Chats'));
    await tapAndSettle(tester, find.text('Mia'));

    // Oben neben dem Namen
    await tapAndSettle(tester, _semantics('Profil von Mia ansehen').first);
    expect(find.byType(ProfileDetailScreen), findsOneWidget);
    await tapAndSettle(tester, find.byTooltip('Schließen'));

    // Eigenes Bild neben der eigenen Nachricht
    final input = find.widgetWithText(TextField, 'Nachricht schreiben');
    await tester.enterText(input, 'Hallo!');
    await tapAndSettle(tester, find.byTooltip('Senden'));
    await tapAndSettle(tester, _semantics('Dein Profil ansehen').last);
    expect(find.text('Du, 28'), findsOneWidget);
  });

  testWidgets('Profilfoto: Zwei-Finger-Zoom vergrößert und springt zurück', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: PinchZoom(
              child: SizedBox(
                width: 200,
                height: 200,
                child: ColoredBox(color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );
    final center = tester.getCenter(find.byType(PinchZoom));
    final a = await tester.startGesture(center - const Offset(20, 0));
    final b = await tester.startGesture(
      center + const Offset(20, 0),
      pointer: 7,
    );
    await a.moveBy(const Offset(-60, 0));
    await b.moveBy(const Offset(60, 0));
    await tester.pump();

    final zoomed = find
        .byType(Transform)
        .evaluate()
        .map((e) => e.widget as Transform)
        .where((t) => t.transform.getMaxScaleOnAxis() > 2.5);
    expect(zoomed, isNotEmpty, reason: 'Abstand 40 → 160 px = Faktor 4');

    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    final still = find
        .byType(Transform)
        .evaluate()
        .map((e) => e.widget as Transform)
        .where((t) => t.transform.getMaxScaleOnAxis() > 1.01);
    expect(still, isEmpty);
  });

  testWidgets('Interessen: max. 3 pro Kategorie, erscheinen im Profil', (
    tester,
  ) async {
    await pumpLovelApp(tester);
    await tapAndSettle(tester, find.text('Profil'));
    await scrollTo(tester, find.text('Profil bearbeiten'));
    await tapAndSettle(tester, find.text('Profil bearbeiten'));
    await tapInEditor(tester, find.text('Interessen'));

    for (final name in ['🎸 Rock', '🎷 Jazz', '🎧 Indie', '🎤 Pop']) {
      await tester.tap(find.widgetWithText(FilterChip, name));
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('Höchstens 3'), findsOneWidget);
    expect(find.text('3/3'), findsOneWidget);

    // Suche quer durch alle Kategorien
    await tester.enterText(find.byType(TextField), 'boulder');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, '🧗 Bouldern'));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Speichern'));
    expect(find.text('Interessen gespeichert.'), findsOneWidget);

    // Zusammenfassung im Bearbeiten-Bildschirm
    expect(find.text('🎧 Indie, 🎷 Jazz, 🎸 Rock +1'), findsOneWidget);

    // In der Vorschau sichtbar
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, find.byType(CompletionAvatar));
    await scrollTo(tester, find.text('🎷 Jazz'));
    expect(find.text('🎷 Jazz'), findsOneWidget);
    expect(find.text('🎤 Pop'), findsNothing);
  });

  testWidgets('Lieblingsspiele suchen, auswählen und speichern', (
    tester,
  ) async {
    await pumpLovelApp(tester);
    await tapAndSettle(tester, find.text('Profil'));
    await scrollTo(tester, find.text('Profil bearbeiten'));
    await tapAndSettle(tester, find.text('Profil bearbeiten'));
    await tapInEditor(tester, find.text('Lieblingsspiele'));

    await tester.enterText(find.byType(TextField), 'zelda');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tapAndSettle(
      tester,
      find
          .widgetWithText(ListTile, 'The Legend of Zelda: Breath of the Wild')
          .first,
    );
    expect(find.text('Deine Auswahl (1/6)'), findsOneWidget);
    expect(find.text('Spieldaten und Bilder von RAWG'), findsOneWidget);
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Speichern'));
    expect(
      find.textContaining('The Legend of Zelda: Breath of the Wild'),
      findsOneWidget,
      reason: 'Zusammenfassung im Bearbeiten-Bildschirm',
    );
  });

  testWidgets('Lieblingsmusik suchen (ohne Spotify-Verbindung)', (
    tester,
  ) async {
    await pumpLovelApp(tester);
    await tapAndSettle(tester, find.text('Profil'));
    await scrollTo(tester, find.text('Profil bearbeiten'));
    await tapAndSettle(tester, find.text('Profil bearbeiten'));
    await tapInEditor(tester, find.text('Lieblingsmusik'));

    // Spotify-Login nur in der Web-App mit Client-ID
    expect(find.text('Spotify verbinden'), findsNothing);
    await tester.enterText(find.byType(TextField), 'radio');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    await tapAndSettle(
      tester,
      find.widgetWithText(ListTile, 'Radiohead').first,
    );
    await tapAndSettle(tester, find.widgetWithText(TextButton, 'Speichern'));
    expect(find.textContaining('Radiohead'), findsOneWidget);
  });

  testWidgets('Fremdes Profil zeigt Interessen, Spiele und Musik', (
    tester,
  ) async {
    await pumpLovelApp(tester);
    await tapAndSettle(tester, find.byTooltip('Profil öffnen'));
    await scrollTo(tester, find.text('Lieblingsmusik'));
    expect(find.text('🎷 Jazz'), findsOneWidget);
    expect(find.text('Hollow Knight'), findsWidgets);
    expect(find.text('Radiohead'), findsWidgets);
  });
}

Finder _semantics(String label) => find.byWidgetPredicate(
  (w) => w is Semantics && w.properties.label == label,
);
