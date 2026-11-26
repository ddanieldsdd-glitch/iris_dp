import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/theme/app_colors.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_recipe.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_terrain.dart';
import 'package:iris_dp/features/camera_plan/arch/plan_levels.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_cad_export.dart';
import 'package:iris_dp/features/camera_plan/plan_category.dart';
import 'package:iris_dp/features/camera_plan/plan_classes.dart';
import 'package:iris_dp/features/camera_plan/plan_elevation.dart';
import 'package:iris_dp/features/camera_plan/plan_opening.dart';
import 'package:iris_dp/features/camera_plan/plan_piece_controls.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/plan_street.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_rig.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';

import '../support/snapshot.dart';

/// Datos inventados: 5 cm por unidad del lienzo.
const mpu = 0.05;

/// Una receta con sus piezas.
List<PlanElement> place(
  RecipeKind k, {
  Offset at = Offset.zero,
  Map<String, Object>? params,
  double metersPerUnit = mpu,
}) {
  final r = ArchRecipe.create(k, at, params: params);
  return [r, ...ArchRecipe.build(r, metersPerUnit)];
}

void main() {
  group('Cada receta', () {
    for (final k in RecipeKind.values) {
      test(
        '${k.label}: solo piezas del motor, suyas y en todo el contrato',
        () {
          final all = place(k);
          final recipe = all.first;
          final pieces = all.skip(1).toList();
          final uid = LightOverrides.uidOf(recipe);
          expect(pieces, isNotEmpty);
          for (final p in pieces) {
            expect(ArchRecipe.ownerOf(p), uid);
            expect(ArchRecipe.isRecipe(p), isFalse);
          }
          // Cada pieza con su propio `uid`, estable al rehacer.
          final uids = [for (final p in pieces) LightOverrides.uidOf(p)];
          expect(uids.toSet().length, pieces.length);
          expect(uids.every((u) => u!.startsWith('$uid-')), isTrue);
          expect([
            for (final p in ArchRecipe.build(recipe, mpu))
              LightOverrides.uidOf(p),
          ], uids);
          // Luz, 3D, DXF y alzado lo leen sin quejarse.
          LightScene.from(all, metersPerUnit: mpu);
          final sc = PlanScene3d.build(all, metersPerUnit: mpu);
          expect(PlanScene3d.structureKey(sc), isNotNull);
          expect(PlanCadExport.planDxf(all, mpu), isNotEmpty);
          PlanElevation.of(all, metersPerUnit: mpu, side: ElevationSide.front);
          // La receta: arquitectura, sin nada propio en el 3D ni en el DXF.
          expect(PlanClass.of(recipe), PlanClass.architecture);
          expect(PlanCategory.of(recipe), PlanCategory.architecture);
          expect(RigTypeCodec.of(recipe)!.label, 'Lugar');
          expect(
            PlanScene3d.build([recipe], metersPerUnit: mpu).toString(),
            isNot(contains(uid!)),
          );
        },
      );
    }

    test('mandos con medidas de la vida real', () {
      for (final k in RecipeKind.values) {
        final r = ArchRecipe.create(k, Offset.zero);
        for (final knob in ArchRecipe.knobs(k)) {
          final v = ArchRecipe.value(r, knob.key);
          if (knob.isNumber) {
            expect(v as double, inInclusiveRange(knob.min, knob.max));
          }
        }
      }
      final station = ArchRecipe.create(RecipeKind.station, Offset.zero);
      expect(
        ArchRecipe.number(station, 'platformM'),
        inInclusiveRange(0.76, 1.1),
      );
      final carriage = ArchRecipe.create(RecipeKind.carriage, Offset.zero);
      expect(ArchRecipe.number(carriage, 'widthM'), 2.9);
      // Fuera de rango, se recorta.
      ArchRecipe.set(carriage, 'widthM', 9.0);
      expect(ArchRecipe.number(carriage, 'widthM'), 3.4);
    });
  });

  group('Casa', () {
    test('por plantas: forjados con nombre, muros y huecos en su nivel', () {
      final all = place(
        RecipeKind.house,
        params: {'floors': 3.0, 'storeyM': 3.0},
      );
      final names = {
        for (final p in all)
          if (p.props[PlanLevels.nameKey] case final String n) n,
      };
      expect(names, containsAll(['Planta 1', 'Planta 2']));
      final walls = all.where(
        (p) => p.type == ElementType.wall && !PlanOpening.isOpening(p),
      );
      final levels = {for (final w in walls) PlanLevel.of(w)};
      expect(levels, containsAll([0.0, 3.0, 6.0]));
      // En 3D, cada muro lleva solo los huecos de su planta.
      final sc = PlanScene3d.build(all, metersPerUnit: mpu);
      final byZ = <double, int>{};
      for (final w in (sc['walls'] as List).cast<Map>()) {
        final z = (w['z0'] as num).toDouble();
        byZ[z] = (byZ[z] ?? 0) + (w['openings'] as List).length;
      }
      expect(byZ.keys, containsAll([0.0, 3.0, 6.0]));
      // La puerta de la calle sustituye a una ventana: mismos huecos.
      expect(byZ[0.0], byZ[3.0]);
      expect(byZ[3.0], byZ[6.0]);
      // Escalera y tejado.
      expect((sc['stairs'] as List).length, 2);
      expect((sc['solids'] as List), isNotEmpty);
    });

    test('una pieza tocada a mano se respeta al rehacer', () {
      final all = place(RecipeKind.house);
      final recipe = all.first;
      final before = all.length;
      final wall = all.firstWhere(
        (p) => p.type == ElementType.wall && !PlanOpening.isOpening(p),
      );
      wall.position += const Offset(10, 0);
      expect(ArchRecipe.markTouched(wall), isTrue);
      expect(ArchRecipe.markTouched(wall), isFalse);
      expect(ArchRecipe.markTouched(recipe), isFalse);
      ArchRecipe.set(recipe, 'floors', 1.0);
      ArchRecipe.regenerate(all, recipe, mpu);
      expect(all.length, lessThan(before));
      expect(all, contains(wall));
      expect(
        all.where((p) => LightOverrides.uidOf(p) == LightOverrides.uidOf(wall)),
        hasLength(1),
      );
      expect(ArchRecipe.summary(recipe, all), contains('1 tocadas a mano'));
    });
  });

  test('Habitación: cada tipo con sus muebles', () {
    final counts = <String, int>{};
    for (final type in ['bedroom', 'kitchen', 'bathroom', 'living', 'bar']) {
      final all = place(RecipeKind.room, params: {'type': type});
      counts[type] = all.where((p) => p.type == ElementType.prop).length;
      expect(counts[type], greaterThan(0), reason: type);
    }
    expect(counts.values.toSet().length, greaterThan(1));
  });

  test('Edificio: más plantas, más piezas; bajo comercial opcional', () {
    final low = place(RecipeKind.building, params: {'floors': 2.0});
    final high = place(RecipeKind.building, params: {'floors': 6.0});
    expect(high.length, greaterThan(low.length));
    // El bajo comercial: escaparates casi hasta el suelo.
    bool showcase(List<PlanElement> els) =>
        els.any((p) => PlanOpening.isWindow(p) && PlanOpening.sill(p) < 0.5);
    expect(showcase(place(RecipeKind.building)), isTrue);
    expect(
      showcase(
        place(RecipeKind.building, params: {'shop': false, 'balconies': false}),
      ),
      isFalse,
    );
  });

  test('Puente y playa: agua bajo el tablero y en la orilla', () {
    final bridge = place(RecipeKind.bridge);
    final river = bridge.where(ArchTerrain.isTerrain).single;
    expect(ArchTerrain.water(river), isNotNull);
    final dry = place(RecipeKind.bridge, params: {'river': false});
    expect(dry.where(ArchTerrain.isTerrain), isEmpty);

    final beach = place(RecipeKind.beach, metersPerUnit: 0.2);
    final sand = beach.where(ArchTerrain.isTerrain).single;
    expect(ArchTerrain.water(sand), 0);
    final scene = LightScene.from(beach, metersPerUnit: 0.2);
    expect(scene, isNotNull);
  });

  test('Calle: edificios a los dos lados, de cara a la calle', () {
    final all = place(RecipeKind.street, metersPerUnit: 0.2);
    expect(all.where(StreetProfile.isStreet), hasLength(1));
    final doors = all.where(
      (p) => PlanOpening.isDoor(p) && PlanLevel.of(p) == 0,
    );
    // Una puerta por edificio, en la fachada de la calle (a 3 + 3,5 m).
    expect(doors.any((d) => d.position.dy < 0), isTrue);
    expect(doors.any((d) => d.position.dy > 0), isTrue);
    for (final d in doors) {
      expect((d.position.dy * 0.2).abs(), closeTo(6.5, 0.01));
    }
    final one = place(
      RecipeKind.street,
      params: {'both': false},
      metersPerUnit: 0.2,
    );
    expect(one.length, lessThan(all.length));
  });

  test('Puente de arco y paso subterráneo', () {
    final arch = place(RecipeKind.bridge, params: {'type': 'arch'});
    final stones = arch.where(
      (p) => LightOverrides.uidOf(p)!.contains('-arch'),
    );
    expect(stones, hasLength(24));
    final top = stones.map(PlanLevel.of).reduce((a, b) => a > b ? a : b);
    expect(top, greaterThan(3));

    final station = place(RecipeKind.station);
    final down = station.where(
      (p) => LightOverrides.uidOf(p)!.endsWith('-down'),
    );
    expect(down, hasLength(1));
    expect(PlanLevel.of(down.single), -3.2);
    final none = place(RecipeKind.station, params: {'underpass': false});
    expect(
      none.where((p) => LightOverrides.uidOf(p)!.contains('tunnel')),
      isEmpty,
    );
  });

  test('Casa: tantas habitaciones al fondo como se pidan', () {
    int doors(double rooms) => place(
      RecipeKind.house,
      params: {'floors': 1.0, 'rooms': rooms, 'widthM': 14.0},
    ).where((p) => PlanOpening.isDoor(p)).length;
    expect(doors(3), doors(1) + 2);
  });

  test('«Nuevo set» desde un lugar tipo', () {
    final els = ArchRecipe.standalone(RecipeKind.station);
    expect(els.every((e) => e.layer == PlanLayer.environment), isTrue);
    final json = FloorPlanJson.encodeDocument(
      FloorPlanDocument(elements: els, metersPerUnit: defaultMetersPerUnit),
    );
    final back = FloorPlanJson.decodeDocument(json);
    expect(back.elements.length, els.length);
    expect(back.elements.where(ArchRecipe.isRecipe), hasLength(1));
    final recipe = back.elements.firstWhere(ArchRecipe.isRecipe);
    expect(ArchRecipe.kind(recipe), RecipeKind.station);
    // Al rehacerla tras leerla, no se duplica nada.
    final again = [...back.elements];
    ArchRecipe.regenerate(again, recipe, defaultMetersPerUnit);
    expect(again.length, els.length);
  });

  testWidgets('el panel: tipo de habitación y medidas', (tester) async {
    final el = ArchRecipe.create(RecipeKind.room, Offset.zero);
    var updates = 0;
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
                onUpdate: () => setState(() => updates++),
              ),
            ),
          ),
        ),
      ),
    );
    expect(PlanPieceControls.appliesTo(el), isTrue);
    expect(find.byKey(const ValueKey('recipe-widthM')), findsOneWidget);
    final kitchen = find.byKey(const ValueKey('recipe-type-kitchen'));
    await tester.ensureVisible(kitchen);
    await tester.tap(kitchen);
    await tester.pump();
    expect(ArchRecipe.value(el, 'type'), 'kitchen');
    expect(updates, 1);
  });

  group('Sets de ejemplo', () {
    Future<void> snap(
      WidgetTester tester,
      String name,
      List<PlanElement> els,
      double metersPerUnit,
      Size size,
    ) async {
      var id = 1;
      for (final e in els) {
        e.id = id++;
      }
      await tester.pumpWidget(
        RepaintBoundary(
          child: CustomPaint(
            size: size,
            painter: CameraPlanPainter(
              elements: els,
              palette: AppPalette.dark,
              metersPerUnit: metersPerUnit,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      await saveSnapshot(tester, name);
    }

    testWidgets('casa', (tester) async {
      await snap(
        tester,
        'receta-casa',
        place(RecipeKind.house, at: const Offset(160, 130)),
        mpu,
        const Size(320, 260),
      );
    });

    testWidgets('calle con edificio', (tester) async {
      await snap(
        tester,
        'receta-edificio',
        place(RecipeKind.building, at: const Offset(200, 160)),
        mpu,
        const Size(400, 320),
      );
    });

    testWidgets('estación con vagón', (tester) async {
      const m = 0.2;
      await snap(
        tester,
        'receta-estacion',
        [
          ...place(
            RecipeKind.station,
            at: const Offset(200, 80),
            metersPerUnit: m,
          ),
          ...place(
            RecipeKind.carriage,
            at: const Offset(200, 160),
            metersPerUnit: m,
          ),
        ],
        m,
        const Size(400, 220),
      );
    });

    testWidgets('playa', (tester) async {
      const m = 0.2;
      await snap(
        tester,
        'receta-playa',
        place(RecipeKind.beach, at: const Offset(170, 120), metersPerUnit: m),
        m,
        const Size(340, 240),
      );
    });
  });
}
