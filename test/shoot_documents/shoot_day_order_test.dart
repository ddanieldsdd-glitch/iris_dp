import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/features/shoot_documents/shoot_day_order.dart';
import 'package:iris_dp/shared/technical_script_export/technical_script_doc.dart';

void main() {
  // Bloques 1..6: escenas 4, 4, 6, 4, 5, 5.
  const scenes = {1: 4, 2: 4, 3: 6, 4: 4, 5: 5, 6: 5};
  const shots = {1: 1, 2: 2, 3: 2, 4: 3, 5: 1, 6: 4};
  final ids = [1, 2, 3, 4, 5, 6];

  test('los planos seguidos de una escena forman un tramo', () {
    final tracts = groupShootTracts(ids, (id) => scenes[id]!);
    expect([for (final t in tracts) t.sceneId], [4, 6, 4, 5]);
    expect(tracts.first.blockIds, [1, 2]);
  });

  test('mover un tramo mueve todos sus planos', () {
    final tracts = groupShootTracts(ids, (id) => scenes[id]!);
    expect(moveShootTract(tracts, 3, 0), [5, 6, 1, 2, 3, 4]);
    expect(moveShootTract(tracts, 0, 3), [3, 4, 5, 6, 1, 2]);
  });

  test('orden de guion: por escena y número de plano', () {
    const position = {4: 0, 5: 1, 6: 2};
    expect(
      scriptOrderOf(
        ids,
        scenePosition: (id) => position[scenes[id]]!,
        shotNumber: (id) => shots[id]!,
      ),
      [1, 2, 4, 5, 6, 3],
    );
  });

  test('la línea del índice es como la de la planta de cámara', () {
    expect(
      scriptIndexLabel(
        sceneLabel: '4',
        intExt: 'INT/EXT',
        location: 'Cortijo',
        dayNight: 'Noche',
        shots: ['1', '2'],
      ),
      'ESCENA 4. INT/EXT CORTIJO NOCHE (1-2)',
    );
  });
}
