import '../location/approx_location.dart';
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
}

/// Demo-Modus: Profile nur im Speicher.
class DemoProfileRepository implements ProfileRepository {
  DemoProfileRepository({Iterable<String> existingUserIds = const []})
    : _profiles = {for (final id in existingUserIds) id: const {}};

  final Map<String, Map<String, Object?>> _profiles;

  @override
  Future<bool> hasOwnProfile(String userId) async =>
      _profiles.containsKey(userId);

  @override
  Future<void> createProfile(String userId, ProfileDraft draft) async {
    _profiles[userId] = draft.toInsertJson();
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
