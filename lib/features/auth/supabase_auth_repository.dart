import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  static AppUser? _map(User? user) =>
      user == null ? null : AppUser(id: user.id, email: user.email);

  @override
  AppUser? get currentUser => _map(_auth.currentUser);

  @override
  Stream<AppUser?> authStateChanges() =>
      _auth.onAuthStateChange.map((state) => _map(state.session?.user));

  @override
  Future<SignUpOutcome> signUp({
    required String email,
    required String password,
  }) async {
    final response = await _guard(
      () => _auth.signUp(email: email.trim(), password: password),
    );
    // Ohne Sitzung muss erst die E-Mail bestätigt werden. Das gilt auch, wenn
    // es die Adresse schon gibt – Supabase verrät das absichtlich nicht.
    return response.session == null
        ? SignUpOutcome.confirmEmail
        : SignUpOutcome.signedIn;
  }

  @override
  Future<void> signIn({required String email, required String password}) =>
      _guard(
        () => _auth.signInWithPassword(email: email.trim(), password: password),
      );

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on AuthException catch (e) {
      throw AuthFailure(messageForAuthError(e.code, e.statusCode));
    } on Exception {
      throw const AuthFailure(
        'Keine Verbindung zum Server. Bitte prüfe dein Internet.',
      );
    }
  }
}

/// Übersetzt Supabase-Fehlercodes in verständliche Meldungen.
String messageForAuthError(String? code, String? statusCode) {
  switch (code) {
    case 'invalid_credentials':
      return 'E-Mail oder Passwort stimmt nicht.';
    case 'email_not_confirmed':
      return 'Bitte bestätige zuerst deine E-Mail-Adresse.';
    case 'user_already_exists':
    case 'email_exists':
      return 'Mit dieser E-Mail gibt es schon ein Konto.';
    case 'weak_password':
      return 'Das Passwort ist zu schwach. Nimm ein längeres oder '
          'mische Buchstaben, Ziffern und Zeichen.';
    case 'email_address_invalid':
      return 'Diese E-Mail-Adresse wird nicht akzeptiert.';
    case 'over_email_send_rate_limit':
    case 'over_request_rate_limit':
      return 'Zu viele Versuche. Bitte warte kurz und probier es dann noch mal.';
    case 'signup_disabled':
      return 'Registrierungen sind gerade geschlossen.';
  }
  return 'Das hat nicht geklappt. Bitte versuch es noch einmal.';
}
