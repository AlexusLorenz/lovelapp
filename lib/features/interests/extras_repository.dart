import 'profile_extras.dart';

class ExtrasFailure implements Exception {
  const ExtrasFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Interessen, Spiele und Künstler:innen lesen und (eigene) speichern.
abstract interface class ExtrasRepository {
  /// Für mehrere Profile auf einmal (Entdecken, Likes, Chats).
  Future<Map<String, ProfileExtras>> fetchFor(List<String> profileIds);

  Future<void> saveInterests(String userId, List<String> keys);
  Future<void> saveGames(String userId, List<FavoriteGame> games);
  Future<void> saveArtists(String userId, List<FavoriteArtist> artists);
}

/// Suche in externen Datenbanken (RAWG, Spotify) – im echten Betrieb über
/// eine Edge Function, damit keine Schlüssel im Client landen.
abstract interface class CatalogSearch {
  Future<List<FavoriteGame>> searchGames(String query);
  Future<List<FavoriteArtist>> searchArtists(String query);
}

class DemoExtrasRepository implements ExtrasRepository {
  DemoExtrasRepository({Map<String, ProfileExtras>? initial})
    : _data = {...?initial};

  final Map<String, ProfileExtras> _data;

  @override
  Future<Map<String, ProfileExtras>> fetchFor(List<String> profileIds) async =>
      {for (final id in profileIds) id: ?_data[id]};

  ProfileExtras _of(String id) => _data[id] ?? ProfileExtras.empty;

  @override
  Future<void> saveInterests(String userId, List<String> keys) async =>
      _data[userId] = _of(userId).copyWith(interests: List.of(keys));

  @override
  Future<void> saveGames(String userId, List<FavoriteGame> games) async =>
      _data[userId] = _of(userId).copyWith(games: List.of(games));

  @override
  Future<void> saveArtists(String userId, List<FavoriteArtist> artists) async =>
      _data[userId] = _of(userId).copyWith(artists: List.of(artists));
}

/// Demo: kleine eingebaute Liste ohne Cover (RAWG braucht einen Schlüssel).
class DemoCatalogSearch implements CatalogSearch {
  const DemoCatalogSearch();

  static const games = [
    FavoriteGame(id: 22511, name: 'The Legend of Zelda: Breath of the Wild'),
    FavoriteGame(id: 452638, name: 'The Legend of Zelda: Tears of the Kingdom'),
    FavoriteGame(id: 22509, name: 'Minecraft'),
    FavoriteGame(id: 3328, name: 'The Witcher 3: Wild Hunt'),
    FavoriteGame(id: 28, name: 'Red Dead Redemption 2'),
    FavoriteGame(id: 422, name: 'Terraria'),
    FavoriteGame(id: 3498, name: 'Grand Theft Auto V'),
    FavoriteGame(id: 4200, name: 'Portal 2'),
    FavoriteGame(id: 326243, name: 'Elden Ring'),
    FavoriteGame(id: 58175, name: 'God of War'),
    FavoriteGame(id: 32, name: 'Destiny 2'),
    FavoriteGame(id: 41494, name: 'Cyberpunk 2077'),
    FavoriteGame(id: 39707, name: 'Stardew Valley'),
    FavoriteGame(id: 9767, name: 'Hollow Knight'),
    FavoriteGame(id: 274755, name: 'Hades'),
    FavoriteGame(id: 51325, name: 'The Last of Us Part II'),
    FavoriteGame(id: 25097, name: 'Super Mario Odyssey'),
    FavoriteGame(id: 42215, name: 'Animal Crossing: New Horizons'),
    FavoriteGame(id: 22121, name: 'Celeste'),
    FavoriteGame(id: 10213, name: 'Dota 2'),
    FavoriteGame(id: 4291, name: 'Counter-Strike'),
    FavoriteGame(id: 5679, name: 'The Elder Scrolls V: Skyrim'),
    FavoriteGame(id: 12020, name: 'Left 4 Dead 2'),
    FavoriteGame(id: 3439, name: 'Life is Strange'),
    FavoriteGame(id: 2454, name: 'DOOM'),
    FavoriteGame(id: 47137, name: 'Mario Kart 8 Deluxe'),
    FavoriteGame(id: 27969, name: 'It Takes Two'),
    FavoriteGame(id: 13537, name: 'Half-Life 2'),
    FavoriteGame(id: 18080, name: 'Pokémon Karmesin'),
    FavoriteGame(id: 802, name: 'Borderlands 2'),
  ];

