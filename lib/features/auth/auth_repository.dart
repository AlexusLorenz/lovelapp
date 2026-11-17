import 'dart:async';

/// Angemeldete Person (nur, was die App braucht).
class AppUser {
  const AppUser({required this.id, required this.email});

  final String id;
  final String? email;
}

enum SignUpOutcome {
  /// Konto angelegt und direkt angemeldet.
  signedIn,

  /// Konto angelegt, aber erst nach Klick auf den Link in der E-Mail nutzbar.
  confirmEmail,
}

/// Fehler mit einer Meldung, die man so anzeigen kann.
class AuthFailure implements Exception {
  const AuthFailure(this.message);

  final String message;

  @override
  String toString() => 'AuthFailure: $message';
}

abstract interface class AuthRepository {
  AppUser? get currentUser;

  /// Meldet jede Änderung (Anmelden, Abmelden, Sitzung abgelaufen).
  Stream<AppUser?> authStateChanges();

  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  });

  Future<void> signIn({required String email, required String password});

  Future<void> signOut();
}

/// Demo-Modus: alles nur im Speicher, jede Eingabe wird akzeptiert.
class DemoAuthRepository implements AuthRepository {
  DemoAuthRepository({AppUser? signedInAs}) : _user = signedInAs;

  AppUser? _user;
  final _controller = StreamController<AppUser?>.broadcast();

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AppUser?> authStateChanges() => _controller.stream;

  void _set(AppUser? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    _set(
      AppUser(id: 'demo-${email.trim().toLowerCase()}', email: email.trim()),
    );
    return SignUpOutcome.signedIn;
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    _set(
      AppUser(id: 'demo-${email.trim().toLowerCase()}', email: email.trim()),
    );
  }

  @override
  Future<void> signOut() async => _set(null);
}
