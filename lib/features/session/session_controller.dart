import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../auth/auth_repository.dart';
import '../auth/supabase_auth_repository.dart';
import '../onboarding/profile_repository.dart';
import '../onboarding/supabase_profile_repository.dart';

/// Echte Repositories mit Supabase, sonst Demo-Modus.
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

enum SessionStatus {
  /// Prüft gerade, ob es schon ein Profil gibt.
  loading,

  /// Konnte den Stand nicht laden (z. B. offline).
  error,

  signedOut,

  /// Angemeldet, aber Onboarding noch nicht abgeschlossen.
  needsProfile,

  ready,
}

class SessionState {
  const SessionState(this.status, {this.user});

  final SessionStatus status;
  final AppUser? user;
}

/// Wer ist angemeldet, und ist das Profil fertig? Steuert die Weiterleitung.
class SessionController extends Notifier<SessionState> {
  StreamSubscription<AppUser?>? _subscription;

  @override
  SessionState build() {
    final auth = ref.watch(authRepositoryProvider);
    _subscription = auth.authStateChanges().listen(_resolve);
    ref.onDispose(() => _subscription?.cancel());

    final user = auth.currentUser;
    if (user == null) return const SessionState(SessionStatus.signedOut);
    Future.microtask(() => _resolve(user));
    return SessionState(SessionStatus.loading, user: user);
  }

  Future<void> _resolve(AppUser? user) async {
    if (user == null) {
      state = const SessionState(SessionStatus.signedOut);
      return;
    }
    // Gleicher Nutzer und schon fertig geladen? Dann nichts tun
    // (z. B. bei automatischer Token-Erneuerung).
    if (state.user?.id == user.id &&
        (state.status == SessionStatus.ready ||
            state.status == SessionStatus.needsProfile)) {
      return;
    }
    state = SessionState(SessionStatus.loading, user: user);
    try {
      final hasProfile = await ref
          .read(profileRepositoryProvider)
          .hasOwnProfile(user.id);
      if (state.user?.id != user.id) return; // inzwischen abgemeldet
      state = SessionState(
        hasProfile ? SessionStatus.ready : SessionStatus.needsProfile,
        user: user,
      );
    } on Exception {
      if (state.user?.id != user.id) return;
      state = SessionState(SessionStatus.error, user: user);
    }
  }

  /// Nach dem Onboarding oder nach einem Fehler neu prüfen.
  Future<void> reload() async {
    final user = state.user;
    state = SessionState(SessionStatus.loading, user: user);
    await _resolve(user);
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(
  SessionController.new,
);
