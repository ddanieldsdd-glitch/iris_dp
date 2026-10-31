import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';
import 'package:iris_dp/features/unreal_link/unreal_return.dart';
import 'package:iris_dp/features/unreal_link/unreal_stage_payload.dart';

/// Altura, paneo e inclinación de los focos (F6.21.5).
void main() {
  const mpu = 0.01;

  PlanElement fresnel({Map<String, dynamic>? props, double rotation = 90}) =>
      PlanElement(
        id: 1,
        type: ElementType.light,
        position: Offset.zero,
        rotation: rotation,
        lightType: LightType.fresnelMedium,
        props: {'uid': 'L', 'intensity': 100, ...?props},
      );

  Map<dynamic, dynamic> sentLight(PlanElement el) =>
      (UnrealStagePayload.build(
                PlanScene3d.build([el], metersPerUnit: mpu),
              )['lights']
              as List)
          .single
          as Map;

  test('lo guardado antes se lee con el mismo ángulo', () {
    // Trípode sin nada: un poco hacia abajo, a 2 m.
    final stand = fresnel();
    expect(PlanLight.elevationOf(stand), PlanLight.standTiltDeg);
    expect(PlanLight.heightOf(stand), 2);
    expect(PlanLight.hasOwnAim(stand), isFalse);
    // Colgada e inclinada 30° desde la vertical = 60° hacia abajo.
    final hung = fresnel(props: {'mount': 'ceiling', 'tilt': 30});
    expect(PlanLight.elevationOf(hung), -60);
    expect(PlanLight.heightOf(hung), 3);
    // La nueva manda y mantiene la antigua para versiones anteriores.
    PlanLight.setElevation(hung, -45);
    expect(hung.props['tiltDeg'], -45);
    expect(hung.props['tilt'], 45);
    expect(PlanLight.tiltOf(hung), 45);
    expect(PlanLight.tiltLabel(-30), '-30° hacia abajo');
    expect(PlanLight.tiltLabel(0), 'horizontal');
  });

  test('un foco de trípode subido e inclinado llega así al 3D y a Unreal', () {
    final el = fresnel(props: {'height': 2.5, 'tiltDeg': -30}, rotation: 90);
    final scene = PlanScene3d.build([el], metersPerUnit: mpu);
    final f = (scene['fixtures'] as List).single as Map;
    expect(f['pos'][2], 2.5);
    final sent = sentLight(el);
    expect(sent['loc'][2], 250);
    // Paneo 90° en planta y 30° hacia abajo.
    expect(sent['rot'][0], closeTo(-30, 0.5));
    final dir = UnrealStagePayload.dirOf(sent['rot'] as List);
    expect(dir.z, closeTo(-0.5, 0.01));
  });

  test('inclinarlo en Unreal lo deja igual en la ficha de IRIS', () {
    final el = fresnel(props: {'height': 2.5, 'tiltDeg': -10});
    final sent = sentLight(el);
    final edits = UnrealReturn.detect(
      {
        'lights': [sent],
      },
      {
        'L': {
          'loc': sent['loc'],
          'rot': [-45.0, sent['rot'][1], 0.0],
          'intensity': sent['cd'],
          'cct': sent['cct'],
        },
      },
    );
    expect(edits, hasLength(1));
    expect(UnrealReturn.apply(el, edits.single, [el], mpu), isTrue);
    expect(PlanLight.elevationOf(el), closeTo(-45, 0.6));
    expect(PlanLight.heightOf(el), 2.5);
  });

  test('el fotómetro cuenta la altura y la inclinación del trípode', () {
    // Un fresnel a 3 m, a 2 m del punto, apuntando hacia él (unos −37°) o
    // en horizontal por encima.
    const point = Offset(0, -200);
    double luxWith(double tilt) {
      final el = fresnel(
        props: {'height': 3.0, 'tiltDeg': tilt},
        rotation: 0,
      );
      final scene = LightScene.from([el], metersPerUnit: mpu);
      return scene.luxAt(point);
    }

    final aimed = luxWith(-37);
    final over = luxWith(0);
    expect(aimed, greaterThan(0));
    // Apuntado al punto da más que en horizontal por encima de él.
    expect(aimed, greaterThan(over * 1.2));
  });
}
