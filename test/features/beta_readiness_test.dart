import 'package:flutter_test/flutter_test.dart';
import 'package:lovelapp/features/moderation/moderation_providers.dart';
import 'package:lovelapp/features/push/push_providers.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers.dart';

/// Push-Status, der sich per Schalter ändern lässt.
class _FakePush implements PushRepository {
  _FakePush(this.current);

  PushStatus current;
  final calls = <String>[];

  @override
  Future<PushStatus> status() async => current;

  @override
  Future<PushStatus> enable() async {
    calls.add('enable');
    return current = PushStatus.on;
  }

  @override
  Future<PushStatus> disable() async {
    calls.add('disable');
    return current = PushStatus.off;
  }
}

class _FakeModeration implements ModerationRepository {
  _FakeModeration({this.admin = true});

  final bool admin;
  final calls = <String>[];
  bool banned = false;

  @override
  Future<bool> isAdmin() async => admin;

  @override
  Future<List<ModReport>> reports({bool onlyOpen = true}) async => [
    if (!banned || !onlyOpen)
      ModReport(
        id: 'r1',
        reason: 'harassment',
        details: 'Hat mich beleidigt.',
        status: banned ? 'resolved' : 'open',
        createdAt: DateTime.utc(2026, 11, 19, 10),
        message: 'Du bist doof',
        reporter: const ModPerson(id: 'u1', name: 'Lena'),
        reported: ModPerson(
          id: 'u2',
          name: 'Ben',
          reportCount: 2,
          bannedAt: banned ? DateTime.utc(2026, 11, 19, 11) : null,
        ),
      ),
  ];

  @override
  Future<void> setReportStatus(String reportId, String status) async =>
      calls.add('status:$reportId:$status');

  @override
  Future<void> ban(String userId, String reason) async {
    calls.add('ban:$userId:$reason');
    banned = true;
  }

  @override
  Future<void> unban(String userId) async => calls.add('unban:$userId');

  @override
  Future<void> removePhoto(String photoId) async => calls.add('photo:$photoId');

  @override
  Future<Map<String, Object?>> stats({bool includeTest = false}) async => {
    'users': 10,
    'matches': 8,
    'matches_with_game': 4,
    'matches_chat_after_game': 3,
    'games': 5,
    'games_finished': 2,
    'games_forfeited': 1,
    'reports_open': 1,
  };
}

