import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';

void main() {
  late AppDatabase db;
  late FloorPlanRepository repo;
  late int projectId;
  late int siteId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FloorPlanRepository(db);
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Kebab Khaled'),
    );
    siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Calle Raval'),
    );
  });

  tearDown(() async => db.close());

  PlanElement light(double x, {String uid = ''}) => PlanElement(
    id: 0,
    type: ElementType.light,
    position: Offset(x, 10),
    props: {if (uid.isNotEmpty) LightOverrides.uidKey: uid},
  );

  /// La luz general de la calle, con dos farolas colocadas.
  Future<LightSetup> siteLight() async {
    final setup = await repo.createLightSetup(
      projectId: projectId,
      siteId: siteId,
    );
    await repo.saveElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: setup.id,
      elements: [light(10, uid: 'farola1'), light(50, uid: 'farola2')],
    );
    return (await db.getLightSetupById(setup.id))!;
  }

  Future<int> newSet(String name) => db.insertLocation(
    LocationBasePlansCompanion.insert(
      projectId: projectId,
      siteId: Value(siteId),
      locationName: name,
    ),
  );

  test('un esquema de un set empieza con las luces de la localización, '
      'copiadas', () async {
    final general = await siteLight();
    final kebabId = await newSet('Kebab');

    expect(await repo.siteLightSetups(projectId, siteId), [general]);

    final setup = await repo.createLightSetupFrom(general, setId: kebabId);
    expect(setup.locationBasePlanId, kebabId);
    expect(setup.locationSiteId, isNull);
    expect(setup.kind, LightSetupKind.plan);
    final lights = FloorPlanJson.decode(setup.planJson);
    expect(lights.map((e) => e.position.dx), [10, 50]);
    // Son copias: identificadores nuevos.
    expect(
      lights.map(LightOverrides.uidOf),
      everyElement(isNot(anyOf('farola1', 'farola2'))),
    );

    // Cambiar la localización después no toca el esquema del set.
    await repo.saveElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: general.id,
      elements: [light(99)],
    );
    final again = await db.getLightSetupById(setup.id);
    expect(FloorPlanJson.decode(again!.planJson).length, 2);
  });

  test('un set nuevo parte de otro set, con o sin sus luces', () async {
    final barraId = await newSet('Barra');
    final barra = (await db.getLocationById(barraId))!;
    await repo.saveElements(
      scope: FloorPlanScope.set,
      setId: barraId,
      elements: [
        PlanElement(
          id: 0,
          type: ElementType.wall,
          position: const Offset(1, 2),
          props: {LightOverrides.uidKey: 'pared'},
        ),
      ],
    );
    final setup = await repo.createLightSetup(
      projectId: projectId,
      setId: barraId,
    );
    await repo.saveElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: setup.id,
      elements: [light(5)],
    );
    final source = (await db.getLocationById(barraId))!;
    expect(source.id, barra.id);

    final withLights = await repo.createSet(
      projectId: projectId,
      siteId: siteId,
      name: 'Barra noche',
      fromSet: source,
      includeLights: true,
    );
    final walls = FloorPlanJson.decode(withLights.floorPlanJson);
    expect(walls.single.type, ElementType.wall);
    expect(LightOverrides.uidOf(walls.single), isNot('pared'));
    final copied = (await db.getLightSetupsForProject(
      projectId,
    )).where((s) => s.locationBasePlanId == withLights.id).toList();
    expect(copied.single.name, setup.name);
    expect(FloorPlanJson.decode(copied.single.planJson).single.position.dx, 5);

    final noLights = await repo.createSet(
      projectId: projectId,
      siteId: siteId,
      name: 'Barra vacía',
      fromSet: source,
    );
    expect(FloorPlanJson.decode(noLights.floorPlanJson).length, 1);
    expect(
      (await db.getLightSetupsForProject(
        projectId,
      )).where((s) => s.locationBasePlanId == noLights.id),
      isEmpty,
    );
  });

  test('un set nuevo parte de la localización con su luz general', () async {
    await siteLight();
    final set = await repo.createSet(
      projectId: projectId,
      siteId: siteId,
      name: 'Acera',
      fromSite: true,
      includeLights: true,
    );
    expect(set.siteId, siteId);
    final setups = (await db.getLightSetupsForProject(
      projectId,
    )).where((s) => s.locationBasePlanId == set.id).toList();
    expect(FloorPlanJson.decode(setups.single.planJson).length, 2);
    // La luz general sigue en la localización.
    expect(await repo.siteLightSetups(projectId, siteId), hasLength(1));
  });
}
