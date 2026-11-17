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

  /// Rücksprung nach Google-/Apple-Login in die App (Deep Link).
  /// Muss in Supabase unter Authentication → URL Configuration →
  /// Redirect URLs eingetragen sein, ebenso in AndroidManifest/Info.plist.
  static const authRedirectUrl = 'de.lovelapp.lovelapp://login-callback';
}
