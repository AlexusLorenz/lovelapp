import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../../data/demo_data.dart';
import '../auth/auth_repository.dart';
import '../auth/supabase_auth_repository.dart';
import '../discover/discover_repository.dart';
import '../interests/extras_repository.dart';
import '../quiz/demo_quiz_repository.dart';
import '../quiz/quiz_models.dart';
import '../quiz/quiz_repository.dart';
import '../quiz/supabase_quiz_repository.dart';
import '../safety/safety_repository.dart';
import '../interests/supabase_extras_repository.dart';
import '../discover/supabase_discover_repository.dart';
import '../location/location_service.dart';
import '../matches/matches_repository.dart';
import '../matches/supabase_matches_repository.dart';
import '../onboarding/profile_repository.dart';
import '../photos/photos_repository.dart';
import '../photos/supabase_photos_repository.dart';
import '../onboarding/supabase_profile_repository.dart';

// Mit Supabase-Zugangsdaten echte Repositories, sonst Demo-Modus.
// In Tests werden diese Provider überschrieben.

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => Env.hasSupabase
      ? SupabaseAuthRepository(Supabase.instance.client)
      : DemoAuthRepository(),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => Env.hasSupabase
      ? SupabaseProfileRepository(Supabase.instance.client)
      : DemoProfileRepository(),
);

final discoverRepositoryProvider = Provider<DiscoverRepository>(
  (ref) => Env.hasSupabase
      ? SupabaseDiscoverRepository(
          Supabase.instance.client,
          ref.read(photosRepositoryProvider),
        )
      : DemoDiscoverRepository(),
);

final matchesRepositoryProvider = Provider<MatchesRepository>(
  (ref) => Env.hasSupabase
      ? SupabaseMatchesRepository(
          Supabase.instance.client,
          ref.read(photosRepositoryProvider),
        )
      : DemoMatchesRepository(
          myUserId: () =>
              ref.read(authRepositoryProvider).currentUser?.id ?? 'me',
        ),
);

final locationServiceProvider = Provider<LocationService>(
  (ref) => Env.hasSupabase
      ? const DeviceLocationService()
      : const FakeLocationService(),
);

final photosRepositoryProvider = Provider<PhotosRepository>(
  (ref) => Env.hasSupabase
      ? SupabasePhotosRepository(Supabase.instance.client)
      : DemoPhotosRepository(),
);

final extrasRepositoryProvider = Provider<ExtrasRepository>(
  (ref) => Env.hasSupabase
      ? SupabaseExtrasRepository(Supabase.instance.client)
      : DemoExtrasRepository(initial: demoExtras),
);

final catalogSearchProvider = Provider<CatalogSearch>(
  (ref) => Env.hasSupabase
      ? EdgeCatalogSearch(Supabase.instance.client)
      : const DemoCatalogSearch(),
);

final safetyRepositoryProvider = Provider<SafetyRepository>(
  (ref) => Env.hasSupabase
      ? SupabaseSafetyRepository(Supabase.instance.client)
      : DemoSafetyRepository(
          onBlock: (id) {
            final matches = ref.read(matchesRepositoryProvider);
            if (matches is DemoMatchesRepository) matches.endMatchWith(id);
          },
        ),
);

final quizRepositoryProvider = Provider<QuizRepository>(
  (ref) => Env.hasSupabase
      ? SupabaseQuizRepository(Supabase.instance.client)
      : demoQuizRepository(
          ref,
          loadBank: () async => QuizBank.fromJson(
            // Ohne Cache: der Katalog wird pro Sitzung nur einmal geladen.
            await rootBundle.loadString(
              'assets/quiz/questions.json',
              cache: false,
            ),
          ),
        ),
);

/// Demo-Quiz: mein Team besteht aus mir und dem Demo-Match.
DemoQuizRepository demoQuizRepository(
  Ref ref, {
  required Future<QuizBank> Function() loadBank,
}) {
  String me() => ref.read(authRepositoryProvider).currentUser?.id ?? 'me';
  return DemoQuizRepository(
    loadBank: loadBank,
    myUserId: me,
    teamFor: (matchId) {
      for (final m in demoMatches) {
        if (m.id != matchId) continue;
        return QuizTeam(
          matchId: m.id,
          players: [
            QuizPlayer(id: me(), name: demoMyName, isMe: true),
            QuizPlayer(id: m.profile.id, name: m.profile.name),
          ],
        );
      }
      return null;
    },
  );
}
