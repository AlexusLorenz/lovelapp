import 'package:supabase_flutter/supabase_flutter.dart';

import 'extras_repository.dart';
import 'profile_extras.dart';

class SupabaseExtrasRepository implements ExtrasRepository {
  SupabaseExtrasRepository(this._client);

  final SupabaseClient _client;

  Future<T> _guard<T>(Future<T> Function() run, String message) async {
    try {
      return await run();
    } on PostgrestException {
      throw ExtrasFailure(message);
    } on AuthException {
      throw ExtrasFailure(message);
    }
  }

  @override
  Future<Map<String, ProfileExtras>> fetchFor(List<String> profileIds) =>
      _guard(() async {
        if (profileIds.isEmpty) return const {};
        final results = await Future.wait([
          _client
              .from('profile_interests')
              .select('profile_id, interest_key')
              .inFilter('profile_id', profileIds),
          _client
              .from('profile_games')
              .select('profile_id, position, rawg_id, name, cover_url')
              .inFilter('profile_id', profileIds),
          _client
              .from('profile_artists')
              .select('profile_id, position, spotify_id, name, image_url')
              .inFilter('profile_id', profileIds),
        ]);
        return groupExtras(
          interestRows: results[0],
          gameRows: results[1],
          artistRows: results[2],
        );
      }, 'Interessen konnten nicht geladen werden.');

  @override
  Future<void> saveInterests(String userId, List<String> keys) => _guard(
    () => _client.rpc<void>('set_profile_interests', params: {'p_keys': keys}),
    'Interessen konnten nicht gespeichert werden.',
  );

  @override
  Future<void> saveGames(String userId, List<FavoriteGame> games) => _guard(
    () => _client.rpc<void>(
      'set_profile_games',
      params: {
        'p_games': [for (final g in games) g.toJson()],
      },
    ),
    'Spiele konnten nicht gespeichert werden.',
  );

  @override
  Future<void> saveArtists(String userId, List<FavoriteArtist> artists) =>
      _guard(
        () => _client.rpc<void>(
          'set_profile_artists',
          params: {
            'p_artists': [for (final a in artists) a.toJson()],
          },
        ),
        'Künstler:innen konnten nicht gespeichert werden.',
      );
}

/// Sucht über die Edge Function `catalog-search` (hält die API-Schlüssel).
class EdgeCatalogSearch implements CatalogSearch {
  EdgeCatalogSearch(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, Object?>>> _search(String type, String q) async {
    if (q.trim().length < 2) return const [];
    try {
      final res = await _client.functions.invoke(
        'catalog-search',
        body: {'type': type, 'q': q.trim()},
      );
      final items = (res.data as Map?)?['items'] as List<Object?>? ?? const [];
      return [for (final i in items) Map<String, Object?>.from(i! as Map)];
    } on FunctionException catch (e) {
      throw ExtrasFailure(
        e.status == 503
            ? 'Die Suche ist noch nicht eingerichtet.'
            : 'Suche gerade nicht möglich.',
      );
    }
  }

  @override
  Future<List<FavoriteGame>> searchGames(String query) async => [
    for (final r in await _search('games', query)) FavoriteGame.fromRow(r),
  ];

  @override
  Future<List<FavoriteArtist>> searchArtists(String query) async => [
    for (final r in await _search('artists', query)) FavoriteArtist.fromRow(r),
  ];
}
