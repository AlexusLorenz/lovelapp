import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../session/session_controller.dart';

/// `true`, solange die App über einen Passwort-Link geöffnet wurde und noch
/// kein neues Passwort gesetzt ist. Der Router schickt dann zur Eingabe.
class PasswordRecovery extends Notifier<bool> {
  StreamSubscription<void>? _sub;

  @override
  bool build() {
    _sub = ref
        .watch(authRepositoryProvider)
        .passwordRecoveries()
        .listen((_) => state = true);
    ref.onDispose(() => _sub?.cancel());
    return false;
  }

  void done() => state = false;
}

final passwordRecoveryProvider = NotifierProvider<PasswordRecovery, bool>(
  PasswordRecovery.new,
);
