import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/sync/bundle_changes.dart';
import 'package:iris_dp/core/sync/project_activity_service.dart';

Map<String, dynamic> _bundle({
  List<Map<String, dynamic>>? scenes,
  List<Map<String, dynamic>>? shots,
  List<Map<String, dynamic>>? elements,
  List<Map<String, dynamic>>? points,
  List<Map<String, dynamic>>? refs,
  List<Map<String, dynamic>>? bible,
}) => {
  'version': 9,
  'scenes':
      scenes ??
      [
        {'uid': 'e1', 'sceneKey': 'scene:1', 'number': 1, 'name': 'Bar'},
      ],
  'shots':
      shots ??
      [
        {
          'uid': 's1',
          'shotKey': 'shot:1:1',
          'sceneKey': 'scene:1',
          'number': 1,
          'lens': '35',
        },
        {
          'uid': 's2',
          'shotKey': 'shot:1:2',
          'sceneKey': 'scene:1',
          'number': 2,
          'lens': '50',
        },
      ],
  'shotReferences': refs ?? [],
  'cameraPlanElements':
      elements ??
      [
        {
          'shotKey': 'shot:1:1',
          'elementKey': 'shot:1:1/el:0:camera',
          'type': 'camera',
          'x': 1.0,
          'y': 2.0,
        },
      ],
  'cameraPathPoints': points ?? [],
  'moodboardImages': bible ?? [],
};

ContentChange _find(List<ContentChange> list, String uid) =>
    list.firstWhere((c) => c.uid == uid);

