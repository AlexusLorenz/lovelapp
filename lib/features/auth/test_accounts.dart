import 'package:material_ui/material_ui.dart';

import '../../core/config/env.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/placeholder_photo.dart';

/// Vorgefertigtes Test-Konto für die Entwicklungsphase.
///
/// Die Konten selbst legt `tool/test_accounts.py` an (gleiche E-Mails und
/// Namen – synchron halten). Serverseitig sind sie mit `profiles.is_test`
/// markiert und von echten Konten komplett getrennt.
class TestAccount {
  const TestAccount({
    required this.email,
    required this.name,
    required this.age,
    required this.isWoman,
    required this.portrait,
    required this.scenes,
  });

  final String email;
  final String name;
  final int age;
  final bool isWoman;

  /// Erstes Profilbild; auch Avatar in der Auswahl.
  final PhotoArt portrait;

  /// Weitere Profilbilder.
  final List<PhotoArt> scenes;

  List<PhotoArt> get photos => [portrait, ...scenes];
}

/// Auswahl nur anzeigen, wenn das Test-Passwort beim Build gesetzt ist.
bool get testAccountsEnabled =>
    Env.hasSupabase && Env.testLoginPassword.isNotEmpty;

const testAccounts = [
  TestAccount(
    email: 'lena@test.lovel.app',
    name: 'Lena',
    age: 27,
    isWoman: true,
    portrait: PhotoArt.portrait(
      skin: Color(0xFFF1CDB0),
      hair: Color(0xFF8A4B2A),
      hairStyle: HairStyle.long,
      shirt: LovelColors.terracotta,
      background: LovelColors.slate,
    ),
    scenes: [
      PhotoArt.scene(PhotoMotif.plants),
      PhotoArt.scene(PhotoMotif.mountains),
    ],
  ),
  TestAccount(
    email: 'mia@test.lovel.app',
    name: 'Mia',
    age: 31,
    isWoman: true,
    portrait: PhotoArt.portrait(
      skin: Color(0xFF8D5A3B),
      hair: Color(0xFF1E1510),
      hairStyle: HairStyle.curly,
      shirt: LovelColors.slate,
      background: LovelColors.cream,
    ),
    scenes: [PhotoArt.scene(PhotoMotif.city), PhotoArt.scene(PhotoMotif.sea)],
  ),
  TestAccount(
    email: 'sophie@test.lovel.app',
    name: 'Sophie',
    age: 29,
    isWoman: true,
    portrait: PhotoArt.portrait(
      skin: Color(0xFFF6D9C4),
      hair: Color(0xFFD9B26A),
      hairStyle: HairStyle.bun,
      shirt: LovelColors.ink,
      background: LovelColors.mist,
    ),
    scenes: [PhotoArt.scene(PhotoMotif.sea), PhotoArt.scene(PhotoMotif.plants)],
  ),
  TestAccount(
    email: 'hannah@test.lovel.app',
    name: 'Hannah',
    age: 34,
    isWoman: true,
    portrait: PhotoArt.portrait(
      skin: Color(0xFFD9A47E),
      hair: Color(0xFF4A3426),
      hairStyle: HairStyle.long,
      shirt: LovelColors.umber,
      background: LovelColors.mist,
    ),
    scenes: [
      PhotoArt.scene(PhotoMotif.mountains),
      PhotoArt.scene(PhotoMotif.city),
    ],
  ),
  TestAccount(
    email: 'jonas@test.lovel.app',
    name: 'Jonas',
    age: 30,
    isWoman: false,
    portrait: PhotoArt.portrait(
      skin: Color(0xFFE2B48C),
      hair: Color(0xFF4A3426),
      hairStyle: HairStyle.short,
      shirt: LovelColors.umber,
      background: LovelColors.mist,
    ),
    scenes: [
      PhotoArt.scene(PhotoMotif.mountains),
      PhotoArt.scene(PhotoMotif.city),
    ],
  ),
  TestAccount(
    email: 'felix@test.lovel.app',
    name: 'Felix',
    age: 28,
    isWoman: false,
    portrait: PhotoArt.portrait(
      skin: Color(0xFFF1CDB0),
      hair: Color(0xFFB5652F),
      hairStyle: HairStyle.curly,
      shirt: LovelColors.slate,
      background: LovelColors.cream,
    ),
    scenes: [PhotoArt.scene(PhotoMotif.sea), PhotoArt.scene(PhotoMotif.plants)],
  ),
  TestAccount(
    email: 'paul@test.lovel.app',
    name: 'Paul',
    age: 33,
    isWoman: false,
    portrait: PhotoArt.portrait(
      skin: Color(0xFF6B4029),
      hair: Color(0xFF1E1510),
      hairStyle: HairStyle.short,
      shirt: LovelColors.terracotta,
      background: LovelColors.slate,
    ),
    scenes: [
      PhotoArt.scene(PhotoMotif.city),
      PhotoArt.scene(PhotoMotif.mountains),
    ],
  ),
  TestAccount(
    email: 'tim@test.lovel.app',
    name: 'Tim',
    age: 26,
    isWoman: false,
    portrait: PhotoArt.portrait(
      skin: Color(0xFFE8C2A0),
      hair: Color(0xFF2B1D14),
      hairStyle: HairStyle.short,
      shirt: LovelColors.ink,
      background: LovelColors.mist,
    ),
    scenes: [PhotoArt.scene(PhotoMotif.plants), PhotoArt.scene(PhotoMotif.sea)],
  ),
];
