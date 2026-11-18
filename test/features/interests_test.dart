import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lovelapp/features/interests/interest_catalog.dart';
import 'package:lovelapp/features/interests/profile_extras.dart';

void main() {
  group('Interessen-Katalog', () {
    test('Schlüssel eindeutig, gültig und mit Emoji', () {
      final keys = <String>{};
      final keyFormat = RegExp(r'^[a-z_]{2,20}\.[a-z0-9_]{2,40}$');
      for (final c in interestCategories) {
        expect(c.items.length, greaterThanOrEqualTo(15), reason: c.label);
        for (final i in c.items) {
          expect(keys.add(i.key), isTrue, reason: 'doppelt: ${i.key}');
          expect(keyFormat.hasMatch(i.key), isTrue, reason: i.key);
          expect(i.category, c.key);
          expect(i.emoji.runes.any((r) => r > 0x2000), isTrue, reason: i.key);
          expect(i.label.trim(), isNotEmpty);
        }
      }
      expect(keys.length, greaterThan(400));
    });

    test('Kategorien stimmen mit der Datenbank überein', () {
      final sql = File(
        'supabase/migrations/20261117220713_interests_games_music.sql',
      ).readAsStringSync();
      final block = RegExp(
        r'select array\[(.*?)\];',
        dotAll: true,
      ).firstMatch(sql)!.group(1)!;
      final dbCategories = RegExp(r"'([a-z_]+)'")
          .allMatches(block)
          .map((m) => m.group(1))
          .toSet();
      expect(dbCategories, {for (final c in interestCategories) c.key});
    });

    test('Suche ignoriert Groß-/Kleinschreibung und Umlaute', () {
      expect(searchInterests('BOULDERN').map((i) => i.key), [
        'sports.bouldern',
      ]);
      expect(
        searchInterests('gaertnern').map((i) => i.key),
        contains('hobbies.gaertnern'),
      );
      expect(
        searchInterests('Märkte').map((i) => i.key),
        contains('going_out.flohmarkt_besuche'),
      );
      expect(searchInterests('jazz', category: 'books'), isEmpty);
    });

    test('Höchstens drei pro Kategorie', () {
      expect(
        validateInterests(['music.jazz', 'music.rock', 'books.krimi']),
        isNull,
      );
      expect(
        validateInterests([
          'music.jazz',
          'music.rock',
          'music.pop',
          'music.indie',
        ]),
        contains('Musikgeschmack'),
      );
      expect(validateInterests(['music.gibtsnicht']), isNotNull);
    });
  });

  test('Extras werden nach Profil gruppiert und sortiert', () {
    final grouped = groupExtras(
      interestRows: [
        {'profile_id': 'a', 'interest_key': 'music.rock'},
        {'profile_id': 'a', 'interest_key': 'books.krimi'},
      ],
      gameRows: [
        {'profile_id': 'a', 'position': 1, 'rawg_id': 2, 'name': 'Zwei'},
        {'profile_id': 'a', 'position': 0, 'rawg_id': 1, 'name': 'Eins'},
      ],
      artistRows: [
        {
          'profile_id': 'b',
          'position': 0,
          'spotify_id': 'abc1234567',
          'name': 'Band',
          'image_url': null,
        },
      ],
    );
    expect(grouped['a']!.interests, ['books.krimi', 'music.rock']);
    expect(grouped['a']!.games.map((g) => g.name), ['Eins', 'Zwei']);
    expect(
      grouped['b']!.artists.single.spotifyUrl,
      'https://open.spotify.com/artist/abc1234567',
    );
  });
}
