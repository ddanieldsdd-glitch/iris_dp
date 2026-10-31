import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/light/plan_grip.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';
import 'package:iris_dp/features/unreal_link/unreal_stage_payload.dart';

/// Marcos, palios y difusión en la planta, el 3D y Unreal (F6.22.1–22.2).
void main() {
  const mpu = 0.01;

  PlanElement grip(LightType type, {Map<String, dynamic>? props}) =>
      PlanElement(
        id: 2,
        type: ElementType.light,
        // Entre el foco (abajo) y el punto de medida (arriba), de lado.
        position: const Offset(0, -150),
        lightType: type,
        props: {'uid': 'G', ...?props},
      );
  PlanElement fresnel() => PlanElement(
    id: 1,
    type: ElementType.light,
    position: Offset.zero,
    rotation: 0,
    lightType: LightType.fresnelMedium,
    props: {'uid': 'L', 'intensity': 100},
  );
  const point = Offset(0, -300);

  test('marco y palio: formato, alto y altura', () {
    final frame = grip(LightType.diffusionFrame);
    PlanGrip.applyFormat(frame, GripFormat.frame2x1, mpu);
    expect(PlanGrip.widthM(frame, mpu), closeTo(2, 1e-9));
    expect(PlanGrip.heightM(frame, mpu), 1);
    // Centrado a la altura de la cara.
    final s = PlanGrip.span(frame, mpu);
    expect((s.bottom + s.top) / 2, closeTo(PlanLight.subjectHeightM, 1e-9));

    final palio = grip(LightType.bounce);
    PlanGrip.applyFormat(palio, GripFormat.palio4, mpu);
    palio.props[PlanGrip.centreKey] = 3.0;
    final p = PlanGrip.span(palio, mpu);
    expect((p.bottom, p.top), (1.0, 5.0));
    expect(GripFormat.palio4.palio, isTrue);
    expect(GripFormat.frame1x1.palio, isFalse);
  });

  test('el grip de antes mide y alumbra igual', () {
    final flag = grip(LightType.flag);
    final s = PlanGrip.span(flag, mpu);
    expect((s.bottom, s.top), (0.0, LightScene.wallHeightM));
    final frame = grip(LightType.diffusionFrame);
    final side = LightScene.lengthOf(frame) * mpu;
    final f = PlanGrip.span(frame, mpu);
    expect(f.top - f.bottom, closeTo(side, 1e-9));
  });

  test('un negro delante del foco corta la luz; una tela la baja', () {
    double lux(List<PlanElement> els) =>
        LightScene.from(els, metersPerUnit: mpu).luxAt(point);
    final open = lux([fresnel()]);
    final flag = lux([fresnel(), grip(LightType.flag)]);
    final cloth = lux([
      fresnel(),
      grip(
        LightType.diffusionFrame,
        props: {
          PlanLight.modifiersKey: ['grid-full'],
        },
      ),
    ]);
    expect(flag, lessThan(open * 0.2));
    expect(cloth, lessThan(open));
    expect(cloth, greaterThan(flag));
  });

  test('la luz de la tela y el panel llegan al 3D y a Unreal', () {
    final frame = grip(LightType.diffusionFrame);
    PlanGrip.applyFormat(frame, GripFormat.frame1x1, mpu);
    final scene = PlanScene3d.build([fresnel(), frame], metersPerUnit: mpu);
    final panel = (scene['grip'] as List).single as Map;
    expect(panel['widthM'], 1);
    expect((panel['top'] as num) - (panel['bottom'] as num), 1);
    final soft = scene['soft'] as List;
    expect(soft, isNotEmpty);
    expect((soft.first as Map)['cd'], greaterThan(0));

    final payload = UnrealStagePayload.build(scene);
    final block = (payload['props'] as List).cast<Map>().firstWhere(
      (p) => p['type'] == 'grip',
    );
    expect(block['sizeCm'], [3.0, 100.0, 100.0]);
    final rect = (payload['lights'] as List).cast<Map>().firstWhere(
      (l) => '${l['id']}'.contains('#luz'),
    );
    expect(rect['kind'], 'rect');
    expect(rect['widthCm'], greaterThan(0));
  });
}
