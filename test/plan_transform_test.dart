import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_rig.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_transform.dart';

void main() {
  const mpu = 0.05; // 1 unidad de la planta = 5 cm.

  PlanElement prop() => PlanElement(
    id: 1,
    type: ElementType.prop,
    position: const Offset(100, -60),
    rotation: 30,
    pathPoints: [const Offset(110, -60)],
  );

  test('X e Y en metros, con y hacia el fondo como en el 3D', () {
    final el = prop();
    final at = PlanTransform.xyM(el, mpu);
    expect(at.x, closeTo(5, 1e-9));
    expect(at.y, closeTo(3, 1e-9));

    expect(PlanTransform.setXY(el, 6.5, 2, [el], mpu), isTrue);
    expect(el.position.dx, closeTo(130, 1e-9));
    expect(el.position.dy, closeTo(-40, 1e-9));
    // Lo que cuelga del elemento se mueve con él.
    expect(el.pathPoints.single.dx, closeTo(140, 1e-9));
    expect(PlanTransform.setXY(el, 6.5, 2, [el], mpu), isFalse);
  });

  test('el giro va de 0 a 360°', () {
    final el = prop();
    PlanTransform.setRotation(el, -90);
    expect(PlanTransform.rotationDeg(el), 270);
    PlanTransform.setRotation(el, el.rotation + 100);
    expect(el.rotation, 10);
  });

  test('la flecha sube el foco o la cámara; lo demás sube con su suelo', () {
    final light = PlanElement(
      id: 2,
      type: ElementType.light,
      position: Offset.zero,
      lightType: LightType.fresnelMedium,
    );
    final start = PlanTransform.heightM(light);
    PlanTransform.liftBy(light, 0.5);
    expect(light.props[PlanLight.heightKey], closeTo(start + 0.5, 1e-9));
    expect(PlanLevel.of(light), 0);

    final el = prop();
    PlanTransform.liftBy(el, 0.64);
    expect(PlanTransform.levelM(el), 0.64);
    PlanTransform.liftBy(el, -0.64);
    // A ras de suelo no se guarda nada.
    expect(el.props.containsKey(PlanLevel.key), isFalse);
  });

  test('la altura no baja de cero', () {
    final cam = PlanElement(
      id: 3,
      type: ElementType.camera,
      position: Offset.zero,
    );
    PlanTransform.setHeight(cam, -1);
    expect(PlanTransform.heightM(cam), 0);
  });

  test('las paredes se editan por sus puntos', () {
    final wall = PlanElement(
      id: 4,
      type: ElementType.wall,
      position: Offset.zero,
      props: {'dx': 100.0, 'dy': 0.0},
    );
    expect(PlanTransform.applies(wall), isFalse);
    expect(PlanTransform.applies(prop()), isTrue);
  });
}
