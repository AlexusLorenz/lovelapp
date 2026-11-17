import 'package:supabase_flutter/supabase_flutter.dart';

import '../economy/like_quota.dart';
import 'discover_repository.dart';
import 'public_profile.dart';

class SupabaseDiscoverRepository implements DiscoverRepository {
  SupabaseDiscoverRepository(this._client);

  final SupabaseClient _client;

  /// Lädt die drei Fragen zu den Profilen nach.
  Future<List<PublicProfile>> _withPrompts(
    List<Map<String, Object?>> rows,
  ) async {
    if (rows.isEmpty) return const [];
    final ids = [for (final r in rows) r['id']! as String];
    final promptRows = await _client
        .from('profile_prompts')
        .select('profile_id, position, prompt_key, answer')
        .inFilter('profile_id', ids);
    final prompts = groupPromptRows(promptRows);
    return [
      for (final r in rows)
        PublicProfile.fromRow(r, prompts: prompts[r['id']] ?? const []),
    ];
  }

  @override
  Future<List<PublicProfile>> fetchFeed() => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'discover_profiles',
      params: {'p_limit': 20},
    );
    return _withPrompts(rows.cast<Map<String, Object?>>());
  });

  @override
  Future<PublicProfile?> fetchProfile(String id) => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>(
      'get_public_profiles',
      params: {
        'p_ids': [id],
      },
    );
    final list = await _withPrompts(rows.cast<Map<String, Object?>>());
    return list.isEmpty ? null : list.first;
  });

  @override
  Future<LikeResult> like(String profileId) => _guard(() async {
    final result = await _client.rpc<Map<String, dynamic>>(
      'like_profile',
      params: {'p_target': profileId},
    );
    return LikeResult(
      matched: result['matched'] == true,
      matchId: result['match_id'] as String?,
      remaining: (result['remaining'] as num?)?.toInt(),
    );
  });

  @override
  Future<void> pass(String profileId) => _guard(
    () => _client.rpc<void>('pass_profile', params: {'p_target': profileId}),
  );

  @override
  Future<LikeQuota> fetchQuota() => _guard(() async {
    final rows = await _client.rpc<List<dynamic>>('like_quota_status');
    if (rows.isEmpty) return const LikeQuota();
    final row = rows.first as Map<String, dynamic>;
    return LikeQuota(
      likesUsed: (row['likes_used'] as num).toInt(),
      rewardedAdsWatched: (row['rewarded_ads'] as num).toInt(),
      isPremium: row['is_premium'] == true,
    );
  });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on PostgrestException catch (e) {
      if (e.hint == 'quota_exhausted') {
        throw const DiscoverFailure(
          'Für heute sind deine Likes aufgebraucht.',
          quotaExhausted: true,
        );
      }
      if (e.message.contains('nicht verfügbar')) {
        throw const DiscoverFailure('Dieses Profil ist nicht mehr verfügbar.');
      }
      throw const DiscoverFailure(
        'Das hat nicht geklappt. Bitte versuch es noch einmal.',
      );
    } on Exception {
      throw const DiscoverFailure(
        'Keine Verbindung zum Server. Bitte prüfe dein Internet.',
      );
    }
  }
}
