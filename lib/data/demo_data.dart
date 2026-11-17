/// Lokale Beispieldaten für den Demo-Modus (ohne Supabase).
library;

import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import '../core/widgets/placeholder_photo.dart';
import '../features/discover/public_profile.dart';
import '../features/profile/profile_basics.dart';
import '../features/profile/profile_prompts.dart';

class DemoMatch {
  const DemoMatch({
    required this.id,
    required this.profile,
    required this.lastMessage,
    this.gamePending = false,
  });

  final String id;
  final PublicProfile profile;
  final String lastMessage;
  final bool gamePending;
}

/// Name des eigenen (Demo-)Profils, z. B. im Match-Overlay.
const demoMyName = 'Du';

/// Platzhalter fürs eigene Bild im Match-Overlay.
const demoMyPhoto = PhotoArt.portrait(
  skin: Color(0xFFE2B48C),
  hair: Color(0xFF4A3426),
  hairStyle: HairStyle.short,
  shirt: LovelColors.umber,
  background: LovelColors.mist,
);

const demoProfiles = [
  PublicProfile(
    id: 'p1',
    name: 'Mia',
    age: 27,
    city: 'Leipzig',
    distanceKm: 3,
    bio: 'Bouldern, Brettspiele und zu viele Zimmerpflanzen.',
    level: 4,
    likesYouBack: true,
    photos: [
      PhotoArt.portrait(
        skin: Color(0xFFF1CDB0),
        hair: Color(0xFF8A4B2A),
        hairStyle: HairStyle.long,
        shirt: LovelColors.terracotta,
        background: LovelColors.slate,
      ),
      PhotoArt.scene(PhotoMotif.plants),
      PhotoArt.scene(PhotoMotif.mountains),
    ],
    prompts: [
      PromptAnswer('perfect_sunday', 'Ausschlafen, Brunch, danach Bouldern.'),
      PromptAnswer('game_loser', 'Siedler. Ich baue immer nur Straßen.'),
      PromptAnswer('green_flag', 'Du gießt meine Pflanzen, wenn ich weg bin.'),
    ],
    basics: ProfileBasics(
      heightCm: 168,
      relationshipGoal: RelationshipGoal.longTerm,
      children: ChildrenPlan.wantSomeday,
      smoking: Smoking.never,
      drinking: Drinking.socially,
      exercise: Exercise.often,
    ),
  ),
  PublicProfile(
    id: 'p2',
    name: 'Jonas',
    age: 30,
    city: 'Leipzig',
    distanceKm: 7,
    bio: 'Hobbykoch. Ich verliere gern bei Mario Kart.',
    level: 2,
    photos: [
      PhotoArt.portrait(
        skin: Color(0xFFC68E63),
        hair: Color(0xFF2B1D16),
        hairStyle: HairStyle.curly,
        shirt: LovelColors.slate,
        background: LovelColors.blush,
      ),
      PhotoArt.scene(PhotoMotif.city),
      PhotoArt.scene(PhotoMotif.sea),
    ],
    prompts: [
      PromptAnswer('cook_for_you', 'Risotto. Und du rührst mit.'),
      PromptAnswer('unpopular_opinion', 'Ananas gehört auf Pizza.'),
      PromptAnswer('song_on_repeat', 'Irgendwas mit Synthesizern.'),
    ],
    basics: ProfileBasics(
      heightCm: 184,
      relationshipGoal: RelationshipGoal.openToAnything,
      smoking: Smoking.sometimes,
      drinking: Drinking.regularly,
      exercise: Exercise.sometimes,
    ),
  ),
  PublicProfile(
    id: 'p3',
    name: 'Sara',
    age: 25,
    city: 'Leipzig',
    distanceKm: 1,
    bio: 'Fotografin, Kaffee-Snob, immer für einen Spieleabend zu haben.',
    level: 6,
    likesYouBack: true,
    photos: [
      PhotoArt.portrait(
        skin: Color(0xFF8D5A3B),
        hair: Color(0xFF1E1410),
        hairStyle: HairStyle.bun,
        shirt: LovelColors.cream,
        background: LovelColors.terracotta,
      ),
      PhotoArt.scene(PhotoMotif.sea),
      PhotoArt.scene(PhotoMotif.city),
    ],
    prompts: [
      PromptAnswer('nerd_about', 'Analoge Kameras und warum Film besser ist.'),
      PromptAnswer('first_date', 'Flohmarkt, danach der beste Flat White.'),
      PromptAnswer('superpower', 'Ich finde in jeder Stadt das beste Café.'),
    ],
    basics: ProfileBasics(
      heightCm: 162,
      relationshipGoal: RelationshipGoal.unsure,
      children: ChildrenPlan.notSure,
      smoking: Smoking.never,
      drinking: Drinking.never,
      exercise: Exercise.rarely,
    ),
  ),
  PublicProfile(
    id: 'p4',
    name: 'Lukas',
    age: 29,
    city: 'Halle',
    distanceKm: 32,
    bio: 'Läuft Halbmarathons, isst danach doppelt so viel.',
    level: 3,
    photos: [
      PhotoArt.portrait(
        skin: Color(0xFFE8C4A0),
        hair: Color(0xFFC79A5B),
        hairStyle: HairStyle.short,
        shirt: LovelColors.terracotta,
        background: LovelColors.mist,
      ),
      PhotoArt.scene(PhotoMotif.mountains),
    ],
    prompts: [
      PromptAnswer('weekend_plan', 'Auf einer Laufstrecke oder beim Bäcker.'),
      PromptAnswer('looking_for', 'mit mir die Medaille feiert.'),
      PromptAnswer('travel_story', 'Mit dem Rad über die Alpen – fast.'),
    ],
    basics: ProfileBasics(
      relationshipGoal: RelationshipGoal.longTerm,
      children: ChildrenPlan.dontWant,
      smoking: Smoking.never,
      exercise: Exercise.often,
    ),
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

PublicProfile? demoProfileById(String id) {
  for (final p in demoProfiles) {
    if (p.id == id) return p;
  }
  return null;
}
