import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../session/session_controller.dart';
import 'push_repository.dart';

export 'push_repository.dart';

final pushRepositoryProvider = Provider<PushRepository>(
  (ref) => Env.hasSupabase
      ? SupabasePushRepository(Supabase.instance.client)
      : const DemoPushRepository(),
);

/// Push an diesem Gerät für das angemeldete Konto.
class PushController extends AsyncNotifier<PushStatus> {
  @override
  Future<PushStatus> build() async {
    if (ref.watch(currentUserIdProvider) == null) return PushStatus.off;
    try {
      return await ref.read(pushRepositoryProvider).status();
    } on Exception {
      return PushStatus.off;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    final repo = ref.read(pushRepositoryProvider);
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => enabled ? repo.enable() : repo.disable(),
    );
  }
}

final pushProvider = AsyncNotifierProvider<PushController, PushStatus>(
  PushController.new,
);

/// Vor dem Abmelden: dieses Gerät abmelden, damit das nächste Konto auf dem
/// Gerät keine fremden Benachrichtigungen bekommt.
Future<void> signOutWithPush(WidgetRef ref) async {
  try {
    if (ref.read(pushProvider).value == PushStatus.on) {
      await ref.read(pushRepositoryProvider).disable();
    }
  } on Exception {
    // Abmelden geht immer vor.
  }
  await ref.read(authRepositoryProvider).signOut();
}
