import 'package:material_ui/material_ui.dart';

/// Platzhalter für AGB und Datenschutzerklärung.
///
/// TODO(legal): Echte Texte vor dem Launch von einer Fachanwältin/einem
/// Fachanwalt erstellen lassen (DSGVO, Art. 9, DSA, Jugendschutz).
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});

  /// `privacy` oder `terms`.
  final String doc;

  @override
  Widget build(BuildContext context) {
    final isPrivacy = doc == 'privacy';
    return Scaffold(
      appBar: AppBar(title: Text(isPrivacy ? 'Datenschutz' : 'AGB')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Entwurf', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
          Text(
            isPrivacy
                ? 'Die Datenschutzerklärung wird vor dem Start der App '
                      'erstellt. Kurz vorab: Lovel speichert deine Daten auf '
                      'Servern in Frankfurt. Angaben dazu, wen du kennenlernen '
                      'möchtest, speichern wir nur mit deiner ausdrücklichen '
                      'Einwilligung. Dein Konto wirst du jederzeit selbst löschen können.'
                : 'Die Allgemeinen Geschäftsbedingungen werden vor dem Start '
                      'der App erstellt. Lovel ist nur für Menschen ab 18 Jahren.',
          ),
        ],
      ),
    );
  }
}
