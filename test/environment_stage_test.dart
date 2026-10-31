import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';
import 'package:iris_dp/features/camera_plan/light/ambient.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';
import 'package:iris_dp/features/camera_plan/set_environment.dart';
import 'package:iris_dp/features/unreal_link/unreal_stage_payload.dart';

/// Plató, interior o exterior (F6.21.1).
void main() {
  const mpu = 0.01;
  const day = PlanAmbient(day: true);
  const studio = SetEnvironment(kind: SetEnvironmentKind.studio);
  const outside = SetEnvironment(
    kind: SetEnvironmentKind.exterior,
    ground: SetGround.asphalt,
  );

  PlanElement fresnel() => PlanElement(
    id: 1,
    type: ElementType.light,
    position: Offset.zero,
    lightType: LightType.fresnelMedium,
    props: {'uid': 'L', 'intensity': 100},
  );

  test('sin entorno guardado es interior, y se lee lo que se guarda', () {
    expect(FloorPlanRepository.environmentOf(null), const SetEnvironment());
    final json = FloorPlanJson.encodeDocument(
      FloorPlanDocument(environment: outside.toJson()),
    );
    expect(FloorPlanRepository.environmentOf(json), outside);
    // Lo que no se entiende vale interior.
    expect(
      SetEnvironment.fromJson({'kind': 'luna'}).kind,
      SetEnvironmentKind.interior,
    );
  });

  test('guardar los elementos o el entorno no borra lo otro', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Rodaje'),
    );
    final setId = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        locationName: 'Plató 2',
      ),
    );
    final repo = FloorPlanRepository(db);
    await repo.saveEnvironment(studio, setId: setId);
    await repo.saveElements(
      scope: FloorPlanScope.set,
      setId: setId,
      elements: [fresnel()],
    );
    final set = await db.getLocationById(setId);
    expect(FloorPlanRepository.environmentOf(set!.floorPlanJson), studio);
    expect(FloorPlanJson.decode(set.floorPlanJson), hasLength(1));
  });

  test('en un plató el fotómetro no cuenta ni el sol ni el cielo', () {
    final effective = studio.effective(day);
    expect(effective.hasSun, isFalse);
    expect(effective.hasSky, isFalse);
    expect(outside.effective(day).hasSun, isTrue);
    // De día en plató da lo mismo que de noche: solo el foco.
    double lux(PlanAmbient a) => LightScene.from(
      [fresnel()],
      metersPerUnit: mpu,
      ambient: a,
    ).luxAt(const Offset(0, -200));
    expect(
      lux(effective),
      closeTo(lux(const PlanAmbient().copyWith(skyOn: false)), 1e-6),
    );
  });

  test('la escena y Unreal llevan el entorno; en plató sin sol ni cielo', () {
    final scene = PlanScene3d.build(
      [fresnel()],
      metersPerUnit: mpu,
      ambient: day,
      environment: studio,
    );
    expect(scene['environment']['kind'], 'studio');
    expect(scene.containsKey('sun'), isFalse);
    final payload = UnrealStagePayload.build(scene);
    expect(payload['environment']['kind'], 'studio');
    expect(payload['sky'], isNull);

    final out = UnrealStagePayload.build(
      PlanScene3d.build(
        [fresnel()],
        metersPerUnit: mpu,
        ambient: day,
        environment: outside,
      ),
    );
    expect(out['environment']['groundRgb'], SetGround.asphalt.rgb);
    expect(out['sun'], isNotNull);
    // Cambiar el entorno se manda solo, con el sol y el cielo nuevos.
    final diff = UnrealStagePayload.diff(payload, out)!;
    expect(diff['environment']['kind'], 'exterior');
    expect(diff['sun'], isNotNull);
    expect(UnrealStagePayload.diff(out, out), isNull);
  });
}
