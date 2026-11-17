import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lovelapp/features/onboarding/date_input_formatter.dart';

TextEditingValue _v(String t) => TextEditingValue(
  text: t,
  selection: TextSelection.collapsed(offset: t.length),
);

void main() {
  const f = GermanDateInputFormatter();

  test('setzt Punkte automatisch', () {
    expect(GermanDateInputFormatter.format('2'), '2');
    expect(GermanDateInputFormatter.format('24'), '24.');
    expect(GermanDateInputFormatter.format('240'), '24.0');
    expect(GermanDateInputFormatter.format('2405'), '24.05.');
    expect(GermanDateInputFormatter.format('24051998'), '24.05.1998');
  });

  test('ignoriert Nicht-Ziffern und kappt bei acht Ziffern', () {
    expect(GermanDateInputFormatter.format('24.05.1998'), '24.05.1998');
    expect(GermanDateInputFormatter.format('2405199812'), '24.05.1998');
    expect(f.formatEditUpdate(_v(''), _v('24a')).text, '24.');
  });

  test('Tippen Ziffer für Ziffer', () {
    var value = _v('');
    for (final ch in '24051998'.split('')) {
      value = f.formatEditUpdate(value, _v(value.text + ch));
    }
    expect(value.text, '24.05.1998');
    expect(value.selection.baseOffset, 10);
  });

  test('Löschen bleibt nicht am Punkt hängen', () {
    // „24.“ → Backspace entfernt Punkt und die 4
    expect(f.formatEditUpdate(_v('24.'), _v('24')).text, '2');
    expect(f.formatEditUpdate(_v('24.05.1'), _v('24.05.')).text, '24.05');
  });
}