void main() {
  test('sin cambios, nada que anotar', () {
    expect(BundleChanges.between(_bundle(), _bundle()), isEmpty);
  });

  test('campo de un plano, en palabras', () {
    final after = _bundle();
    (after['shots'] as List)[0]['lens'] = '40';
    final changes = BundleChanges.between(_bundle(), after);
    expect(changes, hasLength(1));
    final c = changes.single;
    expect(c.collection, 'shots');
    expect(c.uid, 's1');
    expect(c.label, 'Plano 1/1');
    expect(c.action, 'edited');
    expect(c.fields, ['óptica']);
  });

  test('mover algo en la planta se anota en su plano', () {
    final after = _bundle(
      elements: [
        {
          'shotKey': 'shot:1:1',
          'elementKey': 'shot:1:1/el:0:camera',
          'type': 'camera',
          'x': 3.0,
          'y': 2.0,
        },
      ],
    );
    final c = BundleChanges.between(_bundle(), after).single;
    expect(c.uid, 's1');
    expect(c.fields, ['planta']);
  });

  test('un recorrido nuevo también es la planta', () {
    final after = _bundle(
      points: [
        {
          'elementKey': 'shot:1:1/el:0:camera',
          'x': 0,
          'y': 0,
          'pointNumber': 1,
        },
      ],
    );
    expect(BundleChanges.between(_bundle(), after).single.fields, ['planta']);
  });

  test('una planta nueva en un plano que no tenía', () {
    final after = _bundle(
      elements: [
        ...(_bundle()['cameraPlanElements'] as List)
            .cast<Map<String, dynamic>>(),
        {
          'shotKey': 'shot:1:2',
          'elementKey': 'shot:1:2/el:0:light',
          'type': 'light',
          'x': 0.0,
          'y': 0.0,
        },
      ],
    );
    final c = BundleChanges.between(_bundle(), after).single;
    expect(c.uid, 's2');
    expect(c.fields, ['planta']);
  });

  test('planta y óptica del mismo plano van juntas', () {
    final after = _bundle(
      elements: [
        {
          'shotKey': 'shot:1:1',
          'elementKey': 'shot:1:1/el:0:camera',
          'type': 'camera',
          'x': 9.0,
          'y': 2.0,
        },
      ],
    );
    (after['shots'] as List)[0]['lens'] = '24';
    final c = BundleChanges.between(_bundle(), after).single;
    expect(c.fields.toSet(), {'óptica', 'planta'});
  });

  test('añadir y borrar planos', () {
    final after = _bundle(
      shots: [
        {
          'uid': 's1',
          'shotKey': 'shot:1:1',
          'sceneKey': 'scene:1',
          'number': 1,
          'lens': '35',
        },
        {
          'uid': 's3',
          'shotKey': 'shot:1:3',
          'sceneKey': 'scene:1',
          'number': 3,
        },
      ],
    );
    final changes = BundleChanges.between(_bundle(), after);
    expect(_find(changes, 's3').action, 'added');
    expect(_find(changes, 's2').action, 'removed');
    expect(_find(changes, 's2').label, 'Plano 1/2');
  });

  test('la planta de un plano nuevo no se anota aparte', () {
    final after = _bundle(
      shots: [
        ...(_bundle()['shots'] as List).cast<Map<String, dynamic>>(),
        {
          'uid': 's3',
          'shotKey': 'shot:1:3',
          'sceneKey': 'scene:1',
          'number': 3,
        },
      ],
      elements: [
        ...(_bundle()['cameraPlanElements'] as List)
            .cast<Map<String, dynamic>>(),
        {
          'shotKey': 'shot:1:3',
          'elementKey': 'shot:1:3/el:0:camera',
          'type': 'camera',
          'x': 0.0,
          'y': 0.0,
        },
      ],
    );
    final changes = BundleChanges.between(_bundle(), after);
    expect(changes, hasLength(1));
    expect(changes.single.action, 'added');
  });

  test('referencias del plano', () {
    final after = _bundle(
      refs: [
        {'uid': 'r1', 'shotKey': 'shot:1:2', 'imagePath': 'a.jpg'},
      ],
    );
    final c = BundleChanges.between(_bundle(), after).single;
    expect(c.uid, 's2');
    expect(c.fields, ['referencias']);
  });

  test('renumerar no pierde el plano: mismo uid', () {
    final after = _bundle();
    final shot = (after['shots'] as List)[1] as Map<String, dynamic>;
    shot['number'] = 5;
    shot['shotKey'] = 'shot:1:5';
    final c = BundleChanges.between(_bundle(), after).single;
    expect(c.uid, 's2');
    expect(c.fields, ['número']);
  });

  test('la escena y la biblia', () {
    final after = _bundle(
      bible: [
        {'id': 1, 'imagePath': 'x.jpg'},
      ],
    );
    (after['scenes'] as List)[0]['name'] = 'Bar de noche';
    final changes = BundleChanges.between(_bundle(), after);
    expect(_find(changes, 'e1').fields, ['nombre']);
    expect(_find(changes, 'e1').label, 'Escena 1 · Bar de noche');
    expect(_find(changes, 'biblia').collection, 'biblia');
  });

  test('paquetes sin uid (versiones viejas) no se comparan', () {
    final old = _bundle(
      shots: [
        {'shotKey': 'shot:1:1', 'number': 1},
      ],
    );
    expect(
      BundleChanges.between(
        old,
        _bundle(),
      ).where((c) => c.collection == 'shots'),
      isEmpty,
    );
  });

  test('la frase de la actividad', () {
    final e = ActivityEntry.fromRow({
      'at': '2026-11-22T18:00:00Z',
      'user_id': 'u',
      'name': 'Ana',
      'role': 'gaffer',
      'collection': 'shots',
      'uid': 's1',
      'label': 'Plano 6/1',
      'action': 'edited',
      'fields': ['planta', 'óptica', 'notas'],
    });
    expect(
      e.sentence,
      'Ana (gaffer) cambió la planta, la óptica y las notas de Plano 6/1',
    );
    final owner = ActivityEntry.fromRow({
      'at': '2026-11-22T18:00:00Z',
      'user_id': 'u',
      'name': null,
      'role': null,
      'collection': 'shots',
      'label': 'Plano 6/2',
      'action': 'added',
    });
    expect(owner.sentence, 'Alguien (propietario) añadió Plano 6/2');
  });
}
