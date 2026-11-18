import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'quiz_models.dart';
import 'quiz_repository.dart';
import 'quiz_rules.dart';

class SupabaseQuizRepository implements QuizRepository {
  SupabaseQuizRepository(this._client);

  final SupabaseClient _client;
  List<QuizCategory>? _categories;

  Future<T> _rpc<T>(String fn, [Map<String, Object?>? params]) async {
    try {
      return await _client.rpc<T>(fn, params: params);
    } on PostgrestException catch (e) {
      // Unsere eigenen Fehlermeldungen (P0001/P0002) sind schon deutsch.
      if (e.code == 'P0001' || e.code == 'P0002') {
        throw QuizFailure(e.message);
      }
      throw const QuizFailure('Das hat gerade nicht geklappt.');
    }
  }

  Map<String, Object?> _map(Object? v) => Map<String, Object?>.from(v! as Map);

  @override
  Future<List<QuizCategory>> categories() async {
    final cached = _categories;
    if (cached != null) return cached;
    try {
      final rows = await _client
          .from('quiz_categories')
          .select('key, emoji, label, kind')
          .order('label', ascending: true);
      return _categories = [
        for (final r in rows)
          QuizCategory(
            r['key']! as String,
            r['emoji']! as String,
            r['label']! as String,
            QuizKind.parse(r['kind'] as String?),
          ),
      ];
    } on PostgrestException {
      throw const QuizFailure('Kategorien nicht ladbar.');
    }
  }

  @override
  Future<List<QuizGameSummary>> myGames() async {
    final rows = await _rpc<List<dynamic>>('quiz_my_games');
    return [for (final r in rows) QuizGameSummary.fromJson(_map(r))];
  }

  @override
  Future<QuizGameState> state(String gameId) async => QuizGameState.fromJson(
    _map(await _rpc<Object?>('quiz_game_state', {'p_game': gameId})),
  );

  @override
  Future<String> start(
    String matchId, {
    bool invite = false,
    QuizKind kind = QuizKind.quiz,
  }) => _rpc<String>('quiz_start', {
    'p_match': matchId,
    'p_mode': invite ? 'invite' : 'random',
    'p_kind': kind.key,
  });

  @override
  Future<String> join(String matchId, String code) =>
      _rpc<String>('quiz_join', {'p_match': matchId, 'p_code': code});

  @override
  Future<void> chooseCategory(String gameId, String category) => _rpc<void>(
    'quiz_choose_category',
    {'p_game': gameId, 'p_category': category},
  );

  @override
  Future<QuizQuestionView> showQuestion(String gameId, int index) async =>
      QuizQuestionView.fromJson(
        _map(
          await _rpc<Object?>('quiz_show_question', {
            'p_game': gameId,
            'p_q_index': index,
          }),
        ),
      );

  @override
  Future<QuizAnswerReply> answer(
    String gameId,
    int index, {
    int choice = -1,
    num? number,
  }) async => QuizAnswerReply.fromJson(
    _map(
      await _rpc<Object?>('quiz_answer', {
        'p_game': gameId,
        'p_q_index': index,
        'p_choice': choice,
        'p_number': number,
      }),
    ),
  );

  @override
  Future<void> giveUp(String gameId) =>
      _rpc<void>('quiz_give_up', {'p_game': gameId});

  @override
  Stream<void> changes() {
    final me = _client.auth.currentUser?.id;
    if (me == null) return const Stream.empty();
    late final RealtimeChannel channel;
    final controller = StreamController<void>.broadcast(
      onCancel: () => _client.removeChannel(channel),
    );
    // RLS filtert: Es kommen nur Spiele der eigenen Matches an.
    channel = _client
        .channel('quiz-$me')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'quiz_games',
          callback: (_) => controller.add(null),
        )
        .subscribe();
    return controller.stream;
  }
}
