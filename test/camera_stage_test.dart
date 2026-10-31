import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_aim.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/meter.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';
import 'package:iris_dp/features/unreal_link/unreal_return.dart';
import 'package:iris_dp/features/unreal_link/unreal_stage_payload.dart';

/// La cámara de IRIS en Unreal, con todos sus parámetros (F6.22.4).
void main() {
  const mpu = 0.01;

  PlanElement camera({Map<String, dynamic>? props}) => PlanElement(
    id: 1,
    type: ElementType.camera,
    position: Offset.zero,
    lens: '35mm',
    props: {'uid': 'C', ...?props},
  );
  PlanElement actor(Offset at) => PlanElement(
    id: 2,
    type: ElementType.actor,
    position: at,
    props: {'uid': 'A'},
  );

  Map sentCamera(List<PlanElement> els) =>
      (UnrealStagePayload.build(
                PlanScene3d.build(els, metersPerUnit: mpu),
              )['cameras']
              as List)
          .single
          as Map;

  test('altura, inclinación, giro, diafragma, ISO, obturador y foco llegan a '
      'Unreal', () {
    final cam = camera(
      props: {
        PlanLight.heightKey: 1.2,
        CameraAim.tiltKey: -10.0,
        CameraAim.rollKey: 5.0,
        CameraAim.focusKey: 2.5,
        CameraExposure.stopKey: 2.8,
        CameraExposure.isoKey: 800.0,
        CameraExposure.shutterKey: 180.0,
        CameraExposure.fpsKey: 24.0,
      },
    );
    final sent = sentCamera([cam]);
    expect(sent['loc'][2], 120);
    expect(sent['rot'][0], -10);
    expect(sent['rot'][2], 5);
    expect(sent['tStop'], 2.8);
    expect(sent['iso'], 800);
    expect(sent['shutterS'], closeTo(1 / 48, 1e-6));
    expect(sent['focusCm'], 250);
    expect(sent['focalMm'], greaterThan(30));
  });

  test('sin foco propio, enfoca al actor que tiene delante', () {
    // La cámara mira hacia arriba del lienzo: el actor a 4 m delante.
    final cam = camera();
    final els = [cam, actor(const Offset(0, -400)), actor(const Offset(0, 300))];
    expect(CameraAim.focusM(cam, els, mpu), closeTo(4, 1e-9));
    // Sin nadie delante, 3 m.
    expect(CameraAim.focusM(cam, [cam], mpu), 3);
  });

  test('inclinarla o girarla en Unreal vuelve a la ficha de IRIS', () {
    final cam = camera(props: {PlanLight.heightKey: 1.5});
    final sent = sentCamera([cam]);
    final edits = UnrealReturn.detect(
      {
        'cameras': [sent],
      },
      {
        'C': {
          'loc': sent['loc'],
          'rot': [-15.0, sent['rot'][1], 8.0],
        },
      },
    );
    expect(edits, hasLength(1));
    expect(UnrealReturn.apply(cam, edits.single, [cam], mpu), isTrue);
    expect(CameraAim.tiltDeg(cam), -15);
    expect(CameraAim.rollDeg(cam), 8);
  });
}
