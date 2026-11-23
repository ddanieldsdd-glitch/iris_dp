import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/core/theme/app_colors.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_solid.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_stair.dart';
import 'package:iris_dp/features/camera_plan/arch/plan_levels.dart';
import 'package:iris_dp/features/camera_plan/arch/plan_section.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
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
import 'package:iris_dp/shared/pdf_export/rig_sheet_pdf.dart';

import '../support/snapshot.dart';

/// Plan AM.6: la vista de sección por una línea. Datos inventados.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // 1 unidad del lienzo = 1 cm.
  const mpu = 0.01;

  /// Una casa de 8 × 6 m: cuatro paredes de 2,6 m; el norte arriba.
  List<PlanElement> house() => [
    for (final (a, b) in const [
      (Offset.zero, Offset(800, 0)),
      (Offset(800, 0), Offset(800, 600)),
      (Offset(800, 600), Offset(0, 600)),
      (Offset(0, 600), Offset.zero),
    ])
      PlanSegment.create(start: a, end: b)
        ..props[PlanSegment.heightKey] = 2.6
        ..props[PlanSegment.thicknessKey] = 0.2,
  ];

  PlanElement chair(Offset at) => PlanElement(
    id: 0,
    type: ElementType.prop,
    position: at,
    label: PropType.chair.dbValue,
  );

  /// Corta la casa por la mitad, de oeste a este, mirando al norte.
  PlanElement middle() => PlanSection.create(
    const Offset(-100, 300),
    const Offset(900, 300),
  );

  group('modelo', () {
    test('una línea con letra que mira a su izquierda', () {
      final s = middle();
      expect(PlanSection.isSection(s), isTrue);
      expect(RigTypeCodec.of(s), RigType.section);
      expect(PlanSection.name(s), 'A');
      expect(PlanSection.end(s), const Offset(900, 300));
      expect(PlanSection.lengthM(s, mpu), closeTo(10, 1e-9));
      // De oeste a este, mira al norte (arriba en el lienzo).
      expect(PlanSection.look(s).dy, closeTo(-1, 1e-9));
      PlanSection.flip(s);
      expect(PlanSection.look(s).dy, closeTo(1, 1e-9));
      expect(PlanSection.cutOf(s).from, const Offset(900, 300));
      PlanSection.flip(s);
      expect(PlanSection.flipped(s), isFalse);

      expect(PlanSection.contains(s, const Offset(400, 308)), isTrue);
      expect(PlanSection.contains(s, const Offset(400, 340)), isFalse);
      expect(PlanSection.nextName([s]), 'B');
      expect(PlanCategory.of(s), PlanCategory.architecture);
      expect(PlanClass.of(s), PlanClass.architecture);
      expect(PlanTool.section.label, 'Sección');

      final back = FloorPlanJson.decode(FloorPlanJson.encode([s])).single;
      expect(PlanSection.isSection(back), isTrue);
      expect(PlanSection.end(back), const Offset(900, 300));

      // Corta todos los niveles.
      final p1 = PlanLevels.newStorey(house(), mpu);
      expect(PlanLevels.isOn(s, 3, PlanLevels.of([p1])), isTrue);
    });

    test('la proyección general coincide con el alzado de frente', () {
      // Una línea de oeste a este por y = 0 es el alzado desde el sur.
      const cut = ElevationCut(Offset.zero, Offset(100, 0));
      for (final p in const [Offset(120, -340), Offset(-50, 75)]) {
        final a = PlanElevation.project(p, mpu, ElevationSide.front);
        final b = PlanElevation.project(p, mpu, ElevationSide.front, cut);
        expect(b.across, closeTo(a.across, 1e-9));
        expect(b.depth, closeTo(a.depth, 1e-9));
      }
      final clipped = PlanElevation.clipBehind(const [
        Offset(0, -100),
        Offset(100, -100),
        Offset(100, 100),
        Offset(0, 100),
      ], cut);
      // Queda la mitad de arriba (el norte).
      expect(clipped.every((p) => p.dy <= 1e-9), isTrue);
      expect(clipped, hasLength(4));
    });
  });

  group('la sección', () {
    test('quita lo de delante y rellena lo que corta', () {
      final s = middle();
      final front = chair(const Offset(200, 500))..id = 1;
      final back = chair(const Offset(600, 100))..id = 2;
      final e = PlanSection.elevationOf(s, [
        ...house(),
        front,
        back,
        s,
      ], metersPerUnit: mpu);
      expect(e.cut, isNotNull);
      expect(e.title, 'Sección A-A');
      final walls = e.items.where((i) => i.kind == ElevationKind.wall);
      // La del norte entera, detrás; la del sur, delante, no está; las
      // del este y el oeste, cortadas con su grosor.
      final cuts = walls.where((i) => i.cut).toList();
      expect(cuts, hasLength(2));
      for (final c in cuts) {
        expect(c.to - c.from, closeTo(0.2, 1e-6));
        expect(c.top, 2.6);
      }
      expect(
        cuts.map((c) => c.centre).toList()..sort(),
        [closeTo(1, 1e-6), closeTo(9, 1e-6)],
      );
      final whole = walls.where((i) => !i.cut).toList();
      expect(whole, hasLength(1));
      expect(whole.single.depth, closeTo(3, 1e-6));
      expect(whole.single.to - whole.single.from, closeTo(8.02, 1e-6));
      final props = e.items.where((i) => i.kind == ElevationKind.prop);
      expect(props.map((i) => i.element), [back]);
      // La línea no sale en su propia sección.
      expect(e.items.where((i) => i.element == s), isEmpty);
    });

    test('mirando al otro lado se ve el sur', () {
      final s = middle();
      PlanSection.flip(s);
      final front = chair(const Offset(200, 500));
      final e = PlanSection.elevationOf(s, [
        ...house(),
        front,
      ], metersPerUnit: mpu);
      final whole = e.items.where(
        (i) => i.kind == ElevationKind.wall && !i.cut,
      );
      expect(
        PlanSegment.pointAt(whole.single.element, 0.5).dy,
        closeTo(600, 1e-6),
      );
      expect(
        e.items.where((i) => i.kind == ElevationKind.prop).single.element,
        front,
      );
    });

    test('un volumen y una escalera que cruzan, cortados', () {
      final s = middle();
      final bar = ArchSolid.rectangle(
        RigType.volume,
        const Offset(100, 200),
        const Offset(300, 400),
        mpu,
      )..props[ArchSolid.topKey] = 1.1;
      final stair = ArchStair.create(
        const Offset(500, 500),
        const Offset(500, 52),
        mpu,
      );
      final e = PlanSection.elevationOf(s, [bar, stair], metersPerUnit: mpu);
      final b = e.items.singleWhere((i) => i.element == bar);
      expect(b.cut, isTrue);
      expect(b.from, closeTo(2, 1e-6));
      expect(b.to, closeTo(4, 1e-6));
      final st = e.items.singleWhere((i) => i.element == stair);
      expect(st.cut, isTrue);
      // Solo los peldaños de detrás: los de arriba del todo.
      expect(st.top, closeTo(ArchStair.riseM(stair), 1e-6));
      expect(
        st.profile.map((p) => p.$2).reduce(math.min),
        greaterThan(1),
      );
    });

    test('luz, 3D y DXF', () {
      final s = middle();
      final els = [...house(), s];
      final scene = LightScene.from(els, metersPerUnit: mpu);
      expect(scene.blockers.where((b) => b.element == s), isEmpty);
      final sc = PlanScene3d.build(els, metersPerUnit: mpu);
      expect(sc.toString(), isNot(contains('section')));
      final dxf = PlanCadExport.planDxf(els, mpu);
      expect(dxf, contains(PlanCadExport.layerSections));
      final secDxf = PlanCadExport.elevationDxf(
        PlanSection.elevationOf(s, els, metersPerUnit: mpu),
      );
      expect(
        RegExp('\n${PlanCadExport.layerCut}\n').allMatches(secDxf).length,
        greaterThanOrEqualTo(2),
      );
    });

    test('la hoja de luz: una hoja más de secciones', () async {
      final els = [...house(), middle()];
      final base = RigSheetPdf.pageCount(house(), metersPerUnit: mpu);
      expect(RigSheetPdf.pageCount(els, metersPerUnit: mpu), base + 1);
      // Dos secciones en la misma hoja; la tercera, en otra.
      final more = [
        ...els,
        PlanSection.create(
          const Offset(400, -100),
          const Offset(400, 700),
          name: 'B',
        ),
      ];
      expect(RigSheetPdf.pageCount(more, metersPerUnit: mpu), base + 1);
      more.add(
        PlanSection.create(
          const Offset(0, 100),
          const Offset(800, 100),
          name: 'C',
        ),
      );
      expect(RigSheetPdf.pageCount(more, metersPerUnit: mpu), base + 2);
      final bytes = await RigSheetPdf.build(
        more,
        metersPerUnit: mpu,
        info: RigSheetInfo(project: 'Prueba', date: DateTime(2026, 11, 23)),
        options: const RigSheetOptions(schedule: false),
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      final out = Platform.environment['IRIS_RIG_SHEET_OUT'];
      if (out != null) File('$out/hoja_secciones.pdf').writeAsBytesSync(bytes);
    });
  });

  testWidgets('el panel: letra y otro lado', (tester) async {
    final s = middle();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => PlanPieceControls(
                element: s,
                metersPerUnit: mpu,
                onPreview: () => setState(() {}),
                onUpdate: () => setState(() {}),
              ),
            ),
          ),
        ),
      ),
    );
    expect(PlanPieceControls.appliesTo(s), isTrue);
    final flip = find.byKey(const ValueKey('section-flip'));
    await tester.ensureVisible(flip);
    await tester.tap(flip);
    await tester.pump();
    expect(PlanSection.flipped(s), isTrue);
    await tester.enterText(find.byKey(const ValueKey('section-name')), 'C');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(PlanSection.name(s), 'C');
  });

  testWidgets('en la planta y vista', (tester) async {
    final s = middle()..id = 9;
    final bar = ArchSolid.rectangle(
      RigType.volume,
      const Offset(100, 200),
      const Offset(300, 400),
      mpu,
    )..props[ArchSolid.topKey] = 1.1;
    final stair = ArchStair.create(
      const Offset(500, 500),
      const Offset(500, 52),
      mpu,
    );
    final els = [
      ...house(),
      bar..id = 5,
      stair..id = 6,
      chair(const Offset(650, 120))..id = 7,
      s,
    ];
    await tester.pumpWidget(
      RepaintBoundary(
        child: Transform(
          // Que quepan las flechas de las puntas, fuera de la casa.
          transform: Matrix4.identity()
            ..translateByDouble(120, 60, 0, 1)
            ..scaleByDouble(0.55, 0.55, 1, 1),
          child: CustomPaint(
          size: const Size(1000, 800),
          painter: CameraPlanPainter(
            elements: els,
            palette: AppPalette.dark,
            metersPerUnit: mpu,
            selectedElement: s,
          ),
        ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await saveSnapshot(tester, 'seccion_planta');

    await tester.pumpWidget(
      RepaintBoundary(
        child: CustomPaint(
          size: const Size(900, 360),
          painter: PlanElevationPainter(
            elevation: PlanSection.elevationOf(s, els, metersPerUnit: mpu),
            ink: Colors.white,
            faint: Colors.white54,
            background: const Color(0xFF15181C),
            accent: Colors.orange,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await saveSnapshot(tester, 'seccion_vista');
  });
}
