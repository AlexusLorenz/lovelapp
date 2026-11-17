import '../../core/widgets/profile_image.dart';
import '../profile/profile_basics.dart';
import '../profile/profile_prompts.dart';

/// Was andere von einem Profil sehen.
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.city,
    required this.distanceKm,
    required this.bio,
    required this.level,
    this.photos = const [],
    this.prompts = const [],
    this.basics = const ProfileBasics(),
    this.likesYouBack = false,
  });

  /// Aus einer Zeile von `discover_profiles` / `get_public_profiles`.
  factory PublicProfile.fromRow(
    Map<String, Object?> row, {
    List<PromptAnswer> prompts = const [],
    List<ProfileImage> photos = const [],
  }) {
    return PublicProfile(
      id: row['id']! as String,
      name: row['display_name']! as String,
      age: (row['age']! as num).toInt(),
      city: (row['city'] as String?) ?? '',
      distanceKm: (row['distance_km'] as num?)?.toInt(),
      bio: (row['bio'] as String?) ?? '',
      level: (row['level'] as num?)?.toInt() ?? 1,
      prompts: prompts,
      photos: photos,
      basics: ProfileBasics.fromJson(row),
    );
  }

  final String id;
  final String name;
  final int age;
  final String city;

  /// Gerundet; `null`, wenn unbekannt (z. B. bei Matches).
  final int? distanceKm;
  final String bio;
  final int level;

  /// Fotos in Anzeige-Reihenfolge; leer = Initiale zeigen.
  final List<ProfileImage> photos;
  final List<PromptAnswer> prompts;
  final ProfileBasics basics;

  PublicProfile copyWith({List<ProfileImage>? photos}) => PublicProfile(
    id: id,
    name: name,
    age: age,
    city: city,
    distanceKm: distanceKm,
    bio: bio,
    level: level,
    photos: photos ?? this.photos,
    prompts: prompts,
    basics: basics,
    likesYouBack: likesYouBack,
  );

  /// Nur Demo: Würde dieses Profil zurückliken?
  final bool likesYouBack;

  /// „Leipzig · 3 km“ – lässt fehlende Teile weg.
  String get locationLabel => [
    if (city.isNotEmpty) city,
    if (distanceKm != null) '$distanceKm km',
  ].join(' · ');
}

/// Sortiert Zeilen aus `profile_prompts` je Profil in Anzeige-Reihenfolge.
Map<String, List<PromptAnswer>> groupPromptRows(
  Iterable<Map<String, Object?>> rows,
) {
  final sorted = rows.toList()
    ..sort(
      (a, b) => ((a['position'] as num?) ?? 0).compareTo(
        (b['position'] as num?) ?? 0,
      ),
    );
  final result = <String, List<PromptAnswer>>{};
  for (final row in sorted) {
    result
        .putIfAbsent(row['profile_id']! as String, () => [])
        .add(
          PromptAnswer(row['prompt_key']! as String, row['answer']! as String),
        );
  }
  return result;
}
