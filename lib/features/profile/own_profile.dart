/// Das eigene Profil zum Bearbeiten (ohne Flutter-Abhängigkeit).
library;

import '../onboarding/profile_draft.dart';
import '../progress/level.dart';
import 'profile_basics.dart';
import 'profile_prompts.dart';

/// Was man nach dem Onboarding selbst ändern kann.
///
/// Geburtsdatum, Geschlecht und Orientierung sind (noch) nicht dabei – die
/// brauchen eigene Abläufe (18+-Prüfung, Einwilligung/Widerruf).
class OwnProfile {
  const OwnProfile({
    required this.displayName,
    this.age,
    this.xp = 0,
    this.bio = '',
    this.city = '',
    this.basics = const ProfileBasics(),
    this.prompts = const [],
  });

  factory OwnProfile.fromRow(
    Map<String, Object?> row, {
    List<PromptAnswer> prompts = const [],
    DateTime? today,
  }) => OwnProfile(
    displayName: row['display_name']! as String,
    age: switch (row['birthdate']) {
      final String b => ageOn(DateTime.parse(b), today ?? DateTime.now()),
      _ => null,
    },
    xp: (row['xp'] as num?)?.toInt() ?? 0,
    bio: (row['bio'] as String?) ?? '',
    city: (row['city'] as String?) ?? '',
    basics: ProfileBasics.fromJson(row),
    prompts: prompts,
  );

  final String displayName;

  /// Nur zur Anzeige (Vorschau); geändert wird hier nichts davon.
  final int? age;
  final int xp;
  int get level => LevelProgress.fromXp(xp).level;

  final String bio;
  final String city;
  final ProfileBasics basics;
  final List<PromptAnswer> prompts;

  /// Prüft alles; `null` = speicherbar.
  String? validate() =>
      validateDisplayName(displayName) ??
      (bio.trim().length > maxBioLength
          ? 'Über mich: höchstens $maxBioLength Zeichen.'
          : null) ??
      (city.trim().length > maxCityLength ? 'Stadt ist zu lang.' : null) ??
      validatePromptSelection(prompts);

  /// Spalten für `update profiles`.
  Map<String, Object?> toUpdateJson() => {
    'display_name': displayName.trim(),
    'bio': bio.trim(),
    'city': city.trim().isEmpty ? null : city.trim(),
    ...basics.toJson(),
  };

  /// Zeilen für `profile_prompts` (ohne `profile_id`).
  List<Map<String, Object?>> promptRows() => [
    for (var i = 0; i < prompts.length; i++)
      {
        'position': i,
        'prompt_key': prompts[i].promptKey,
        'answer': prompts[i].answer.trim(),
      },
  ];
}
