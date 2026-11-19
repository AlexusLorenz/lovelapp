import 'package:flutter_test/flutter_test.dart';
import 'package:lovelapp/features/auth/test_account_picker.dart';
import 'package:lovelapp/features/auth/test_accounts.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('4 Frauen und 4 Männer mit eindeutigen Test-E-Mails', () {
    expect(testAccounts.where((a) => a.isWoman), hasLength(4));
    expect(testAccounts.where((a) => !a.isWoman), hasLength(4));
    expect(testAccounts.map((a) => a.email).toSet(), hasLength(8));
    for (final a in testAccounts) {
      expect(a.email, endsWith('@test.lovel.app'));
      expect(a.age, greaterThanOrEqualTo(18));
      expect(a.photos, hasLength(3));
    }
  });

  test('ohne Test-Passwort im Build keine Auswahl', () {
    expect(testAccountsEnabled, isFalse);
  });

  testWidgets('Antippen meldet das gewählte Konto an', (tester) async {
    TestAccount? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TestAccountPicker(onPick: (a) => picked = a)),
      ),
    );
    expect(find.text('Test-Accounts'), findsOneWidget);
    for (final a in testAccounts) {
      expect(find.text('${a.name}, ${a.age}'), findsOneWidget);
    }
    await tester.tap(find.text('Paul, 33'));
    expect(picked?.email, 'paul@test.lovel.app');
  });

  testWidgets('während der Anmeldung gesperrt', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TestAccountPicker(
            busyEmail: 'lena@test.lovel.app',
            onPick: (_) => taps++,
          ),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Mia, 31'));
    expect(taps, 0);
  });
}
