// Interessen, Lieblingsspiele und Lieblingskünstler:innen eines Profils.
// Reine Logik ohne Flutter-Import.

/// Grenzen – MÜSSEN zu supabase/migrations/20261117220713_interests_games_music.sql
/// passen.
const maxFavoriteGames = 6;
const maxFavoriteArtists = 6;

/// Ein Spiel aus der RAWG-Datenbank.
class FavoriteGame {
  const FavoriteGame({required this.id, required this.name, this.coverUrl});

  factory FavoriteGame.fromRow(Map<String, Object?> row) => FavoriteGame(
    id: (row['rawg_id'] ?? row['id'])! as int,
    name: row['name']! as String,
    coverUrl: (row['cover_url'] ?? row['cover']) as String?,
  );

  final int id;
  final String name;
  final String? coverUrl;

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'cover': coverUrl};

  @override
  bool operator ==(Object other) => other is FavoriteGame && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Ein:e Künstler:in von Spotify.
class FavoriteArtist {
  const FavoriteArtist({required this.id, required this.name, this.imageUrl});

  factory FavoriteArtist.fromRow(Map<String, Object?> row) => FavoriteArtist(
    id: (row['spotify_id'] ?? row['id'])! as String,
    name: row['name']! as String,
    imageUrl: (row['image_url'] ?? row['image']) as String?,
  );

  final String id;
  final String name;
  final String? imageUrl;

  /// Link zurück zu Spotify (Pflicht laut Spotify-Richtlinien).
  String get spotifyUrl => 'https://open.spotify.com/artist/$id';

  Map<String, Object?> toJson() => {'id': id, 'name': name, 'image': imageUrl};

  @override
  bool operator ==(Object other) => other is FavoriteArtist && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

class ProfileExtras {
  const ProfileExtras({
    this.interests = const [],
    this.games = const [],
    this.artists = const [],
  });

  /// Schlüssel wie `music.jazz`.
  final List<String> interests;
  final List<FavoriteGame> games;
  final List<FavoriteArtist> artists;

  static const empty = ProfileExtras();

  bool get isEmpty => interests.isEmpty && games.isEmpty && artists.isEmpty;

  ProfileExtras copyWith({
    List<String>? interests,
    List<FavoriteGame>? games,
    List<FavoriteArtist>? artists,
  }) => ProfileExtras(
    interests: interests ?? this.interests,
    games: games ?? this.games,
    artists: artists ?? this.artists,
  );
}

/// Gruppiert Zeilen der drei Tabellen nach Profil.
Map<String, ProfileExtras> groupExtras({
  required Iterable<Map<String, Object?>> interestRows,
  required Iterable<Map<String, Object?>> gameRows,
  required Iterable<Map<String, Object?>> artistRows,
}) {
  int pos(Map<String, Object?> r) => (r['position'] as num?)?.toInt() ?? 0;
  final interests = <String, List<String>>{};
  for (final r in interestRows) {
    interests
        .putIfAbsent(r['profile_id']! as String, () => [])
        .add(r['interest_key']! as String);
  }
  final games = <String, List<Map<String, Object?>>>{};
  for (final r in gameRows) {
    games.putIfAbsent(r['profile_id']! as String, () => []).add(r);
  }
  final artists = <String, List<Map<String, Object?>>>{};
  for (final r in artistRows) {
    artists.putIfAbsent(r['profile_id']! as String, () => []).add(r);
  }
  final ids = {...interests.keys, ...games.keys, ...artists.keys};
  return {
    for (final id in ids)
      id: ProfileExtras(
        interests: [...?interests[id]]..sort(),
        games: [
          for (final r in [
            ...?games[id],
          ]..sort((a, b) => pos(a).compareTo(pos(b))))
            FavoriteGame.fromRow(r),
        ],
        artists: [
          for (final r in [
            ...?artists[id],
          ]..sort((a, b) => pos(a).compareTo(pos(b))))
            FavoriteArtist.fromRow(r),
        ],
      ),
  };
}
