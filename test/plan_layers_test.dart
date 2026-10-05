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
import 'package:iris_dp/features/camera_plan/light/photometry.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/light_beam.dart';
import 'package:iris_dp/features/camera_plan/plan_data.dart';
import 'package:iris_dp/features/camera_plan/plan_equipment.dart';
import 'package:iris_dp/features/camera_plan/plan_gear_list.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';

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

  group('haz de luz y lista de material', () {
    PlanElement light(LightType type, {Map<String, dynamic>? props}) =>
        PlanElement(
          id: 0,
          type: ElementType.light,
          position: Offset.zero,
          lightType: type,
          props: props,
        );

    test('una luz toma su haz del tipo y lo cambia con sus propiedades', () {
      final fresnel = LightBeam.of(light(LightType.fresnelMedium))!;
      expect(fresnel.spread, 40);
      expect(fresnel.cct, 3200);
      expect(fresnel.off, isFalse);

      final tuned = LightBeam.of(
        light(
          LightType.fresnelMedium,
          props: {'spread': 24, 'throw': 550, 'intensity': 78, 'cct': 5600},
        ),
      )!;
      expect(tuned.spread, 24);
      expect(tuned.reach, 550);
      expect(tuned.intensity, 78);
      expect(tuned.cct, 5600);

      expect(
        LightBeam.of(light(LightType.hmi, props: {'off': true}))!.off,
        isTrue,
      );
    });

    test('el grip no emite luz', () {
      expect(LightBeam.of(light(LightType.flag)), isNull);
      expect(LightBeam.of(light(LightType.bounce)), isNull);
    });

    test('la luz cálida tira a naranja y la fría a azul', () {
      final warm = LightBeam.colorForCct(2800);
      final cool = LightBeam.colorForCct(9000);
      expect(warm.r, greaterThan(warm.b));
      expect(cool.b, greaterThan(cool.r));
    });

    test('el haz se guarda y se lee con la planta', () {
      final json = FloorPlanJson.encode([
        light(LightType.hmi, props: {'spread': 74, 'cct': 5600, 'off': true}),
      ]);
      final beam = LightBeam.of(FloorPlanJson.decode(json).single)!;
      expect(beam.spread, 74);
      expect(beam.off, isTrue);
    });

    test('el ángulo de visión sale de la focal y el sensor', () {
      expect(cameraFovDegrees('35mm')!, closeTo(39.1, 0.3));
      expect(cameraFovDegrees('50')!, closeTo(28.0, 0.3));
      expect(
        cameraFovDegrees('35mm', sensorWidthMm: 36)!,
        greaterThan(cameraFovDegrees('35mm')!),
      );
      expect(cameraFovDegrees(null), isNull);
      expect(cameraFovDegrees('zoom'), isNull);
    });

    test('la lista de material agrupa y cuenta', () {
      final gear = GearList.from([
        light(LightType.hmi),
        light(LightType.hmi),
        light(LightType.softbox, props: {'name': 'Titan Tube'}),
        light(LightType.flag),
        PlanElement(
          id: 0,
          type: ElementType.camera,
          position: Offset.zero,
          lens: '35mm',
          stabilization: 'DOLLY',
        ),
        PlanElement(id: 0, type: ElementType.wall, position: Offset.zero),
      ]);
      expect(gear.lights.map((l) => '$l'), ['2× HMI', '1× Titan Tube']);
      expect(gear.filters, isEmpty);
      final filtered = GearList.from([
        light(
          LightType.hmi,
          props: {
            'modifiers': ['white-full', 'cto-half'],
          },
        ),
        light(
          LightType.hmi,
          props: {
            'modifiers': ['white-full'],
          },
        ),
      ]);
      expect(filtered.filters.map((l) => '$l'), [
        '2× Difusión blanca (Rosco 3026 · 216)',
        '1× ½ CTO (Rosco 3408)',
      ]);
      expect(gear.grip.map((l) => '$l'), ['1× Negro']);
      expect(gear.cameras.map((l) => '$l'), ['1× Cámara A · 35mm · DOLLY']);
      expect(
        gear.toText(title: 'Setup A'),
        'Setup A\nLUCES\n  2× HMI\n  1× Titan Tube\nGRIP\n  1× Negro\n'
        'CÁMARA\n  1× Cámara A · 35mm · DOLLY\n'
        'CORRIENTE\n  3900 W encendidos · 17.0 A a 230 V\n'
        '  2 circuitos de 16 A (máx. 2944 W cada uno)',
      );
      expect(GearList.from(const []).isEmpty, isTrue);
      // Dos HMI de 1800 W, un LED de 300 W; la bandera no consume.
      expect(gear.watts, 3900);
      expect(gear.amps, closeTo(16.96, 0.01));
      expect(gear.circuits, 2);
      expect(gear.toText(), contains('CORRIENTE'));
      final dark = GearList.from([
        light(LightType.hmi, props: {'off': true}),
      ]);
      expect(dark.watts, 0);
      expect(dark.circuits, 0);
    });
  });

  group('tramos punto a punto', () {
    test('un tramo recto mide lo que separa sus extremos', () {
      final wall = PlanSegment.create(
        start: const Offset(100, 100),
        end: const Offset(400, 500),
      );
      expect(PlanSegment.isSegment(wall), isTrue);
      expect(PlanSegment.length(wall), 500);
      expect(PlanSegment.kind(wall), PlanSegment.kindWall);
      expect(formatMeters(500, 0.02), '10.0 m');
      expect(formatMeters(300, 0.02), '6.00 m');
    });

    test('mover el elemento mueve el tramo entero', () {
      final wall = PlanSegment.create(
        start: const Offset(100, 100),
        end: const Offset(300, 100),
      );
      wall.position += const Offset(50, 20);
      expect(PlanSegment.end(wall), const Offset(350, 120));
    });

    test('mover un extremo deja el otro en su sitio', () {
      final wall = PlanSegment.create(
        start: const Offset(100, 100),
        end: const Offset(300, 100),
      );
      PlanSegment.setStart(wall, const Offset(100, 200));
      expect(PlanSegment.start(wall), const Offset(100, 200));
      expect(PlanSegment.end(wall), const Offset(300, 100));
    });

    test('curvar hace pasar el centro por el punto y alarga el tramo', () {
      final wall = PlanSegment.create(
        start: const Offset(0, 0),
        end: const Offset(200, 0),
      );
      PlanSegment.bendThrough(wall, const Offset(100, 50));
      final mid = PlanSegment.midpoint(wall);
      expect(mid.dx, closeTo(100, 0.001));
      expect(mid.dy.abs(), closeTo(50, 0.001));
      expect(PlanSegment.pointAt(wall, 0.5), mid);
      expect(PlanSegment.length(wall), greaterThan(200));
      // Casi recto vuelve a recto.
      PlanSegment.bendThrough(wall, const Offset(100, 1));
      expect(PlanSegment.curve(wall), 0);
    });

    test('la distancia a un tramo sirve para seleccionarlo', () {
      final wall = PlanSegment.create(
        start: const Offset(0, 0),
        end: const Offset(200, 0),
      );
      expect(PlanSegment.distanceTo(wall, const Offset(100, 6)), 6);
      expect(PlanSegment.distanceTo(wall, const Offset(260, 0)), 60);
    });

    test('calle y relieve se guardan con su tipo', () {
      final street = PlanSegment.create(
        start: Offset.zero,
        end: const Offset(100, 0),
        kind: PlanSegment.kindStreet,
      );
      final back = FloorPlanJson.decode(FloorPlanJson.encode([street])).single;
      expect(PlanSegment.isSegment(back), isTrue);
      expect(PlanSegment.kind(back), PlanSegment.kindStreet);
      expect(back.displayLabel, 'Calle');
    });
  });

  group('equipo y tiros', () {
    test('una luz del catálogo llega a la planta con sus datos', () async {
      final id = await db.insertLight(
        LightsCompanion.insert(
          brand: 'ARRI',
          model: 'M18',
          lightType: 'hmi',
          powerW: 1800,
          colorTempMin: 5600,
          colorTempMax: 5600,
          beamAngleDeg: const Value(52),
          photometryLux: const Value(4550),
          photometryDistanceM: const Value(5),
        ),
      );
      final el = PlanEquipment.lightFromCatalog((await db.getLightById(id))!);
      expect(el.lightType, LightType.hmi);
      expect(el.props['name'], 'ARRI M18');
      expect(el.externalMapping.catalogLightId, id);

      el.props['intensity'] = 100;
      final light = PlanLight.of(el)!;
      expect(light.watts, 1800);
      expect(light.tech, LightTech.hmi);
      expect(light.source.beamDeg, 52);
      // Con fotometría del fabricante, el cálculo parte de ella.
      expect(light.source.status, PhotometryStatus.manufacturer);
      expect(light.source.illuminance(5), closeTo(4550, 5));

      // Sin fotometría, se estima.
      final bareId = await db.insertLight(
        LightsCompanion.insert(
          brand: 'Aputure',
          model: '600d',
          lightType: 'led',
          powerW: 600,
          colorTempMin: 5600,
          colorTempMax: 5600,
        ),
      );
      final bare = PlanEquipment.lightFromCatalog(
        (await db.getLightById(bareId))!,
      )..props['intensity'] = 100;
      expect(PlanLight.of(bare)!.source.status, PhotometryStatus.estimated);
    });

    test('los planos de una escena se agrupan por su esquema de luz', () async {
      final a = await addShot(1);
      final b = await addShot(2);
      final c = await addShot(3);
      final d = await addShot(4);
      final setupA = await repo.createLightSetup(
        projectId: projectId,
        setId: setId,
      );
      final setupB = await repo.createLightSetup(
        projectId: projectId,
        setId: setId,
      );
      await db.assignLightSetupToShot(a, setupA.id);
      await db.assignLightSetupToShot(b, setupB.id);
      await db.assignLightSetupToShot(c, setupA.id);
      await addElement(a, 'camera', x: 300, y: 300);

      final data = PlanProjectData(
        sites: await db.watchSitesForProject(projectId).first,
        sets: await db.watchLocationsForProject(projectId).first,
        setups: await db.getLightSetupsForProject(projectId),
        scenes: await db.watchScenesForProject(projectId).first,
        shots: await db.watchShotsForProject(projectId).first,
        elementRows: await db
            .watchCameraPlanElementsForProject(projectId)
            .first,
      );
      final tiros = data.tirosOf(data.scenes.single);
      expect(tiros.map((t) => t.setup?.name), ['Setup A', 'Setup B', null]);
      expect(tiros[0].shots.map((s) => s.id), [a, c]);
      expect(tiros[1].shots.map((s) => s.id), [b]);
      expect(tiros[2].shots.map((s) => s.id), [d]);
      // En la planta del tiro, cada cámara lleva el rótulo de su plano.
      final camera = data.ownOfShot(tiros[0].shots.first, tagged: true).single;
      expect(camera.props['shotTag'], '1·1');
    });
  });
}
