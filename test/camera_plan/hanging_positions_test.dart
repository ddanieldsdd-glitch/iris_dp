import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/light/wall_mount.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/rig/hanging_positions.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_rig.dart';

const mpu = 0.02;

void main() {
  PlanElement light(Offset at, [LightType type = LightType.fresnelSmall]) =>
      PlanElement(
        id: 1,
        type: ElementType.light,
        position: at,
        lightType: type,
      );

  List<PlanElement> trusses() {
    final list = [
      // Abajo, a la derecha y a la izquierda; arriba, uno solo.
      PlanTruss.create(const Offset(400, 300), const Offset(600, 300)),
      PlanTruss.create(const Offset(0, 300), const Offset(200, 300)),
      PlanTruss.create(const Offset(0, 0), const Offset(600, 0), lowM: 6),
    ];
    LightOverrides.ensureUids(list);
    return list;
  }

  test('cada truss tiene nombre: el suyo o «Truss N» en orden', () {
    final t = trusses();
    var names = HangingPositions.names(t);
    expect(names[LightOverrides.uidOf(t[2])], 'Truss 1');
    expect(names[LightOverrides.uidOf(t[1])], 'Truss 2');
    expect(names[LightOverrides.uidOf(t[0])], 'Truss 3');

    t[2].customName = 'Vara FOH';
    names = HangingPositions.names(t);
    expect(names[LightOverrides.uidOf(t[2])], 'Vara FOH');
    // Los demás se numeran sin él.
    expect(names[LightOverrides.uidOf(t[1])], 'Truss 1');
  });

  test('cada foco dice dónde va montado', () {
    final t = trusses()..[2].customName = 'Vara FOH';
    final names = HangingPositions.names(t);
    final hung = light(const Offset(300, 5));
    expect(TrussMagnet.snap(hung, t, mpu), isTrue);
    expect(HangingPositions.mountOf(hung, names), 'Vara FOH');
    // Colgado a la altura del truss menos la garra.
    expect(
      (hung.props[PlanLight.heightKey] as num).toDouble(),
      closeTo(6 - TrussMagnet.defaultDropM, 1e-9),
    );

    expect(HangingPositions.mountOf(light(Offset.zero), names), 'Pie');
    final wall = light(Offset.zero)
      ..props[PlanLight.mountKey] = PlanLight.mountWall;
    expect(HangingPositions.mountOf(wall, names), 'Pared');
  });

  test('una luz de pared sigue a su pared y se despega si se aleja', () {
    final wall = PlanSegment.create(
      start: const Offset(0, 100),
      end: const Offset(400, 100),
    );
    final lamp = light(const Offset(100, 90), LightType.floSingle)
      ..props[PlanLight.mountKey] = PlanLight.mountWall;
    final elements = [wall, lamp];
    expect(LightWallMount.snap(lamp, elements, mpu), isTrue);
    final uid = LightOverrides.uidOf(wall)!;
    expect(LightWallMount.wallUidOf(lamp), uid);
    final before = lamp.position;
    expect(before.dy, lessThan(100), reason: 'por el lado en que estaba');

    // La pared baja 50 y la luz la sigue, por el mismo lado.
    wall.position += const Offset(0, 50);
    final moved = LightWallMount.follow(elements, {uid}, mpu);
    expect(moved, [lamp]);
    expect(lamp.position.dx, closeTo(before.dx, 1e-6));
    expect(lamp.position.dy, closeTo(before.dy + 50, 1e-6));

    // Una pared que no es la suya no la mueve.
    expect(LightWallMount.follow(elements, {'otra'}, mpu), isEmpty);

    // Lejos de cualquier pared, se despega.
    lamp.position = const Offset(100, 900);
    expect(LightWallMount.snap(lamp, elements, mpu), isFalse);
    expect(LightWallMount.wallUidOf(lamp), isNull);
  });
}
