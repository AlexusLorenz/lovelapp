import 'dart:async';

import '../../data/demo_data.dart';
import '../discover/public_profile.dart';

class MatchSummary {
  const MatchSummary({
    required this.matchId,
    required this.profile,
    this.lastMessage,
    this.gamePending = false,
  });

  final String matchId;
  final PublicProfile profile;
  final String? lastMessage;
  final bool gamePending;
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  factory ChatMessage.fromRow(Map<String, Object?> row) => ChatMessage(
    id: '${row['id']}',
    senderId: row['sender_id']! as String,
    body: row['body']! as String,
    createdAt: DateTime.parse(row['created_at']! as String),
  );

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
}

class ChatFailure implements Exception {
  const ChatFailure(this.message);

  final String message;

  @override
  String toString() => 'ChatFailure: $message';
}

abstract interface class MatchesRepository {
  Future<List<MatchSummary>> fetchMatches();

  /// Alle Nachrichten eines Matches, aktualisiert sich live.
  Stream<List<ChatMessage>> watchMessages(String matchId);

  Future<void> sendMessage(String matchId, String body);
}

/// Demo-Modus: Matches und Nachrichten nur im Speicher.
class DemoMatchesRepository implements MatchesRepository {
  DemoMatchesRepository({required this.myUserId});

  /// Als Funktion, weil sich im Demo-Modus die Anmeldung ändern kann.
  final String Function() myUserId;
  final _messages = <String, List<ChatMessage>>{};
  final _controllers = <String, StreamController<List<ChatMessage>>>{};

  List<ChatMessage> _seed(String matchId) => _messages.putIfAbsent(matchId, () {
    for (final m in demoMatches) {
      if (m.id == matchId) {
        return [
          ChatMessage(
            id: '$matchId-0',
            senderId: m.profile.id,
            body: m.lastMessage,
            createdAt: DateTime(2026, 11, 17, 12),
          ),
        ];
      }
    }
    return [];
  });

  @override
  Future<List<MatchSummary>> fetchMatches() async => [
    for (final m in demoMatches)
      MatchSummary(
        matchId: m.id,
        profile: m.profile,
        lastMessage: _seed(m.id).isEmpty ? null : _seed(m.id).last.body,
        gamePending: m.gamePending,
      ),
  ];

  @override
  Stream<List<ChatMessage>> watchMessages(String matchId) {
    final controller = _controllers.putIfAbsent(
      matchId,
      StreamController<List<ChatMessage>>.broadcast,
    );
    return Stream.multi((sink) {
      sink.add(List.unmodifiable(_seed(matchId)));
      final sub = controller.stream.listen(sink.add);
      sink.onCancel = sub.cancel;
    });
  }

  @override
  Future<void> sendMessage(String matchId, String body) async {
    final list = _seed(matchId)
      ..add(
        ChatMessage(
          id: '$matchId-${_messages[matchId]!.length}',
          senderId: myUserId(),
          body: body.trim(),
          createdAt: DateTime.now(),
        ),
      );
    _controllers[matchId]?.add(List.unmodifiable(list));
  }
}
