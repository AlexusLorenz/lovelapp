import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_controller.dart';
import 'profile_extras.dart';

export 'profile_extras.dart';

/// Interessen, Spiele und Musik eines Profils (auch des eigenen).
final profileExtrasProvider = FutureProvider.family<ProfileExtras, String>((
  ref,
  profileId,
) async {
  ref.watch(currentUserIdProvider);
  final all = await ref.read(extrasRepositoryProvider).fetchFor([profileId]);
  return all[profileId] ?? ProfileExtras.empty;
});

/// Eigene Extras; `null`, solange niemand angemeldet ist.
final ownExtrasProvider = FutureProvider<ProfileExtras?>((ref) async {
  final id = ref.watch(currentUserIdProvider);
  if (id == null) return null;
  return ref.watch(profileExtrasProvider(id).future);
});
