import 'profile_draft.dart';

/// Fehler beim Speichern des Profils, mit anzeigbarer Meldung.
class ProfileFailure implements Exception {
  const ProfileFailure(this.message);

  final String message;

  @override
  String toString() => 'ProfileFailure: $message';
}

abstract interface class ProfileRepository {
  Future<bool> hasOwnProfile(String userId);

  Future<void> createProfile(String userId, ProfileDraft draft);
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
}
