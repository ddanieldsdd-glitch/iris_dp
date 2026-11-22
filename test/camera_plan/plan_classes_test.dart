import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/theme/app_colors.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/plan_classes.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_drape.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_rig.dart';

import '../support/snapshot.dart';

void main() {
  PlanElement el(ElementType type, {LightType? light, String? label}) =>
      PlanElement(
        id: 1,
        type: type,
        position: Offset.zero,
        lightType: light,
        label: label,
      );

  test('cada cosa de la planta tiene su clase', () {
    expect(PlanClass.of(el(ElementType.camera)), PlanClass.cameras);
    expect(PlanClass.of(el(ElementType.actor)), PlanClass.people);
    expect(
      PlanClass.of(
        PlanSegment.create(start: Offset.zero, end: const Offset(100, 0)),
      ),
      PlanClass.architecture,
    );
    expect(
      PlanClass.of(PlanDrape.create(Offset.zero, const Offset(100, 0))),
      PlanClass.rigging,
    );
    expect(
      PlanClass.of(el(ElementType.light, light: LightType.hmi)),
      PlanClass.fixtures,
    );
    expect(
      PlanClass.of(el(ElementType.light, light: LightType.flag)),
      PlanClass.grip,
    );
    expect(
      PlanClass.of(RigTypeCodec.create(RigType.truss, Offset.zero)),
      PlanClass.rigging,
    );
    expect(
      PlanClass.of(RigTypeCodec.create(RigType.pillar, Offset.zero)),
      PlanClass.architecture,
    );
    expect(
      PlanClass.of(el(ElementType.prop, label: PropType.table.dbValue)),
      PlanClass.decor,
    );
  });

  test('ocultar una clase no toca las demás', () {
    final actor = el(ElementType.actor);
    final hmi = el(ElementType.light, light: LightType.hmi);
    final all = [actor, hmi];
    expect(PlanClass.shown(all, const {}), same(all));
    expect(PlanClass.shown(all, {PlanClass.people}), [hmi]);
  });

  test('se guarda y se lee', () {
    final hidden = {PlanClass.people, PlanClass.cameras};
    expect(PlanClass.encode(hidden), 'people,cameras');
    expect(PlanClass.decode('people,cameras'), hidden);
    expect(PlanClass.decode(''), isEmpty);
    expect(PlanClass.decode('nada, people'), {PlanClass.people});
  });

  testWidgets('la planta no dibuja lo oculto', (tester) async {
    await loadSnapshotFonts();
    await tester.binding.setSurfaceSize(const Size(700, 360));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final elements = <PlanElement>[
      PlanSegment.create(
        start: const Offset(40, 40),
        end: const Offset(640, 40),
      ),
      PlanElement(
        id: 2,
        type: ElementType.light,
        position: const Offset(200, 120),
        rotation: 180,
        lightType: LightType.fresnelMedium,
      ),
      PlanElement(
        id: 3,
        type: ElementType.actor,
        position: const Offset(200, 260),
        label: 'Ana',
      ),
      PlanElement(
        id: 4,
        type: ElementType.camera,
        position: const Offset(420, 280),
      ),
    ];
    Future<void> paint(Set<PlanClass> hidden, String name) async {
      await tester.pumpWidget(
        RepaintBoundary(
          child: CustomPaint(
            size: const Size(700, 360),
            painter: CameraPlanPainter(
              elements: elements,
              palette: AppPalette.dark,
              hiddenClasses: hidden,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await saveSnapshot(tester, name);
    }

    await paint(const {}, 'clases_todo');
    await paint({PlanClass.people, PlanClass.cameras}, 'clases_sin_personas');
  });
}
