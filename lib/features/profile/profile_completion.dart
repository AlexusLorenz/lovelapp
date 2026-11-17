/// Wie vollständig ist ein Profil? (ohne Flutter-Abhängigkeit)
library;

import 'profile_basics.dart';

class ProfileCompletion {
  const ProfileCompletion(this.percent, this.nextTip);

  /// 0 bis 100.
  final int percent;

  /// Was als Nächstes am meisten bringt; `null`, wenn alles erledigt ist.
  final String? nextTip;
}

/// Gewichtung (Summe 100):
/// Fotos 30 (1 Foto 20, jedes weitere +5 bis 3), Über mich 15,
/// Fragen 30 (je 10), Steckbrief 20 (je Angabe 5, max. 4), Stadt 5.
ProfileCompletion computeCompletion({
  required int photoCount,
  required String bio,
  required String city,
  required int promptCount,
  required ProfileBasics basics,
}) {
  final photos = photoCount <= 0
      ? 0
      : 20 + 5 * ((photoCount > 3 ? 3 : photoCount) - 1);
  final hasBio = bio.trim().isNotEmpty;
  final prompts = 10 * (promptCount > 3 ? 3 : promptCount);
  final basicsFilled = basics.labels.length;
  final basicsScore = 5 * (basicsFilled > 4 ? 4 : basicsFilled);
  final hasCity = city.trim().isNotEmpty;

  final percent =
      photos + (hasBio ? 15 : 0) + prompts + basicsScore + (hasCity ? 5 : 0);

  final String? tip;
  if (photoCount == 0) {
    tip = 'Lade ein Foto hoch – Profile mit Foto bekommen viel mehr Likes.';
  } else if (photoCount < 3) {
    tip =
        'Noch ${3 - photoCount} ${3 - photoCount == 1 ? 'Foto' : 'Fotos'} '
        'mehr zeigen mehr von dir.';
  } else if (!hasBio) {
    tip = 'Schreib ein paar Sätze über dich.';
  } else if (promptCount < 3) {
    tip =
        'Beantworte noch ${3 - promptCount} '
        '${3 - promptCount == 1 ? 'Frage' : 'Fragen'} – gute Eisbrecher!';
  } else if (basicsFilled < 4) {
    tip = 'Ergänze deinen Steckbrief.';
  } else if (!hasCity) {
    tip = 'Trag deine Stadt ein.';
  } else {
    tip = null;
  }
  return ProfileCompletion(percent.clamp(0, 100), tip);
}
