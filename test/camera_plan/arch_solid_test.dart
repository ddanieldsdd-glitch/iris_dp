import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/core/theme/app_colors.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_material.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_solid.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/plan_cad_export.dart';
import 'package:iris_dp/features/camera_plan/plan_category.dart';
import 'package:iris_dp/features/camera_plan/plan_classes.dart';
import 'package:iris_dp/features/camera_plan/plan_elevation.dart';
import 'package:iris_dp/features/camera_plan/plan_piece_controls.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_rig.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';

import '../support/snapshot.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // 1 unidad del lienzo = 1 cm.
  const mpu = 0.01;

  /// Una barra de 4 × 0,6 m con el centro en (200, 100).
  PlanElement bar() => ArchSolid.rectangle(
    RigType.volume,
    const Offset(0, 70),
    const Offset(400, 130),
    mpu,
  );

  /// Una tarima de 3 × 2 m a 40 cm.
  PlanElement stage() => ArchSolid.rectangle(
    RigType.slab,
    const Offset(0, 300),
    const Offset(300, 500),
    mpu,
  );

  group('modelo', () {
    test('un rectángulo de esquina a esquina, con el centro en su sitio', () {
      final b = bar();
      expect(ArchSolid.isVolume(b), isTrue);
      expect(b.position, const Offset(200, 100));
      expect(ArchSolid.sizeM(b), const Size(4, 0.6));
      expect(ArchSolid.areaM2(b), closeTo(2.4, 1e-9));
      expect(ArchSolid.topM(b), ArchSolid.defaultVolumeM);
      expect(ArchSolid.bottomM(b), 0);
      expect(ArchSolid.material(b).id, ArchSolid.defaultVolumeMat);
      expect(b.props['uid'], isNotNull);
    });

    test('un forjado: de su cota menos el grosor a su cota', () {
      final s = stage();
      expect(ArchSolid.isSlab(s), isTrue);
      expect(ArchSolid.topM(s), 0.4);
      expect(ArchSolid.bottomM(s), closeTo(0.2, 1e-9));
      expect(ArchSolid.isOverhead(s), isFalse);
      // Una entreplanta a 3 m: por encima de la cabeza.
      s.props[ArchSolid.topKey] = 3.0;
      s.props[ArchSolid.thickKey] = 0.3;
      expect(ArchSolid.isOverhead(s), isTrue);
      // Una tarima más fina que su cota no se mete bajo el suelo.
      s.props[ArchSolid.topKey] = 0.1;
      expect(ArchSolid.bottomM(s), 0);
    });

    test('gira con el elemento y se coge tocando dentro', () {
      final b = bar();
      expect(ArchSolid.contains(b, const Offset(390, 100), mpu), isTrue);
      expect(ArchSolid.contains(b, const Offset(200, 150), mpu), isFalse);
      b.rotation = 90;
      expect(ArchSolid.contains(b, const Offset(390, 100), mpu), isFalse);
      expect(ArchSolid.contains(b, const Offset(200, 280), mpu), isTrue);
      final pts = ArchSolid.outline(b, mpu);
      expect(pts.first.dx, closeTo(230, 1e-6));
      expect(pts.first.dy, closeTo(-100, 1e-6));
    });

    test('cambiar ancho y fondo sin moverlo', () {
      final b = bar()..rotation = 30;
      ArchSolid.resize(b, const Size(2, 1));
      expect(ArchSolid.sizeM(b).width, closeTo(2, 1e-9));
      expect(ArchSolid.sizeM(b).height, closeTo(1, 1e-9));
      expect(b.position, const Offset(200, 100));
    });

    test('pasa por el JSON de la planta', () {
      final b = bar()..props[ArchMaterials.key] = 'wood-planks';
      final back = FloorPlanJson.decode(FloorPlanJson.encode([b])).single;
      expect(ArchSolid.isVolume(back), isTrue);
      expect(ArchSolid.sizeM(back), ArchSolid.sizeM(b));
      expect(ArchSolid.material(back).id, 'wood-planks');
    });

    test('clase y categoría: arquitectura', () {
      expect(PlanClass.of(bar()), PlanClass.architecture);
      expect(PlanClass.of(stage()), PlanClass.architecture);
      expect(PlanCategory.of(bar()), PlanCategory.architecture);
    });
  });

  group('contrato de la pieza', () {
    test('luz: cada lado tapa de su cota de abajo a la de arriba', () {
      final b = bar();
      final s = stage()
        ..props[ArchSolid.topKey] = 3.0
        ..props[ArchSolid.thickKey] = 0.3;
      final scene = LightScene.from([b, s], metersPerUnit: mpu);
      final ofBar = scene.blockers.where((x) => x.element == b).toList();
      expect(ofBar, hasLength(4));
      expect(ofBar.every((x) => x.heightM == ArchSolid.defaultVolumeM), isTrue);
      expect(ofBar.every((x) => x.baseM == 0), isTrue);
      final ofSlab = scene.blockers.where((x) => x.element == s).toList();
      expect(ofSlab, hasLength(4));
      // La entreplanta deja pasar la luz por debajo.
      expect(ofSlab.first.baseM, closeTo(2.7, 1e-9));
      expect(ofSlab.first.heightM, 3.0);
    });

    test('3D y Unreal: su contorno, sus cotas y su material', () {
      final b = bar()..props[ArchMaterials.key] = 'brick-tan';
      final s = stage();
      PlanLevel.set(s, 1);
      final truss = PlanTruss.create(Offset.zero, const Offset(300, 0));
      final sc = PlanScene3d.build([b, s, truss], metersPerUnit: mpu);
      final solids = (sc['solids'] as List).cast<Map>();
      expect(solids, hasLength(2));
      // Ni ellos ni el truss salen además como atrezzo.
      expect(sc['props'], isEmpty);
      final v = solids.firstWhere((x) => x['kind'] == 'volume');
      expect(v['outline'], hasLength(4));
      expect(v['outline'].first, [0.0, -0.7]);
      expect(v['z0'], 0);
      expect(v['z1'], ArchSolid.defaultVolumeM);
      expect(v['mat'], 'brick-tan');
      expect(v['cls'], 'architecture');
      final f = solids.firstWhere((x) => x['kind'] == 'slab');
      // Con su nivel.
      expect(f['z0'], closeTo(1.2, 1e-9));
      expect(f['z1'], closeTo(1.4, 1e-9));
      expect(
        (sc['materials'] as Map).keys,
        containsAll(['brick-tan', ArchSolid.defaultSlabMat]),
      );
      // Mover un volumen cambia la estructura que va a Unreal.
      final before = PlanScene3d.structureKey(sc);
      b.position += const Offset(50, 0);
      expect(
        PlanScene3d.structureKey(PlanScene3d.build([b, s], metersPerUnit: mpu)),
        isNot(before),
      );
    });

    test('DXF: su contorno en la capa de volúmenes', () {
      final dxf = PlanCadExport.planDxf([bar()], mpu);
      expect(dxf, contains(PlanCadExport.layerSolids));
      // La capa y los cuatro lados.
      expect(
        PlanCadExport.layerSolids.allMatches(dxf).length,
        greaterThanOrEqualTo(5),
      );
    });

    test('alzado: de su cota de abajo a la de arriba', () {
      final b = bar();
      final front = PlanElevation.of(
        [b],
        metersPerUnit: mpu,
        side: ElevationSide.front,
      );
      final item = front.items.singleWhere((i) => i.element == b);
      expect(item.bottom, 0);
      expect(item.top, ArchSolid.defaultVolumeM);
      expect(item.to - item.from, closeTo(4, 1e-6));
    });
  });

  testWidgets('el panel: medidas, alto y material', (tester) async {
    final b = bar();
    final s = stage();
    Future<void> pump(PlanElement el) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PlanPieceControls(
              element: el,
              metersPerUnit: mpu,
              onPreview: () {},
              onUpdate: () {},
            ),
          ),
        ),
      ),
    );
    expect(PlanPieceControls.appliesTo(b), isTrue);
    await pump(b);
    expect(find.text('Ancho'), findsOneWidget);
    expect(find.text('4.00 m'), findsOneWidget);
    expect(find.text('Alto'), findsOneWidget);
    expect(find.text('Pintura blanca · Yeso y pintura'), findsOneWidget);
    await pump(s);
    expect(find.text('Cota de arriba'), findsOneWidget);
    expect(find.text('+0.40 m'), findsOneWidget);
    expect(find.text('Grosor'), findsOneWidget);
  });

  testWidgets('en la planta', (tester) async {
    final upper = stage()
      ..position = const Offset(500, 220)
      ..props[ArchSolid.topKey] = 3.0;
    final elements = [
      bar()
        ..id = 1
        ..props[ArchMaterials.key] = 'wood-planks',
      stage()..id = 2,
      upper..id = 3,
      PlanSegment.create(start: const Offset(-20, 40), end: const Offset(700, 40)),
    ];
    await tester.pumpWidget(
      RepaintBoundary(
        child: CustomPaint(
          size: const Size(760, 560),
          painter: CameraPlanPainter(
            elements: elements,
            palette: AppPalette.dark,
            selectedElement: upper,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await saveSnapshot(tester, 'forjados_volumenes');
  });
}
