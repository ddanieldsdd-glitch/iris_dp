import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
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
}
