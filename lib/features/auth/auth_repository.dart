import 'dart:async';

/// Angemeldete Person (nur, was die App braucht).
class AppUser {
  const AppUser({required this.id, required this.email});

  final String id;
  final String? email;
}

/// Anmeldung über einen externen Anbieter.
enum SocialProvider {
  apple('Apple'),
  google('Google');

  const SocialProvider(this.label);
  final String label;
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

  /// Öffnet die Anmeldeseite des Anbieters. Die Sitzung kommt danach über
  /// [authStateChanges] (Rücksprung per Deep Link).
  Future<void> signInWithProvider(SocialProvider provider);

  /// Schickt einen Login-Link per E-Mail (nur für bestehende Konten).
  Future<void> sendLoginLink(String email);

  Future<void> signOut();

  /// Schickt einen Link zum Zurücksetzen des Passworts.
  Future<void> sendPasswordReset(String email);

  /// Meldet, wenn die App über einen Passwort-Link geöffnet wurde.
  Stream<void> passwordRecoveries();

  /// Neues Passwort für das angemeldete Konto.
  Future<void> updatePassword(String newPassword);

  /// Löscht das eigene Konto mit allen Daten und meldet ab.
  Future<void> deleteAccount();

  /// Hat das Konto ein Passwort (E-Mail-Login) oder nur Google/Apple?
  bool get hasPasswordLogin;
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
  Future<void> signInWithProvider(SocialProvider provider) async {
    final email = 'demo-${provider.name}@lovel.app';
    _set(AppUser(id: 'demo-$email', email: email));
  }

  @override
  Future<void> sendLoginLink(String email) async {}

  @override
  Future<void> signOut() async => _set(null);

  final _recoveries = StreamController<void>.broadcast();

  /// Für Tests: so tun, als käme die App über einen Passwort-Link.
  void simulatePasswordRecovery() => _recoveries.add(null);

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Stream<void> passwordRecoveries() => _recoveries.stream;

  @override
  Future<void> updatePassword(String newPassword) async {}

  /// Zuletzt gelöschtes Konto (für Tests).
  String? deletedUserId;

  @override
  Future<void> deleteAccount() async {
    deletedUserId = _user?.id;
    _set(null);
  }

  @override
  bool get hasPasswordLogin => true;
}
