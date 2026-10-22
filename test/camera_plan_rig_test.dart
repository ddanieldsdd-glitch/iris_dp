import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/core/theme/app_theme.dart';

import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_opening.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/rig/catenary.dart';
import 'package:iris_dp/features/camera_plan/rig/drape_controls.dart';
import 'package:iris_dp/features/camera_plan/rig/hall_builder_sheet.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_drape.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_hall.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_rig.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';

const mpu = 0.02; // 2 cm por unidad: 50 unidades por metro.

PlanElement light(Offset at) => PlanElement(
  id: 0,
  type: ElementType.light,
  position: at,
  lightType: LightType.lightPanel,
);

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('catenaria', () {
    test('baja la flecha en el centro y nada en los amarres', () {
      final c = Catenary.fromSag(6, 0.4);
      expect(c.dropAt(0), closeTo(0, 1e-9));
      expect(c.dropAt(1), closeTo(0, 1e-9));
      expect(c.dropAt(0.5), closeTo(-0.4, 1e-6));
    });

    test('la cuerda mide algo más que la luz y vuelve a dar la flecha', () {
      final c = Catenary.fromSag(6, 0.4);
      expect(c.rope, greaterThan(6));
      expect(c.rope, closeTo(6.07, 0.01));
      expect(Catenary.fromRope(6, c.rope).sag, closeTo(0.4, 1e-3));
    });

    test('cuanto menos cae, más tira de los amarres', () {
      final slack = Catenary.fromSag(6, 0.8).anchorTension(2);
      final tight = Catenary.fromSag(6, 0.1).anchorTension(2);
      expect(tight, greaterThan(slack * 4));
      expect(Catenary.fromSag(6, 0).isTaut, isTrue);
    });
  });

  group('pared de tela', () {
    test('el bajo sigue la curva y no pasa del suelo', () {
      final drape = PlanDrape.create(
        Offset.zero,
        const Offset(300, 0), // 6 m
        anchorM: 4.4,
        sagM: 0.4,
        lengthM: 1.2,
      );
      expect(PlanDrape.isDrape(drape), isTrue);
      expect(PlanSegment.kind(drape), PlanDrape.kind);
      final c = PlanDrape.catenary(drape, mpu);
      expect(PlanDrape.topAt(drape, 0.5, c), closeTo(4.0, 1e-3));
      expect(PlanDrape.clearanceM(drape, c), closeTo(2.8, 1e-3));

      drape.props[PlanDrape.lengthKey] = 5.0;
      expect(PlanDrape.clearanceM(drape, c), 0);
      expect(PlanDrape.poolM(drape, c), closeTo(1.0, 1e-3));
    });

    test('el largo de cuerda manda sobre la flecha', () {
      final drape = PlanDrape.create(Offset.zero, const Offset(300, 0));
      drape.props[PlanDrape.ropeKey] = 6.07;
      expect(PlanDrape.catenary(drape, mpu).sag, closeTo(0.4, 0.02));
      PlanDrape.setSag(drape, 0.2);
      expect(drape.props.containsKey(PlanDrape.ropeKey), isFalse);
    });
  });

  group('truss', () {
    test('se parte en tramos de catálogo', () {
      expect(PlanTruss.breakdown(12).pieces, [4, 4, 4]);
      final odd = PlanTruss.breakdown(7.3);
      expect(odd.pieces, [4, 3]);
      expect(odd.rest, closeTo(0.3, 1e-6));
      expect(PlanTruss.breakdown(5.5).pieces, [4, 1.5]);
    });

    test('una luz soltada cerca se cuelga a la altura del truss', () {
      final truss = PlanTruss.create(
        const Offset(0, 0),
        const Offset(600, 0),
        lowM: 5,
      );
      final l = light(const Offset(150, 20));
      expect(TrussMagnet.snap(l, [truss, l], mpu), isTrue);
      expect(l.position, const Offset(150, 0));
      expect(PlanLight.isOverhead(l), isTrue);
      expect(PlanLight.heightOf(l), closeTo(4.65, 1e-9));
      expect(TrussMagnet.trussUidOf(l), LightOverrides.uidOf(truss));

      // Lejos, no se engancha y se descuelga.
      l.position = const Offset(150, 400);
      expect(TrussMagnet.snap(l, [truss, l], mpu), isFalse);
      expect(TrussMagnet.rigOf(l), isNull);
    });

    test('lo colgado sigue al truss y se suelta si el truss desaparece', () {
      final truss = PlanTruss.create(Offset.zero, const Offset(600, 0));
      final l = light(const Offset(300, 10));
      final elements = [truss, l];
      TrussMagnet.snap(l, elements, mpu);
      truss.position = const Offset(0, 100);
      PlanTruss.setEnd(truss, const Offset(600, 100));
      truss.props[PlanTruss.lowKey] = 6.0;
      TrussMagnet.follow(elements, mpu);
      expect(l.position, const Offset(300, 100));
      expect(PlanLight.heightOf(l), closeTo(5.65, 1e-9));

      elements.remove(truss);
      TrussMagnet.follow(elements, mpu);
      expect(TrussMagnet.rigOf(l), isNull);
    });
  });

  group('nave', () {
    PlanElement hallOf(HallRecipe r) => PlanHall.create(Offset.zero, r);

    test(
      'una caseta de lona sale con bambalinas, pilares y ground support',
      () {
        final hall = hallOf(HallRecipe.rectangle(width: 24, depth: 12));
        final built = PlanHall.build(hall, mpu);
        final walls = built.where(
          (e) => PlanSegment.isSegment(e) && !PlanDrape.isDrape(e),
        );
        expect(walls.length, 3);
        expect(built.where(PlanDrape.isDrape).length, 4);
        expect(built.where(PlanPillar.isPillar).length, 12);
        final trusses = built.where(PlanTruss.isTruss).toList();
        expect(trusses.length, 6); // 4 líneas y 2 travesaños
        final rig = built.where(PlanRigPoint.isRigPoint).toList();
        expect(
          rig.every((e) => RigTypeCodec.of(e) == RigType.groundSupport),
          isTrue,
        );
        expect(rig.length, 12);
        // Todo lo generado lleva la nave y un uid propio.
        expect(
          built.every(
            (e) => PlanHall.hallUidOf(e) == LightOverrides.uidOf(hall),
          ),
          isTrue,
        );
        expect(built.map(LightOverrides.uidOf).toSet().length, built.length);
      },
    );

    test('con cubierta que carga, los motores van en la línea de pilares', () {
      final hall = hallOf(
        HallRecipe.rectangle(width: 24, depth: 12, roof: HallRoof.gable),
      );
      final rig = PlanHall.build(hall, mpu).where(PlanRigPoint.isRigPoint);
      expect(rig.every((e) => RigTypeCodec.of(e) == RigType.motor), isTrue);
      // 21,6 m de línea, cada 6 m como mucho: 5 puntos por línea.
      expect(rig.length, 4 * 5);
    });

    test('la cubierta a dos aguas sube hasta la cumbrera', () {
      final r = HallRecipe.rectangle(
        width: 24,
        depth: 12,
        roof: HallRoof.gable,
        eaveM: 4.5,
        riseM: 2,
      );
      expect(r.roofAt(const Offset(12, 6)), closeTo(6.5, 1e-6));
      expect(r.roofAt(const Offset(12, 0)), closeTo(4.5, 1e-6));
      final tent = r.copyWith(roof: HallRoof.tensile, sagM: 0.3);
      // Entre cerchas la lona cae; sobre la cercha no.
      expect(tent.roofAt(const Offset(3, 0)), lessThan(4.5));
      expect(tent.roofAt(const Offset(6, 0)), closeTo(4.5, 1e-6));
    });

    test('lados curvos, ventanales y pilares dentro', () {
      final base = HallRecipe.rectangle(width: 24, depth: 12);
      final r = base.copyWith(
        edges: [
          const HallEdge(kind: HallEdgeKind.glass, sillM: 0, bulgeM: 2),
          ...base.edges.skip(1),
        ],
        interiorPillarsM: 6,
      );
      final built = PlanHall.build(hallOf(r), mpu);
      final front = built.firstWhere(
        (e) => PlanSegment.isSegment(e) && PlanSegment.curve(e) != 0,
      );
      expect(PlanSegment.curve(front), closeTo(100, 1e-9));
      final glass = built.where(PlanOpening.isWindow).toList();
      expect(glass.length, greaterThanOrEqualTo(16));
      expect(PlanOpening.sill(glass.first), 0);
      expect(PlanOpening.head(glass.first), closeTo(4.35, 1e-9));
      // Hay pilares por la curva, fuera del rectángulo.
      expect(
        built.where(PlanPillar.isPillar).any((p) => p.position.dy > 12 / mpu),
        isTrue,
      );
      final inside = built.where(
        (p) =>
            PlanPillar.isPillar(p) &&
            p.position.dx > 1 / mpu &&
            p.position.dx < 23 / mpu &&
            p.position.dy > 1 / mpu &&
            p.position.dy < 11 / mpu,
      );
      expect(inside, isNotEmpty);
    });

    test('al rehacer la receta, las luces colgadas siguen en su truss', () {
      final hall = hallOf(HallRecipe.rectangle(width: 24, depth: 12));
      final elements = <PlanElement>[hall, ...PlanHall.build(hall, mpu)];
      final truss = elements.firstWhere(PlanTruss.isTruss);
      final l = light(PlanTruss.pointAt(truss, 0.3));
      elements.add(l);
      expect(TrussMagnet.snap(l, elements, mpu), isTrue);
      final uid = LightOverrides.uidOf(truss);

      hall.props[PlanHall.recipeKey] = PlanHall.recipeOf(
        hall,
      )!.copyWith(gridLowM: 3.5).toJson();
      PlanHall.regenerate(elements, hall, mpu);
      final again = elements.firstWhere((e) => LightOverrides.uidOf(e) == uid);
      expect(PlanTruss.lowM(again), 3.5);
      expect(TrussMagnet.trussUidOf(l), uid);
      expect(PlanLight.heightOf(l), closeTo(3.15, 1e-9));
    });

    test('lo desligado no se rehace', () {
      final hall = hallOf(HallRecipe.rectangle(width: 12, depth: 8));
      final elements = <PlanElement>[hall, ...PlanHall.build(hall, mpu)];
      final pillar = elements.firstWhere(PlanPillar.isPillar);
      pillar
        ..position = const Offset(-50, -50)
        ..props[PlanHall.detachedKey] = true;
      final count = elements.length;
      PlanHall.regenerate(elements, hall, mpu);
      expect(elements.length, count);
      expect(elements.where((e) => identical(e, pillar)), hasLength(1));
    });
  });

  test('todo pasa por el JSON v2 de la planta', () {
    final hall = PlanHall.create(
      Offset.zero,
      HallRecipe.rectangle(width: 10, depth: 6).copyWith(levelM: 1.2),
    );
    final elements = [hall, ...PlanHall.build(hall, mpu)];
    final l = light(
      PlanTruss.pointAt(elements.firstWhere(PlanTruss.isTruss), .5),
    );
    TrussMagnet.snap(l, [...elements, l], mpu);
    elements.add(l);

    final decoded = FloorPlanJson.decode(FloorPlanJson.encode(elements));
    expect(decoded.length, elements.length);
    final recipe = PlanHall.recipeOf(decoded.firstWhere(PlanHall.isHall))!;
    expect(recipe.outline.length, 4);
    expect(recipe.levelM, 1.2);
    final back = decoded.last;
    expect(TrussMagnet.trussUidOf(back), TrussMagnet.trussUidOf(l));
    expect(PlanLevel.of(back), 1.2);
    expect(
      decoded.where(PlanTruss.isTruss).length,
      elements.where(PlanTruss.isTruss).length,
    );
  });

  group('escena 3D', () {
    test('resuelve paredes con huecos, cubierta, telas, truss y focos', () {
      final base = HallRecipe.rectangle(width: 24, depth: 12);
      final hall = PlanHall.create(
        Offset.zero,
        base.copyWith(
          edges: [
            base.edges[0],
            const HallEdge(kind: HallEdgeKind.glass, sillM: 0.5),
            ...base.edges.skip(2),
          ],
        ),
      );
      final elements = [hall, ...PlanHall.build(hall, mpu)];
      final l = light(
        PlanTruss.pointAt(elements.firstWhere(PlanTruss.isTruss), 0.5),
      );
      TrussMagnet.snap(l, elements, mpu);
      elements.add(l);

      final scene = PlanScene3d.build(elements, metersPerUnit: mpu);
      expect(scene['format'], 'iris.scene3d');
      final halls = scene['halls'] as List;
      expect(halls, hasLength(1));
      final grid = (halls.first as Map)['roofGrid'] as Map;
      expect(
        (grid['z'] as List).length,
        ((grid['nx'] as int) + 1) * ((grid['ny'] as int) + 1),
      );

      final walls = (scene['walls'] as List).cast<Map>();
      expect(walls, hasLength(3));
      final glazed = walls.firstWhere(
        (w) => (w['openings'] as List).isNotEmpty,
      );
      final holes = (glazed['openings'] as List).cast<Map>();
      expect(
        holes.every((h) => h['glass'] == true && h['sill'] == 0.5),
        isTrue,
      );
      // Los módulos cubren el lado entero.
      expect(holes.first['from'], closeTo(0, 0.01));
      expect(holes.last['to'], closeTo(12, 0.01));

      final drapes = (scene['drapes'] as List).cast<Map>();
      expect(drapes, hasLength(4));
      final samples = (drapes.first['samples'] as List).cast<Map>();
      final mid = samples[samples.length ~/ 2];
      expect(mid['top'] as double, lessThan(samples.first['top'] as double));

      final fixtures = (scene['fixtures'] as List).cast<Map>();
      expect(fixtures, hasLength(1));
      final pos = fixtures.first['pos'] as List,
          aim = fixtures.first['aim'] as List;
      expect(pos[2], closeTo(3.65, 1e-6));
      expect(aim[2], closeTo(0, 1e-6)); // cuelga mirando al suelo
      expect(fixtures.first['truss'], isNotNull);
      // y al revés que el lienzo.
      expect(pos[1], closeTo(-l.position.dy * mpu, 1e-3));
    });
  });

  group('perímetro editable', () {
    test('estirar una pared de la nave mueve su lado y las esquinas', () {
      final hall = PlanHall.create(
        Offset.zero,
        HallRecipe.rectangle(width: 10, depth: 6),
      );
      final elements = <PlanElement>[hall, ...PlanHall.build(hall, mpu)];
      // El lateral derecho: de (10, 6) a (10, 0).
      final side = elements.firstWhere((e) => PlanHall.edgeIndexOf(e) == 1);
      PlanSegment.setEnd(side, const Offset(12 / mpu, 0));
      side.props['curve'] = 1 / mpu;
      expect(PlanHall.syncFromWall(hall, side, mpu), isTrue);
      final r = PlanHall.recipeOf(hall)!;
      expect(r.outline[2], const Offset(12, 0));
      expect(r.edge(1).bulgeM, closeTo(1, 1e-9));
      PlanHall.regenerate(elements, hall, mpu);
      // El fondo arranca ahora en la esquina movida.
      final back = elements.firstWhere((e) => PlanHall.edgeIndexOf(e) == 2);
      expect(PlanSegment.start(back), const Offset(12 / mpu, 0));
    });

    test('las paredes que cierran un recinto dan una receta', () {
      final walls = [
        PlanSegment.create(start: Offset.zero, end: const Offset(500, 0)),
        // Dibujada al revés.
        PlanSegment.create(
          start: const Offset(500, 300),
          end: const Offset(500, 0),
        ),
        PlanSegment.create(
          start: const Offset(500, 300),
          end: const Offset(0, 300),
        ),
        PlanSegment.create(start: const Offset(0, 300), end: Offset.zero),
      ];
      final traced = PlanHall.fromWalls(walls, mpu)!;
      expect(traced.$1, Offset.zero);
      expect(traced.$2.outline, [
        Offset.zero,
        const Offset(10, 0),
        const Offset(10, 6),
        const Offset(0, 6),
      ]);
      expect(PlanHall.fromWalls(walls.take(3).toList(), mpu), isNull);
    });

    test('partir un lado y quitar una esquina', () {
      final r = HallRecipe.rectangle(width: 10, depth: 6);
      final split = r.splitEdge(0);
      expect(split.outline.length, 5);
      expect(split.outline[1], const Offset(5, 6));
      expect(split.edges.length, 5);
      expect(split.removeVertex(1).outline, r.outline);
    });
  });

  testWidgets('la hoja del constructor devuelve la receta', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    HallRecipe? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                result = await HallBuilderSheet.show(context),
            child: const Text('abrir'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Nave nueva'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Dos aguas'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Dos aguas'));
    await tester.pump();
    await tester.tap(find.text('Crear la nave'));
    await tester.pumpAndSettle();
    expect(result?.roof, HallRoof.gable);
  });

  testWidgets('los controles de la tela leen cuerda, tensión y altura libre', (
    tester,
  ) async {
    final drape = PlanDrape.create(
      Offset.zero,
      const Offset(300, 0),
      anchorM: 4.4,
      sagM: 0.4,
      lengthM: 1.2,
    );
    expect(drape.displayLabel, 'Tela');
    Future<void> show() => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: DrapeControls(
              element: drape,
              metersPerUnit: mpu,
              onPreview: () {},
              onUpdate: () {},
            ),
          ),
        ),
      ),
    );
    await show();
    expect(find.text('6.07 m'), findsOneWidget); // cuerda
    expect(find.text('2.80 m'), findsOneWidget); // altura libre
    expect(find.textContaining('tira mucho'), findsNothing);

    PlanDrape.setSag(drape, 0.02);
    await show();
    expect(find.textContaining('tira mucho'), findsOneWidget);
  });
}
