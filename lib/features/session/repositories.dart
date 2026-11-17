import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../auth/auth_repository.dart';
import '../auth/supabase_auth_repository.dart';
import '../discover/discover_repository.dart';
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
