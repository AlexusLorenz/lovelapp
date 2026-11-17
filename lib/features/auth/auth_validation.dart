/// Eingabeprüfung für Anmeldung und Registrierung (ohne Flutter-Abhängigkeit).
library;

/// Muss zur Einstellung „Minimum password length“ in Supabase passen.
const minPasswordLength = 10;

final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

/// Gibt eine Fehlermeldung zurück oder `null`, wenn alles passt.
String? validateEmail(String? value) {
  final email = value?.trim() ?? '';
  if (email.isEmpty) return 'Bitte gib deine E-Mail-Adresse ein.';
  if (!_emailPattern.hasMatch(email)) {
    return 'Das sieht nicht nach einer E-Mail-Adresse aus.';
  }
  return null;
}

String? validatePassword(String? value) {
  final password = value ?? '';
  if (password.isEmpty) return 'Bitte wähle ein Passwort.';
  if (password.length < minPasswordLength) {
    return 'Mindestens $minPasswordLength Zeichen.';
  }
  if (password.trim() != password) {
    return 'Bitte keine Leerzeichen am Anfang oder Ende.';
  }
  return null;
}

String? validatePasswordRepeat(String? value, String password) {
  if ((value ?? '') != password) return 'Die Passwörter stimmen nicht überein.';
  return null;
}
