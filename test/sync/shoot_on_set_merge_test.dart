import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/sync/bundle_merge.dart';

/// Un paquete con una jornada y sus planos. [docId] imita el id local de
/// cada equipo: cambia entre el Mac y el iPhone.
Map<String, dynamic> _bundle({
  required int docId,
  String date = '2026-11-13',
  List<String> order = const ['a', 'b'],
  Map<String, Map<String, dynamic>> marks = const {},
}) {
  final key = 'doc:$docId:Jornada 1';
  return jsonDecode(
        jsonEncode({
          'version': 7,
          'projectFields': <String, dynamic>{},
          'scenes': [
            {'uid': 's1', 'sceneKey': 'scene:$docId', 'number': 1},
          ],
          'shots': [
            for (final (i, shot) in const ['a', 'b'].indexed)
              {
                'uid': shot,
                'shotKey': 'shot:$docId:$shot',
                'sceneKey': 'scene:$docId',
                'number': i + 1,
              },
          ],
          'shootDocuments': [
            {
              'documentKey': key,
              'name': 'Jornada 1',
              'shootDate': date,
              'kind': 'technical_day',
            },
          ],
          'shootDocumentBlocks': [
            for (final (i, shot) in order.indexed)
              {
                'documentKey': key,
                'blockType': 'shot',
                'sortOrder': i,
                'shotKey': 'shot:$docId:$shot',
                'contentOverridesJson': marks[shot] == null
                    ? null
                    : jsonEncode({'onSet': marks[shot]}),
              },
          ],
        }),
      )
      as Map<String, dynamic>;
}

Map<String, dynamic>? _markOf(Map<String, dynamic> bundle, String shot) {
  final block = (bundle['shootDocumentBlocks'] as List)
      .cast<Map<String, dynamic>>()
      .firstWhere((b) => '${b['shotKey']}'.endsWith(':$shot'));
  final raw = block['contentOverridesJson'];
  if (raw == null) return null;
  return (jsonDecode(raw as String) as Map)['onSet'] as Map<String, dynamic>?;
}

void main() {
  const done = {'status': 'done', 'at': '2026-11-13T10:00:00.000Z'};
  const dropped = {'status': 'dropped', 'at': '2026-11-13T11:00:00.000Z'};

  test('el iPhone marca en el set y el Mac cambia el orden: no se pierde '
      'ninguna de las dos cosas', () {
    for (final newer in MergeSide.values) {
      final result = BundleMerge.merge(
        baseLocal: _bundle(docId: 70),
        baseCloud: _bundle(docId: 12),
        // Mac: nuevo orden.
        local: _bundle(docId: 70, order: ['b', 'a']),
        // iPhone: «a» hecho.
        cloud: _bundle(docId: 12, marks: {'a': done}),
        newer: newer,
      ).merged;
      expect(_markOf(result, 'a')?['status'], 'done', reason: '$newer');
      if (newer == MergeSide.local) {
        final order = [
          for (final b in result['shootDocumentBlocks'] as List)
            '${b['shotKey']}'.split(':').last,
        ];
        expect(order, ['b', 'a']);
      }
    }
  });

  test('si los dos marcan distinto el mismo plano, gana la última marca', () {
    final result = BundleMerge.merge(
      baseLocal: _bundle(docId: 70),
      baseCloud: _bundle(docId: 12),
      local: _bundle(docId: 70, order: ['b', 'a'], marks: {'a': done}),
      cloud: _bundle(docId: 12, marks: {'a': dropped}),
      newer: MergeSide.local,
    ).merged;
    expect(_markOf(result, 'a')?['status'], 'dropped');
  });

  test('quitar la marca en un lado también viaja', () {
    final result = BundleMerge.merge(
      baseLocal: _bundle(docId: 70, marks: {'b': done}),
      baseCloud: _bundle(docId: 12, marks: {'b': done}),
      local: _bundle(docId: 70, order: ['b', 'a'], marks: {'b': done}),
      cloud: _bundle(docId: 12),
      newer: MergeSide.local,
    ).merged;
    expect(_markOf(result, 'b'), isNull);
  });

  test('si la jornada cambió de fecha, se empareja por nombre', () {
    final result = BundleMerge.merge(
      baseLocal: _bundle(docId: 70),
      baseCloud: _bundle(docId: 12),
      local: _bundle(docId: 70, date: '2026-11-14'),
      cloud: _bundle(docId: 12, marks: {'b': done}),
      newer: MergeSide.local,
    ).merged;
    expect(_markOf(result, 'b')?['status'], 'done');
    expect(
      (result['shootDocuments'] as List).single['shootDate'],
      '2026-11-14',
    );
  });
}
