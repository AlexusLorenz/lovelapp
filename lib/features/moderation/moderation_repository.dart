import 'package:supabase_flutter/supabase_flutter.dart';

import 'moderation_models.dart';

export 'moderation_models.dart';

/// Moderation – alle Aufrufe prüft der Server (nur Admins).
abstract interface class ModerationRepository {
  Future<bool> isAdmin();
  Future<List<ModReport>> reports({bool onlyOpen = true});
  Future<void> setReportStatus(String reportId, String status);
  Future<void> ban(String userId, String reason);
  Future<void> unban(String userId);
  Future<void> removePhoto(String photoId);
  Future<Map<String, Object?>> stats({bool includeTest = false});
}

class SupabaseModerationRepository implements ModerationRepository {
  SupabaseModerationRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<bool> isAdmin() async =>
      await _client.rpc<bool?>('am_i_admin') ?? false;

  @override
  Future<List<ModReport>> reports({bool onlyOpen = true}) async {
    final raw = await _client.rpc<List<dynamic>>(
      'mod_reports',
      params: {'p_status': onlyOpen ? 'open' : 'all'},
    );
    final list = [
      for (final r in raw)
        ModReport.fromJson(Map<String, Object?>.from(r as Map)),
    ];
    // Fotos für die Ansicht signieren (Bucket ist privat).
    final paths = {
      for (final r in list)
        for (final p in r.reported.photos) p.path,
    }.toList();
    if (paths.isEmpty) return list;
    final signed = await _client.storage
        .from('profile-photos')
        .createSignedUrlsResult(paths, 60 * 30);
    final urls = {
      for (final s in signed.whereType<SignedUrlSuccess>()) s.path: s.signedUrl,
    };
    return [
      for (final r in list)
        r.withReported(
          r.reported.withPhotos([
            for (final p in r.reported.photos) p.withUrl(urls[p.path]),
          ]),
        ),
    ];
  }

  @override
  Future<void> setReportStatus(String reportId, String status) =>
      _client.rpc<void>(
        'mod_set_report_status',
        params: {'p_report': reportId, 'p_status': status},
      );

  @override
  Future<void> ban(String userId, String reason) => _client.rpc<void>(
    'mod_ban_user',
    params: {'p_user': userId, 'p_reason': reason},
  );

  @override
  Future<void> unban(String userId) =>
      _client.rpc<void>('mod_unban_user', params: {'p_user': userId});

  @override
  Future<void> removePhoto(String photoId) =>
      _client.rpc<void>('mod_remove_photo', params: {'p_photo': photoId});

  @override
  Future<Map<String, Object?>> stats({bool includeTest = false}) async =>
      Map<String, Object?>.from(
        await _client.rpc<Map<String, dynamic>>(
          'mod_stats',
          params: {'p_include_test': includeTest},
        ),
      );
}

/// Demo-Modus: keine Moderation.
class DemoModerationRepository implements ModerationRepository {
  const DemoModerationRepository();

  @override
  Future<bool> isAdmin() async => false;

  @override
  Future<List<ModReport>> reports({bool onlyOpen = true}) async => const [];

  @override
  Future<void> setReportStatus(String reportId, String status) async {}

  @override
  Future<void> ban(String userId, String reason) async {}

  @override
  Future<void> unban(String userId) async {}

  @override
  Future<void> removePhoto(String photoId) async {}

  @override
  Future<Map<String, Object?>> stats({bool includeTest = false}) async =>
      const {};
}
