import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/core/theme/app_colors.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_material.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_roof.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_solid.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/plan_cad_export.dart';
import 'package:iris_dp/features/camera_plan/plan_elevation.dart';
import 'package:iris_dp/features/camera_plan/plan_piece_controls.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_hall.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_rig.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';

import '../support/snapshot.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Un rectángulo de 10 × 6 m centrado en el origen; cumbrera en x.
  const rect = [
    Offset(-5, -3),
    Offset(5, -3),
    Offset(5, 3),
    Offset(-5, 3),
  ];

  ArchRoof roof(ArchRoofKind kind) => ArchRoof(kind: kind, riseM: 2);

  group('la cubierta común', () {
    test('plana: nada sobre el alero', () {
      expect(roof(ArchRoofKind.flat).riseAt(rect, Offset.zero), 0);
      expect(roof(ArchRoofKind.flat).peakM, 0);
    });

    test('dos aguas: arriba en la cumbrera, abajo en los aleros', () {
      final r = roof(ArchRoofKind.gable);
      expect(r.riseAt(rect, Offset.zero), closeTo(2, 1e-9));
      expect(r.riseAt(rect, const Offset(4, 0)), closeTo(2, 1e-9));
      expect(r.riseAt(rect, const Offset(0, 3)), closeTo(0, 1e-9));
      expect(r.riseAt(rect, const Offset(0, -1.5)), closeTo(1, 1e-9));
    });

    test('un agua: de un lado a otro', () {
      final r = roof(ArchRoofKind.shed);
      expect(r.riseAt(rect, const Offset(0, -3)), closeTo(0, 1e-9));
      expect(r.riseAt(rect, const Offset(0, 3)), closeTo(2, 1e-9));
      expect(r.riseAt(rect, Offset.zero), closeTo(1, 1e-9));
    });

    test('bóveda: un arco a lo ancho', () {
      final r = roof(ArchRoofKind.vault);
      expect(r.riseAt(rect, Offset.zero), closeTo(2, 1e-9));
      expect(
        r.riseAt(rect, const Offset(0, 1.5)),
        closeTo(2 * math.sqrt(0.75), 1e-9),
      );
      expect(r.riseAt(rect, const Offset(0, 3)), closeTo(0, 1e-9));
    });

    test('cuatro aguas: todos los faldones con la misma pendiente', () {
      final r = roof(ArchRoofKind.hip);
      expect(r.riseAt(rect, Offset.zero), closeTo(2, 1e-9));
      // A 1 m del lado corto, 1/3 de la subida (pendiente 2/3).
      expect(r.riseAt(rect, const Offset(4, 0)), closeTo(2 / 3, 1e-9));
      // La cumbrera, media luz más corta por cada lado.
      final (a, b) = r.ridge(rect)!;
      expect(a.dx, closeTo(-2, 1e-9));
      expect(b.dx, closeTo(2, 1e-9));
    });

    test('girar la cumbrera', () {
      final r = roof(ArchRoofKind.gable).copyWith(ridgeDeg: 90);
      expect(r.riseAt(rect, const Offset(0, 2)), closeTo(2, 1e-9));
      expect(r.riseAt(rect, const Offset(5, 0)), closeTo(0, 1e-9));
    });

    test('malla: la cubierta llega a la cumbrera y los hastiales cierran', () {
      final gable = roof(ArchRoofKind.gable).mesh(rect, stepM: 0.5);
      final zs = [for (var i = 2; i < gable.roof.length; i += 3) gable.roof[i]];
      expect(zs.reduce(math.max), closeTo(2, 1e-9));
      expect(zs.reduce(math.min), closeTo(0, 1e-9));
      expect(gable.gables, isNotEmpty);
      // A cuatro aguas, ningún lado sube: no hay hastiales.
      expect(roof(ArchRoofKind.hip).mesh(rect).gables, isEmpty);
      final flat = roof(ArchRoofKind.flat).mesh(rect).roof;
      expect([for (var i = 2; i < flat.length; i += 3) flat[i]].toSet(), {0});
    });

    test('pasa por JSON', () {
      const r = ArchRoof(
        kind: ArchRoofKind.vault,
        riseM: 1.2,
        ridgeDeg: 90,
        overhangM: 0.3,
        mat: 'stone-slate-roof',
      );
      final back = ArchRoof.fromJson(r.toJson())!;
      expect(back.kind, r.kind);
      expect(back.riseM, r.riseM);
      expect(back.ridgeDeg, r.ridgeDeg);
      expect(back.overhangM, r.overhangM);
      expect(back.mat, r.mat);
    });
  });

  test('la nave, también a un agua, a cuatro aguas o en bóveda', () {
    final base = HallRecipe.rectangle(width: 10, depth: 6);
    for (final kind in [HallRoof.shed, HallRoof.hip, HallRoof.vault]) {
      final r = base.copyWith(roof: kind, riseM: 2);
      final back = HallRecipe.fromJson(r.toJson())!;
      expect(back.roof, kind);
      final heights = [
        for (final p in r.polygon()) r.roofAt(p),
        r.roofAt(r.centroid),
      ];
      expect(heights.reduce(math.max), closeTo(r.eaveM + 2, 0.05));
      expect(heights.reduce(math.min), greaterThanOrEqualTo(r.eaveM - 1e-9));
    }
    expect(
      base.copyWith(roof: HallRoof.hip, riseM: 2).roofAt(base.centroid),
      closeTo(base.eaveM + 2, 1e-6),
    );
  });

  group('un volumen con cubierta', () {
    const mpu = 0.01;

    /// Una caseta de 4 × 3 m, 2,5 m al alero, a dos aguas de 1,5 m.
    PlanElement kiosk() {
      final el =
          ArchSolid.rectangle(
              RigType.volume,
              Offset.zero,
              const Offset(400, 300),
              mpu,
            )
            ..id = 7
            ..props[ArchSolid.heightKey] = 2.5;
      ArchSolid.setRoof(
        el,
        const ArchRoof(
          kind: ArchRoofKind.gable,
          riseM: 1.5,
          mat: 'stone-slate-roof',
        ),
      );
      return el;
    }

    test('su altura llega a la cumbrera', () {
      final k = kiosk();
      expect(ArchSolid.topM(k), 4);
      expect(ArchSolid.topAt(k, const Offset(200, 150), mpu), closeTo(4, 1e-9));
      expect(ArchSolid.topAt(k, const Offset(200, 0), mpu), closeTo(2.5, 1e-9));
      // Plana: se quita.
      ArchSolid.setRoof(k, const ArchRoof(kind: ArchRoofKind.flat));
      expect(ArchSolid.roof(k), isNull);
      expect(ArchSolid.topM(k), 2.5);
    });

    test('luz: los hastiales tapan más que los aleros', () {
      final k = kiosk();
      final scene = LightScene.from([k], metersPerUnit: mpu);
      final heights = [
        for (final b in scene.blockers)
          if (b.element == k) b.heightM,
      ]..sort();
      expect(heights, [2.5, 2.5, 4, 4]);
    });

    test('3D y Unreal: alero, cubierta, hastiales y su material', () {
      final sc = PlanScene3d.build([kiosk()], metersPerUnit: mpu);
      final s = (sc['solids'] as List).single as Map;
      expect(s['eave'], 2.5);
      expect(s['z1'], 4);
      expect(s['roof'], 'gable');
      expect(s['roofMat'], 'stone-slate-roof');
      final tris = (s['roofTris'] as List).cast<num>();
      expect(tris.length % 9, 0);
      final zs = [for (var i = 2; i < tris.length; i += 3) tris[i]];
      expect(zs.reduce(math.max), closeTo(4, 1e-6));
      expect((s['gableTris'] as List), isNotEmpty);
      expect((sc['materials'] as Map).keys, contains('stone-slate-roof'));
    });

    test('alzado: de lado se ve el hastial en pico', () {
      final k = kiosk();
      PlanElevation view(ElevationSide side) =>
          PlanElevation.of([k], metersPerUnit: mpu, side: side);
      final side = view(ElevationSide.side).items.single;
      final tops = [for (final p in side.profile) p.$2];
      expect(tops.reduce(math.max), closeTo(4, 0.1));
      expect(tops.first, closeTo(2.5, 0.15));
      expect(tops.last, closeTo(2.5, 0.15));
      // De frente, a lo largo de la cumbrera: plano a 4 m.
      final front = view(ElevationSide.front).items.single;
      expect(
        front.profile.map((p) => p.$2).every((t) => (t - 4).abs() < 0.05),
        isTrue,
      );
      final dxf = PlanCadExport.elevationDxf(view(ElevationSide.side));
      expect(dxf, contains(PlanCadExport.layerSolids));
    });

    testWidgets('el panel: forma, subida, giro y material', (tester) async {
      final k =
          ArchSolid.rectangle(
              RigType.volume,
              Offset.zero,
              const Offset(400, 300),
              mpu,
            )
            ..id = 8;
      var saved = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => PlanPieceControls(
                  element: k,
                  metersPerUnit: mpu,
                  onPreview: () => setState(() {}),
                  onUpdate: () => setState(() => saved++),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Cubierta'), findsOneWidget);
      expect(find.text('Alto'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('solid-roof-gable')));
      await tester.pump();
      expect(ArchSolid.roof(k)!.kind, ArchRoofKind.gable);
      // La cumbrera, a lo largo del lado largo (4 m en x).
      expect(ArchSolid.roof(k)!.ridgeDeg, 0);
      expect(find.text('Alto al alero'), findsOneWidget);
      expect(find.text('Material de la cubierta'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('solid-roof-turn')));
      await tester.tap(find.byKey(const ValueKey('solid-roof-turn')));
      await tester.pump();
      expect(ArchSolid.roof(k)!.ridgeDeg, 90);
      expect(saved, 2);
    });

    testWidgets('en la planta: cumbreras y limatesas', (tester) async {
      final gable = kiosk()..position = const Offset(220, 170);
      final hip = kiosk()
        ..id = 9
        ..position = const Offset(620, 170);
      ArchSolid.setRoof(
        hip,
        const ArchRoof(kind: ArchRoofKind.hip, riseM: 1.5),
      );
      final shed = kiosk()
        ..id = 10
        ..position = const Offset(330, 420)
        ..rotation = 20;
      ArchSolid.setRoof(
        shed,
        const ArchRoof(kind: ArchRoofKind.shed, riseM: 1),
      );
      shed.props[ArchMaterials.key] = 'brick-tan';
      await tester.pumpWidget(
        RepaintBoundary(
          child: CustomPaint(
            size: const Size(760, 560),
            painter: CameraPlanPainter(
              elements: [gable, hip, shed],
              palette: AppPalette.dark,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await saveSnapshot(tester, 'cubiertas');
    });
  });
}
