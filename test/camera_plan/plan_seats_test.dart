import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/features/camera_plan/arch/arch_recipe.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_solid.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_marks.dart';
import 'package:iris_dp/features/camera_plan/plan_seats.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_rig.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';

/// Datos inventados: 5 cm por unidad del lienzo.
const mpu = 0.05;

PlanElement actor(Offset p) =>
    PlanElement(id: 0, type: ElementType.actor, position: p);

PlanElement sofa(Offset p, {double width = 1.8, double rotation = 0}) {
  final el = PlanElement(
    id: 0,
    type: ElementType.prop,
    position: p,
    rotation: rotation,
    label: PropType.sofa.dbValue,
    props: {LightScene.widthKey: width, LightScene.depthKey: 0.9},
  );
  LightOverrides.ensureUids([el]);
  return el;
}

void main() {
  test('un sofá de 1,8 m tiene tres plazas; una silla, una', () {
    final s = sofa(const Offset(100, 100));
    expect(PlanSeats.places(s, mpu), hasLength(3));
    final chair = PlanElement(
      id: 0,
      type: ElementType.prop,
      position: Offset.zero,
      label: PropType.chair.dbValue,
    );
    expect(PlanSeats.places(chair, mpu), hasLength(1));
    expect(PlanSeats.isSeat(actor(Offset.zero)), isFalse);
  });

  test('soltar sobre el sofá sienta; apartarlo levanta', () {
    final s = sofa(const Offset(100, 100), rotation: 90);
    PlanLevel.set(s, 1.1);
    final a = actor(const Offset(102, 101));
    final els = [s, a];
    expect(PlanSeats.settle(els, a, mpu), isTrue);
    expect(PlanMarks.pose(a), PlanMarks.poseSit);
    expect(a.rotation, 90);
    expect(PlanLevel.of(a), 1.1);
    expect(PlanSeats.of(a)?.uid, LightOverrides.uidOf(s));
    // Otro actor no ocupa la misma plaza.
    final b = actor(a.position);
    els.add(b);
    PlanSeats.settle(els, b, mpu);
    expect(PlanSeats.of(b)?.place, isNot(PlanSeats.of(a)!.place));
    // Lejos: se levanta.
    a.position = const Offset(400, 400);
    expect(PlanSeats.settle(els, a, mpu), isTrue);
    expect(PlanMarks.pose(a), PlanMarks.poseStand);
    expect(PlanSeats.of(a), isNull);
  });

  test('lo sentado sigue a su asiento, y se levanta si desaparece', () {
    final s = sofa(const Offset(100, 100));
    final a = actor(const Offset(100, 100));
    final els = [s, a];
    PlanSeats.settle(els, a, mpu);
    final before = a.position;
    s.position += const Offset(40, 0);
    expect(PlanSeats.follow(els, mpu), [a]);
    expect(a.position, before + const Offset(40, 0));
    els.remove(s);
    PlanSeats.follow(els, mpu);
    expect(PlanMarks.pose(a), PlanMarks.poseStand);
  });

  test('un forjado o una tarima suben a quien los pisa', () {
    final floor = ArchSolid.rectangle(
      RigType.slab,
      const Offset(0, 0),
      const Offset(200, 100),
      mpu,
    );
    floor.props[ArchSolid.topKey] = 1.1;
    final a = actor(const Offset(100, 50));
    final els = [floor, a];
    expect(PlanFloors.settle(els, a, mpu), isTrue);
    expect(PlanLevel.of(a), 1.1);
    // Fuera, vuelve a la calle.
    a.position = const Offset(500, 50);
    expect(PlanFloors.settle(els, a, mpu), isTrue);
    expect(PlanLevel.of(a), 0);
    // Un techo a 2,8 m no se pisa desde el suelo.
    floor.props[ArchSolid.topKey] = 2.8;
    a.position = const Offset(100, 50);
    expect(PlanFloors.settle(els, a, mpu), isFalse);
    expect(PlanLevel.of(a), 0);
  });

  test('el vagón: dentro se sienta en un asiento y en 3D sale sentado', () {
    final r = ArchRecipe.create(RecipeKind.carriage, const Offset(300, 200));
    final els = [r, ...ArchRecipe.build(r, mpu)];
    final seats = els.where(PlanSeats.isSeat).toList();
    final tables = els.where((e) => e.propType == PropType.table).toList();
    expect(seats, isNotEmpty);
    expect(tables, hasLength(seats.length ~/ 2));
    for (final layout in ['rows', 'metro']) {
      final o = ArchRecipe.create(
        RecipeKind.carriage,
        Offset.zero,
        params: {'layout': layout},
      );
      expect(ArchRecipe.build(o, mpu).where(PlanSeats.isSeat), isNotEmpty);
    }
    // Uno sentado y otro de pie en el pasillo, sobre el piso.
    final sitting = actor(PlanSeats.places(seats.first, mpu).first.at);
    final standing = actor(const Offset(300, 200));
    els.addAll([sitting, standing]);
    PlanSeats.settle(els, sitting, mpu);
    PlanFloors.settle(els, standing, mpu);
    expect(PlanLevel.of(sitting), 1.1);
    expect(PlanLevel.of(standing), 1.1);
    // Al rehacer el vagón, sigue sentado.
    ArchRecipe.set(r, 'floorM', 1.0);
    ArchRecipe.regenerate(els, r, mpu);
    PlanSeats.follow(els, mpu);
    expect(PlanLevel.of(sitting), 1.0);
    final sc = PlanScene3d.build(els, metersPerUnit: mpu);
    final people = (sc['people'] as List).cast<Map>();
    final sat = people.firstWhere((p) => p['pose'] == 'sit');
    expect(sat['seatM'], 0.45);
    expect(sat['dir'], hasLength(2));
    // Las ventanas cortan las paredes del vagón en el 3D.
    final walls = (sc['walls'] as List).cast<Map>();
    expect(walls.any((w) => (w['openings'] as List).length > 3), isTrue);
  });
}
