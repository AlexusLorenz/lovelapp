import 'package:flutter/foundation.dart';

/// Build-Zeit-Konfiguration.
///
/// Werte werden per `--dart-define` übergeben, für das echte Projekt am
/// einfachsten mit: `flutter run --dart-define-from-file=config/supabase.json`
///
/// Ohne diese Werte startet die App im Demo-Modus mit lokalen Beispieldaten.
class Env {
  const Env._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabasePublishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;

  /// „Mit Apple fortfahren“ anzeigen? Erst einschalten, wenn Apple in
  /// Supabase eingerichtet ist (Apple-Developer-Konto). Im Demo-Modus immer.
  static bool get appleLoginEnabled =>
      !hasSupabase || const bool.fromEnvironment('APPLE_LOGIN');

  /// Geschlossene Testphase: keine offene Registrierung, Anmeldung nur für
  /// eingeladene Personen (in Supabase „Allow new users to sign up“ aus).
  static const inviteOnly = bool.fromEnvironment('INVITE_ONLY');

  /// Wohin Supabase nach Login-Link, Google/Apple usw. zurückleitet:
  /// im Browser auf die aktuelle Seite, in der App per Deep Link.
  static String get authCallbackUrl {
    if (!kIsWeb) return authRedirectUrl;
    final base = Uri.base;
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: base.path,
    ).toString();
  }

  /// Rücksprung nach Google-/Apple-Login in die App (Deep Link).
  /// Muss in Supabase unter Authentication → URL Configuration →
  /// Redirect URLs eingetragen sein, ebenso in AndroidManifest/Info.plist.
  static const authRedirectUrl = 'de.lovelapp.lovelapp://login-callback';

  /// Client-ID der Spotify-App (öffentlich, kein Geheimnis). Leer = die
  /// Spotify-Verbindung wird nicht angeboten; die Suche läuft trotzdem.
  static const spotifyClientId = String.fromEnvironment('SPOTIFY_CLIENT_ID');

  /// Spotify-Login gibt es vorerst nur in der Web-App.
  static bool get spotifyConnectEnabled => kIsWeb && spotifyClientId.isNotEmpty;

  /// Rücksprungseite nach dem Spotify-Login (web/spotify-callback.html).
  /// Muss so im Spotify-Developer-Dashboard als Redirect URI stehen.
  static String get spotifyRedirectUrl =>
      Uri.parse(authCallbackUrl).resolve('spotify-callback.html').toString();
}
