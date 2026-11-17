/// Profil-Entwurf aus dem Onboarding und seine Regeln (ohne Flutter-Abhängigkeit).
library;

import '../location/approx_location.dart';
import '../profile/profile_basics.dart';
import '../profile/profile_prompts.dart';

/// Muss zum CHECK auf `profiles.gender` / `profiles.interested_in` passen.
enum Gender {
  woman('woman', 'Frau', 'Frauen'),
  man('man', 'Mann', 'Männer'),
  nonbinary('nonbinary', 'Nicht-binär', 'Nicht-binäre Menschen');

  const Gender(this.dbValue, this.label, this.pluralLabel);

  final String dbValue;
  final String label;
  final String pluralLabel;
}

const minAge = 18;
const maxDisplayNameLength = 40;
const maxBioLength = 500;
const maxCityLength = 80;

/// Alter in ganzen Jahren an einem Stichtag.
int ageOn(DateTime birthdate, DateTime today) {
  var age = today.year - birthdate.year;
  final hadBirthday =
      today.month > birthdate.month ||
      (today.month == birthdate.month && today.day >= birthdate.day);
  if (!hadBirthday) age--;
  return age;
}

/// Liest „TT.MM.JJJJ“. Gibt `null` zurück, wenn das kein gültiges Datum ist.
DateTime? parseGermanDate(String input) {
  final match = RegExp(r'^\s*(\d{1,2})\.(\d{1,2})\.(\d{4})\s*$')
      .firstMatch(input);
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  // DateTime rechnet z. B. 31.02. still in den März um – das wollen wir nicht.
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

String? validateDisplayName(String? value) {
  final name = value?.trim() ?? '';
  if (name.isEmpty) return 'Wie sollen dich andere nennen?';
  if (name.length > maxDisplayNameLength) {
    return 'Höchstens $maxDisplayNameLength Zeichen.';
  }
  return null;
}

String? validateBirthdate(String? value, {required DateTime today}) {
  if (value == null || value.trim().isEmpty) {
    return 'Bitte gib dein Geburtsdatum ein.';
  }
  final date = parseGermanDate(value);
  if (date == null) return 'Bitte im Format TT.MM.JJJJ, z. B. 24.05.1998.';
  if (date.isAfter(today)) return 'Das Datum liegt in der Zukunft.';
  final age = ageOn(date, today);
  if (age < minAge) return 'Lovel ist erst ab $minAge Jahren.';
  if (age > 120) return 'Bitte prüfe das Jahr.';
  return null;
}

class ProfileDraft {
  String displayName = '';
  DateTime? birthdate;
  Gender? gender;
  final Set<Gender> interestedIn = {};

  /// Ausdrückliche Einwilligung nach Art. 9 Abs. 2 lit. a DSGVO.
  DateTime? sensitiveConsentAt;
  String city = '';
  String bio = '';

  /// Ungefährer Standort fürs Matching (optional, später nachholbar).
  ApproxLocation? location;

  /// Steckbrief, alles freiwillig.
  ProfileBasics basics = const ProfileBasics();

  /// Genau drei beantwortete Fragen, in Anzeige-Reihenfolge.
  List<PromptAnswer> prompts = [];

  bool get isComplete =>
      validateDisplayName(displayName) == null &&
      birthdate != null &&
      gender != null &&
      interestedIn.isNotEmpty &&
      sensitiveConsentAt != null &&
      validatePromptSelection(prompts) == null;

  /// Spalten für `insert into profiles` (ohne `id`).
  Map<String, Object?> toInsertJson() {
    if (!isComplete) {
      throw StateError('Profil ist noch nicht vollständig.');
    }
    final b = birthdate!;
    String two(int n) => n.toString().padLeft(2, '0');
    return {
      'display_name': displayName.trim(),
      'birthdate': '${b.year}-${two(b.month)}-${two(b.day)}',
      'gender': gender!.dbValue,
      'interested_in': [
        for (final g in Gender.values)
          if (interestedIn.contains(g)) g.dbValue,
      ],
      'sensitive_consent_at': sensitiveConsentAt!.toUtc().toIso8601String(),
      'city': city.trim().isEmpty ? null : city.trim(),
      'bio': bio.trim(),
      ...basics.toJson(),
      if (location != null) 'location': location!.toEwkt(),
    };
  }

  /// Zeilen für `insert into profile_prompts` (ohne `profile_id`).
  List<Map<String, Object?>> promptRows() => [
    for (var i = 0; i < prompts.length; i++)
      {
        'position': i,
        'prompt_key': prompts[i].promptKey,
        'answer': prompts[i].answer.trim(),
      },
  ];
}
