import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/sync/bundle_merge.dart';

Map<String, dynamic> _scene(String uid, int number, {String? name}) => {
  'uid': uid,
  'sceneKey': 'scene:$number',
  'number': number,
  'name': name ?? 'INT. CASA $number',
  'sortOrder': number,
};

Map<String, dynamic> _shot(
  String uid,
  int scene,
  int number, {
  String? lens,
  String? notes,
  String? storyboardImagePath,
}) => {
  'uid': uid,
  'shotKey': 'shot:$scene:$number',
  'sceneKey': 'scene:$scene',
  'number': number,
  'lens': lens,
  'notes': notes,
  'storyboardImagePath': storyboardImagePath,
  'sortOrder': number,
};

Map<String, dynamic> _bundle({
  List<Map<String, dynamic>> scenes = const [],
  List<Map<String, dynamic>> shots = const [],
  List<Map<String, dynamic>> moodboardImages = const [],
  Map<String, dynamic> projectFields = const {},
}) =>
    jsonDecode(
          jsonEncode({
            'version': 7,
            'projectFields': projectFields,
            'scenes': scenes,
            'shots': shots,
            'shotReferences': <Object>[],
            'moodboardImages': moodboardImages,
          }),
        )
        as Map<String, dynamic>;

BundleMergeResult _merge(
  Map<String, dynamic> base,
  Map<String, dynamic> local,
  Map<String, dynamic> cloud, {
  MergeSide newer = MergeSide.local,
}) => BundleMerge.merge(
  baseLocal: base,
  baseCloud: base,
  local: local,
  cloud: cloud,
  newer: newer,
);

Map<String, dynamic> _shotOf(Map<String, dynamic> bundle, String uid) =>
    (bundle['shots'] as List).cast<Map<String, dynamic>>().firstWhere(
      (s) => s['uid'] == uid,
    );

