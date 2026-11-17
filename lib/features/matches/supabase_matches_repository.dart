import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../discover/public_profile.dart';
import 'matches_repository.dart';

class SupabaseMatchesRepository implements MatchesRepository {
  SupabaseMatchesRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<MatchSummary>> fetchMatches() async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return const [];
    try {
      // RLS liefert nur eigene Matches.
      final matches = await _client
          .from('matches')
          .select('id, user_a, user_b, created_at')
          .isFilter('unmatched_at', null)
          .order('created_at', ascending: false);
      if (matches.isEmpty) return const [];

      final partnerByMatch = {
        for (final m in matches)
          m['id'] as String: m['user_a'] == me
              ? m['user_b'] as String
              : m['user_a'] as String,
      };
      final partnerIds = partnerByMatch.values.toSet().toList();

      final profileRows = await _client.rpc<List<dynamic>>(
        'get_public_profiles',
        params: {'p_ids': partnerIds},
      );
      final promptRows = await _client
          .from('profile_prompts')
          .select('profile_id, position, prompt_key, answer')
          .inFilter('profile_id', partnerIds);
      final prompts = groupPromptRows(promptRows);
      final profiles = {
        for (final r in profileRows.cast<Map<String, Object?>>())
          r['id']! as String: PublicProfile.fromRow(
            r,
            prompts: prompts[r['id']] ?? const [],
          ),
      };

      final matchIds = partnerByMatch.keys.toList();

      // Letzte Nachricht je Match (für die Vorschau in der Liste).
      final recent = await _client
          .from('messages')
          .select('match_id, body, created_at')
          .inFilter('match_id', matchIds)
          .order('created_at', ascending: false)
          .limit(200);
      final lastByMatch = <String, Map<String, dynamic>>{};
      for (final row in recent) {
        lastByMatch.putIfAbsent(row['match_id'] as String, () => row);
      }

      // Ungelesene Nachrichten vom Gegenüber zählen.
      final unreadRows = await _client
          .from('messages')
          .select('match_id')
          .inFilter('match_id', matchIds)
          .neq('sender_id', me)
          .isFilter('read_at', null)
          .limit(1000);
      final unread = <String, int>{};
      for (final row in unreadRows) {
        final id = row['match_id'] as String;
        unread[id] = (unread[id] ?? 0) + 1;
      }

      return [
        for (final entry in partnerByMatch.entries)
          if (profiles[entry.value] != null) // z. B. inzwischen blockiert
            MatchSummary(
              matchId: entry.key,
              profile: profiles[entry.value]!,
              lastMessage: lastByMatch[entry.key]?['body'] as String?,
              lastMessageAt: lastByMatch[entry.key] == null
                  ? null
                  : DateTime.parse(
                      lastByMatch[entry.key]!['created_at'] as String,
                    ),
              unreadCount: unread[entry.key] ?? 0,
            ),
      ];
    } on PostgrestException {
      throw const ChatFailure('Matches konnten nicht geladen werden.');
    } on Exception {
      throw const ChatFailure('Keine Verbindung zum Server.');
    }
  }

  @override
  Stream<List<ChatMessage>> watchMessages(String matchId) => _client
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('match_id', matchId)
      .order('created_at', ascending: true)
      .map((rows) => [for (final r in rows) ChatMessage.fromRow(r)]);

  @override
  Future<void> sendMessage(String matchId, String body) async {
    try {
      await _client.from('messages').insert({
        'match_id': matchId,
        'body': body.trim(),
      });
    } on PostgrestException catch (e) {
      throw ChatFailure(
        e.code == '42501'
            ? 'Dieses Match ist nicht mehr aktiv.'
            : 'Nachricht konnte nicht gesendet werden.',
      );
    } on Exception {
      throw const ChatFailure('Keine Verbindung zum Server.');
    }
  }

  @override
  Future<void> markRead(String matchId) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) return;
    try {
      await _client
          .from('messages')
          .update({'read_at': DateTime.now().toUtc().toIso8601String()})
          .eq('match_id', matchId)
          .neq('sender_id', me)
          .isFilter('read_at', null);
    } on Exception {
      // Nicht schlimm – beim nächsten Öffnen wird es erneut versucht.
    }
  }

  @override
  Stream<void> watchInbox() {
    final me = _client.auth.currentUser?.id;
    if (me == null) return const Stream.empty();
    late final RealtimeChannel channel;
    late final StreamController<void> controller;
    void ping(PostgresChangePayload _) => controller.add(null);
    controller = StreamController<void>.broadcast(
      onListen: () {
        // RLS sorgt dafür, dass nur eigene Matches/Nachrichten/Likes ankommen.
        channel = _client
            .channel('inbox-$me')
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'messages',
              callback: ping,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'messages',
              callback: ping,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'matches',
              callback: ping,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'likes',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'likee_id',
                value: me,
              ),
              callback: ping,
            )
            .subscribe();
      },
      onCancel: () => _client.removeChannel(channel),
    );
    return controller.stream;
  }
}
