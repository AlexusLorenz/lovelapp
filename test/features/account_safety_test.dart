import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:lovelapp/features/account/change_password_screen.dart';
import 'package:lovelapp/features/auth/auth_repository.dart';
import 'package:lovelapp/features/auth/welcome_screen.dart';
import 'package:lovelapp/features/chat/chat_screen.dart';
import 'package:lovelapp/features/matches/matches_repository.dart';

import '../helpers.dart';

Future<void> tap(WidgetTester tester, Finder finder) async {
  unawaited(Scrollable.ensureVisible(tester.element(finder), alignment: 0.5));
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openMiaChat(WidgetTester tester) async {
  await tap(tester, find.text('Chats'));
  await tap(tester, find.text('Mia'));
  expect(find.byType(ChatScreen), findsOneWidget);
}

void main() {
  test('Status einer Nachricht', () {
    final base = ChatMessage(
      id: '1',
      senderId: 'me',
      body: 'Hi',
      createdAt: DateTime(2026),
    );
    expect(base.status, DeliveryStatus.sent);
    expect(
      base.copyWith(deliveredAt: DateTime(2026)).status,
      DeliveryStatus.delivered,
    );
    expect(
      base.copyWith(deliveredAt: DateTime(2026), readAt: DateTime(2026)).status,
      DeliveryStatus.read,
    );
    expect(
      ChatMessage(
        id: 'l',
        senderId: 'me',
        body: 'x',
        createdAt: DateTime(2026),
        pending: true,
      ).status,
      DeliveryStatus.sending,
    );
  });

  testWidgets('Eigene Nachricht zeigt Häkchen (Demo: zugestellt)', (
    tester,
  ) async {
    await pumpLovelApp(tester);
    await openMiaChat(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Nachricht schreiben'),
      'Hallo Mia',
    );
    await tap(tester, find.byTooltip('Senden'));
    final ticks = tester.widget<DeliveryTicks>(find.byType(DeliveryTicks).last);
    expect(ticks.status, DeliveryStatus.delivered);
    expect(find.byTooltip('Zugestellt'), findsWidgets);
  });

  testWidgets('Blockieren beendet das Match', (tester) async {
    await pumpLovelApp(tester);
    await openMiaChat(tester);
    await tap(tester, find.byTooltip('Mehr'));
    await tap(tester, find.text('Blockieren'));
    await tap(tester, find.widgetWithText(FilledButton, 'Blockieren'));
    expect(find.byType(ChatScreen), findsNothing);
    expect(find.text('Mia ist blockiert.'), findsOneWidget);
    expect(find.text('Mia'), findsNothing);
  });

  testWidgets('Melden mit Grund, standardmäßig auch blockieren', (
    tester,
  ) async {
    await pumpLovelApp(tester);
    await openMiaChat(tester);
    await tap(tester, find.byTooltip('Mehr'));
    await tap(tester, find.text('Melden'));
    final send = find.widgetWithText(FilledButton, 'Meldung senden');
    expect(tester.widget<FilledButton>(send).onPressed, isNull);
    await tap(tester, find.text('Spam oder Werbung'));
    await tap(tester, send);
    expect(find.textContaining('Danke für deine Meldung'), findsOneWidget);
    expect(find.text('Mia'), findsNothing);
  });

  testWidgets('Konto löschen nur nach Bestätigung', (tester) async {
    final auth = DemoAuthRepository(signedInAs: testUser);
    await pumpLovelApp(tester, auth: auth);
    await tap(tester, find.text('Profil'));
    await tester.scrollUntilVisible(
      find.text('Konto löschen'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tap(tester, find.text('Konto löschen'));
    final confirm = find.widgetWithText(FilledButton, 'Endgültig löschen');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(find.byType(TextField), 'löschen');
    await tester.pump();
    await tap(tester, confirm);
    expect(auth.deletedUserId, testUser.id);
    expect(find.byType(WelcomeScreen), findsOneWidget);
  });

  testWidgets('Passwort-Link führt zur Eingabe des neuen Passworts', (
    tester,
  ) async {
    final auth = DemoAuthRepository(signedInAs: testUser);
    await pumpLovelApp(tester, auth: auth);
    auth.simulatePasswordRecovery();
    await tester.pumpAndSettle();
    expect(find.byType(ChangePasswordScreen), findsOneWidget);

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'sehrgeheim123');
    await tester.enterText(fields.at(1), 'anders12345');
    await tap(tester, find.widgetWithText(FilledButton, 'Speichern'));
    expect(find.text('Die Passwörter stimmen nicht überein.'), findsOneWidget);

    await tester.enterText(fields.at(1), 'sehrgeheim123');
    await tap(tester, find.widgetWithText(FilledButton, 'Speichern'));
    expect(find.byType(ChangePasswordScreen), findsNothing);
    expect(find.text('Neues Passwort gespeichert.'), findsOneWidget);
  });

  testWidgets('Passwort vergessen schickt Link', (tester) async {
    await pumpLovelApp(tester, signedIn: false);
    await tap(tester, find.text('Ich habe schon ein Konto'));
    await tester.enterText(find.widgetWithText(TextField, 'E-Mail'), 'a@b.de');
    await tap(tester, find.text('Passwort vergessen?'));
    expect(find.textContaining('Link zum Zurücksetzen'), findsOneWidget);
  });
}
