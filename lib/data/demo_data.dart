/// Lokale Beispieldaten für den Demo-Modus (ohne Supabase).
library;

class DemoProfile {
  const DemoProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.city,
    required this.distanceKm,
    required this.bio,
    required this.level,
    this.likesYouBack = false,
  });

  final String id;
  final String name;
  final int age;
  final String city;
  final int distanceKm;
  final String bio;
  final int level;

  /// Nur Demo: Würde dieses Profil zurückliken?
  final bool likesYouBack;
}

class DemoMatch {
  const DemoMatch({
    required this.id,
    required this.profile,
    required this.lastMessage,
    this.gamePending = false,
  });

  final String id;
  final DemoProfile profile;
  final String lastMessage;
  final bool gamePending;
}

const demoProfiles = [
  DemoProfile(
    id: 'p1',
    name: 'Mia',
    age: 27,
    city: 'Leipzig',
    distanceKm: 3,
    bio: 'Bouldern, Brettspiele und zu viele Zimmerpflanzen.',
    level: 4,
    likesYouBack: true,
  ),
  DemoProfile(
    id: 'p2',
    name: 'Jonas',
    age: 30,
    city: 'Leipzig',
    distanceKm: 7,
    bio: 'Hobbykoch. Ich verliere gern bei Mario Kart.',
    level: 2,
  ),
  DemoProfile(
    id: 'p3',
    name: 'Sara',
    age: 25,
    city: 'Leipzig',
    distanceKm: 1,
    bio: 'Fotografin, Kaffee-Snob, immer für einen Spieleabend zu haben.',
    level: 6,
    likesYouBack: true,
  ),
  DemoProfile(
    id: 'p4',
    name: 'Lukas',
    age: 29,
    city: 'Halle',
    distanceKm: 32,
    bio: 'Läuft Halbmarathons, isst danach doppelt so viel.',
    level: 3,
  ),
];

final demoMatches = [
  DemoMatch(
    id: 'm1',
    profile: demoProfiles[0],
    lastMessage: 'Okay, Revanche bei This or That?',
    gamePending: true,
  ),
  DemoMatch(
    id: 'm2',
    profile: demoProfiles[2],
    lastMessage: 'Haha, Meer natürlich!',
  ),
];
