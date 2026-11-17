import '../../data/demo_data.dart';
import '../economy/like_quota.dart';
import 'public_profile.dart';

class LikeResult {
  const LikeResult({required this.matched, this.matchId, this.remaining});

  final bool matched;
  final String? matchId;

  /// Verbleibende Likes laut Server (`null` im Demo-Modus).
  final int? remaining;
}

/// Fehler mit anzeigbarer Meldung.
class DiscoverFailure implements Exception {
  const DiscoverFailure(this.message, {this.quotaExhausted = false});

  final String message;
  final bool quotaExhausted;

  @override
  String toString() => 'DiscoverFailure: $message';
}

abstract interface class DiscoverRepository {
  /// Nächste passende Profile (beidseitige Filter, ohne schon gesehene).
  Future<List<PublicProfile>> fetchFeed();

  Future<PublicProfile?> fetchProfile(String id);

  Future<LikeResult> like(String profileId);

  Future<void> pass(String profileId);

  Future<LikeQuota> fetchQuota();
}

/// Demo-Modus: Beispielprofile aus `demo_data.dart`.
class DemoDiscoverRepository implements DiscoverRepository {
  final _seen = <String>{};

  @override
  Future<List<PublicProfile>> fetchFeed() async =>
      demoProfiles.where((p) => !_seen.contains(p.id)).toList();

  @override
  Future<PublicProfile?> fetchProfile(String id) async => demoProfileById(id);

  @override
  Future<LikeResult> like(String profileId) async {
    _seen.add(profileId);
    final profile = demoProfileById(profileId);
    return LikeResult(
      matched: profile?.likesYouBack ?? false,
      matchId: profile?.likesYouBack ?? false ? 'demo-$profileId' : null,
    );
  }

  @override
  Future<void> pass(String profileId) async => _seen.add(profileId);

  @override
  Future<LikeQuota> fetchQuota() async => const LikeQuota();
}
