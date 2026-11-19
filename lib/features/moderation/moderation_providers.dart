import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../session/session_controller.dart';
import 'moderation_repository.dart';

export 'moderation_repository.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>(
  (ref) => Env.hasSupabase
      ? SupabaseModerationRepository(Supabase.instance.client)
      : const DemoModerationRepository(),
);

/// Ist das angemeldete Konto Admin? (Nur für die Anzeige; der Server prüft.)
final isAdminProvider = FutureProvider<bool>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return false;
  try {
    return await ref.read(moderationRepositoryProvider).isAdmin();
  } on Exception {
    return false;
  }
});

/// Nur offene oder alle Meldungen anzeigen?
final modOnlyOpenProvider = NotifierProvider<_Flag, bool>(() => _Flag(true));

/// Test-Konten in den Kennzahlen mitzählen?
final modIncludeTestProvider = NotifierProvider<_Flag, bool>(
  () => _Flag(false),
);

class _Flag extends Notifier<bool> {
  _Flag(this._initial);
  final bool _initial;

  @override
  bool build() => _initial;

  void set(bool value) => state = value;
}

final modReportsProvider = FutureProvider<List<ModReport>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref
      .read(moderationRepositoryProvider)
      .reports(onlyOpen: ref.watch(modOnlyOpenProvider));
});

final modStatsProvider = FutureProvider<Map<String, Object?>>((ref) {
  ref.watch(currentUserIdProvider);
  return ref
      .read(moderationRepositoryProvider)
      .stats(includeTest: ref.watch(modIncludeTestProvider));
});
