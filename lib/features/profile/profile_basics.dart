/// Steckbrief: freiwillige Standardangaben (ohne Flutter-Abhängigkeit).
///
/// Die `dbValue`s MÜSSEN zu den CHECK-Constraints in
/// `supabase/migrations/*_profile_details.sql` passen.
library;

/// Gemeinsame Schnittstelle, damit die UI alle Felder gleich behandeln kann.
abstract interface class BasicOption {
  String get dbValue;
  String get label;
}

T? _fromDb<T extends BasicOption>(List<T> values, Object? value) {
  for (final v in values) {
    if (v.dbValue == value) return v;
  }
  return null;
}

enum RelationshipGoal implements BasicOption {
  longTerm('long_term', 'Etwas Festes'),
  openToAnything('open', 'Offen für alles'),
  casual('casual', 'Etwas Lockeres'),
  friends('friends', 'Neue Freundschaften'),
  unsure('unsure', 'Weiß ich noch nicht');

  const RelationshipGoal(this.dbValue, this.label);
  @override
  final String dbValue;
  @override
  final String label;

  static RelationshipGoal? fromDb(Object? v) => _fromDb(values, v);
}

enum ChildrenPlan implements BasicOption {
  wantSomeday('want_someday', 'Möchte irgendwann Kinder'),
  dontWant('dont_want', 'Möchte keine Kinder'),
  haveWantMore('have_want_more', 'Habe Kinder, gern mehr'),
  haveNoMore('have_no_more', 'Habe Kinder, keine weiteren'),
  notSure('not_sure', 'Bin mir nicht sicher');

  const ChildrenPlan(this.dbValue, this.label);
  @override
  final String dbValue;
  @override
  final String label;

  static ChildrenPlan? fromDb(Object? v) => _fromDb(values, v);
}

enum Smoking implements BasicOption {
  never('never', 'Nichtraucher:in'),
  sometimes('sometimes', 'Rauche gelegentlich'),
  regularly('regularly', 'Rauche');

  const Smoking(this.dbValue, this.label);
  @override
  final String dbValue;
  @override
  final String label;

  static Smoking? fromDb(Object? v) => _fromDb(values, v);
}

enum Drinking implements BasicOption {
  never('never', 'Trinke keinen Alkohol'),
  socially('socially', 'Trinke gesellig'),
  regularly('regularly', 'Trinke gern mal einen');

  const Drinking(this.dbValue, this.label);
  @override
  final String dbValue;
  @override
  final String label;

  static Drinking? fromDb(Object? v) => _fromDb(values, v);
}

enum Exercise implements BasicOption {
  often('often', 'Sehr sportlich'),
  sometimes('sometimes', 'Ab und zu Sport'),
  rarely('rarely', 'Eher Couch');

  const Exercise(this.dbValue, this.label);
  @override
  final String dbValue;
  @override
  final String label;

  static Exercise? fromDb(Object? v) => _fromDb(values, v);
}

const minHeightCm = 120;
const maxHeightCm = 230;

String? validateHeight(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null; // freiwillig
  final cm = int.tryParse(text);
  if (cm == null || cm < minHeightCm || cm > maxHeightCm) {
    return 'Bitte zwischen $minHeightCm und $maxHeightCm cm.';
  }
  return null;
}

class ProfileBasics {
  const ProfileBasics({
    this.relationshipGoal,
    this.children,
    this.smoking,
    this.drinking,
    this.exercise,
    this.heightCm,
  });

  factory ProfileBasics.fromJson(Map<String, Object?> json) => ProfileBasics(
    relationshipGoal: RelationshipGoal.fromDb(json['relationship_goal']),
    children: ChildrenPlan.fromDb(json['children']),
    smoking: Smoking.fromDb(json['smoking']),
    drinking: Drinking.fromDb(json['drinking']),
    exercise: Exercise.fromDb(json['exercise']),
    heightCm: (json['height_cm'] as num?)?.toInt(),
  );

  final RelationshipGoal? relationshipGoal;
  final ChildrenPlan? children;
  final Smoking? smoking;
  final Drinking? drinking;
  final Exercise? exercise;
  final int? heightCm;

  bool get isEmpty => labels.isEmpty;

  /// Alle ausgefüllten Angaben als Text, z. B. für Chips.
  List<String> get labels => [
    if (heightCm != null) '$heightCm cm',
    if (relationshipGoal != null) relationshipGoal!.label,
    if (children != null) children!.label,
    if (smoking != null) smoking!.label,
    if (drinking != null) drinking!.label,
    if (exercise != null) exercise!.label,
  ];

  Map<String, Object?> toJson() => {
    'relationship_goal': relationshipGoal?.dbValue,
    'children': children?.dbValue,
    'smoking': smoking?.dbValue,
    'drinking': drinking?.dbValue,
    'exercise': exercise?.dbValue,
    'height_cm': heightCm,
  };

  ProfileBasics copyWith({
    RelationshipGoal? Function()? relationshipGoal,
    ChildrenPlan? Function()? children,
    Smoking? Function()? smoking,
    Drinking? Function()? drinking,
    Exercise? Function()? exercise,
    int? Function()? heightCm,
  }) => ProfileBasics(
    relationshipGoal: relationshipGoal != null
        ? relationshipGoal()
        : this.relationshipGoal,
    children: children != null ? children() : this.children,
    smoking: smoking != null ? smoking() : this.smoking,
    drinking: drinking != null ? drinking() : this.drinking,
    exercise: exercise != null ? exercise() : this.exercise,
    heightCm: heightCm != null ? heightCm() : this.heightCm,
  );
}
