import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('proyecto sin escenas devuelve lista vacía', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Vacío'),
    );

    final scenes = await (db.select(db.scenes)
          ..where((s) => s.projectId.equals(projectId)))
        .get();
    expect(scenes, isEmpty);
  });

  test('listado de planos y elementos de planta en base de datos', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Planta Test'),
    );
    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Escena 1',
        locationCanonical: 'INT. SALA - DÍA',
        locationPureName: 'SALA',
      ),
    );
    final shotId = await db.insertShot(
      ShotsCompanion.insert(
        sceneId: sceneId,
        projectId: projectId,
        number: 1,
      ),
    );

    final shots = await db.getShotsForScene(sceneId);
    expect(shots.single.id, shotId);

    await db.insertCameraPlanElement(
      CameraPlanElementsCompanion.insert(
        shotId: shotId,
        type: 'camera',
        cameraLetter: const Value('A'),
        cameraNumber: const Value(1),
      ),
    );

    final elements = await db.getCameraPlanElementsForShot(shotId);
    expect(elements, hasLength(1));
    expect(elements.first.type, 'camera');
  });
}
