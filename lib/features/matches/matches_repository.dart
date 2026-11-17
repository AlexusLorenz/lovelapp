import 'dart:async';

import '../../data/demo_data.dart';
import '../discover/public_profile.dart';

class MatchSummary {
  const MatchSummary({
    required this.matchId,
    required this.profile,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
    this.gamePending = false,
  });

  final String matchId;
  final PublicProfile profile;

  /// `null` = noch keine Nachricht (neues Match).
  final String? lastMessage;
  final DateTime? lastMessageAt;

  /// Nachrichten vom Gegenüber, die ich noch nicht gelesen habe.
  final int unreadCount;
  final bool gamePending;
}

/// Unterhaltungen: neueste Nachricht zuerst.
List<MatchSummary> sortChats(Iterable<MatchSummary> matches) =>
    matches.toList()..sort(
      (a, b) => (b.lastMessageAt ?? DateTime(0)).compareTo(
        a.lastMessageAt ?? DateTime(0),
      ),
    );

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

  /// Markiert alle Nachrichten des Gegenübers in diesem Match als gelesen.
  Future<void> markRead(String matchId);

  /// Meldet, wenn sich etwas für mich ändert: neue Nachricht, gelesen,
  /// neuer Like, neues Match. Die App lädt dann die Listen neu.
  Stream<void> watchInbox();
}

/// Demo-Modus: Matches und Nachrichten nur im Speicher.
class DemoMatchesRepository implements MatchesRepository {
  DemoMatchesRepository({required this.myUserId});

  /// Als Funktion, weil sich im Demo-Modus die Anmeldung ändern kann.
  final String Function() myUserId;
  final _messages = <String, List<ChatMessage>>{};
  final _controllers = <String, StreamController<List<ChatMessage>>>{};
  final _inbox = StreamController<void>.broadcast();

  /// Index der ersten ungelesenen Nachricht je Match (alles davor gelesen).
  final _readUpTo = <String, int>{};

  List<ChatMessage> _seed(String matchId) => _messages.putIfAbsent(matchId, () {
    for (final m in demoMatches) {
      if (m.id == matchId && m.lastMessage != null) {
        return [
          ChatMessage(
            id: '$matchId-0',
            senderId: m.profile.id,
            body: m.lastMessage!,
            createdAt: DateTime(2026, 11, 17, 12),
          ),
        ];
      }
    }
    return [];
  });

  int _unread(String matchId) {
    final list = _seed(matchId);
    final me = myUserId();
    return [
      for (var i = _readUpTo[matchId] ?? 0; i < list.length; i++)
        if (list[i].senderId != me) i,
    ].length;
  }

  @override
  Future<List<MatchSummary>> fetchMatches() async => [
    for (final m in demoMatches)
      MatchSummary(
        matchId: m.id,
        profile: m.profile,
        lastMessage: _seed(m.id).isEmpty ? null : _seed(m.id).last.body,
        lastMessageAt: _seed(m.id).isEmpty ? null : _seed(m.id).last.createdAt,
        unreadCount: _unread(m.id),
        gamePending: m.gamePending,
      ),
  ];

  @override
  Future<void> markRead(String matchId) async {
    if (_unread(matchId) == 0) return;
    _readUpTo[matchId] = _seed(matchId).length;
    _inbox.add(null);
  }

  @override
  Stream<void> watchInbox() => _inbox.stream;

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
    _inbox.add(null);
  }
}
