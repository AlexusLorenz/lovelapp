import 'package:material_ui/material_ui.dart';

/// Ein Minispiel, das zwei Matches als Eisbrecher zusammen spielen können.
class MiniGame {
  const MiniGame({
    required this.key,
    required this.title,
    required this.tagline,
    required this.icon,
    this.available = false,
  });

  /// Stabiler Schlüssel, identisch mit `game_sessions.game_key` in der DB.
  final String key;
  final String title;
  final String tagline;
  final IconData icon;

  /// Im aktuellen Build spielbar?
  final bool available;
}

class GameCatalog {
  const GameCatalog._();

  static const thisOrThat = MiniGame(
    key: 'this_or_that',
    title: 'This or That',
    tagline: 'Wählt beide – wie ähnlich tickt ihr?',
    icon: Icons.compare_arrows,
    available: true,
  );

  static const twoTruthsOneLie = MiniGame(
    key: 'two_truths_one_lie',
    title: '2 Wahrheiten, 1 Lüge',
    tagline: 'Findest du die Lüge?',
    icon: Icons.psychology_alt,
  );

  static const quiz = MiniGame(
    key: 'quiz_about_me',
    title: 'Quiz über mich',
    tagline: 'Wie gut hast du das Profil gelesen?',
    icon: Icons.quiz,
  );

  static const all = [thisOrThat, twoTruthsOneLie, quiz];

  static MiniGame? byKey(String key) {
    for (final game in all) {
      if (game.key == key) return game;
    }
    return null;
  }
}
