import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/core/theme/app_colors.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_material.dart';
import 'package:iris_dp/features/camera_plan/arch/wall_faces.dart';
import 'package:iris_dp/features/camera_plan/arch/wall_joints.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/plan_cad_export.dart';
import 'package:iris_dp/features/camera_plan/plan_elevation.dart';
import 'package:iris_dp/features/camera_plan/plan_opening.dart';
import 'package:iris_dp/features/camera_plan/plan_piece_controls.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_rig.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';

import '../support/snapshot.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // 1 unidad del lienzo = 1 cm.
  const mpu = 0.01;

  PlanElement wall(Offset a, Offset b, {double thick = 0.2, int id = 0}) =>
      PlanSegment.create(start: a, end: b)
        ..id = id
        ..props[PlanSegment.thicknessKey] = thick;

  /// Un hastial de 6 m: 2,5 m en las puntas y 4 m en medio.
  PlanElement gableWall() =>
      wall(Offset.zero, const Offset(600, 0))
        ..props[PlanSegment.heightKey] = 2.5
        ..props[PlanSegment.peakKey] = 4.0;

  PlanElement door(Offset at, {String? arch}) => PlanElement(
    id: 50,
    type: ElementType.wall,
    position: at,
    label: ArchitectureType.doorClosed.dbValue,
    props: {
      PlanOpening.widthKey: 100.0,
      PlanOpening.headKey: 2.6,
      PlanOpening.archKey: ?arch,
    },
  );

  group('perfil', () {
    test('recta, inclinada y hastial', () {
      final w = wall(Offset.zero, const Offset(600, 0));
      expect(PlanSegment.hasProfile(w), isFalse);
      expect(PlanSegment.topAtM(w, 0.5), isNull);
      w
        ..props[PlanSegment.heightKey] = 2.0
        ..props[PlanSegment.heightEndKey] = 3.0;
      expect(PlanSegment.topAtM(w, 0.5), closeTo(2.5, 1e-9));
      expect(PlanSegment.maxTopM(w), 3);
      final g = gableWall();
      expect(PlanSegment.profileTs(g), [0, 0.5, 1]);
      expect(PlanSegment.topAtM(g, 0.5), 4);
      expect(PlanSegment.topAtM(g, 0.25), closeTo(3.25, 1e-9));
      g.props[PlanSegment.peakAtKey] = 0.25;
      expect(PlanSegment.topAtM(g, 0.25), 4);
      expect(PlanSegment.tOf(g, const Offset(150, 40)), closeTo(0.25, 1e-9));
    });

    test('luz: el hastial tapa a su alto en cada tramo', () {
      final g = gableWall();
      final scene = LightScene.from([g], metersPerUnit: mpu);
      final hs = [
        for (final b in scene.blockers)
          if (b.element == g) b.heightM,
      ];
      expect(hs.length, greaterThan(4));
      expect(hs.reduce(math.max), closeTo(4, 0.15));
      expect(hs.reduce(math.min), closeTo(2.5, 0.15));
    });
  });

  group('esquinas unidas', () {
    test('dos paredes en L: a inglete', () {
      final a = wall(Offset.zero, const Offset(400, 0));
      final b = wall(const Offset(400, 0), const Offset(400, 300));
      final o = WallJoints.of([a, b], mpu);
      // Medio grosor: 10 unidades. Esquina de dentro y de fuera.
      expect(o[a]!.left.last, const Offset(390, 10));
      expect(o[a]!.right.last, const Offset(410, -10));
      expect(o[b]!.left.first, const Offset(390, 10));
      expect(o[b]!.right.first, const Offset(410, -10));
      // La cara de dentro se acorta y la de fuera se alarga 10 cm.
      expect(o[a]!.extendM[2], closeTo(-0.1, 1e-9));
      expect(o[a]!.extendM[3], closeTo(0.1, 1e-9));
      // El inicio, suelto: a escuadra.
      expect(o[a]!.extendM[0], 0);
    });

    test('en línea, a escuadra; tres en un punto, se alargan', () {
      final a = wall(Offset.zero, const Offset(400, 0));
      final b = wall(const Offset(400, 0), const Offset(800, 0));
      expect(WallJoints.of([a, b], mpu)[a]!.extendM, everyElement(0));
      final c = wall(const Offset(400, 0), const Offset(400, 300), thick: 0.3);
      final o = WallJoints.of([a, b, c], mpu);
      expect(o[a]!.extendM[2], closeTo(0.15, 1e-9));
      expect(o[c]!.extendM[0], closeTo(0.1, 1e-9));
    });
  });

  group('arco', () {
    test('medio punto y rebajado', () {
      final round = door(Offset.zero, arch: PlanOpening.archRound);
      // 1 m de ancho: sube medio metro.
      expect(PlanOpening.archRiseM(round, mpu), closeTo(0.5, 1e-9));
      expect(PlanOpening.headAtM(round, 0, mpu), closeTo(2.6, 1e-9));
      expect(PlanOpening.headAtM(round, 1, mpu), closeTo(2.1, 1e-9));
      final eff = PlanOpening.effectiveHeadM(round, mpu);
      expect(eff, greaterThan(2.1));
      expect(eff, lessThan(2.6));
      final low = door(Offset.zero, arch: PlanOpening.archSegmental);
      expect(PlanOpening.archRiseM(low, mpu), closeTo(0.2, 1e-9));
      expect(PlanOpening.headAtM(low, -1, mpu), closeTo(2.4, 1e-9));
      expect(PlanOpening.headAtM(door(Offset.zero), 0.5, mpu), 2.6);
    });
  });

  group('contrato', () {
    test('3D y Unreal: perfil, esquinas, dos caras, arco, pilar y sello', () {
      final g = gableWall()
        ..props[ArchMaterials.key] = 'brick-old'
        ..props[WallFaces.backKey] = 'paint-white';
      final side = wall(const Offset(600, 0), const Offset(600, 400), id: 2);
      final pillar = PlanPillar.create(const Offset(300, 300))..rotation = 30;
      final stamp = PlanElement(
        id: 9,
        type: ElementType.wall,
        position: const Offset(900, 100),
        label: ArchitectureType.wall.dbValue,
      );
      final sc = PlanScene3d.build([
        g,
        side,
        door(const Offset(300, 0), arch: PlanOpening.archRound),
        pillar,
        stamp,
      ], metersPerUnit: mpu);
      final walls = (sc['walls'] as List).cast<Map>();
      expect(walls, hasLength(3));
      final w = walls.first;
      expect(w['points'], hasLength(3));
      expect(w['tops'], [2.5, 4.0, 2.5]);
      expect(w['matB'], 'paint-white');
      expect((sc['materials'] as Map).keys, contains('paint-white'));
      expect((w['ext'] as List).length, 4);
      final hole = (w['openings'] as List).single as Map;
      expect(hole['arch'], 'round');
      expect(hole['rise'], 0.5);
      // El sello de antes, a su largo de siempre.
      final legacy = walls.last;
      expect(legacy['points'], hasLength(2));
      final p = (sc['pillars'] as List).single as Map;
      expect(p['rotDeg'], 30);
      expect(p['cls'], isNotNull);
    });

    test('luz: cada cara devuelve con su material', () {
      final g = wall(Offset.zero, const Offset(600, 0))
        ..props[ArchMaterials.key] = 'paint-black'
        ..props[WallFaces.backKey] = 'paint-white';
      expect(WallFaces.isTwoSided(g), isTrue);
      expect(
        WallFaces.surface(g, -1).reflectance,
        greaterThan(WallFaces.surface(g, 1).reflectance),
      );
      // Una luz del lado B (y hacia abajo en el lienzo): rebota en blanco.
      final light = PlanElement(
        id: 3,
        type: ElementType.light,
        position: const Offset(300, -200),
        rotation: 180,
        lightType: LightType.hmi,
        props: {'intensity': 100},
      );
      final scene = LightScene.from(
        [g, light],
        metersPerUnit: mpu,
        fuseBounces: false,
      );
      final labels = scene.lights.map((l) => l.label).join(' | ');
      expect(labels, contains('blanca'));
      expect(labels, isNot(contains('negra')));
      g.props.remove(WallFaces.backKey);
      expect(WallFaces.colors(g), isNull);
    });

    test('alzado y DXF: hastial, arco y contorno', () {
      final g = gableWall();
      final d = door(const Offset(300, 0), arch: PlanOpening.archRound);
      final e = PlanElevation.of(
        [g, d],
        metersPerUnit: mpu,
        side: ElevationSide.front,
      );
      final w = e.items.firstWhere((i) => i.kind == ElevationKind.wall);
      expect(w.top, 4);
      expect(w.profile, isNotEmpty);
      final o = e.items.firstWhere((i) => i.kind == ElevationKind.opening);
      expect(o.profile.map((p) => p.$2).reduce(math.max), closeTo(2.6, 1e-6));
      expect(PlanCadExport.elevationDxf(e), contains(PlanCadExport.layerWalls));
      // En planta, el contorno a su grosor: cuatro lados.
      final dxf = PlanCadExport.planDxf([g], mpu);
      expect(
        PlanCadExport.layerWalls.allMatches(dxf).length,
        greaterThanOrEqualTo(5),
      );
    });
  });

  testWidgets('el panel: perfil, otra cara y remate', (tester) async {
    final w = wall(Offset.zero, const Offset(600, 0));
    final d = door(Offset.zero);
    Future<void> pump(PlanElement el) => tester.pumpWidget(
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
    await pump(w);
    final gable = find.byKey(const ValueKey('wall-profile-gable'));
    await tester.ensureVisible(gable);
    await tester.tap(gable);
    await tester.pump();
    expect(PlanSegment.peakM(w), 4);
    expect(find.text('Alto del pico'), findsOneWidget);
    expect(find.text('Alto al inicio'), findsOneWidget);
    expect(find.text('Material del otro lado'), findsOneWidget);
    final flat = find.byKey(const ValueKey('wall-profile-flat'));
    await tester.ensureVisible(flat);
    await tester.tap(flat);
    await tester.pump();
    expect(PlanSegment.hasProfile(w), isFalse);

    await pump(d);
    final round = find.byKey(const ValueKey('opening-arch-round'));
    await tester.ensureVisible(round);
    await tester.tap(round);
    await tester.pump();
    expect(PlanOpening.arch(d), PlanOpening.archRound);
    expect(find.text('Clave del arco (lo más alto)'), findsOneWidget);
  });

  testWidgets('en la planta: grosor, esquinas y caras', (tester) async {
    final elements = [
      wall(const Offset(80, 80), const Offset(480, 80), thick: 0.25, id: 1)
        ..props[ArchMaterials.key] = 'brick-old'
        ..props[WallFaces.backKey] = 'paint-white',
      wall(const Offset(480, 80), const Offset(480, 420), thick: 0.25, id: 2),
      wall(const Offset(480, 420), const Offset(80, 420), thick: 0.25, id: 3),
      wall(const Offset(80, 420), const Offset(80, 80), thick: 0.25, id: 4),
      wall(const Offset(280, 80), const Offset(280, 420), thick: 0.1, id: 5),
      wall(const Offset(480, 250), const Offset(680, 250), thick: 0.12, id: 6)
        ..props['curve'] = 60.0,
      door(const Offset(380, 420))..id = 7,
      PlanPillar.create(const Offset(600, 450))
        ..id = 8
        ..rotation = 30
        ..props[PlanPillar.sizeKey] = 0.4,
    ];
    await tester.pumpWidget(
      RepaintBoundary(
        child: CustomPaint(
          size: const Size(760, 560),
          painter: CameraPlanPainter(
            elements: elements,
            palette: AppPalette.dark,
            metersPerUnit: mpu,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await saveSnapshot(tester, 'muros');
  });
}
