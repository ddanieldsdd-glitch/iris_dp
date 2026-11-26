import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/core/theme/app_colors.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_stair.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/plan_cad_export.dart';
import 'package:iris_dp/features/camera_plan/plan_category.dart';
import 'package:iris_dp/features/camera_plan/plan_classes.dart';
import 'package:iris_dp/features/camera_plan/plan_elevation.dart';
import 'package:iris_dp/features/camera_plan/plan_palette.dart';
import 'package:iris_dp/features/camera_plan/plan_piece_controls.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_rig.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';

import '../support/snapshot.dart';

/// Plan AM.6: escaleras y rampas. Datos inventados.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // 1 unidad del lienzo = 1 cm.
  const mpu = 0.01;

  /// Una escalera de un piso (2,80 m) con 4,48 m de tramo.
  PlanElement straight({Offset at = Offset.zero, double run = 448}) =>
      ArchStair.create(at, at + Offset(run, 0), mpu);

  PlanElement shaped(StairShape s, {bool left = false, double run = 196}) =>
      ArchStair.create(Offset.zero, Offset(run, 0), mpu, shape: s)
        ..props[ArchStair.turnKey] = left ? 'left' : 'right';

  group('modelo', () {
    test('recta: peldaños de 17,5 × 28 y cómoda', () {
      final el = straight();
      expect(ArchStair.isStair(el), isTrue);
      expect(RigTypeCodec.of(el), RigType.stair);
      expect(el.rotation, 0);
      expect(ArchStair.runM(el), 4.48);
      expect(ArchStair.risers(el), 16);
      expect(ArchStair.riserM(el), closeTo(0.175, 1e-9));
      expect(ArchStair.treadM(el), closeTo(0.28, 1e-9));
      expect(ArchStair.warning(el), isNull);
      final steps = ArchStair.steps(el);
      expect(steps, hasLength(16));
      expect(steps.first.top, closeTo(0.175, 1e-9));
      expect(steps.last.top, closeTo(2.8, 1e-9));
      expect(steps.last.poly.map((p) => p.dx).reduce(math.max), 4.48);
    });

    test('se dibuja hacia donde sube', () {
      final el = ArchStair.create(Offset.zero, const Offset(0, -300), mpu);
      expect(el.rotation, -90);
      // El último peldaño, arriba en el lienzo.
      final top = ArchStair.steps(el).last.poly.first;
      expect(ArchStair.toCanvas(el, top, mpu).dy, lessThan(-250));
    });

    test('demasiado empinada o con mucha pendiente: avisa', () {
      expect(ArchStair.warning(straight(run: 200)), contains('Huella'));
      final ramp = ArchStair.create(
        Offset.zero,
        const Offset(300, 0),
        mpu,
        shape: StairShape.ramp,
      );
      expect(ArchStair.riseM(ramp), ArchStair.defaultRampRiseM);
      expect(ArchStair.slopePct(ramp), closeTo(10, 1e-9));
      expect(ArchStair.warning(ramp), isNull);
      ramp.props[ArchStair.riseKey] = 0.6;
      expect(ArchStair.warning(ramp), contains('20 %'));
      final step = ArchStair.steps(ramp).single;
      expect(step.tops, [0, 0.6, 0.6, 0]);
    });

    test('en L: tramo, meseta y tramo hacia su lado', () {
      final right = shaped(StairShape.l);
      final steps = ArchStair.steps(right);
      expect(steps, hasLength(16));
      // 7 peldaños, la meseta y 8 más.
      final landing = steps[7];
      expect(landing.poly.map((p) => p.dx).reduce(math.min), 1.96);
      expect(landing.top, closeTo(8 * 0.175, 1e-9));
      expect(steps.last.poly.every((p) => p.dy > 0), isTrue);
      final left = shaped(StairShape.l, left: true);
      expect(ArchStair.steps(left).last.poly.every((p) => p.dy < 0), isTrue);
      expect(ArchStair.treadM(right), closeTo(0.28, 1e-9));
    });

    test('en U: el segundo tramo vuelve al lado del primero', () {
      final el = shaped(StairShape.u);
      final steps = ArchStair.steps(el);
      final last = steps.last;
      // Acaba cerca del arranque, al otro lado del ojo.
      expect(last.poly.map((p) => p.dx).reduce(math.min), lessThan(0.3));
      expect(
        last.poly.map((p) => p.dy).reduce(math.min),
        closeTo(0.5 + ArchStair.wellM, 1e-9),
      );
    });

    test('de caracol: cuñas alrededor del núcleo', () {
      final el = ArchStair.create(
        Offset.zero,
        const Offset(100, 0),
        mpu,
        shape: StairShape.spiral,
      );
      final steps = ArchStair.steps(el);
      expect(steps, hasLength(16));
      for (final s in steps) {
        expect(s.bottom, closeTo(s.top - 0.05, 1e-9));
        for (final p in s.poly) {
          expect(p.distance, inInclusiveRange(ArchStair.coreM - 1e-9, 1.0001));
        }
      }
      expect(ArchStair.post(el), isNotNull);
      // A media huella, por donde se pisa: 0,5 m × 2π / 16.
      expect(ArchStair.treadM(el), closeTo(0.5 * 2 * math.pi / 16, 1e-9));
    });

    test('se toca en un peldaño y se guarda', () {
      final el = straight();
      expect(ArchStair.contains(el, const Offset(100, 20), mpu), isTrue);
      expect(ArchStair.contains(el, const Offset(100, 80), mpu), isFalse);
      final back = FloorPlanJson.decode(FloorPlanJson.encode([el])).single;
      expect(ArchStair.isStair(back), isTrue);
      expect(ArchStair.risers(back), 16);
      expect(PlanCategory.of(el), PlanCategory.architecture);
      expect(PlanClass.of(el), PlanClass.architecture);
      expect(PlanTool.stair.label, 'Escalera');
    });

    test('la malla mira hacia fuera', () {
      final tris = ArchStair.mesh(straight());
      // 16 peldaños de 12 triángulos.
      expect(tris.length, 16 * 12 * 9);
      // En el 3D (x, z, y del lienzo), la huella de arriba mira arriba.
      final a = [tris[0], tris[2], tris[1]];
      final b = [tris[3], tris[5], tris[4]];
      final c = [tris[6], tris[8], tris[7]];
      final u = [for (var i = 0; i < 3; i++) b[i] - a[i]];
      final v = [for (var i = 0; i < 3; i++) c[i] - a[i]];
      final ny = u[2] * v[0] - u[0] * v[2];
      expect(ny, greaterThan(0));
    });
  });

  group('contrato', () {
    test('luz, 3D, DXF y alzado', () {
      final el = straight();
      final scene = LightScene.from([el], metersPerUnit: mpu);
      final blockers = scene.blockers.where((b) => b.element == el).toList();
      expect(blockers, hasLength(16 * 4));
      expect(
        blockers.map((b) => b.heightM).reduce(math.max),
        closeTo(2.8, 1e-9),
      );

      final sc = PlanScene3d.build([el], metersPerUnit: mpu);
      final pieces = (sc['stairs'] as List).cast<Map>();
      final stair = pieces.singleWhere((s) => s['shape'] != 'rail');
      // Y su barandilla, de metal, como pieza aparte.
      final rail = pieces.singleWhere((s) => s['shape'] == 'rail');
      expect(rail['mat'], ArchStair.railMat);
      expect(rail['uid'], '${stair['id']}:rail');
      expect(stair['mat'], ArchStair.defaultMat);
      expect(stair['cls'], 'architecture');
      expect((stair['tris'] as List).length, 16 * 12 * 9);
      expect((sc['materials'] as Map).containsKey(ArchStair.defaultMat), isTrue);
      expect(PlanScene3d.structureKey(sc), isNotNull);

      final dxf = PlanCadExport.planDxf([el], mpu);
      // 16 peldaños y la línea por la que se sube.
      expect(PlanCadExport.layerSolids.allMatches(dxf).length, greaterThan(16));

      final side = PlanElevation.of(
        [el],
        metersPerUnit: mpu,
        side: ElevationSide.front,
      );
      final item = side.items.singleWhere((i) => i.element == el);
      expect(item.top, closeTo(2.8, 1e-9));
      expect(item.to - item.from, closeTo(4.48, 1e-6));
      // Escalonada: a media huella del primero, a la altura del primero.
      final first = item.profile.firstWhere(
        (p) => (p.$1 - (item.from + 0.14)).abs() < 0.08,
      );
      expect(first.$2, closeTo(0.175, 1e-9));
    });
  });

  testWidgets('el panel: forma, giro y aviso', (tester) async {
    final el = straight();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => PlanPieceControls(
                element: el,
                metersPerUnit: mpu,
                onPreview: () => setState(() {}),
                onUpdate: () => setState(() {}),
              ),
            ),
          ),
        ),
      ),
    );
    expect(PlanPieceControls.appliesTo(el), isTrue);
    expect(
      find.text('16 peldaños: contrahuella de 17,5 cm y huella de 28 cm.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('stair-warning')), findsNothing);
    final l = find.byKey(const ValueKey('stair-shape-l'));
    await tester.ensureVisible(l);
    await tester.tap(l);
    await tester.pump();
    expect(ArchStair.shape(el), StairShape.l);
    final left = find.byKey(const ValueKey('stair-turn-left'));
    await tester.ensureVisible(left);
    await tester.tap(left);
    await tester.pump();
    expect(ArchStair.turnsLeft(el), isTrue);
    // A rampa: de un piso entero pasa al 8 %.
    final ramp = find.byKey(const ValueKey('stair-shape-ramp'));
    await tester.ensureVisible(ramp);
    await tester.tap(ramp);
    await tester.pump();
    expect(ArchStair.slopePct(el), closeTo(8, 0.3));
  });

  testWidgets('en la planta', (tester) async {
    final elements = [
      straight(at: const Offset(40, 60))..id = 1,
      (shaped(StairShape.l)..id = 2)..position = const Offset(40, 260),
      (shaped(StairShape.u, left: true)..id = 3)
        ..position = const Offset(380, 440),
      ArchStair.create(
          const Offset(620, 180),
          const Offset(720, 180),
          mpu,
          shape: StairShape.spiral,
        )
        ..id = 4,
      ArchStair.create(
          const Offset(40, 520),
          const Offset(340, 520),
          mpu,
          shape: StairShape.ramp,
        )
        ..id = 5,
      PlanSegment.create(start: const Offset(20, 20), end: const Offset(760, 20)),
    ];
    await tester.pumpWidget(
      RepaintBoundary(
        child: CustomPaint(
          size: const Size(800, 600),
          painter: CameraPlanPainter(
            elements: elements,
            palette: AppPalette.dark,
            metersPerUnit: mpu,
            selectedElement: elements[3],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await saveSnapshot(tester, 'escaleras');
  });
}
