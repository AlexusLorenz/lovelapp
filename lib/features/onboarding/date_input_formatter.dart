import 'package:flutter/services.dart';

/// Setzt beim Tippen automatisch die Punkte: „24051998“ → „24.05.1998“.
///
/// Akzeptiert nur Ziffern (eingetippte Punkte werden ignoriert) und höchstens
/// acht davon. Beim Löschen verschwindet ein Punkt zusammen mit der Ziffer
/// davor, damit man nicht „hängen bleibt“.
class GermanDateInputFormatter extends TextInputFormatter {
  const GermanDateInputFormatter();

  /// Reine Formatierung, ohne Cursor-Logik – auch für Tests.
  static String format(String digits) {
    final d = digits.replaceAll(RegExp(r'\D'), '');
    final clipped = d.length > 8 ? d.substring(0, 8) : d;
    final buffer = StringBuffer();
    for (var i = 0; i < clipped.length; i++) {
      if (i == 2 || i == 4) buffer.write('.');
      buffer.write(clipped[i]);
    }
    // Punkt direkt anhängen, sobald Tag bzw. Monat vollständig sind.
    if (clipped.length == 2 || clipped.length == 4) buffer.write('.');
    return buffer.toString();
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final oldDigits = oldValue.text.replaceAll(RegExp(r'\D'), '');

    // Nur ein automatisch gesetzter Punkt wurde gelöscht → Ziffer davor mit weg.
    final deleting = newValue.text.length < oldValue.text.length;
    if (deleting && digits == oldDigits && digits.isNotEmpty) {
      digits = digits.substring(0, digits.length - 1);
    }

    var text = format(digits);
    // Beim Löschen keinen Punkt am Ende stehen lassen.
    if (deleting && text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
