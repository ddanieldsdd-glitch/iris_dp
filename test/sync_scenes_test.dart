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

  group('syncScenesFromWorkspace', () {
    test('inserta escenas nuevas desde el workspace', () async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Test'),
      );

      await db.syncScenesFromWorkspace(projectId, [
        (
          intExt: 'INT',
          dayNight: 'DÍA',
          location: 'COCINA',
          shootSet: 'COCINA',
          locationSite: 'CASA',
          name: null,
          description: null,
          locationColor: '#FF0000',
          charactersJson: '["MARÍA","GALA"]',
          sourceStartIndex: 100,
        ),
        (
          intExt: 'EXT',
          dayNight: 'NOCHE',
          location: 'CALLE',
          shootSet: 'CALLE',
          locationSite: 'PUEBLO',
          name: 'La huida',
          description: 'Acción',
          locationColor: null,
          charactersJson: null,
          sourceStartIndex: 200,
        ),
      ]);

      final scenes = await db.watchScenesForProject(projectId).first;
      expect(scenes.length, 2);
      expect(scenes[0].locationPureName, 'COCINA');
      expect(scenes[0].sourceStartIndex, 100);
      expect(scenes[0].charactersJson, '["MARÍA","GALA"]');
      expect(scenes[1].dayNight, 'NOCHE');
      expect(scenes[1].name, 'La huida');
    });

    test('preserva planos al sincronizar por sourceStartIndex', () async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Test'),
      );

      await db.syncScenesFromWorkspace(projectId, [
        (
          intExt: 'INT',
          dayNight: 'DÍA',
          location: 'SALA',
          shootSet: 'SALA',
          locationSite: 'CASA',
          name: null,
          description: null,
          locationColor: null,
          charactersJson: null,
          sourceStartIndex: 50,
        ),
      ]);

      final scenes = await db.watchScenesForProject(projectId).first;
      final sceneId = scenes.first.id;

      await db.insertShot(ShotsCompanion.insert(
        sceneId: sceneId,
        projectId: projectId,
        number: 1,
        framing: const Value('PD'),
      ));

      await db.syncScenesFromWorkspace(projectId, [
        (
          intExt: 'INT',
          dayNight: 'NOCHE',
          location: 'SALA ACTUALIZADA',
          shootSet: 'SALA',
          locationSite: 'CASA',
          name: null,
          description: null,
          locationColor: null,
          charactersJson: null,
          sourceStartIndex: 50,
        ),
      ]);

      final updated = await db.watchScenesForProject(projectId).first;
      expect(updated.length, 1);
      expect(updated.first.dayNight, 'NOCHE');
      expect(updated.first.id, sceneId);

      final shots = await db.watchShotsForScene(sceneId).first;
      expect(shots.length, 1);
      expect(shots.first.framing, 'PD');
    });

    test('elimina escenas sobrantes al sincronizar', () async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Test'),
      );

      await db.syncScenesFromWorkspace(projectId, [
        (
          intExt: 'INT',
          dayNight: 'DÍA',
          location: 'A',
          shootSet: 'A',
          locationSite: 'A',
          name: null,
          description: null,
          locationColor: null,
          charactersJson: null,
          sourceStartIndex: 1,
        ),
        (
          intExt: 'EXT',
          dayNight: 'NOCHE',
          location: 'B',
          shootSet: 'B',
          locationSite: 'B',
          name: null,
          description: null,
          locationColor: null,
          charactersJson: null,
          sourceStartIndex: 2,
        ),
      ]);

      await db.syncScenesFromWorkspace(projectId, [
        (
          intExt: 'INT',
          dayNight: 'DÍA',
          location: 'A',
          shootSet: 'A',
          locationSite: 'A',
          name: null,
          description: null,
          locationColor: null,
          charactersJson: null,
          sourceStartIndex: 1,
        ),
      ]);

      final scenes = await db.watchScenesForProject(projectId).first;
      expect(scenes.length, 1);
    });
  });

  group('findScenesWithShotsToRemoveOnSync', () {
    test('detecta escenas con planos que se eliminarían', () async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Test'),
      );

      await db.syncScenesFromWorkspace(projectId, [
        (
          intExt: 'INT',
          dayNight: 'DÍA',
          location: 'A',
          shootSet: 'A',
          locationSite: 'A',
          name: null,
          description: null,
          locationColor: null,
          charactersJson: null,
          sourceStartIndex: 10,
        ),
        (
          intExt: 'EXT',
          dayNight: 'NOCHE',
          location: 'B',
          shootSet: 'B',
          locationSite: 'B',
          name: null,
          description: null,
          locationColor: null,
          charactersJson: null,
          sourceStartIndex: 20,
        ),
      ]);

      final scenes = await db.watchScenesForProject(projectId).first;
      await db.insertShot(ShotsCompanion.insert(
        sceneId: scenes[1].id,
        projectId: projectId,
        number: 1,
      ));

      final atRisk = await db.findScenesWithShotsToRemoveOnSync(
        projectId,
        [10],
        1,
      );

      expect(atRisk.length, 1);
      expect(atRisk.first.sourceStartIndex, 20);
    });

    test('no reporta escenas sin planos', () async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Test'),
      );

      await db.syncScenesFromWorkspace(projectId, [
        (
          intExt: 'INT',
          dayNight: 'DÍA',
          location: 'A',
          shootSet: 'A',
          locationSite: 'A',
          name: null,
          description: null,
          locationColor: null,
          charactersJson: null,
          sourceStartIndex: 10,
        ),
        (
          intExt: 'EXT',
          dayNight: 'NOCHE',
          location: 'B',
          shootSet: 'B',
          locationSite: 'B',
          name: null,
          description: null,
          locationColor: null,
          charactersJson: null,
          sourceStartIndex: 20,
        ),
      ]);

      final atRisk = await db.findScenesWithShotsToRemoveOnSync(
        projectId,
        [10],
        1,
      );

      expect(atRisk, isEmpty);
    });
  });
}
