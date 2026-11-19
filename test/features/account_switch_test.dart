import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovelapp/features/auth/auth_repository.dart';
import 'package:lovelapp/features/quiz/quiz_providers.dart';
import 'package:lovelapp/features/quiz/quiz_repository.dart';
import 'package:lovelapp/features/session/session_controller.dart';

/// Sitzung, deren Nutzer der Test direkt umschaltet.
class _Session extends SessionController {
  @override
  SessionState build() => const SessionState(
    SessionStatus.ready,
    user: AppUser(id: 'alex', email: null),
  );

  void switchTo(String? id) => state = id == null
      ? const SessionState(SessionStatus.signedOut)
      : SessionState(SessionStatus.ready, user: AppUser(id: id, email: null));
}

/// Liefert je Konto ein Spiel mit dessen ID.
class _Quiz implements QuizRepository {
  String user = 'alex';

  @override
  Future<List<QuizGameSummary>> myGames() async => [
    QuizGameSummary.fromJson({
      'id': 'spiel-von-$user',
      'status': 'searching',
      'my_team': {'id': 'm', 'players': <Object?>[]},
      'updated_at': '2026-11-19T00:00:00Z',
    }),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('Kontowechsel verwirft die Spieleliste des vorherigen Kontos', () async {
    final quiz = _Quiz();
    final container = ProviderContainer(
      overrides: [
        sessionProvider.overrideWith(_Session.new),
        quizRepositoryProvider.overrideWithValue(quiz),
      ],
    );
    addTearDown(container.dispose);
    final sub = container.listen(quizGamesProvider, (_, _) {});
    addTearDown(sub.close);

    expect(
      (await container.read(quizGamesProvider.future)).single.id,
      'spiel-von-alex',
    );

    final session = container.read(sessionProvider.notifier) as _Session;
    session.switchTo(null);
    expect(await container.read(quizGamesProvider.future), isEmpty);

    quiz.user = 'lena';
    session.switchTo('lena');
    expect(
      (await container.read(quizGamesProvider.future)).single.id,
      'spiel-von-lena',
    );
  });
}
