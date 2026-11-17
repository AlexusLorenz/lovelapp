import 'package:flutter_test/flutter_test.dart';
import 'package:lovelapp/features/discover/public_profile.dart';
import 'package:lovelapp/features/location/approx_location.dart';
import 'package:lovelapp/features/profile/profile_basics.dart';

void main() {
  test('Standort wird auf ~1 km gerundet und als EWKT gespeichert', () {
    final l = ApproxLocation.rounded(51.339712, 12.373118);
    expect(l.latitude, 51.34);
    expect(l.longitude, 12.37);
    expect(l.toEwkt(), 'SRID=4326;POINT(12.37 51.34)');
  });

  test('PublicProfile aus RPC-Zeile', () {
    final p = PublicProfile.fromRow({
      'id': 'x',
      'display_name': 'Mia',
      'age': 27,
      'bio': null,
      'city': 'Leipzig',
      'distance_km': 3,
      'level': 4,
      'smoking': 'never',
      'height_cm': 168,
    });
    expect(p.name, 'Mia');
    expect(p.bio, '');
    expect(p.locationLabel, 'Leipzig · 3 km');
    expect(p.basics.smoking, Smoking.never);
    expect(p.basics.heightCm, 168);
    expect(p.photos, isEmpty);
  });

  test('ohne Entfernung nur die Stadt', () {
    final p = PublicProfile.fromRow({
      'id': 'x',
      'display_name': 'Ben',
      'age': 30,
      'city': 'Halle',
    });
    expect(p.locationLabel, 'Halle');
    expect(p.level, 1);
  });

  test('Fragen werden je Profil nach Position sortiert', () {
    final grouped = groupPromptRows([
      {
        'profile_id': 'a',
        'position': 2,
        'prompt_key': 'superpower',
        'answer': 'C',
      },
      {
        'profile_id': 'a',
        'position': 0,
        'prompt_key': 'perfect_sunday',
        'answer': 'A',
      },
      {
        'profile_id': 'b',
        'position': 0,
        'prompt_key': 'green_flag',
        'answer': 'X',
      },
      {
        'profile_id': 'a',
        'position': 1,
        'prompt_key': 'green_flag',
        'answer': 'B',
      },
    ]);
    expect(grouped['a']!.map((p) => p.answer), ['A', 'B', 'C']);
    expect(grouped['b']!.single.question, 'Eine Green Flag bei dir wäre …');
  });
}
