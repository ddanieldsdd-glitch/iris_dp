import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/core/theme/app_colors.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_solid.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_stair.dart';
import 'package:iris_dp/features/camera_plan/arch/plan_levels.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/plan_piece_controls.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_rig.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';

import '../support/snapshot.dart';

/// Plan AM.6: niveles de la localización. Datos inventados.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // 1 unidad del lienzo = 1 cm.
  const mpu = 0.01;

  /// Una casa de 8 × 6 m: cuatro paredes.
  List<PlanElement> house() => [
    PlanSegment.create(start: Offset.zero, end: const Offset(800, 0)),
    PlanSegment.create(start: const Offset(800, 0), end: const Offset(800, 600)),
    PlanSegment.create(start: const Offset(800, 600), end: const Offset(0, 600)),
    PlanSegment.create(start: const Offset(0, 600), end: Offset.zero),
  ];

  PlanElement chair(Offset at, double level) => PlanElement(
    id: 0,
    type: ElementType.prop,
    position: at,
    label: PropType.chair.dbValue,
  )..props[PlanLevel.key] = level;

  test('sin forjados con nombre, solo la planta baja', () {
    final storeys = PlanLevels.of(house());
    expect(storeys, hasLength(1));
    expect(storeys.single.name, 'Planta baja');
    expect(storeys.single.isGround, isTrue);
    expect(PlanLevels.label(storeys.single), 'Planta baja · +0,00');
  });

  test('un nivel nuevo cubre lo construido, a 3 m del de abajo', () {
    final els = house();
    final p1 = PlanLevels.newStorey(els, mpu);
    expect(PlanLevels.isLevelSlab(p1), isTrue);
    expect(p1.props[PlanLevels.nameKey], 'Planta 1');
    expect(PlanLevels.slabFloorM(p1), 3.0);
    expect(ArchSolid.sizeM(p1).width, closeTo(8, 1e-6));
    expect(ArchSolid.sizeM(p1).height, closeTo(6, 1e-6));
    expect(ArchSolid.bottomM(p1), closeTo(2.75, 1e-9));
    els.add(p1);
    final p2 = PlanLevels.newStorey(els, mpu);
    expect(p2.props[PlanLevels.nameKey], 'Planta 2');
    expect(PlanLevels.slabFloorM(p2), 6.0);
    els.add(p2);
    // Un forjado sin nombre (una tarima) no es un nivel; dos a la misma
    // cota cuentan como uno.
    els
      ..add(
        ArchSolid.rectangle(
          RigType.slab,
          Offset.zero,
          const Offset(100, 100),
          mpu,
        ),
      )
      ..add(
        ArchSolid.rectangle(
            RigType.slab,
            Offset.zero,
            const Offset(100, 100),
            mpu,
          )
          ..props[PlanLevels.nameKey] = 'Otra'
          ..props[ArchSolid.topKey] = 3.02,
      );
    final storeys = PlanLevels.of(els);
    expect([for (final s in storeys) s.name], [
      'Planta baja',
      'Planta 1',
      'Planta 2',
    ]);
    // Se guarda con la planta.
    final back = FloorPlanJson.decode(FloorPlanJson.encode(els));
    expect(PlanLevels.of(back).map((s) => s.elevationM), [0, 3.0, 6.0]);
  });

  test('sin nada construido, 10 × 10 m alrededor del centro', () {
    final p1 = PlanLevels.newStorey(const [], mpu, around: const Offset(50, 50));
    expect(ArchSolid.sizeM(p1).width, closeTo(10, 1e-6));
  });

  test('en qué nivel está cada cosa', () {
    final els = house();
    final p1 = PlanLevels.newStorey(els, mpu);
    els.add(p1);
    final storeys = PlanLevels.of(els);
    final down = chair(const Offset(100, 100), 0);
    final up = chair(const Offset(100, 100), 3);
    expect(PlanLevels.storeyOf(down, storeys).name, 'Planta baja');
    expect(PlanLevels.storeyOf(up, storeys).name, 'Planta 1');
    expect(PlanLevels.storeyOf(p1, storeys).name, 'Planta 1');
    expect(PlanLevels.isOn(up, 0, storeys), isFalse);
    expect(PlanLevels.isOn(up, 3, storeys), isTrue);
    // La escalera que sube de un nivel al otro se ve en los dos.
    final stair = ArchStair.create(
      const Offset(100, 300),
      const Offset(548, 300),
      mpu,
    );
    stair.props[ArchStair.riseKey] = PlanLevels.riseToNext(
      storeys.first,
      storeys,
    );
    expect(ArchStair.riseM(stair), 3.0);
    expect(PlanLevels.isOn(stair, 0, storeys), isTrue);
    expect(PlanLevels.isOn(stair, 3, storeys), isTrue);
    expect(PlanLevels.riseToNext(storeys.last, storeys), isNull);
    // En el 3D, lo de arriba a su cota.
    final sc = PlanScene3d.build([...els, up], metersPerUnit: mpu);
    final solid = (sc['solids'] as List).single as Map;
    expect(solid['z1'], 3.0);
    expect(((sc['props'] as List).single as Map)['z0'], 3.0);
  });

  testWidgets('el panel del forjado: es un nivel y su nombre', (tester) async {
    final slab = ArchSolid.rectangle(
      RigType.slab,
      Offset.zero,
      const Offset(400, 300),
      mpu,
    )..props[ArchSolid.topKey] = 3.0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => PlanPieceControls(
                element: slab,
                metersPerUnit: mpu,
                onPreview: () => setState(() {}),
                onUpdate: () => setState(() {}),
              ),
            ),
          ),
        ),
      ),
    );
    final toggle = find.byKey(const ValueKey('slab-is-level'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    expect(PlanLevels.isLevelSlab(slab), isTrue);
    final name = find.byKey(const ValueKey('slab-level-name'));
    await tester.enterText(name, 'Entreplanta');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(slab.props[PlanLevels.nameKey], 'Entreplanta');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
    expect(PlanLevels.isLevelSlab(slab), isFalse);
  });

  testWidgets('la planta de un nivel: lo demás, atenuado', (tester) async {
    final els = house();
    final p1 = PlanLevels.newStorey(els, mpu)..id = 9;
    els
      ..add(p1)
      ..add(chair(const Offset(200, 200), 0)..id = 10)
      ..add(chair(const Offset(600, 400), 3)..id = 11)
      ..add(
        ArchStair.create(const Offset(100, 500), const Offset(548, 500), mpu)
          ..props[ArchStair.riseKey] = 3.0
          ..id = 12,
      );
    for (final level in [0.0, 3.0]) {
      await tester.pumpWidget(
        RepaintBoundary(
          child: CustomPaint(
            size: const Size(840, 640),
            painter: CameraPlanPainter(
              elements: els,
              palette: AppPalette.dark,
              metersPerUnit: mpu,
              activeLevelM: level,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await saveSnapshot(tester, 'niveles_${level.round()}');
    }
  });
}
