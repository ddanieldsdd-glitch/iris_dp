import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/exposure.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';
import 'package:iris_dp/features/unreal_link/unreal_stage_payload.dart';

/// La misma exposición en el fotómetro, el 3D y Unreal (F6.21.4).
void main() {
  const mpu = 0.01;
  const camera = ExposureSettings(iso: 800, shutterDeg: 180, fps: 24);

  PlanElement fresnel() => PlanElement(
    id: 1,
    type: ElementType.light,
    position: Offset.zero,
    lightType: LightType.fresnelMedium,
    props: {'uid': 'L', 'intensity': 100},
  );

  test('la EV100 es la del fotómetro: lo bien expuesto queda en gris medio',
      () {
    final e = PlanScene3d.exposureOf(camera, 2.8);
    // T2.8, 1/48 s, ISO 800: log2(2.8² · 48) − log2(8) ≈ 5,6.
    expect(e['ev100'], closeTo(5.6, 0.05));
    // Los lux que el fotómetro pide para T2.8 dan el gris medio (0,16 lineal)
    // en una superficie del 18 %.
    final lux = camera.luxFor(2.8);
    final grey = 0.18 * lux / math.pi * (e['scale'] as double);
    expect(grey, closeTo(0.162, 0.01));
    // Con 1 stop de ND, la imagen pide el doble de luz.
    final nd = PlanScene3d.exposureOf(camera.copyWith(ndStops: 1), 2.8);
    expect(nd['ev100'], closeTo((e['ev100'] as double) + 1, 0.01));
  });

  test('la escena y Unreal llevan la exposición; cambiarla se manda sola', () {
    final scene = PlanScene3d.build(
      [fresnel()],
      metersPerUnit: mpu,
      exposure: camera,
      stop: 2.8,
    );
    expect(scene['exposure']['tStop'], 2.8);
    final payload = UnrealStagePayload.build(scene);
    expect(payload['exposure']['iso'], 800);
    expect(payload['exposure']['shutterS'], closeTo(1 / 48, 1e-6));

    final darker = UnrealStagePayload.build(
      PlanScene3d.build(
        [fresnel()],
        metersPerUnit: mpu,
        exposure: camera,
        stop: 4,
      ),
    );
    final diff = UnrealStagePayload.diff(payload, darker)!;
    expect(diff['exposure']['tStop'], 4);
    expect(diff['lights'], isEmpty);
    // Sin cambios, nada que mandar.
    expect(UnrealStagePayload.diff(darker, darker), isNull);
  });

  test('sin cámara no hay exposición fija', () {
    final scene = PlanScene3d.build([fresnel()], metersPerUnit: mpu);
    expect(scene.containsKey('exposure'), isFalse);
    expect(UnrealStagePayload.build(scene).containsKey('exposure'), isFalse);
  });
}
