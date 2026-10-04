import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Offset, Rect;
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/plan_layer_migration.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';

const _wallV1 =
    '{"version":1,"elements":[{"type":"wall","x":100,"y":100,"rotation":0,'
    '"label":"wall","cameraLetter":"A","cameraNumber":1,"pathPoints":[]}]}';
const _treeV1 =
    '{"version":1,"elements":[{"type":"prop","x":900,"y":400,"rotation":0,'
    '"label":"rectangle","cameraLetter":"A","cameraNumber":1,"pathPoints":[]}]}';

void main() {
  late AppDatabase db;
  late FloorPlanRepository repo;
  late int projectId;
  late int siteId;
  late int setId;
  late int sceneId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FloorPlanRepository(db);
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'Capas'));
    siteId = await db.insertSite(
      LocationSitesCompanion.insert(
        projectId: projectId,
        name: 'Bosque',
        floorPlanJson: const Value(_treeV1),
      ),
    );
    setId = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        locationName: 'Cabaña',
        floorPlanJson: const Value(_wallV1),
      ),
    );
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Escena 1',
        locationCanonical: 'INT. CABAÑA - NOCHE',
        locationPureName: 'CABAÑA',
        locationSiteId: Value(siteId),
        locationId: Value(setId),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> addShot(int number) => db.insertShot(
    ShotsCompanion.insert(
      sceneId: sceneId,
      projectId: projectId,
      number: number,
    ),
  );

  Future<void> addElement(
    int shotId,
    String type, {
    double x = 0,
    double y = 0,
    String? label,
    String? lightType,
  }) => db.insertCameraPlanElement(
    CameraPlanElementsCompanion.insert(
      shotId: shotId,
      type: type,
      x: Value(x),
      y: Value(y),
      label: Value(label),
      lightType: Value(lightType),
    ),
  );

  Future<Shot> shot(int id) =>
      (db.select(db.shots)..where((s) => s.id.equals(id))).getSingle();

  group('formato del plano', () {
    test('lee la versión 1', () {
      final doc = FloorPlanJson.decodeDocument(_wallV1);
      expect(doc.elements.single.type, ElementType.wall);
      expect(doc.metersPerUnit, isNull);
      expect(doc.underlay, isNull);
    });

    test('la versión 2 conserva escala, fondo y propiedades', () {
      final json = FloorPlanJson.encodeDocument(
        FloorPlanDocument(
          metersPerUnit: 0.01,
          underlay: const FloorPlanUnderlay(
            path: 'plano.png',
            rect: Rect.fromLTWH(10, 20, 300, 200),
            opacity: 0.5,
            kind: 'boceto',
          ),
          elements: [
            PlanElement(
              id: 0,
              type: ElementType.light,
              position: const Offset(50, 60),
              lightType: LightType.softbox,
              props: {'cct': 5600, 'spread': 40},
            ),
          ],
        ),
      );
      expect(jsonDecode(json)['version'], 2);

      final doc = FloorPlanJson.decodeDocument(json);
      expect(doc.metersPerUnit, 0.01);
      expect(doc.underlay!.kind, 'boceto');
      expect(doc.underlay!.rect.width, 300);
      expect(doc.elements.single.props['cct'], 5600);
    });
  });

  group('capas', () {
    test('el plano ve el entorno, el set y la luz por referencia', () async {
      final shotId = await addShot(1);
      await addElement(shotId, 'camera', x: 300, y: 300);
      final setup = await repo.createLightSetup(
        projectId: projectId,
        setId: setId,
      );
      await repo.saveElements(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: setup.id,
        elements: [
          PlanElement(
            id: 0,
            type: ElementType.light,
            position: const Offset(200, 200),
            lightType: LightType.hmi,
          ),
        ],
      );
      await db.assignLightSetupToShot(shotId, setup.id);

      final layers = await repo.layersForShot(await shot(shotId));
      expect(layers.environment.single.type, ElementType.prop);
      expect(layers.set.single.type, ElementType.wall);
      expect(layers.light.single.lightType, LightType.hmi);
      expect(layers.shot.single.type, ElementType.camera);
      expect(layers.all, hasLength(4));

      // Lo heredado no se guarda en el plano.
      expect(await db.getCameraPlanElementsForShot(shotId), hasLength(1));
    });

    test('cambiar el set se refleja en el plano sin tocarlo', () async {
      final shotId = await addShot(1);
      await repo.saveElements(
        scope: FloorPlanScope.set,
        setId: setId,
        elements: const [],
      );
      final layers = await repo.layersForShot(await shot(shotId));
      expect(layers.set, isEmpty);
      expect(layers.environment, hasLength(1));
    });

    test(
      'un esquema de luz libre no necesita escenas ni localización',
      () async {
        final setup = await repo.createLightSetup(projectId: projectId);
        expect(setup.locationBasePlanId, isNull);
        expect(setup.locationSiteId, isNull);
        expect(setup.status, 'boceto');
        final second = await repo.createLightSetup(projectId: projectId);
        expect([setup.name, second.name], ['Setup A', 'Setup B']);
      },
    );

    test('guardar elementos conserva la escala de la capa', () async {
      final setup = await repo.createLightSetup(projectId: projectId);
      await db.updateLightSetup(
        setup.copyWith(
          planJson: Value(
            FloorPlanJson.encodeDocument(
              const FloorPlanDocument(metersPerUnit: 0.02),
            ),
          ),
        ),
      );
      await repo.saveElements(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: setup.id,
        elements: [
          PlanElement(
            id: 0,
            type: ElementType.light,
            position: Offset.zero,
            lightType: LightType.led,
          ),
        ],
      );
      final saved = await db.getLightSetupById(setup.id);
      final doc = FloorPlanJson.decodeDocument(saved!.planJson);
      expect(doc.metersPerUnit, 0.02);
      expect(doc.elements, hasLength(1));
    });

    test('borrar un esquema deja los planos sin luz, no los borra', () async {
      final shotId = await addShot(1);
      final setup = await repo.createLightSetup(
        projectId: projectId,
        setId: setId,
      );
      await db.assignLightSetupToShot(shotId, setup.id);
      await db.deleteLightSetup(setup.id);
      expect((await shot(shotId)).lightSetupId, isNull);
    });
  });

  group('migración a capas', () {
    test('planos con la misma luz comparten esquema', () async {
      final a = await addShot(1);
      final b = await addShot(2);
      final c = await addShot(3);
      for (final id in [a, b]) {
        await addElement(id, 'light', x: 200, y: 200, lightType: 'hmi');
        await addElement(id, 'camera', x: 300, y: 300);
        // Pared copiada del set al heredar.
        await addElement(id, 'wall', x: 100, y: 100, label: 'wall');
      }
      await addElement(c, 'light', x: 500, y: 500, lightType: 'softbox');
      // Pared propia del plano: no coincide con la del set.
      await addElement(c, 'wall', x: 700, y: 700, label: 'wall');

      await PlanLayerMigration(db).run();

      final setups = await db.getLightSetupsForProject(projectId);
      expect(setups.map((s) => s.name), ['Setup A', 'Setup B']);
      expect(setups.every((s) => s.locationBasePlanId == setId), isTrue);

      final shotA = await shot(a);
      final shotB = await shot(b);
      final shotC = await shot(c);
      expect(shotA.lightSetupId, setups[0].id);
      expect(shotB.lightSetupId, setups[0].id);
      expect(shotC.lightSetupId, setups[1].id);

      final rowsA = await db.getCameraPlanElementsForShot(a);
      expect(rowsA.map((r) => r.type), ['camera']);
      final rowsC = await db.getCameraPlanElementsForShot(c);
      expect(rowsC.map((r) => r.type), ['wall']);

      // Lo que se ve en el plano no cambia.
      final layers = await repo.layersForShot(shotA);
      expect(layers.light.single.lightType, LightType.hmi);
      expect(layers.set.single.type, ElementType.wall);
    });

    test('es idempotente', () async {
      final a = await addShot(1);
      await addElement(a, 'light', x: 200, y: 200, lightType: 'hmi');
      await PlanLayerMigration(db).run();
      await PlanLayerMigration(db).run();
      expect(await db.getLightSetupsForProject(projectId), hasLength(1));
    });

    test('el diagrama de la biblia pasa a esquema «boceto»', () async {
      final bibleId = await db
          .into(db.visualBibles)
          .insert(VisualBiblesCompanion.insert(projectId: projectId));
      final bibleSetupId = await db.insertLightingSetup(
        LightingSetupsCompanion.insert(
          bibleId: bibleId,
          setupName: 'Noche en la cabaña',
          diagramJson:
              '[{"type":"key","x":50,"y":40,"rotation":30,"label":"M18"},'
              '{"type":"subject","x":100,"y":100},'
              '{"type":"camera","x":150,"y":160}]',
          locationBasePlanId: Value(setId),
        ),
      );
      final emptyId = await db.insertLightingSetup(
        LightingSetupsCompanion.insert(
          bibleId: bibleId,
          setupName: 'Vacío',
          diagramJson: '[]',
        ),
      );

      await PlanLayerMigration(db).run();
      await PlanLayerMigration(db).run();

      final setup = (await db.getLightSetupsForProject(projectId)).single;
      expect(setup.name, 'Noche en la cabaña');
      expect(setup.status, 'boceto');
      expect(setup.origin, 'biblia');
      expect(setup.locationBasePlanId, setId);

      final elements = FloorPlanJson.decode(setup.planJson);
      expect(elements.map((e) => e.type), [
        ElementType.light,
        ElementType.actor,
        ElementType.camera,
      ]);
      expect(elements.first.props['role'], 'key');
      expect(elements.first.props['name'], 'M18');

      final rows = await db.select(db.lightingSetups).get();
      final migrated = rows.firstWhere((r) => r.id == bibleSetupId);
      expect(migrated.planSetupId, setup.id);
      // La biblia conserva su diagrama.
      expect(migrated.diagramJson, contains('"key"'));
      expect(rows.firstWhere((r) => r.id == emptyId).planSetupId, isNull);
    });
  });

  test('el bundle lleva esquemas, asignación y propiedades', () async {
    final shotId = await addShot(1);
    final setup = await repo.createLightSetup(
      projectId: projectId,
      setId: setId,
      name: 'Setup noche',
    );
    await db.updateLightSetup(
      setup.copyWith(
        status: 'definitivo',
        planJson: const Value('{"version":2,"elements":[]}'),
      ),
    );
    await db.assignLightSetupToShot(shotId, setup.id);
    await db.insertCameraPlanElement(
      CameraPlanElementsCompanion.insert(
        shotId: shotId,
        type: 'camera',
        propsJson: const Value('{"lensMm":35}'),
      ),
    );

    final bundle =
        jsonDecode(jsonEncode(await ProjectContentBundle.export(db, projectId)))
            as Map<String, dynamic>;
    final targetId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Destino'),
    );
    await ProjectContentBundle.importBundle(db, targetId, bundle);

    final imported = (await db.getLightSetupsForProject(targetId)).single;
    expect(imported.name, 'Setup noche');
    expect(imported.status, 'definitivo');
    expect(imported.locationBasePlanId, isNotNull);
    expect(imported.locationBasePlanId, isNot(setId));

    final importedShot = await (db.select(
      db.shots,
    )..where((s) => s.projectId.equals(targetId))).getSingle();
    expect(importedShot.lightSetupId, imported.id);
    final rows = await db.getCameraPlanElementsForShot(importedShot.id);
    expect(rows.single.propsJson, '{"lensMm":35}');
  });
}
