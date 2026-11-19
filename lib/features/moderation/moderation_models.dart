/// Datenmodelle der Moderationsansicht (nur für Admins).
library;

class ModPhoto {
  const ModPhoto({
    required this.id,
    required this.path,
    required this.status,
    this.url,
  });

  factory ModPhoto.fromJson(Map<String, Object?> j) => ModPhoto(
    id: j['id']! as String,
    path: j['path']! as String,
    status: j['status']! as String,
  );

  final String id;
  final String path;

  /// approved | pending | rejected
  final String status;

  /// Signierte URL zum Ansehen (wird nachgeladen).
  final String? url;

  bool get isRemoved => status == 'rejected';

  ModPhoto withUrl(String? url) =>
      ModPhoto(id: id, path: path, status: status, url: url);
}

class ModPerson {
  const ModPerson({
    required this.id,
    required this.name,
    this.bio = '',
    this.isTest = false,
    this.bannedAt,
    this.reportCount = 0,
    this.photos = const [],
  });

  factory ModPerson.fromJson(Map<String, Object?> j) => ModPerson(
    id: j['id']! as String,
    name: j['name']! as String,
    bio: j['bio'] as String? ?? '',
    isTest: j['is_test'] as bool? ?? false,
    bannedAt: j['banned_at'] == null
        ? null
        : DateTime.parse(j['banned_at']! as String),
    reportCount: (j['report_count'] as num?)?.toInt() ?? 0,
    photos: [
      for (final p in (j['photos'] as List<Object?>?) ?? const [])
        ModPhoto.fromJson(Map<String, Object?>.from(p! as Map)),
    ],
  );

  final String id;
  final String name;
  final String bio;
  final bool isTest;
  final DateTime? bannedAt;
  final int reportCount;
  final List<ModPhoto> photos;

  bool get isBanned => bannedAt != null;

  ModPerson withPhotos(List<ModPhoto> photos) => ModPerson(
    id: id,
    name: name,
    bio: bio,
    isTest: isTest,
    bannedAt: bannedAt,
    reportCount: reportCount,
    photos: photos,
  );
}

class ModReport {
  const ModReport({
    required this.id,
    required this.reason,
    required this.status,
    required this.createdAt,
    required this.reported,
    this.details = '',
    this.message,
    this.reporter,
  });

  factory ModReport.fromJson(Map<String, Object?> j) => ModReport(
    id: j['id']! as String,
    reason: j['reason']! as String,
    details: j['details'] as String? ?? '',
    status: j['status']! as String,
    createdAt: DateTime.parse(j['created_at']! as String),
    message: j['message'] as String?,
    reporter: j['reporter'] == null
        ? null
        : ModPerson.fromJson(Map<String, Object?>.from(j['reporter']! as Map)),
    reported: ModPerson.fromJson(
      Map<String, Object?>.from(j['reported']! as Map),
    ),
  );

  final String id;

  /// Wert aus public.report_reason.
  final String reason;
  final String details;

  /// open | in_review | resolved | dismissed
  final String status;
  final DateTime createdAt;
  final String? message;
  final ModPerson? reporter;
  final ModPerson reported;

  bool get isOpen => status == 'open' || status == 'in_review';

  ModReport withReported(ModPerson p) => ModReport(
    id: id,
    reason: reason,
    details: details,
    status: status,
    createdAt: createdAt,
    message: message,
    reporter: reporter,
    reported: p,
  );
}

/// Kennzahl mit Beschriftung, in der Reihenfolge der Anzeige.
class ModStat {
  const ModStat(this.label, this.value, {this.hint});
  final String label;
  final String value;
  final String? hint;
}

String _pct(num part, num whole) =>
    whole == 0 ? '–' : '${(part * 100 / whole).round()} %';

/// Kennzahlen aus `mod_stats` in lesbarer Form (reine Logik, testbar).
List<(String, List<ModStat>)> describeStats(Map<String, Object?> s) {
  int n(String k) => (s[k] as num?)?.toInt() ?? 0;
  final kinds = Map<String, Object?>.from(
    (s['games_by_kind'] as Map?) ?? const {},
  );
  return [
    (
      'Nutzer:innen',
      [
        ModStat('Konten', '${n('users')}'),
        ModStat('Neu (7 Tage)', '${n('users_new_7d')}'),
        ModStat('Aktiv (7 Tage)', '${n('users_active_7d')}'),
        ModStat('Push aktiviert (Geräte)', '${n('push_devices')}'),
        ModStat('Gesperrt', '${n('banned')}'),
      ],
    ),
    (
      'Matches & Chats',
      [
        ModStat('Likes (7 Tage)', '${n('likes_7d')}'),
        ModStat('Matches', '${n('matches')}'),
        ModStat('Matches (7 Tage)', '${n('matches_7d')}'),
        ModStat(
          'Matches mit Chat',
          '${n('matches_with_chat')}',
          hint: _pct(n('matches_with_chat'), n('matches')),
        ),
        ModStat('Nachrichten (7 Tage)', '${n('messages_7d')}'),
      ],
    ),
    (
      'Spiele',
      [
        ModStat(
          'Matches, die ein Spiel starten',
          '${n('matches_with_game')}',
          hint: _pct(n('matches_with_game'), n('matches')),
        ),
        ModStat(
          '… und danach chatten',
          '${n('matches_chat_after_game')}',
          hint: _pct(n('matches_chat_after_game'), n('matches_with_game')),
        ),
        ModStat('Spiele gesamt', '${n('games')}'),
        ModStat('Laufend', '${n('games_running')}'),
        ModStat(
          'Zu Ende gespielt',
          '${n('games_finished')}',
          hint: _pct(n('games_finished'), n('games')),
        ),
        ModStat(
          'Aufgegeben / abgelaufen',
          '${n('games_forfeited')}',
          hint: _pct(n('games_forfeited'), n('games')),
        ),
        for (final e in kinds.entries)
          ModStat('Spielart „${e.key}“', '${(e.value as num?)?.toInt() ?? 0}'),
      ],
    ),
    ('Sicherheit', [ModStat('Offene Meldungen', '${n('reports_open')}')]),
  ];
}
