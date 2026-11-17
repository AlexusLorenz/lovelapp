/// Level- und XP-System.
///
/// XP belohnt gutes Verhalten (antworten, Spiele zu Ende spielen, Profil
/// vervollständigen) – nicht endloses Swipen. Vergeben werden XP nur
/// serverseitig (Tabelle `xp_events`); diese Datei rechnet nur für die Anzeige.
///
/// Kurve: Für Level n braucht man insgesamt 50 · n · (n − 1) XP.
/// Level 1 = 0 XP, Level 2 = 100, Level 3 = 300, Level 4 = 600, …
class LevelProgress {
  const LevelProgress._(this.xp, this.level);

  factory LevelProgress.fromXp(int xp) {
    if (xp < 0) xp = 0;
    var level = 1;
    while (xpForLevel(level + 1) <= xp) {
      level++;
    }
    return LevelProgress._(xp, level);
  }

  static int xpForLevel(int level) => 50 * level * (level - 1);

  final int xp;
  final int level;

  int get currentLevelXp => xpForLevel(level);
  int get nextLevelXp => xpForLevel(level + 1);
  int get xpIntoLevel => xp - currentLevelXp;
  int get xpNeededForNext => nextLevelXp - xp;

  /// Fortschritt innerhalb des aktuellen Levels, 0.0 bis < 1.0.
  double get fraction => xpIntoLevel / (nextLevelXp - currentLevelXp);
}

/// Gründe für XP – muss zur Tabelle `xp_rewards` in der Datenbank passen.
enum XpReason {
  profileCompleted('profile_completed', 50, 'Profil vervollständigt'),
  photoVerified('photo_verified', 50, 'Foto verifiziert'),
  repliedToMessage('replied_to_message', 5, 'Auf Nachricht geantwortet'),
  gameFinished('game_finished', 20, 'Minispiel zu Ende gespielt'),
  dailyQuest('daily_quest', 15, 'Tagesaufgabe erledigt');

  const XpReason(this.key, this.amount, this.label);

  final String key;
  final int amount;
  final String label;
}
