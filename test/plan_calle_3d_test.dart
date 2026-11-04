import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/light/wall_mount.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';

/// 3D legible y calle con perfil (plan CA).
void main() {
  const mpu = 0.01;

  PlanElement wall(Offset a, Offset b, {Map<String, dynamic>? props}) =>
      PlanSegment.create(start: a, end: b)
        ..props['uid'] = 'W${a.dx}'
        ..props.addAll(props ?? const {});

  PlanElement door(ArchitectureType t, Offset at) => PlanElement(
    id: 3,
    type: ElementType.wall,
    position: at,
    label: t.dbValue,
    props: {'uid': 'D', 'width': 90},
  );

  Map<String, dynamic> scene(List<PlanElement> els) =>
      PlanScene3d.build(els, metersPerUnit: mpu);

  Map<String, dynamic> firstWall(Map<String, dynamic> sc) =>
      (sc['walls'] as List).first as Map<String, dynamic>;

  test('CA.1: la pared lleva su grosor (12 cm si no se dice)', () {
    final plain = firstWall(scene([wall(Offset.zero, const Offset(400, 0))]));
    expect(plain['thick'], PlanSegment.defaultThicknessM);
    final thick = firstWall(
      scene([
        wall(
          Offset.zero,
          const Offset(400, 0),
          props: {PlanSegment.thicknessKey: 0.3},
        ),
      ]),
    );
    expect(thick['thick'], 0.3);
  });

  test('CA.2: una puerta cerrada lleva su hoja sobre el hueco', () {
    final w = firstWall(
      scene([
        wall(Offset.zero, const Offset(400, 0)),
        door(ArchitectureType.doorClosed, const Offset(200, 0)),
      ]),
    );
    final hole = (w['openings'] as List).single as Map<String, dynamic>;
    expect(hole['kind'], 'door');
    final span = hole['span'] as List;
    expect(span[0], closeTo(1.55, 1e-6));
    expect(span[2], closeTo(2.45, 1e-6));
    final leaf = (hole['leaves'] as List).single as List;
    // Cerrada: de la bisagra al otro canto, sobre la línea de la pared.
    expect(leaf[0], closeTo(1.55, 1e-6));
    expect(leaf[2], closeTo(2.45, 1e-6));
    expect(leaf[3], closeTo(0, 1e-6));
  });

  test('CA.2: una puerta doble abierta lleva dos hojas giradas', () {
    final w = firstWall(
      scene([
        wall(Offset.zero, const Offset(400, 0)),
        door(ArchitectureType.doubleDoor, const Offset(200, 0)),
      ]),
    );
    final hole = (w['openings'] as List).single as Map<String, dynamic>;
    final leaves = hole['leaves'] as List;
    expect(leaves, hasLength(2));
    for (final l in leaves.cast<List>()) {
      // A 90°: la hoja sale de la pared, 45 cm.
      expect((l[3] as double).abs(), closeTo(0.45, 1e-6));
    }
  });

  PlanElement tube({Map<String, dynamic>? props}) => PlanElement(
    id: 4,
    type: ElementType.light,
    position: const Offset(200, 60),
    lightType: LightType.floSingle,
    props: {'uid': 'T', 'intensity': 100, ...?props},
  );

  test('CA.3: un tubo pegado a la pared se queda a ras y tumbado', () {
    final w = wall(Offset.zero, const Offset(400, 0));
    final t = tube(props: {PlanLight.mountKey: PlanLight.mountWall});
    expect(LightWallMount.snap(t, [w, t], mpu), isTrue);
    // A 6 + 5 cm de la línea de la pared, por el lado en que estaba.
    expect(t.position.dx, closeTo(200, 1e-6));
    expect(t.position.dy, closeTo(11, 1e-6));
    // Mira hacia fuera de la pared (+y en la planta = 180°).
    expect(t.rotation, closeTo(180, 1e-6));
    expect(t.props[PlanLight.heightKey], LightWallMount.defaultHeightM);

    final f = (scene([w, t])['fixtures'] as List).single as Map;
    expect(f['shape'], 'tube');
    expect(f['mount'], 'wall');
    expect(f['lengthM'], greaterThan(0.2));
    final axis = (f['axis'] as List).cast<double>();
    // Tumbado a lo largo de la pared (el eje x).
    expect(axis[0].abs(), closeTo(1, 1e-6));
    expect(axis[2], 0);
    expect((f['pos'] as List)[2], closeTo(2.2, 1e-6));
  });

  test('CA.3: de pie si se pide, y lejos de toda pared no se pega', () {
    final t = tube(
      props: {LightWallMount.tubeAxisKey: LightWallMount.axisVertical},
    );
    final f = (scene([t])['fixtures'] as List).single as Map;
    expect(f['axis'], [0.0, 0.0, 1.0]);
    final far = tube()..position = const Offset(200, 900);
    expect(
      LightWallMount.snap(far, [wall(Offset.zero, const Offset(400, 0))], mpu),
      isFalse,
    );
  });

  test('CA.3: cada aparato con su forma', () {
    PlanElement light(LightType t) => PlanElement(
      id: 5,
      type: ElementType.light,
      position: Offset.zero,
      lightType: t,
    );
    expect(PlanScene3d.shapeOf(light(LightType.lightPanel)), 'panel');
    expect(PlanScene3d.shapeOf(light(LightType.softbox)), 'softbox');
    expect(PlanScene3d.shapeOf(light(LightType.practical)), 'practical');
    expect(PlanScene3d.shapeOf(light(LightType.fresnelLarge)), 'can');
  });

  test('CA.4: el alto de la pared vale para el 3D y para la luz', () {
    final w = wall(
      Offset.zero,
      const Offset(400, 0),
      props: {PlanSegment.heightKey: 6.0},
    );
    expect((firstWall(scene([w]))['tops'] as List).first, 6.0);
    final light = LightScene.from([w], metersPerUnit: mpu);
    final walls = light.blockers.where((b) => b.isWall).toList();
    expect(walls, isNotEmpty);
    for (final b in walls) {
      expect(b.heightM, 6.0);
    }
    // Sin alto puesto, la de siempre.
    final plain = LightScene.from([
      wall(Offset.zero, const Offset(400, 0)),
    ], metersPerUnit: mpu);
    expect(plain.blockers.firstWhere((b) => b.isWall).heightM, 2.5);
  });
}