Future<void> _openProfile(WidgetTester tester) async {
  await tester.tap(find.text('Profil').last);
  await tester.pumpAndSettle();
}

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  group('Kennzahlen', () {
    test('Quoten werden aus den Rohzahlen berechnet', () {
      final sections = describeStats({
        'matches': 8,
        'matches_with_game': 4,
        'matches_chat_after_game': 3,
        'games': 5,
        'games_finished': 2,
        'games_by_kind': {'quiz': 3, 'estimate': 2},
      });
      final games = sections.firstWhere((s) => s.$1 == 'Spiele').$2;
      expect(games.first.value, '4');
      expect(games.first.hint, '50 %');
      expect(games[1].hint, '75 %');
      expect(games.any((s) => s.label.contains('estimate')), isTrue);
    });

    test('keine Division durch null', () {
      final sections = describeStats(const {});
      final games = sections.firstWhere((s) => s.$1 == 'Spiele').$2;
      expect(games.first.hint, '–');
    });
  });

  group('Push', () {
    testWidgets('Hinweis im Spiele-Tab schaltet Push ein', (tester) async {
      final push = _FakePush(PushStatus.off);
      await pumpLovelApp(
        tester,
        overrides: [pushRepositoryProvider.overrideWithValue(push)],
      );
      await tester.tap(find.text('Spiele').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Benachrichtigungen an?'), findsOneWidget);
      await tester.tap(find.text('Aktivieren'));
      await tester.pumpAndSettle();
      expect(push.calls, ['enable']);
      expect(find.textContaining('Benachrichtigungen an?'), findsNothing);
    });

    testWidgets('Schalter im Profil', (tester) async {
      final push = _FakePush(PushStatus.on);
      await pumpLovelApp(
        tester,
        overrides: [pushRepositoryProvider.overrideWithValue(push)],
      );
      await _openProfile(tester);
      final tile = find.widgetWithText(SwitchListTile, 'Benachrichtigungen');
      await _scrollTo(tester, tile);
      expect(tester.widget<SwitchListTile>(tile).value, isTrue);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(push.calls, ['disable']);
      expect(tester.widget<SwitchListTile>(tile).value, isFalse);
    });

    testWidgets('im Browser blockiert: Schalter gesperrt mit Hinweis', (
      tester,
    ) async {
      await pumpLovelApp(
        tester,
        overrides: [
          pushRepositoryProvider.overrideWithValue(
            _FakePush(PushStatus.blocked),
          ),
        ],
      );
      await _openProfile(tester);
      final tile = find.widgetWithText(SwitchListTile, 'Benachrichtigungen');
      await _scrollTo(tester, tile);
      expect(tester.widget<SwitchListTile>(tile).onChanged, isNull);
      expect(find.textContaining('Im Browser blockiert'), findsOneWidget);
    });

    testWidgets('Abmelden meldet auch das Gerät ab', (tester) async {
      final push = _FakePush(PushStatus.on);
      await pumpLovelApp(
        tester,
        overrides: [pushRepositoryProvider.overrideWithValue(push)],
      );
      await _openProfile(tester);
      await _scrollTo(tester, find.text('Abmelden'));
      await tester.tap(find.text('Abmelden'));
      await tester.pumpAndSettle();
      expect(push.calls, ['disable']);
      expect(find.text('Ich habe schon ein Konto'), findsOneWidget);
    });
  });

  group('Moderation', () {
    testWidgets('nur für Admins im Profil sichtbar', (tester) async {
      await pumpLovelApp(
        tester,
        overrides: [
          moderationRepositoryProvider.overrideWithValue(
            _FakeModeration(admin: false),
          ),
        ],
      );
      await _openProfile(tester);
      await _scrollTo(tester, find.text('Abmelden'));
      expect(find.text('Moderation'), findsNothing);
    });

    testWidgets('Meldung ansehen und Person sperren', (tester) async {
      final mod = _FakeModeration();
      await pumpLovelApp(
        tester,
        overrides: [moderationRepositoryProvider.overrideWithValue(mod)],
      );
      await _openProfile(tester);
      await _scrollTo(tester, find.text('Moderation'));
      await tester.tap(find.text('Moderation'));
      await tester.pumpAndSettle();

      expect(find.text('Belästigung oder Beleidigung'), findsWidgets);
      expect(find.textContaining('Du bist doof'), findsOneWidget);
      expect(find.text('2 Meldung(en) insgesamt'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Sperren'));
      await tester.pumpAndSettle();
      expect(find.text('Ben sperren?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Sperren').last);
      await tester.pumpAndSettle();
      expect(mod.calls, ['ban:u2:Belästigung oder Beleidigung']);
      expect(find.text('Keine Meldungen. 🎉'), findsOneWidget);

      // Alle anzeigen → gesperrt, mit Entsperren.
      await tester.tap(find.text('Alle'));
      await tester.pumpAndSettle();
      expect(find.text('Entsperren'), findsOneWidget);
    });

    testWidgets('Kennzahlen-Tab', (tester) async {
      await pumpLovelApp(
        tester,
        overrides: [
          moderationRepositoryProvider.overrideWithValue(_FakeModeration()),
        ],
      );
      await _openProfile(tester);
      await _scrollTo(tester, find.text('Moderation'));
      await tester.tap(find.text('Moderation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kennzahlen'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Matches, die ein Spiel starten'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('Matches, die ein Spiel starten'), findsOneWidget);
      expect(find.text('50 %'), findsWidgets);
    });
  });
}