void main() {
  final base = _bundle(
    scenes: [_scene('s1', 1), _scene('s2', 2)],
    shots: [_shot('a', 1, 1), _shot('b', 1, 2), _shot('c', 2, 1)],
  );

  test('cambios en planos distintos: quedan los dos', () {
    final local = _bundle(
      scenes: [_scene('s1', 1), _scene('s2', 2)],
      shots: [_shot('a', 1, 1, lens: '35mm'), _shot('b', 1, 2), _shot('c', 2, 1)],
    );
    final cloud = _bundle(
      scenes: [_scene('s1', 1), _scene('s2', 2)],
      shots: [_shot('a', 1, 1), _shot('b', 1, 2, notes: 'grúa'), _shot('c', 2, 1)],
    );
    final r = _merge(base, local, cloud);
    expect(_shotOf(r.merged, 'a')['lens'], '35mm');
    expect(_shotOf(r.merged, 'b')['notes'], 'grúa');
    expect(r.discards, isEmpty);
  });

  test('campos distintos del mismo plano: se juntan', () {
    final local = _bundle(
      scenes: [_scene('s1', 1), _scene('s2', 2)],
      shots: [_shot('a', 1, 1, lens: '50mm'), _shot('b', 1, 2), _shot('c', 2, 1)],
    );
    final cloud = _bundle(
      scenes: [_scene('s1', 1), _scene('s2', 2)],
      shots: [_shot('a', 1, 1, notes: 'steady'), _shot('b', 1, 2), _shot('c', 2, 1)],
    );
    final a = _shotOf(_merge(base, local, cloud).merged, 'a');
    expect(a['lens'], '50mm');
    expect(a['notes'], 'steady');
  });

  test('el mismo campo en los dos: gana lo más reciente y se anota', () {
    final local = _bundle(
      scenes: [_scene('s1', 1), _scene('s2', 2)],
      shots: [_shot('a', 1, 1, lens: '50mm'), _shot('b', 1, 2), _shot('c', 2, 1)],
    );
    final cloud = _bundle(
      scenes: [_scene('s1', 1), _scene('s2', 2)],
      shots: [_shot('a', 1, 1, lens: '85mm'), _shot('b', 1, 2), _shot('c', 2, 1)],
    );
    final r = _merge(base, local, cloud, newer: MergeSide.cloud);
    expect(_shotOf(r.merged, 'a')['lens'], '85mm');
    expect(r.discards, hasLength(1));
    final d = r.discards.single;
    expect(d.collection, 'shots');
    expect(d.field, 'lens');
    expect(d.discarded, '50mm');
    expect(d.discardedSide, MergeSide.local);
    expect(d.label, 'Plano 1/1');
  });

  test('añadidos en cada lado: están todos', () {
    final local = _bundle(
      scenes: [_scene('s1', 1), _scene('s2', 2)],
      shots: [..._bundle(shots: [_shot('a', 1, 1), _shot('b', 1, 2), _shot('c', 2, 1)])['shots'], _shot('d', 1, 3)],
    );
    final cloud = _bundle(
      scenes: [_scene('s1', 1), _scene('s2', 2), _scene('s3', 3)],
      shots: [_shot('a', 1, 1), _shot('b', 1, 2), _shot('c', 2, 1), _shot('e', 3, 1)],
    );
    final r = _merge(base, local, cloud);
    expect((r.merged['shots'] as List).map((s) => s['uid']), containsAll(['a', 'b', 'c', 'd', 'e']));
    expect((r.merged['scenes'] as List).map((s) => s['uid']), containsAll(['s1', 's2', 's3']));
    expect(_shotOf(r.merged, 'e')['sceneKey'], 'scene:3');
  });

  test('borrado en un lado sin tocar en el otro: se borra', () {
    final local = _bundle(
      scenes: [_scene('s1', 1), _scene('s2', 2)],
      shots: [_shot('a', 1, 1), _shot('c', 2, 1)],
    );
    final r = _merge(base, local, base);
    expect((r.merged['shots'] as List).map((s) => s['uid']), ['a', 'c']);
    expect(r.discards, isEmpty);
  });

  test('borrado aquí y editado en la nube más tarde: se queda', () {
    final local = _bundle(
      scenes: [_scene('s1', 1), _scene('s2', 2)],
      shots: [_shot('a', 1, 1), _shot('c', 2, 1)],
    );
    final cloud = _bundle(
      scenes: [_scene('s1', 1), _scene('s2', 2)],
      shots: [_shot('a', 1, 1), _shot('b', 1, 2, notes: 'nuevo'), _shot('c', 2, 1)],
    );
    final r = _merge(base, local, cloud, newer: MergeSide.cloud);
    expect(_shotOf(r.merged, 'b')['notes'], 'nuevo');
    expect(r.discards.single.discarded, isNull);
    expect(r.discards.single.discardedSide, MergeSide.local);
  });

  test('renumerar aquí no deja colgado el plano añadido en la nube', () {
    // Aquí la escena 2 pasa a ser la 5; en la nube se le añade un plano.
    final local = _bundle(
      scenes: [_scene('s1', 1), _scene('s2', 5)],
      shots: [_shot('a', 1, 1), _shot('b', 1, 2), _shot('c', 5, 1)],
    );
    final cloud = _bundle(
      scenes: [_scene('s1', 1), _scene('s2', 2)],
      shots: [_shot('a', 1, 1), _shot('b', 1, 2), _shot('c', 2, 1), _shot('n', 2, 2)],
    );
    final r = _merge(base, local, cloud);
    expect(_shotOf(r.merged, 'n')['sceneKey'], 'scene:5');
    expect(_shotOf(r.merged, 'c')['sceneKey'], 'scene:5');
    expect(r.discards, isEmpty);
  });

  test('escena borrada en la nube: sus planos se van con ella', () {
    final local = _bundle(
      scenes: [_scene('s1', 1), _scene('s2', 2)],
      shots: [_shot('a', 1, 1), _shot('b', 1, 2), _shot('c', 2, 1, lens: '24mm')],
    );
    final cloud = _bundle(
      scenes: [_scene('s1', 1)],
      shots: [_shot('a', 1, 1), _shot('b', 1, 2)],
    );
    // La escena no se tocó aquí: el borrado de la nube gana; el plano
    // editado aquí se va con ella, y queda anotado.
    final r = _merge(base, local, cloud);
    expect((r.merged['scenes'] as List).map((s) => s['uid']), ['s1']);
    expect((r.merged['shots'] as List).map((s) => s['uid']), ['a', 'b']);
    expect(r.discards.where((d) => d.uid == 'c'), hasLength(1));
  });

  test('las rutas son las de aquí; lo nuevo de la nube lo baja el hidratado', () {
    final b = _bundle(
      scenes: [_scene('s1', 1)],
      shots: [_shot('a', 1, 1, storyboardImagePath: '/mac/a.jpg'), _shot('b', 1, 2)],
    );
    final local = b;
    final cloud = _bundle(
      scenes: [_scene('s1', 1)],
      shots: [
        _shot('a', 1, 1, storyboardImagePath: '/var/mobile/a.jpg'),
        _shot('b', 1, 2, storyboardImagePath: '/var/mobile/b.jpg'),
      ],
    );
    final r = _merge(b, local, cloud);
    expect(_shotOf(r.merged, 'a')['storyboardImagePath'], '/mac/a.jpg');
    expect(_shotOf(r.merged, 'b')['storyboardImagePath'], isNull);
  });

  test('la biblia va entera: gana el lado que cambió, o el más reciente', () {
    final img = {'uid': 'm1', 'caption': 'base', 'localId': 1};
    final b = _bundle(moodboardImages: [img]);
    final local = _bundle(moodboardImages: [{...img, 'caption': 'aquí'}]);
    final cloud = _bundle(moodboardImages: [{...img, 'caption': 'nube'}]);

    final onlyCloud = _merge(b, b, cloud);
    expect((onlyCloud.merged['moodboardImages'] as List).single['caption'], 'nube');
    expect(onlyCloud.discards, isEmpty);

    final both = _merge(b, local, cloud, newer: MergeSide.local);
    expect((both.merged['moodboardImages'] as List).single['caption'], 'aquí');
    expect(both.discards.single.collection, 'biblia');
    expect(both.discards.single.field, isNull);
  });

  test('campos del proyecto, uno a uno', () {
    final b = _bundle(projectFields: {'cardColor': 'rojo', 'cardSize': 'M'});
    final local = _bundle(projectFields: {'cardColor': 'azul', 'cardSize': 'M'});
    final cloud = _bundle(projectFields: {'cardColor': 'rojo', 'cardSize': 'XL'});
    final pf = _merge(b, local, cloud).merged['projectFields'] as Map;
    expect(pf['cardColor'], 'azul');
    expect(pf['cardSize'], 'XL');
  });

  test('una colección con elementos sin uid se decide entera', () {
    final b = _bundle(
      scenes: [_scene('s1', 1)],
      shots: [{..._shot('a', 1, 1), 'uid': null}],
    );
    final local = _bundle(
      scenes: [_scene('s1', 1)],
      shots: [{..._shot('a', 1, 1, lens: '35mm'), 'uid': null}],
    );
    final r = _merge(b, local, b);
    expect((r.merged['shots'] as List).single['lens'], '35mm');
  });
}
