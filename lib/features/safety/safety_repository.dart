import 'package:supabase_flutter/supabase_flutter.dart';

/// Gründe – MÜSSEN zum Enum public.report_reason passen.
enum ReportReason {
  fakeProfile('fake_profile', 'Fake-Profil oder Betrug'),
  harassment('harassment', 'Belästigung oder Beleidigung'),
  inappropriateContent('inappropriate_content', 'Unangemessene Inhalte'),
  underage('underage', 'Wirkt minderjährig'),
  spam('spam', 'Spam oder Werbung'),
  other('other', 'Etwas anderes');

  const ReportReason(this.dbValue, this.label);

  final String dbValue;
  final String label;
}

class SafetyFailure implements Exception {
  const SafetyFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract interface class SafetyRepository {
  /// Blockiert die Person. Ein bestehendes Match endet dabei (DB-Trigger),
  /// und beide sehen sich nicht mehr.
  Future<void> block(String profileId);

  /// Meldet die Person an die Moderation.
  Future<void> report(
    String profileId,
    ReportReason reason, {
    String details = '',
  });
}

class SupabaseSafetyRepository implements SafetyRepository {
  SupabaseSafetyRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<void> block(String profileId) async {
    try {
      await _client.from('blocks').insert({'blocked_id': profileId});
    } on PostgrestException catch (e) {
      if (e.code == '23505') return; // schon blockiert

      throw const SafetyFailure('Blockieren hat nicht geklappt.');
    }
  }

  @override
  Future<void> report(
    String profileId,
    ReportReason reason, {
    String details = '',
  }) async {
    try {
      await _client.from('reports').insert({
        'reported_id': profileId,
        'reason': reason.dbValue,
        'details': details.trim(),
      });
    } on PostgrestException {
      throw const SafetyFailure('Melden hat nicht geklappt.');
    }
  }
}

class DemoSafetyRepository implements SafetyRepository {
  DemoSafetyRepository({this.onBlock});

  /// Im Demo-Modus: Match im Speicher beenden.
  final void Function(String profileId)? onBlock;
  final blocked = <String>{};
  final reports = <(String, ReportReason, String)>[];

  @override
  Future<void> block(String profileId) async {
    blocked.add(profileId);
    onBlock?.call(profileId);
  }

  @override
  Future<void> report(
    String profileId,
    ReportReason reason, {
    String details = '',
  }) async => reports.add((profileId, reason, details));
}