  static const artists = [
    FavoriteArtist(id: '4Z8W4fKeB5YxbusRsdQVPb', name: 'Radiohead'),
    FavoriteArtist(id: '06HL4z0CvFAxyc27GXpf02', name: 'Taylor Swift'),
    FavoriteArtist(id: '3TVXtAsR1Inumwj472S9r4', name: 'Drake'),
    FavoriteArtist(id: '1Xyo4u8uXC1ZmMpatF05PJ', name: 'The Weeknd'),
    FavoriteArtist(id: '6qqNVTkY8uBg9cP3Jd7DAH', name: 'Billie Eilish'),
    FavoriteArtist(id: '4gzpq5DPGxSnKTe4SA8HAU', name: 'Coldplay'),
    FavoriteArtist(id: '0k17h0D3J5VfsdmQ1iZtE9', name: 'Pink Floyd'),
    FavoriteArtist(id: '22bE4uQ6baNwSHPVcDxLCe', name: 'The Rolling Stones'),
    FavoriteArtist(id: '3WrFJ7ztbogyGnTHbHJFl2', name: 'The Beatles'),
    FavoriteArtist(id: '7dGJo4pcD2V6oG8kP0tJRR', name: 'Eminem'),
    FavoriteArtist(id: '0oSGxfWSnnOXhD2fKuz2Gy', name: 'David Bowie'),
    FavoriteArtist(id: '1dfeR4HaWDbWqFHLkxsg1d', name: 'Queen'),
    FavoriteArtist(id: '4q3ewBCX7sLwd24euuV69X', name: 'Bad Bunny'),
    FavoriteArtist(id: '3jOstUTkEu2JkjvRdBA5Gu', name: 'Weezer'),
    FavoriteArtist(id: '5K4W6rqBFWDnAN6FQUkS6x', name: 'Kanye West'),
    FavoriteArtist(id: '6eUKZXaKkcviH0Ku9w2n3V', name: 'Ed Sheeran'),
    FavoriteArtist(id: '0du5cEVh5yTK9QJze8zA0C', name: 'Bruno Mars'),
    FavoriteArtist(id: '7jy3rLJdDQY21OgRLCZ9sD', name: 'Foo Fighters'),
    FavoriteArtist(id: '0L8ExT028jH3ddEcZwqJJ5', name: 'Red Hot Chili Peppers'),
    FavoriteArtist(id: '3AA28KZvwAUcZuOKwyblJQ', name: 'Gorillaz'),
    FavoriteArtist(id: '5INjqkS1o8h1imAzPqGZBb', name: 'Tame Impala'),
    FavoriteArtist(id: '4tZwfgrHOc3mvqYlEYSvVi', name: 'Daft Punk'),
    FavoriteArtist(id: '6XyY86QOPPrYVGvF9ch6wz', name: 'Linkin Park'),
    FavoriteArtist(id: '7Ln80lUS6He07XvHI8qqHH', name: 'Arctic Monkeys'),
    FavoriteArtist(id: '0epOFNiUfyON9EYx7Tpr6V', name: 'The Strokes'),
  ];

  static bool _matches(String name, String q) =>
      name.toLowerCase().contains(q.trim().toLowerCase());

  @override
  Future<List<FavoriteGame>> searchGames(String query) async => [
    for (final g in games)
      if (_matches(g.name, query)) g,
  ];

  @override
  Future<List<FavoriteArtist>> searchArtists(String query) async => [
    for (final a in artists)
      if (_matches(a.name, query)) a,
  ];
}
