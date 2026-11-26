import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/theme/app_colors.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_terrain.dart';
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

import '../support/snapshot.dart';

/// Datos inventados: 10 cm por unidad del lienzo.
const mpu = 0.1;

/// Un terreno de 40 × 30 m con el centro en (200, 150).
PlanElement terrain() =>
    ArchTerrain.create(Offset.zero, const Offset(400, 300), mpu);

/// Una loma de 6 m en el centro, subida a pinceladas.
PlanElement ridge() {
  final t = terrain();
  for (var k = 0; k < 12; k++) {
    ArchTerrain.stroke(
      t,
      const Offset(200, 150),
      const TerrainBrush(radiusM: 8, strengthM: 0.5),
      mpu,
    );
  }
  return t;
}

void main() {
  group('Modelo', () {
    test('un rectángulo llano con casillas de medio metro', () {
      final t = terrain();
      expect(ArchTerrain.isTerrain(t), isTrue);
      expect(ArchTerrain.widthM(t), closeTo(40, 1e-9));
      expect(ArchTerrain.depthM(t), closeTo(30, 1e-9));
      expect(ArchTerrain.cellM(t), 0.5);
      expect(t.position, const Offset(200, 150));
      expect(ArchTerrain.heightAt(t, const Offset(10, 10), mpu), 0);
      expect(ArchTerrain.heightAt(t, const Offset(-10, 10), mpu), isNull);
      // Uno grande no pasa de 80 casillas por lado.
      final big = ArchTerrain.create(Offset.zero, const Offset(3000, 500), mpu);
      expect(ArchTerrain.cols(big), lessThanOrEqualTo(80));
      expect(ArchTerrain.widthM(big), closeTo(300, 2));
      // Se guarda y se lee igual.
      final back = FloorPlanJson.decode(FloorPlanJson.encode([ridge()])).single;
      expect(
        ArchTerrain.range(back).$2,
        closeTo(ArchTerrain.range(ridge()).$2, 0.01),
      );
    });

    test('subir, bajar, alisar y aplanar', () {
      final t = ridge();
      final top = ArchTerrain.heightAt(t, const Offset(200, 150), mpu)!;
      expect(top, closeTo(6, 0.01));
      // Fuera del radio no cambia.
      expect(ArchTerrain.heightAt(t, const Offset(20, 20), mpu), 0);
      // Más baja hacia el borde de la pincelada.
      expect(
        ArchTerrain.heightAt(t, const Offset(240, 150), mpu)!,
        inExclusiveRange(0.1, top),
      );
      ArchTerrain.stroke(
        t,
        const Offset(200, 150),
        const TerrainBrush(mode: TerrainBrushMode.lower, strengthM: 1),
        mpu,
      );
      expect(
        ArchTerrain.heightAt(t, const Offset(200, 150), mpu),
        closeTo(5, 0.01),
      );
      final before = ArchTerrain.heightAt(t, const Offset(200, 150), mpu)!;
      ArchTerrain.stroke(
        t,
        const Offset(200, 150),
        const TerrainBrush(mode: TerrainBrushMode.smooth, radiusM: 4),
        mpu,
      );
      expect(
        ArchTerrain.heightAt(t, const Offset(200, 150), mpu)!,
        lessThan(before),
      );
      for (var k = 0; k < 20; k++) {
        ArchTerrain.stroke(
          t,
          const Offset(200, 150),
          const TerrainBrush(
            mode: TerrainBrushMode.flatten,
            radiusM: 3,
            flattenTo: 1.5,
          ),
          mpu,
        );
      }
      expect(
        ArchTerrain.heightAt(t, const Offset(200, 150), mpu),
        closeTo(1.5, 0.05),
      );
    });

    test('pintar arena sobre la hierba', () {
      final t = terrain();
      ArchTerrain.stroke(
        t,
        const Offset(100, 100),
        const TerrainBrush(mode: TerrainBrushMode.paint, radiusM: 2),
        mpu,
      );
      expect(ArchTerrain.materials(t), ['grass', 'sand']);
      final painted = ArchTerrain.paint(t).where((m) => m == 1).length;
      // Un círculo de 2 m en casillas de 0,5 m: unas 50.
      expect(painted, inInclusiveRange(40, 60));
      final mesh = ArchTerrain.mesh(t, mpu);
      expect(mesh.keys, containsAll(['grass', 'sand']));
      final cells = ArchTerrain.cols(t) * ArchTerrain.rows(t);
      expect(
        mesh.values.fold<int>(0, (n, m) => n + m.tris.length),
        cells * 2 * 3 * 3,
      );
    });

    test('las colinas y los taludes de antes pasan al terreno', () {
      final t = terrain();
      final hill = PlanElement(
        id: 1,
        type: ElementType.prop,
        position: const Offset(100, 150),
        label: PropType.hill.dbValue,
        props: {LightScene.sizeKey: 5.0, LightScene.heightKey: 4.0},
      );
      final bank = PlanSegment.create(
        start: const Offset(260, 20),
        end: const Offset(260, 280),
        kind: PlanSegment.kindRelief,
      )..props[LightScene.heightKey] = 2.0;
      final away = PlanElement(
        id: 3,
        type: ElementType.prop,
        position: const Offset(900, 900),
        label: PropType.hill.dbValue,
      );
      final taken = ArchTerrain.absorb(t, [hill, bank, away], mpu);
      expect(taken, [hill, bank]);
      expect(
        ArchTerrain.heightAt(t, const Offset(100, 150), mpu),
        closeTo(4, 0.05),
      );
      // Fuera de la colina, llano.
      expect(ArchTerrain.heightAt(t, const Offset(40, 40), mpu), 0);
      // El talud: arriba de un lado, abajo del otro.
      final hA = ArchTerrain.heightAt(t, const Offset(240, 150), mpu)!;
      final hB = ArchTerrain.heightAt(t, const Offset(280, 150), mpu)!;
      expect({hA, hB}.reduce(math.max), closeTo(2, 0.05));
      expect({hA, hB}.reduce(math.min), lessThan(1));
    });

    test('curvas de nivel y agua', () {
      final t = ridge();
      final step = ArchTerrain.contourStep(t);
      expect(step, 0.5);
      final lines = ArchTerrain.contours(t, mpu);
      expect(lines, isNotEmpty);
      expect({for (final (_, _, z) in lines) z}, contains(3.0));
      // Cada tramo de la curva de 3 m está a esa cota.
      for (final (a, b, z) in lines.where((l) => l.$3 == 3.0)) {
        expect(ArchTerrain.heightAt(t, (a + b) / 2, mpu), closeTo(z, 0.15));
      }
      expect(ArchTerrain.flooded(t, mpu), isEmpty);
      ArchTerrain.setWater(t, 2);
      // Todo bajo el agua menos la loma.
      final wet = ArchTerrain.flooded(t, mpu);
      final cells = ArchTerrain.cols(t) * ArchTerrain.rows(t);
      expect(wet.length, inExclusiveRange(cells ~/ 2, cells));
      expect(ArchTerrain.mesh(t, mpu).keys, contains(ArchTerrain.waterMat));
      expect(ArchTerrain.summary(t), contains('agua a 2.00 m'));
    });
  });

  group('Contrato', () {
    test('la luz: cota del suelo, laderas que tapan y fosos', () {
      final t = ridge();
      final scene = LightScene.from([t], metersPerUnit: mpu);
      expect(scene.groundAt(const Offset(200, 150)), closeTo(6, 0.01));
      expect(scene.groundAt(const Offset(20, 20)), 0);
      // De un lado de la loma al otro, a la altura de la cara: tapado.
      expect(
        scene.transmissionBetween(
          const Offset(60, 150),
          const Offset(340, 150),
        ),
        0,
      );
      // Por un lado, sin loma en medio: pasa.
      expect(
        scene.transmissionBetween(const Offset(20, 20), const Offset(380, 20)),
        1,
      );
      // Un foso baja de cero.
      final pit = terrain();
      ArchTerrain.stroke(
        pit,
        const Offset(200, 150),
        const TerrainBrush(mode: TerrainBrushMode.lower, strengthM: 2),
        mpu,
      );
      expect(
        LightScene.from([
          pit,
        ], metersPerUnit: mpu).groundAt(const Offset(200, 150)),
        closeTo(-2, 0.01),
      );
    });

    test('3D, Unreal, DXF, clase y paleta', () {
      final t = ridge()..id = 1;
      ArchTerrain.setWater(t, 1);
      final sc = PlanScene3d.build([t], metersPerUnit: mpu);
      final list = sc['terrains'] as List;
      expect(
        [for (final m in list) (m as Map)['uid']],
        containsAll([
          '${PlanScene3d.idOf(t, 0)}:grass',
          '${PlanScene3d.idOf(t, 0)}:water',
        ]),
      );
      final grass = list.first as Map;
      final tris = (grass['tris'] as List).cast<num>();
      final norms = (grass['norms'] as List).cast<num>();
      expect(norms.length, tris.length);
      // De cara arriba: en metros de la planta (y al norte) el primer
      // triángulo gira en sentido antihorario y su normal sube.
      final a = Offset(tris[0].toDouble(), tris[1].toDouble());
      final b = Offset(tris[3].toDouble(), tris[4].toDouble());
      final c = Offset(tris[6].toDouble(), tris[7].toDouble());
      final cross = (b - a).dx * (c - a).dy - (b - a).dy * (c - a).dx;
      expect(cross, greaterThan(0));
      expect(norms[2], greaterThan(0));
      expect(PlanScene3d.materialsOf(sc).keys, containsAll(['grass', 'water']));
      expect(PlanScene3d.structureKey(sc), isNotNull);

      final dxf = PlanCadExport.planDxf([t], mpu);
      expect(dxf, contains('\n${PlanCadExport.layerTerrain}\n'));
      expect(dxf, contains('\n${PlanCadExport.layerWater}\n'));
      expect(dxf, contains('5 m'));

      expect(PlanClass.of(t), PlanClass.architecture);
      expect(PlanCategory.of(t), PlanCategory.architecture);
      expect(RigTypeCodec.of(t)!.label, 'Terreno');
      expect(PlanTool.terrain.drawsSegment, isTrue);
    });

    test('en el 3D, muebles, personas, cámaras y focos se apoyan en él', () {
      final t = ridge();
      final actor = PlanElement(
        id: 2,
        type: ElementType.actor,
        position: const Offset(200, 150),
      );
      final chair = PlanElement(
        id: 3,
        type: ElementType.prop,
        position: const Offset(200, 150),
        label: PropType.chair.dbValue,
      );
      final cam = PlanElement(
        id: 4,
        type: ElementType.camera,
        position: const Offset(20, 20),
      );
      final sc = PlanScene3d.build([
        t,
        actor,
        chair,
        cam,
      ], metersPerUnit: mpu);
      expect((sc['people'] as List).single['z0'], closeTo(6, 0.05));
      expect((sc['props'] as List).single['z0'], closeTo(6, 0.05));
      expect((sc['cameras'] as List).single['z0'], closeTo(0, 0.05));
    });

    test('alzado y sección: la loma de lado y cortada', () {
      final t = ridge();
      final side = PlanElevation.of(
        [t],
        metersPerUnit: mpu,
        side: ElevationSide.front,
      );
      final item = side.items.singleWhere((i) => i.label == 'Terreno');
      expect(item.top, closeTo(6, 0.01));
      expect(item.to - item.from, closeTo(40, 0.01));
      final peak = item.profile.map((p) => p.$2).reduce(math.max);
      expect(peak, closeTo(6, 0.1));

      final cut = PlanSection.create(
        const Offset(0, 150),
        const Offset(400, 150),
      );
      final e = PlanSection.elevationOf(cut, [t, cut], metersPerUnit: mpu);
      final section = e.items.singleWhere((i) => i.cut);
      expect(section.top, closeTo(6, 0.05));
      expect(section.profile.first.$2, closeTo(0, 0.05));
    });
  });

  testWidgets('el panel: pincel, agua y llano', (tester) async {
    final el = ridge();
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
    expect(ArchTerrain.brush.value, isNull);
    await tester.tap(find.byKey(const ValueKey('terrain-brush')));
    await tester.pump();
    expect(ArchTerrain.brush.value?.mode, TerrainBrushMode.raise);
    await tester.tap(find.byKey(const ValueKey('terrain-mode-paint')));
    await tester.pump();
    expect(ArchTerrain.brush.value?.mode, TerrainBrushMode.paint);
    expect(find.byKey(const ValueKey('terrain-paint-sand')), findsOneWidget);
    final water = find.byKey(const ValueKey('terrain-water'));
    await tester.ensureVisible(water);
    await tester.tap(water);
    await tester.pump();
    expect(ArchTerrain.water(el), closeTo(3, 0.01));
    final flat = find.byKey(const ValueKey('terrain-flat'));
    await tester.ensureVisible(flat);
    await tester.tap(flat);
    await tester.pump();
    expect(ArchTerrain.range(el).$2, 0);
    // Al cerrar el panel, el pincel se quita.
    await tester.pumpWidget(const SizedBox());
    expect(ArchTerrain.brush.value, isNull);
  });

  testWidgets('en la planta', (tester) async {
    final t = ridge()..id = 1;
    ArchTerrain.stroke(
      t,
      const Offset(80, 220),
      const TerrainBrush(mode: TerrainBrushMode.paint, radiusM: 5),
      mpu,
    );
    for (var k = 0; k < 6; k++) {
      ArchTerrain.stroke(
        t,
        const Offset(330, 60),
        const TerrainBrush(mode: TerrainBrushMode.lower, radiusM: 6),
        mpu,
      );
    }
    ArchTerrain.setWater(t, -0.5);
    await tester.pumpWidget(
      RepaintBoundary(
        child: CustomPaint(
          size: const Size(420, 320),
          painter: CameraPlanPainter(
            elements: [t],
            palette: AppPalette.dark,
            metersPerUnit: mpu,
            selectedElement: t,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await saveSnapshot(tester, 'terreno');
  });
}
