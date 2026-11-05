import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/env_overrides.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_trash_service.dart';

/// SG.1: grupos de sets con luz compartida y cambios de entorno por set.
void main() {
  late AppDatabase db;
  late FloorPlanRepository repo;
  late int projectId;
  late int siteId;
  late int sceneId;

  PlanElement el(
    String uid,
    ElementType type, {
    double x = 0,
    LightType? lightType,
    String? label,
  }) => PlanElement(
    id: 0,
    type: type,
    position: Offset(x, 0),
    lightType: lightType,
    label: label,
    props: {LightOverrides.uidKey: uid},
  );

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FloorPlanRepository(db);
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'SG'));
    siteId = await db.insertSite(
      LocationSitesCompanion.insert(
        projectId: projectId,
        name: 'Calle Raval',
        floorPlanJson: Value(
          FloorPlanJson.encode([
            el('pared', ElementType.wall),
            el('farola', ElementType.prop, x: 10, label: 'farola'),
            el('banco', ElementType.prop, x: 20, label: 'banco'),
          ]),
        ),
      ),
    );
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Escena 1',
        locationCanonical: 'EXT. CALLE - NOCHE',
        locationPureName: 'CALLE',
        locationSiteId: Value(siteId),
      ),
    );
  });

  tearDown(() => db.close());

  Future<Shot> shotOn(int setupId, {int number = 1, String? overrides}) async {
    final id = await db.insertShot(
      ShotsCompanion.insert(
        sceneId: sceneId,
        projectId: projectId,
        number: number,
        lightSetupId: Value(setupId),
        lightOverridesJson: Value(overrides),
      ),
    );
    return (db.select(db.shots)..where((s) => s.id.equals(id))).getSingle();
  }

  Future<LightSetup> newSet(String name, List<PlanElement> light) async {
    final setup = await repo.createLightSetup(
      projectId: projectId,
      siteId: siteId,
      name: name,
    );
    await repo.saveElements(
      scope: FloorPlanScope.lightSetup,
      lightSetupId: setup.id,
      elements: light,
    );
    return (await db.getLightSetupById(setup.id))!;
  }

  test('sin grupo ni cambios, las capas son las de siempre', () async {
    final setup = await newSet('Setup A', [
      el('hmi', ElementType.light, lightType: LightType.hmi),
    ]);
    final layers = await repo.layersForShot(await shotOn(setup.id));
    expect(layers.environment, hasLength(3));
    expect(layers.groupLight, isEmpty);
    expect(layers.group, isNull);
    expect(layers.light.single.lightType, LightType.hmi);
  });

  test('cambios de entorno: sustituye, añade y quita por uid', () async {
    final setup = await newSet('Setup A', []);
    await db.setLightSetupEnvOverrides(
      setup.id,
      EnvOverrides.encode({
        'farola': el('farola', ElementType.prop, x: 99, label: 'farola'),
        'pared': null,
        'contenedor': el('contenedor', ElementType.prop, label: 'contenedor'),
      }),
    );
    final layers = await repo.layersForShot(await shotOn(setup.id));
    final uids = layers.all.map(LightOverrides.uidOf).toList();
    expect(uids, ['farola', 'banco', 'contenedor']);
    expect(layers.environment.first.position.dx, 99);
    // Lo añadido es del set.
    expect(LightOverrides.uidOf(layers.set.single), 'contenedor');

    // El entorno de la localización no se toca.
    final site = await db.getSiteById(siteId);
    expect(FloorPlanJson.decode(site!.floorPlanJson), hasLength(3));

    // Otro set de la misma localización lo ve entero.
    final other = await newSet('Setup B', []);
    final otherLayers = await repo.layersForShot(
      await shotOn(other.id, number: 2),
    );
    expect(otherLayers.environment, hasLength(3));
  });

  test('el marcador «hidden» viaja en el JSON', () {
    final json = EnvOverrides.encode({'pared': null})!;
    expect(json, contains('"hidden":true'));
    expect(EnvOverrides.decode(json), {'pared': null});
  });

  test(
    'la luz del grupo se comparte y el plano conserva sus retoques',
    () async {
      final groupId = await db.insertSetGroup(
        SetGroupsCompanion.insert(
          projectId: projectId,
          locationSiteId: Value(siteId),
          name: 'Fondo fachada kebab',
          planJson: Value(
            FloorPlanJson.encode([
              el('luna', ElementType.light, lightType: LightType.hmi),
            ]),
          ),
        ),
      );
      final a = await newSet('Setup A', [
        el('kino', ElementType.light, lightType: LightType.softbox),
      ]);
      final b = await newSet('Setup B', []);
      await db.assignLightSetupToGroup(a.id, groupId);
      await db.assignLightSetupToGroup(b.id, groupId);

      // El plano 1 retoca la luz del grupo solo para él.
      final tweak = LightOverrides.clone(
        el('luna', ElementType.light, x: 50, lightType: LightType.hmi),
      );
      final shotA = await shotOn(
        a.id,
        overrides: LightOverrides.encode({'luna': tweak}),
      );
      final shotB = await shotOn(b.id, number: 2);

      var layersA = await repo.layersForShot(shotA);
      var layersB = await repo.layersForShot(shotB);
      expect(layersA.group?.id, groupId);
      expect(layersA.groupLight.single.position.dx, 50);
      expect(layersA.groupLight.single.shotOverride, isTrue);
      expect(layersB.groupLight.single.position.dx, 0);
      // Orden: entorno, set, luz del grupo, luz del set, plano.
      expect(layersA.all.map(LightOverrides.uidOf), [
        'pared',
        'farola',
        'banco',
        'luna',
        'kino',
      ]);

      // Se cambia la luz del grupo una vez y cambia en los dos sets.
      await db.setSetGroupPlanJson(
        groupId,
        FloorPlanJson.encode([
          el('luna', ElementType.light, lightType: LightType.hmi),
          el('farol', ElementType.light, x: 30, lightType: LightType.softbox),
        ]),
      );
      layersA = await repo.layersForShot(shotA);
      layersB = await repo.layersForShot(shotB);
      expect(layersA.groupLight, hasLength(2));
      expect(layersB.groupLight, hasLength(2));
      expect(layersA.groupLight.first.position.dx, 50);

      // El esquema también ve la luz del grupo debajo.
      final inherited = await repo.inheritedLayers(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: b.id,
      );
      expect(inherited.groupLight, hasLength(2));
    },
  );

  test('borrar el grupo deja sus sets sin grupo', () async {
    final groupId = await db.insertSetGroup(
      SetGroupsCompanion.insert(projectId: projectId, name: 'G'),
    );
    final a = await newSet('Setup A', []);
    await db.assignLightSetupToGroup(a.id, groupId);
    await db.deleteSetGroup(groupId);
    expect((await db.getLightSetupById(a.id))!.groupId, isNull);
    expect(await db.getSetGroupsForProject(projectId), isEmpty);
  });

  test('papelera: el grupo se va y vuelve con sus sets', () async {
    final groupId = await db.insertSetGroup(
      SetGroupsCompanion.insert(
        projectId: projectId,
        locationSiteId: Value(siteId),
        name: 'G',
      ),
    );
    final a = await newSet('Setup A', []);
    final b = await newSet('Setup B', []);
    await db.assignLightSetupToGroup(a.id, groupId);
    await db.assignLightSetupToGroup(b.id, groupId);

    final trash = PlanTrashService(db);
    final entry = await trash.deleteSetGroup(groupId);
    expect(entry, isNotNull);
    expect(await db.getSetGroupsForProject(projectId), isEmpty);
    expect((await db.getLightSetupById(a.id))!.groupId, isNull);
    expect((await db.getLightSetupById(b.id))!.groupId, isNull);
    // Los sets siguen.
    expect(await db.getLightSetupById(a.id), isNotNull);

    // Mientras tanto, B se va a otro grupo: no se le quita.
    final otherId = await db.insertSetGroup(
      SetGroupsCompanion.insert(projectId: projectId, name: 'Otro'),
    );
    await db.assignLightSetupToGroup(b.id, otherId);

    await trash.restore(entry!);
    final groups = await db.getSetGroupsForProject(projectId);
    final restored = groups.firstWhere((g) => g.name == 'G');
    expect(restored.locationSiteId, siteId);
    expect((await db.getLightSetupById(a.id))!.groupId, restored.id);
    expect((await db.getLightSetupById(b.id))!.groupId, otherId);
  });

  test(
    'papelera: borrar la localización suelta sus grupos y los devuelve',
    () async {
      final groupId = await db.insertSetGroup(
        SetGroupsCompanion.insert(
          projectId: projectId,
          locationSiteId: Value(siteId),
          name: 'G',
        ),
      );
      final trash = PlanTrashService(db);
      final entry = await trash.deleteSite(siteId);
      expect((await db.getSetGroupById(groupId))!.locationSiteId, isNull);
      await trash.restore(entry!);
      final site =
          (await db.getSiteById(siteId)) ??
          (await (db.select(db.locationSites)).get()).single;
      expect((await db.getSetGroupById(groupId))!.locationSiteId, site.id);
    },
  );
}
