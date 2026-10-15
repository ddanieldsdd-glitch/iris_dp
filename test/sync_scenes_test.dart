import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/script/script_scene_matcher.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';

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
          sceneText: null,
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
          sceneText: null,
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
          sceneText: null,
        ),
      ]);

      final scenes = await db.watchScenesForProject(projectId).first;
      final sceneId = scenes.first.id;

      await db.insertShot(
        ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: 1,
          framing: const Value('PD'),
        ),
      );

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
          sceneText: null,
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
          sceneText: null,
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
          sceneText: null,
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
          sceneText: null,
        ),
      ]);

      final scenes = await db.watchScenesForProject(projectId).first;
      expect(scenes.length, 1);
    });
  });

  group('actualizar el guion con trabajo ya hecho', () {
    WorkspaceScene scene(String location, String text, int start) => (
      intExt: 'EXT',
      dayNight: 'NOCHE',
      location: location,
      shootSet: location,
      locationSite: location,
      name: null,
      description: null,
      locationColor: null,
      charactersJson: null,
      sourceStartIndex: start,
      sceneText: text,
    );

    const calle = 'Ali conduce serio su moto de reparto por la calle vacía.';
    const rellano = 'La chica recoge el pedido en el rellano y cierra.';
    const kebab = 'Simo y Ali sacan la basura del kebab bajo la persiana.';
    const plaza = 'Amanece en la plaza; un camión de limpieza riega la acera.';

    Future<int> sceneId(int projectId, String location) async {
      final scenes = await db.select(db.scenes).get();
      return scenes
          .firstWhere(
            (s) => s.projectId == projectId && s.locationPureName == location,
          )
          .id;
    }

    Future<void> addShot(int projectId, int scene, String framing) =>
        db.insertShot(
          ShotsCompanion.insert(
            sceneId: scene,
            projectId: projectId,
            number: 1,
            framing: Value(framing),
          ),
        );

    late int projectId;

    setUp(() async {
      projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Kebab Khaled'),
      );
      await db.syncScenesFromWorkspace(projectId, [
        scene('CALLE RAVAL', calle, 0),
        scene('RELLANO', rellano, 100),
        scene('KEBAB', kebab, 200),
      ]);
      await addShot(projectId, await sceneId(projectId, 'CALLE RAVAL'), 'PP');
      await addShot(projectId, await sceneId(projectId, 'RELLANO'), 'PMC');
      await addShot(projectId, await sceneId(projectId, 'KEBAB'), 'PG');
    });

    Future<Map<String, String?>> framingByLocation() async {
      final scenes = await db.select(db.scenes).get();
      final shots = await db.select(db.shots).get();
      return {
        for (final s in scenes)
          s.locationPureName: shots
              .where((sh) => sh.sceneId == s.id)
              .map((sh) => sh.framing)
              .join(','),
      };
    }

    test(
      'una escena nueva en medio no cambia de escena ningún plano',
      () async {
        // Las posiciones en el texto cambian todas, como en un guion reescrito.
        await db.syncScenesFromWorkspace(projectId, [
          scene('CALLE RAVAL', calle, 30),
          scene('PLAZA', plaza, 140),
          scene('RELLANO', rellano, 260),
          scene('KEBAB', kebab, 390),
        ]);

        expect(await framingByLocation(), {
          'CALLE RAVAL': 'PP',
          'PLAZA': '',
          'RELLANO': 'PMC',
          'KEBAB': 'PG',
        });
        final scenes = await db.watchScenesForProject(projectId).first;
        expect(scenes.map((s) => '${s.number} ${s.locationPureName}'), [
          '1 CALLE RAVAL',
          '2 PLAZA',
          '3 RELLANO',
          '4 KEBAB',
        ]);
        expect(scenes.every((s) => s.scriptLinked && !s.offScript), isTrue);
      },
    );

    test('una escena quitada del guion se conserva con sus planos, fuera del '
        'guion, y vuelve a vincularse si reaparece', () async {
      await db.syncScenesFromWorkspace(projectId, [
        scene('CALLE RAVAL', calle, 0),
        scene('KEBAB', kebab, 90),
      ]);

      expect(await framingByLocation(), {
        'CALLE RAVAL': 'PP',
        'RELLANO': 'PMC',
        'KEBAB': 'PG',
      });
      var scenes = await db.watchScenesForProject(projectId).first;
      expect(scenes.map((s) => s.locationPureName), [
        'CALLE RAVAL',
        'KEBAB',
        'RELLANO',
      ]);
      expect(scenes.last.offScript, isTrue);
      expect(scenes.map((s) => s.number).take(2), [1, 2]);

      // Vuelve en una versión posterior: es la misma escena, con su plano.
      await db.syncScenesFromWorkspace(projectId, [
        scene('CALLE RAVAL', calle, 0),
        scene('RELLANO', rellano, 80),
        scene('KEBAB', kebab, 170),
      ]);
      scenes = await db.watchScenesForProject(projectId).first;
      expect(scenes.length, 3);
      expect(scenes.every((s) => !s.offScript), isTrue);
      expect(await framingByLocation(), {
        'CALLE RAVAL': 'PP',
        'RELLANO': 'PMC',
        'KEBAB': 'PG',
      });
    });

    test(
      'si solo cambia el texto, se guarda el nuevo y los planos siguen',
      () async {
        const calleNueva =
            'Ali conduce serio su moto de reparto. Empieza a llover con fuerza.';
        final plan = await db.planScriptUpdate(projectId, [
          scene('CALLE RAVAL', calleNueva, 0),
          scene('RELLANO', rellano, 100),
          scene('KEBAB', kebab, 200),
        ]);
        expect(plan.isTrivial, isTrue);
        expect(plan.count(ScriptSceneChange.textChanged), 1);

        await db.syncScenesFromWorkspace(projectId, [
          scene('CALLE RAVAL', calleNueva, 0),
          scene('RELLANO', rellano, 100),
          scene('KEBAB', kebab, 200),
        ]);
        final scenes = await db.watchScenesForProject(projectId).first;
        expect(scenes.first.actionText, calleNueva);
        expect((await db.select(db.shots).get()).length, 3);
      },
    );

    test('la revisión puede corregir una pareja a mano', () async {
      final rellanoId = await sceneId(projectId, 'RELLANO');
      final calleId = await sceneId(projectId, 'CALLE RAVAL');
      final kebabId = await sceneId(projectId, 'KEBAB');
      // El rellano pasa a ser «PORTAL», con un texto que no se parece.
      await db.syncScenesFromWorkspace(
        projectId,
        [
          scene('CALLE RAVAL', calle, 0),
          scene('PORTAL', 'Adil espera delante de la puerta del portal.', 100),
          scene('KEBAB', kebab, 200),
        ],
        links: [calleId, rellanoId, kebabId],
      );
      expect(await framingByLocation(), {
        'CALLE RAVAL': 'PP',
        'PORTAL': 'PMC',
        'KEBAB': 'PG',
      });
    });
  });

  test('el bundle de sincronización lleva el vínculo con el guion y no '
      'mezcla los planos de dos escenas con el mismo número', () async {
    final source = await db.insertProject(
      ProjectsCompanion.insert(name: 'Origen'),
    );
    final target = await db.insertProject(
      ProjectsCompanion.insert(name: 'Destino'),
    );
    Future<int> addScene(String place, {bool off = false}) => db.insertScene(
      ScenesCompanion.insert(
        projectId: source,
        number: 1,
        name: place,
        locationCanonical: 'EXT. $place - NOCHE',
        locationPureName: place,
        sortOrder: Value(off ? 2 : 1),
        scriptLinked: const Value(true),
        scriptHeadingKey: Value('ext|${place.toLowerCase()}|noche'),
        scriptTextHash: const Value('abc'),
        offScript: Value(off),
      ),
    );
    final inScript = await addScene('CALLE');
    final offScript = await addScene('RELLANO', off: true);
    for (final entry in {inScript: 'PP', offScript: 'PMC'}.entries) {
      await db.insertShot(
        ShotsCompanion.insert(
          sceneId: entry.key,
          projectId: source,
          number: 1,
          framing: Value(entry.value),
          cellStylesJson: const Value('{"action":"green"}'),
        ),
      );
    }

    final bundle = await ProjectContentBundle.export(db, source);
    await ProjectContentBundle.importBundle(db, target, bundle);

    final scenes = await db.watchScenesForProject(target).first;
    expect(scenes.map((s) => s.locationPureName), ['CALLE', 'RELLANO']);
    expect(scenes.map((s) => s.offScript), [false, true]);
    expect(scenes.every((s) => s.scriptLinked), isTrue);
    expect(scenes.first.scriptHeadingKey, 'ext|calle|noche');
    expect(scenes.first.scriptTextHash, 'abc');
    final shots = await db.getShotsForProject(target);
    final framingByScene = {
      for (final s in scenes)
        s.locationPureName: shots
            .where((sh) => sh.sceneId == s.id)
            .map((sh) => sh.framing)
            .join(','),
    };
    expect(framingByScene, {'CALLE': 'PP', 'RELLANO': 'PMC'});
    expect(shots.first.cellStylesJson, '{"action":"green"}');
  });

  test('la copia antes de migrar se hace una vez y solo si hace falta', () {
    final dir = Directory.systemTemp.createTempSync('iris_backup_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/iris_dp.db';
    File(path).writeAsStringSync('datos');

    // Base recién creada o ya migrada: nada que copiar.
    expect(backupBeforeSchemaUpgrade(path, 0), isNull);
    expect(backupBeforeSchemaUpgrade(path, kSchemaVersion), isNull);

    final copy = backupBeforeSchemaUpgrade(path, kSchemaVersion - 1);
    expect(copy, '$path.antes-de-esquema-$kSchemaVersion');
    expect(File(copy!).readAsStringSync(), 'datos');

    // Una segunda apertura no pisa la copia buena.
    File(path).writeAsStringSync('datos ya migrados');
    backupBeforeSchemaUpgrade(path, kSchemaVersion - 1);
    expect(File(copy).readAsStringSync(), 'datos');
  });

  test('cada subida de esquema deja copia y se guardan las tres últimas', () {
    final dir = Directory.systemTemp.createTempSync('iris_backup_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    final path = '${dir.path}/iris_dp.db';
    for (var target = 45; target <= 49; target++) {
      File(path).writeAsStringSync('esquema ${target - 1}');
      File('$path-wal').writeAsStringSync('wal ${target - 1}');
      backupBeforeSchemaUpgrade(path, target - 1, targetVersion: target);
    }
    final copies =
        dir
            .listSync()
            .map((f) => f.path.split('/').last)
            .where((n) => n.contains('antes-de-esquema'))
            .toList()
          ..sort();
    expect(copies, [
      'iris_dp.db.antes-de-esquema-47',
      'iris_dp.db.antes-de-esquema-47-wal',
      'iris_dp.db.antes-de-esquema-48',
      'iris_dp.db.antes-de-esquema-48-wal',
      'iris_dp.db.antes-de-esquema-49',
      'iris_dp.db.antes-de-esquema-49-wal',
    ]);
    expect(
      File('$path.antes-de-esquema-49').readAsStringSync(),
      'esquema 48',
    );
  });
}
