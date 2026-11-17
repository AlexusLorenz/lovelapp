/// Profil-Fragen: Jede Person kann bis zu drei Fragen aus einem Katalog
/// beantworten – freiwillig (ohne Flutter-Abhängigkeit).
///
/// Die Schlüssel landen in `profile_prompts.prompt_key` – nie umbenennen,
/// nur neue hinzufügen.
library;

class ProfilePrompt {
  const ProfilePrompt(this.key, this.question);

  final String key;
  final String question;
}

const promptsPerProfile = 3;
const maxPromptAnswerLength = 150;

const promptCatalog = [
  ProfilePrompt('perfect_sunday', 'Mein perfekter Sonntag …'),
  ProfilePrompt('game_loser', 'Bei diesem Spiel verliere ich am liebsten:'),
  ProfilePrompt('green_flag', 'Eine Green Flag bei dir wäre …'),
  ProfilePrompt('unpopular_opinion', 'Meine unpopuläre Meinung:'),
  ProfilePrompt('first_date', 'Mein Lieblings-erstes-Date:'),
  ProfilePrompt('cant_live_without', 'Ohne das gehe ich nicht aus dem Haus:'),
  ProfilePrompt('nerd_about', 'Darüber könnte ich stundenlang reden:'),
  ProfilePrompt('travel_story', 'Meine beste Reisegeschichte:'),
  ProfilePrompt('song_on_repeat', 'Dieser Song läuft gerade in Dauerschleife:'),
  ProfilePrompt('guilty_pleasure', 'Mein Guilty Pleasure:'),
  ProfilePrompt('looking_for', 'Ich suche jemanden, der …'),
  ProfilePrompt('two_truths', 'Zwei Wahrheiten und eine Lüge:'),
  ProfilePrompt('weekend_plan', 'Am Wochenende findet man mich …'),
  ProfilePrompt('cook_for_you', 'Wenn ich für dich koche, gibt es …'),
  ProfilePrompt('superpower', 'Meine heimliche Superkraft:'),
];

ProfilePrompt? promptByKey(String key) {
  for (final p in promptCatalog) {
    if (p.key == key) return p;
  }
  return null;
}

class PromptAnswer {
  const PromptAnswer(this.promptKey, this.answer);

  final String promptKey;
  final String answer;

  /// Fragetext; bei unbekanntem Schlüssel (ältere App-Version) leer.
  String get question => promptByKey(promptKey)?.question ?? '';
}

String? validatePromptAnswer(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Bitte beantworte die Frage.';
  if (text.length > maxPromptAnswerLength) {
    return 'Höchstens $maxPromptAnswerLength Zeichen.';
  }
  return null;
}

/// Prüft eine Auswahl: höchstens drei verschiedene, beantwortete Fragen.
/// Keine Frage ist auch in Ordnung.
String? validatePromptSelection(List<PromptAnswer> answers) {
  if (answers.length > promptsPerProfile) {
    return 'Höchstens $promptsPerProfile Fragen.';
  }
  final keys = answers.map((a) => a.promptKey).toSet();
  if (keys.length != answers.length) return 'Jede Frage nur einmal, bitte.';
  if (keys.any((k) => promptByKey(k) == null)) return 'Unbekannte Frage.';
  for (final a in answers) {
    final error = validatePromptAnswer(a.answer);
    if (error != null) return error;
  }
  return null;
}
