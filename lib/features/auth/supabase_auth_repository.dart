import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';

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
      () => _auth.signUp(
        email: email.trim(),
        password: password,
        emailRedirectTo: Env.authCallbackUrl,
      ),
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
  Future<void> signInWithProvider(SocialProvider provider) async {
    final opened = await _guard(
      () => _auth.signInWithOAuth(
        switch (provider) {
          SocialProvider.apple => OAuthProvider.apple,
          SocialProvider.google => OAuthProvider.google,
        },
        // Im Browser zurück auf dieselbe Seite, in der App per Deep Link.
        redirectTo: Env.authCallbackUrl,
      ),
    );
    if (!opened) {
      throw AuthFailure(
        'Die Anmeldung mit ${provider.label} konnte nicht geöffnet werden.',
      );
    }
  }

  @override
  Future<void> sendLoginLink(String email) => _guard(
    () => _auth.signInWithOtp(
      email: email.trim(),
      emailRedirectTo: Env.authCallbackUrl,
      shouldCreateUser: false, // nur bestehende/eingeladene Konten
    ),
  );

  @override
  Future<void> signOut() => _guard(_auth.signOut);

  @override
  Future<void> sendPasswordReset(String email) => _guard(
    () => _auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: Env.authCallbackUrl,
    ),
  );

  @override
  Stream<void> passwordRecoveries() => _auth.onAuthStateChange
      .where((s) => s.event == AuthChangeEvent.passwordRecovery)
      .map((_) {});

  @override
  Future<void> updatePassword(String newPassword) =>
      _guard(() => _auth.updateUser(UserAttributes(password: newPassword)));

  @override
  bool get hasPasswordLogin =>
      _auth.currentUser?.identities?.any((i) => i.provider == 'email') ?? false;

  @override
  Future<void> deleteAccount() => _guard(() async {
    final me = _auth.currentUser?.id;
    if (me == null) return;
    // Fotodateien zuerst (SQL darf Storage nicht direkt löschen).
    final bucket = _client.storage.from('profile-photos');
    final files = await bucket.list(path: me);
    if (files.isNotEmpty) {
      await bucket.remove([for (final f in files) '$me/${f.name}']);
    }
    await _client.rpc<void>('delete_own_account');
    // Lokale Sitzung verwerfen; der Server kennt das Konto nicht mehr.
    await _auth.signOut(scope: SignOutScope.local);
  });

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
    case 'otp_disabled':
      return 'Lovel ist gerade in einer geschlossenen Testphase – '
          'Anmeldung nur mit Einladung.';
  }
  return 'Das hat nicht geklappt. Bitte versuch es noch einmal.';
}
