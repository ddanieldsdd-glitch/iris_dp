import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/ambient.dart';
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

  group('palio inclinado (F6.22.1)', () {
    const sunny = PlanAmbient(day: true, sunElevation: 85);
    const under = Offset(0, -150);
    PlanElement palio(LightType type, {List<String>? cloth}) {
      final el = grip(
        type,
        props: {
          PlanGrip.tiltKey: 90.0,
          PlanGrip.centreKey: 3.0,
          if (cloth != null) PlanLight.modifiersKey: cloth,
        },
      );
      PlanGrip.applyFormat(el, GripFormat.palio4, mpu);
      return el;
    }

    double lux(List<PlanElement> els) => LightScene.from(
      els,
      metersPerUnit: mpu,
      ambient: sunny,
    ).luxAt(under);

    test('un palio negro horizontal tapa el sol; uno de tela lo ablanda', () {
      final open = lux(const []);
      final black = lux([palio(LightType.flag)]);
      final silk = lux([
        palio(LightType.diffusionFrame, cloth: ['grid-full']),
      ]);
      expect(open, greaterThan(1000));
      expect(black, lessThan(open * 0.3));
      expect(silk, greaterThan(black));
      expect(silk, lessThan(open));
    });

    test('la tela horizontal suelta su luz hacia abajo, y así va al 3D y a '
        'Unreal', () {
      final el = palio(LightType.diffusionFrame, cloth: ['grid-full']);
      final scene = LightScene.from([el], metersPerUnit: mpu, ambient: sunny);
      final soft = scene.lights.where((l) => identical(l.surface?.element, el));
      expect(soft, isNotEmpty);
      expect(soft.first.overheadM, isNotNull);

      final s3d = PlanScene3d.build([el], metersPerUnit: mpu, ambient: sunny);
      final panel = (s3d['grip'] as List).single as Map;
      expect(panel['tiltDeg'], 90);
      expect(panel['centreM'], 3);
      final dir = ((s3d['soft'] as List).first as Map)['dir'] as List;
      expect(dir[2], lessThan(-0.9));

      final payload = UnrealStagePayload.build(s3d);
      final block = (payload['props'] as List).cast<Map>().firstWhere(
        (p) => p['type'] == 'grip',
      );
      expect(block['rot'][0], 90);
      // Centrado a 3 m: la base del bloque, a 1 m (alto 4 m).
      expect(block['loc'][2], 100);
    });
  });
}
