import '../../core/widgets/placeholder_photo.dart';
import '../profile/profile_basics.dart';
import '../profile/profile_prompts.dart';

/// Was andere von einem Profil sehen.
class PublicProfile {
  const PublicProfile({
    required this.id,
    required this.name,
    required this.age,
    required this.city,
    required this.distanceKm,
    required this.bio,
    required this.level,
    this.photos = const [],
    this.prompts = const [],
    this.basics = const ProfileBasics(),
    this.likesYouBack = false,
  });

  final String id;
  final String name;
  final int age;
  final String city;
  final int distanceKm;
  final String bio;
  final int level;

  /// Bis zum Foto-Upload gezeichnete Platzhalter.
  final List<PhotoArt> photos;
  final List<PromptAnswer> prompts;
  final ProfileBasics basics;

  /// Nur Demo: Würde dieses Profil zurückliken?
  final bool likesYouBack;
}
