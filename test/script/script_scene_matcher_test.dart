import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/script/script_scene_matcher.dart';

String _key(String heading) {
  final parts = heading.split('|');
  return scriptHeadingKey(
    intExt: parts[0],
    location: parts[1],
    dayNight: parts[2],
  );
}

const _texts = {
  'a': 'Ali conduce serio su moto de reparto. El semáforo se pone en ámbar.',
  'b': 'Diego cierra el cajón de la moto y Ali le da un manotazo.',
  'c': 'La chica recoge el pedido en el rellano y cierra la puerta despacio.',
  'd': 'Simo y Ali sacan la basura del kebab mientras cae la persiana.',
  'e': 'Amanece en la calle vacía; un camión de limpieza riega la acera.',
};

ExistingScriptScene _old(int id, String heading, [String? text]) =>
    ExistingScriptScene(
      id: id,
      headingKey: _key(heading),
      text: _texts[text],
      textHash: scriptTextHash(_texts[text]),
    );

IncomingScriptScene _new(String heading, [String? text]) =>
    IncomingScriptScene(headingKey: _key(heading), text: _texts[text] ?? text);

const _calle = 'EXT|CALLE RAVAL|NOCHE';
const _rellano = 'INT|RELLANO BLOQUE PISOS|NOCHE';
const _kebab = 'INT|KEBAB KHALED|NOCHE';

List<int?> _ids(ScriptSceneMatch m) => [for (final l in m.links) l.existingId];

void main() {
  test('la cabecera se reconoce con otras tildes, signos y mayúsculas', () {
    expect(
      scriptHeadingKey(
        intExt: 'EXT.',
        location: 'Calle Raval',
        dayNight: 'NOCHE',
      ),
      scriptHeadingKey(
        intExt: 'ext',
        location: 'CALLE  RAVAL',
        dayNight: 'Noche',
      ),
    );
    expect(
      scriptHeadingKey(intExt: 'INT', location: 'SALÓN', dayNight: 'DÍA'),
      scriptHeadingKey(intExt: 'INT', location: 'SALON', dayNight: 'DIA'),
    );
  });

  test('un guion sin cambios empareja todo y no hay nada que revisar', () {
    final m = matchScriptScenes(
      existing: [
        _old(1, _calle, 'a'),
        _old(2, _rellano, 'c'),
        _old(3, _kebab, 'd'),
      ],
      incoming: [_new(_calle, 'a'), _new(_rellano, 'c'), _new(_kebab, 'd')],
    );
    expect(_ids(m), [1, 2, 3]);
    expect(m.removedIds, isEmpty);
    expect(m.isTrivial, isTrue);
    expect(m.count(ScriptSceneChange.unchanged), 3);
  });

  test('una escena insertada en medio no desplaza a las siguientes', () {
    final m = matchScriptScenes(
      existing: [
        _old(1, _calle, 'a'),
        _old(2, _rellano, 'c'),
        _old(3, _kebab, 'd'),
      ],
      incoming: [
        _new(_calle, 'a'),
        _new('EXT|PLAZA|DÍA', 'e'),
        _new(_rellano, 'c'),
        _new(_kebab, 'd'),
      ],
    );
    expect(_ids(m), [1, null, 2, 3]);
    expect(m.links[1].change, ScriptSceneChange.added);
    expect(m.removedIds, isEmpty);
    expect(m.isTrivial, isFalse);
  });

  test('una escena quitada queda como «ya no está» y las demás siguen', () {
    final m = matchScriptScenes(
      existing: [
        _old(1, _calle, 'a'),
        _old(2, _rellano, 'c'),
        _old(3, _kebab, 'd'),
      ],
      incoming: [_new(_calle, 'a'), _new(_kebab, 'd')],
    );
    expect(_ids(m), [1, 3]);
    expect(m.removedIds, [2]);
  });

  test('dos escenas con la misma cabecera se emparejan en su orden', () {
    final m = matchScriptScenes(
      existing: [
        _old(1, _calle, 'a'),
        _old(2, _kebab, 'd'),
        _old(3, _calle, 'b'),
      ],
      incoming: [
        _new(_calle, 'a'),
        _new(_rellano, 'c'),
        _new(_kebab, 'd'),
        _new(_calle, 'b'),
      ],
    );
    expect(_ids(m), [1, null, 2, 3]);
  });

  test('si solo cambia el texto, la escena es la misma con texto nuevo', () {
    final m = matchScriptScenes(
      existing: [_old(1, _calle, 'a'), _old(2, _kebab, 'd')],
      incoming: [
        _new(_calle, 'Ali conduce serio su moto. Empieza a llover con fuerza.'),
        _new(_kebab, 'd'),
      ],
    );
    expect(_ids(m), [1, 2]);
    expect(m.links[0].change, ScriptSceneChange.textChanged);
    expect(m.links[1].change, ScriptSceneChange.unchanged);
    expect(m.isTrivial, isTrue);
  });

  test('una cabecera que pasa de noche a día sigue siendo su escena', () {
    final m = matchScriptScenes(
      existing: [
        _old(1, _calle, 'a'),
        _old(2, _rellano, 'c'),
        _old(3, _kebab, 'd'),
      ],
      incoming: [
        _new(_calle, 'a'),
        _new('INT|RELLANO BLOQUE PISOS|DÍA', 'c'),
        _new(_kebab, 'd'),
      ],
    );
    expect(_ids(m), [1, 2, 3]);
    expect(m.links[1].change, ScriptSceneChange.headingChanged);
    expect(m.removedIds, isEmpty);
  });

  test('una escena que cambia de sitio en el guion conserva su vínculo', () {
    final m = matchScriptScenes(
      existing: [
        _old(1, _calle, 'a'),
        _old(2, _rellano, 'c'),
        _old(3, _kebab, 'd'),
      ],
      incoming: [_new(_rellano, 'c'), _new(_calle, 'a'), _new(_kebab, 'd')],
    );
    expect(_ids(m).toSet(), {1, 2, 3});
    expect(_ids(m)[0], 2);
    expect(_ids(m)[1], 1);
    expect(m.removedIds, isEmpty);
  });

  test('una escena distinta en el mismo sitio no se confunde con la vieja', () {
    final m = matchScriptScenes(
      existing: [
        _old(1, _calle, 'a'),
        _old(2, _rellano, 'c'),
        _old(3, _kebab, 'd'),
      ],
      incoming: [
        _new(_calle, 'a'),
        _new('EXT|PLAZA|DÍA', 'e'),
        _new(_kebab, 'd'),
      ],
    );
    expect(_ids(m), [1, null, 3]);
    expect(m.removedIds, [2]);
  });

  test('proyecto antiguo sin texto guardado: la cabecera cambiada entre dos '
      'escenas conocidas se toma por la misma', () {
    final m = matchScriptScenes(
      existing: [_old(1, _calle), _old(2, _rellano), _old(3, _kebab)],
      incoming: [
        _new(_calle, 'a'),
        _new('INT|RELLANO BLOQUE PISOS|DÍA', 'c'),
        _new(_kebab, 'd'),
      ],
    );
    expect(_ids(m), [1, 2, 3]);
    expect(m.links[1].change, ScriptSceneChange.headingChanged);
  });
}
