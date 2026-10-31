import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/shared/rich_text/script_markup.dart';

String _show(List<ScriptSpan> spans) => spans
    .map(
      (s) =>
          '${s.text}[${s.bold ? 'b' : ''}${s.italic ? 'i' : ''}'
          '${s.underline ? 'u' : ''}${s.marker ?? ''}]',
    )
    .join('|');

void main() {
  test('trocea negrita, cursiva, subrayado y marcador', () {
    expect(
      _show(
        parseScriptMarkup('PP de **ALI** en *moto*, __importante__ ==ya=='),
      ),
      'PP de []|ALI[b]| en []|moto[i]|, []|importante[u]| []|ya[y]',
    );
  });

  test('admite formatos anidados y marcador de otro color', () {
    expect(
      _show(parseScriptMarkup('**muy *muy* serio** ==g:verde==')),
      'muy [b]|muy[bi]| serio[b]| []|verde[g]',
    );
  });

  test('una marca sin pareja se queda como texto', () {
    expect(_show(parseScriptMarkup('lente 2 * 50mm')), 'lente 2 * 50mm[]');
    expect(_show(parseScriptMarkup('a == b')), 'a == b[]');
  });

  test('el texto sin marcas es lo que se lee', () {
    expect(
      scriptMarkupToPlain('PP de **ALI** ==g:CAMERA CAR=='),
      'PP de ALI CAMERA CAR',
    );
    expect(scriptMarkupToPlain(null), '');
    expect(scriptMarkupToPlain('sin formato'), 'sin formato');
  });

  test('el cursor del texto visible se traduce al texto con marcas', () {
    const text = 'PP de **ALI** serio';
    // Visible: "PP de ALI serio". Tras la «A» visible (posición 7).
    expect(scriptRawOffsetForPlain(text, 7), 9);
    expect(scriptRawOffsetForPlain(text, 0), 0);
    expect(scriptRawOffsetForPlain(text, 99), text.length);
  });

  test('aplicar un formato envuelve la selección y la deja seleccionada', () {
    final r = toggleScriptMarkup('PP de ALI', 6, 9, ScriptMark.bold);
    expect(r.text, 'PP de **ALI**');
    expect(r.text.substring(r.start, r.end), 'ALI');
  });

  test('aplicarlo otra vez lo quita, se seleccione con o sin las marcas', () {
    final on = toggleScriptMarkup('PP de ALI', 6, 9, ScriptMark.italic);
    final off = toggleScriptMarkup(
      on.text,
      on.start,
      on.end,
      ScriptMark.italic,
    );
    expect(off.text, 'PP de ALI');
    expect(off.text.substring(off.start, off.end), 'ALI');

    final whole = toggleScriptMarkup(
      'PP de __ALI__',
      6,
      13,
      ScriptMark.underline,
    );
    expect(whole.text, 'PP de ALI');
  });

  test('el marcador cambia de color sin anidarse, y sin color se quita', () {
    final yellow = toggleScriptMarkup(
      'ojo aquí',
      0,
      3,
      ScriptMark.marker,
      color: 'y',
    );
    expect(yellow.text, '==ojo== aquí');
    final green = toggleScriptMarkup(
      yellow.text,
      yellow.start,
      yellow.end,
      ScriptMark.marker,
      color: 'g',
    );
    expect(green.text, '==g:ojo== aquí');
    final none = toggleScriptMarkup(
      green.text,
      green.start,
      green.end,
      ScriptMark.marker,
    );
    expect(none.text, 'ojo aquí');
  });

  test('los asteriscos sueltos no ponen cursiva', () {
    expect(_show(parseScriptMarkup('2 * 3 * 4')), '2 * 3 * 4[]');
    expect(_show(parseScriptMarkup('* nota *')), '* nota *[]');
    // La cursiva no cruza líneas.
    expect(_show(parseScriptMarkup('a *b\nc* d')), 'a *b\nc* d[]');
    expect(_show(parseScriptMarkup('__ x __')), '__ x __[]');
  });

  test('color de letra en una parte del texto', () {
    final spans = parseScriptMarkup('ojo {{r:FUEGO}} aquí');
    expect(spans.map((s) => s.text).join('|'), 'ojo |FUEGO| aquí');
    expect(spans[1].textColor, 'r');
    expect(scriptMarkupToPlain('{{a:**AZUL**}}'), 'AZUL');
  });

  test('el color de letra se pone, se cambia y se quita', () {
    final red = toggleScriptMarkup(
      'ojo aquí',
      0,
      3,
      ScriptMark.textColor,
      color: 'r',
    );
    expect(red.text, '{{r:ojo}} aquí');
    final blue = toggleScriptMarkup(
      red.text,
      red.start,
      red.end,
      ScriptMark.textColor,
      color: 'a',
    );
    expect(blue.text, '{{a:ojo}} aquí');
    final none = toggleScriptMarkup(
      blue.text,
      blue.start,
      blue.end,
      ScriptMark.textColor,
    );
    expect(none.text, 'ojo aquí');
  });

  test('los blancos de los bordes de la selección quedan fuera', () {
    final r = toggleScriptMarkup('PP de ALI ', 5, 10, ScriptMark.italic);
    expect(r.text, 'PP de *ALI* ');
    expect(parseScriptMarkup(r.text).any((s) => s.italic), isTrue);
  });

  test('sin selección no cambia nada', () {
    final r = toggleScriptMarkup('PP de ALI', 3, 3, ScriptMark.bold);
    expect(r.text, 'PP de ALI');
  });
}
