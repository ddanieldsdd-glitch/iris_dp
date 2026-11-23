import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/core/theme/app_colors.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_material.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_sweep.dart';
import 'package:iris_dp/features/camera_plan/arch/plan_section.dart';
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
import 'package:iris_dp/features/camera_plan/rig/plan_rig.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';

import '../support/snapshot.dart';

/// Plan AM.5: barridos, un perfil a lo largo de un camino. Datos
/// inventados.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // 1 unidad del lienzo = 1 cm.
  const mpu = 0.01;

  PlanElement sweep(
    SweepKind kind, {
    Offset from = Offset.zero,
    Offset to = const Offset(480, 0),
  }) => ArchSweep.create(from, to, kind: kind);

  /// El volumen que encierra una malla cerrada, en m³; positivo si sus
  /// caras miran hacia fuera. Del lienzo (y hacia abajo) al mundo.
  double volume(List<double> t) {
    var v = 0.0;
    for (var i = 0; i + 8 < t.length; i += 9) {
      final a = [t[i] * mpu, -t[i + 1] * mpu, t[i + 2]];
      final b = [t[i + 3] * mpu, -t[i + 4] * mpu, t[i + 5]];
      final c = [t[i + 6] * mpu, -t[i + 7] * mpu, t[i + 8]];
      v +=
          a[0] * (b[1] * c[2] - b[2] * c[1]) -
          a[1] * (b[0] * c[2] - b[2] * c[0]) +
          a[2] * (b[0] * c[1] - b[1] * c[0]);
    }
    return v / 6;
  }

  group('modelo', () {
    test('una barandilla: postes de punta a punta sin pasar de 1,20', () {
      final el = sweep(SweepKind.railing);
      expect(ArchSweep.isSweep(el), isTrue);
      expect(RigTypeCodec.of(el), RigType.sweep);
      expect(ArchSweep.lengthM(el, mpu), closeTo(4.8, 1e-9));
      final posts = ArchSweep.instances(el, mpu);
      // 4,80 m / 1,20: cinco postes, el primero y el último en las puntas.
      expect(posts, hasLength(5));
      expect(posts.first.$2.first.s, 0);
      expect(posts.last.$2.first.s, closeTo(4.8, 1e-9));
      expect(ArchSweep.heightM(el), 1.0);
      expect(
        ArchSweep.summary(el, mpu),
        'Barandilla · 4,80 m · postes cada 1,20 m',
      );
      expect(PlanCategory.of(el), PlanCategory.architecture);
      expect(PlanClass.of(el), PlanClass.architecture);
      expect(PlanTool.sweep.label, 'Barrido');
    });

    test('vía de tren: traviesas repartidas y carriles a 1,435 m', () {
      final el = sweep(SweepKind.track, to: const Offset(1200, 0));
      final sleepers = ArchSweep.instances(el, mpu);
      expect(sleepers, hasLength(20));
      expect(sleepers.first.$2.first.s, closeTo(0.3, 1e-9));
      final rails = ArchSweep.parts(el).where((p) => p.main).toList();
      expect(rails, hasLength(2));
      // Entre las caras de dentro de los carriles.
      final gauge = rails[1].minAcross - rails[0].maxAcross;
      expect(gauge, closeTo(1.435, 1e-9));
    });

    test('con curva: más largo; y se guarda', () {
      final el = sweep(SweepKind.kerb)..props[ArchSweep.curveKey] = 100;
      expect(ArchSweep.path(el).length, 25);
      expect(ArchSweep.lengthM(el, mpu), greaterThan(5.2));
      final back = FloorPlanJson.decode(FloorPlanJson.encode([el])).single;
      expect(ArchSweep.isSweep(back), isTrue);
      expect(ArchSweep.kind(back), SweepKind.kerb);
      expect(ArchSweep.lengthM(back, mpu), ArchSweep.lengthM(el, mpu));
    });

    test('una esquina: lo de un lado sigue paralelo (inglete)', () {
      final el = sweep(SweepKind.custom);
      ArchSweep.setPoints(el, const [
        Offset.zero,
        Offset(400, 0),
        Offset(400, 300),
      ]);
      final f = ArchSweep.frames(el, mpu);
      expect(ArchSweep.lengthM(el, mpu), closeTo(7, 1e-9));
      // A 0,15 m a la izquierda, en la esquina: a 0,15 de los dos tramos.
      final c = ArchSweep.place(f[1], 0.15, mpu);
      expect(c.dx, closeTo(415, 1e-6));
      expect(c.dy, closeTo(-15, 1e-6));
    });

    test('otro tipo vuelve a sus medidas', () {
      final el = sweep(SweepKind.railing)
        ..props[ArchSweep.heightKey] = 1.4
        ..props[ArchMaterials.key] = 'wood-planks';
      expect(ArchSweep.mainMaterial(el).id, 'wood-planks');
      ArchSweep.setKind(el, SweepKind.deck);
      expect(ArchSweep.heightM(el), 1.0);
      expect(ArchSweep.widthM(el), 6.0);
      expect(ArchSweep.mainMaterial(el).id, 'concrete-smooth');
    });
  });

  group('contrato', () {
    test('la malla está cerrada y mira hacia fuera', () {
      final el = sweep(SweepKind.custom)
        ..props[ArchSweep.widthKey] = 0.3
        ..props[ArchSweep.heightKey] = 0.5;
      final mesh = ArchSweep.mesh(el, mpu);
      expect(volume(mesh.values.single), closeTo(4.8 * 0.3 * 0.5, 1e-6));
      // Con curva y con perfiles no convexos, también.
      final track = sweep(SweepKind.track)..props[ArchSweep.curveKey] = 80;
      for (final tris in ArchSweep.mesh(track, mpu).values) {
        expect(volume(tris), greaterThan(0));
      }
      final hull = sweep(SweepKind.hull);
      for (final tris in ArchSweep.mesh(hull, mpu).values) {
        expect(volume(tris), greaterThan(0));
      }
    });

    test('luz: la barandilla deja pasar, el casco no, las pilas tapan', () {
      final rail = sweep(SweepKind.railing);
      final hull = sweep(SweepKind.hull, from: const Offset(0, 400), to: const Offset(1600, 400));
      final bridge = sweep(
        SweepKind.deck,
        from: const Offset(0, 1200),
        to: const Offset(4000, 1200),
      );
      final scene = LightScene.from([rail, hull, bridge], metersPerUnit: mpu);
      final r = scene.blockers.where((b) => b.element == rail).toList();
      expect(r, hasLength(1));
      expect(r.single.transmission, 0.75);
      expect(r.single.heightM, 1.0);
      final h = scene.blockers.where((b) => b.element == hull).toList();
      expect(h, hasLength(2));
      expect(h.every((b) => b.transmission == 0), isTrue);
      expect(h.first.baseM, 1.1);
      // Dos pretiles y dos pilas de cuatro caras.
      final d = scene.blockers.where((b) => b.element == bridge).toList();
      expect(d, hasLength(2 + 2 * 4));
    });

    test('3D, Unreal y DXF', () {
      final els = [
        sweep(SweepKind.track)..id = 1,
        sweep(SweepKind.railing, from: const Offset(0, 300))..id = 2,
      ];
      final sc = PlanScene3d.build(els, metersPerUnit: mpu);
      final sweeps = (sc['sweeps'] as List).cast<Map>();
      // Vía: balasto, carriles y traviesas; barandilla: un material.
      expect(sweeps.map((s) => s['mat']).toSet(), {
        'stone-rock',
        'metal-brushed',
        'concrete-smooth',
      });
      expect(sweeps, hasLength(4));
      final uids = sweeps.map((s) => s['uid']).toSet();
      expect(uids, hasLength(4));
      expect(sweeps.every((s) => s['cls'] == 'architecture'), isTrue);
      expect(
        (PlanScene3d.materialsOf(sc)).keys,
        containsAll(['stone-rock', 'metal-brushed']),
      );
      expect(PlanScene3d.structureKey(sc), isNotNull);
      final dxf = PlanCadExport.planDxf(els, mpu);
      // Balasto, dos carriles, 8 traviesas, dos barras y cinco postes.
      expect(
        RegExp('\n${PlanCadExport.layerSolids}\n').allMatches(dxf).length,
        greaterThanOrEqualTo(3 + 8 + 2 + 5),
      );
    });

    test('alzado y sección: el puente de lado y el vagón de frente', () {
      final bridge = sweep(SweepKind.deck, to: const Offset(4000, 0));
      final side = PlanElevation.of(
        [bridge],
        metersPerUnit: mpu,
        side: ElevationSide.front,
      );
      final deck = side.items.firstWhere((i) => i.top == 5.6);
      expect(deck.to - deck.from, closeTo(40, 1e-6));
      expect(deck.bottom, 5.0);
      // Dos pilas, cada 20 m, del suelo al tablero.
      final piers = side.items.where((i) => i.bottom == 0).toList();
      expect(piers, hasLength(2));
      expect(piers.first.top, 5.0);

      // El vagón cortado de través: su perfil, con el techo en arco.
      final hull = sweep(
        SweepKind.hull,
        from: const Offset(0, -800),
        to: const Offset(0, 800),
      );
      final cut = PlanSection.create(
        const Offset(-300, 0),
        const Offset(300, 0),
      );
      final e = PlanSection.elevationOf(cut, [hull, cut], metersPerUnit: mpu);
      final roof = e.items.firstWhere(
        (i) => (i.top - (1.1 + 2.9)).abs() < 1e-6,
      );
      expect(roof.cut, isTrue);
      expect(roof.to - roof.from, closeTo(2.9, 0.01));
      // En arco: más alto en el centro que en el alero.
      final mid = roof.profile[roof.profile.length ~/ 2].$2;
      expect(mid, greaterThan(roof.profile.first.$2 + 0.4));
    });
  });

  testWidgets('el panel: perfil, medidas y curva', (tester) async {
    final el = sweep(SweepKind.railing);
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
    expect(find.byKey(const ValueKey('sweep-every')), findsOneWidget);
    expect(find.byKey(const ValueKey('sweep-curve')), findsOneWidget);
    final track = find.byKey(const ValueKey('sweep-kind-track'));
    await tester.ensureVisible(track);
    await tester.tap(track);
    await tester.pump();
    expect(ArchSweep.kind(el), SweepKind.track);
    // La vía no tiene alto que tocar.
    expect(find.byKey(const ValueKey('sweep-height')), findsNothing);
    expect(
      find.text('Vía de tren · 4,80 m · traviesas cada 0,60 m'),
      findsOneWidget,
    );
  });

  testWidgets('en la planta', (tester) async {
    var id = 0;
    PlanElement at(SweepKind k, Offset a, Offset b, {double curve = 0}) =>
        (ArchSweep.create(a, b, kind: k)..id = ++id)
          ..props[ArchSweep.curveKey] = curve;
    final els = [
      at(SweepKind.track, const Offset(40, 60), const Offset(760, 60), curve: 30),
      at(SweepKind.catenary, const Offset(40, 60), const Offset(760, 60), curve: 30),
      at(SweepKind.railing, const Offset(40, 200), const Offset(360, 200)),
      at(SweepKind.kerb, const Offset(40, 260), const Offset(360, 260)),
      at(SweepKind.columns, const Offset(420, 200), const Offset(760, 200)),
      at(SweepKind.seats, const Offset(420, 280), const Offset(760, 280)),
      at(SweepKind.deck, const Offset(40, 430), const Offset(400, 430)),
      at(SweepKind.hull, const Offset(460, 430), const Offset(760, 430)),
      at(SweepKind.cornice, const Offset(40, 560), const Offset(760, 560)),
    ];
    await tester.pumpWidget(
      RepaintBoundary(
        child: CustomPaint(
          size: const Size(800, 600),
          painter: CameraPlanPainter(
            elements: els,
            palette: AppPalette.dark,
            metersPerUnit: mpu,
            selectedElement: els[2],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await saveSnapshot(tester, 'barridos');
  });
}
