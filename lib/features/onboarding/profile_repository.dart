import '../location/approx_location.dart';
import '../profile/own_profile.dart';
import '../profile/profile_basics.dart';
import '../profile/profile_prompts.dart';
import 'profile_draft.dart';

/// Fehler beim Speichern des Profils, mit anzeigbarer Meldung.
class ProfileFailure implements Exception {
  const ProfileFailure(this.message);

  final String message;

  @override
  String toString() => 'ProfileFailure: $message';
}

/// Das Nötigste über das eigene Profil.
class OwnProfileSummary {
  const OwnProfileSummary({
    required this.displayName,
    required this.hasLocation,
  });

  final String displayName;
  final bool hasLocation;
}

abstract interface class ProfileRepository {
  Future<bool> hasOwnProfile(String userId);

  Future<void> createProfile(String userId, ProfileDraft draft);

  Future<OwnProfileSummary?> fetchOwnSummary(String userId);

  Future<void> updateLocation(String userId, ApproxLocation location);

  Future<OwnProfile?> fetchOwnProfile(String userId);

  /// Speichert Name, Texte, Steckbrief und ersetzt die Fragen.
  Future<void> updateOwnProfile(String userId, OwnProfile profile);
}

/// Demo-Modus: Profile nur im Speicher.
class DemoProfileRepository implements ProfileRepository {
  DemoProfileRepository({Iterable<String> existingUserIds = const []})
    : _profiles = {for (final id in existingUserIds) id: const {}};

  final Map<String, Map<String, Object?>> _profiles;
  final Map<String, List<PromptAnswer>> _prompts = {};

  @override
  Future<bool> hasOwnProfile(String userId) async =>
      _profiles.containsKey(userId);

  @override
  Future<void> createProfile(String userId, ProfileDraft draft) async {
    _profiles[userId] = draft.toInsertJson();
    _prompts[userId] = List.of(draft.prompts);
  }

  @override
  Future<OwnProfile?> fetchOwnProfile(String userId) async {
    final row = _profiles[userId];
    if (row == null) return null;
    if (row.isEmpty) {
      // Vorbelegtes Demo-Profil
      return const OwnProfile(
        displayName: 'Du',
        age: 28,
        xp: 240,
        city: 'Leipzig',
        basics: ProfileBasics(smoking: Smoking.never),
      );
    }
    return OwnProfile.fromRow(row, prompts: _prompts[userId] ?? const []);
  }

  @override
  Future<void> updateOwnProfile(String userId, OwnProfile profile) async {
    _profiles[userId] = {...?_profiles[userId], ...profile.toUpdateJson()};
    _prompts[userId] = List.of(profile.prompts);
  }

  @override
  Future<OwnProfileSummary?> fetchOwnSummary(String userId) async {
    final row = _profiles[userId];
    if (row == null) return null;
    return OwnProfileSummary(
      displayName: (row['display_name'] as String?) ?? 'Du',
      // Vorbelegte Demo-Profile gelten als vollständig.
      hasLocation: row.isEmpty || row['location'] != null,
    );
  }

  @override
  Future<void> updateLocation(String userId, ApproxLocation location) async {
    final row = Map<String, Object?>.of(_profiles[userId] ?? const {});
    row['location'] = location.toEwkt();
    _profiles[userId] = row;
  }
}
