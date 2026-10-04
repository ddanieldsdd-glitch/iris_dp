import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_editor.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_screen.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('proyecto sin escenas devuelve lista vacía', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Vacío'),
    );

    final scenes = await (db.select(
      db.scenes,
    )..where((s) => s.projectId.equals(projectId))).get();
    expect(scenes, isEmpty);
  });

  test('listado de planos y elementos de planta en base de datos', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Planta Test'),
    );
    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Escena 1',
        locationCanonical: 'INT. SALA - DÍA',
        locationPureName: 'SALA',
      ),
    );
    final shotId = await db.insertShot(
      ShotsCompanion.insert(sceneId: sceneId, projectId: projectId, number: 1),
    );

    final shots = await db.getShotsForScene(sceneId);
    expect(shots.single.id, shotId);

    await db.insertCameraPlanElement(
      CameraPlanElementsCompanion.insert(
        shotId: shotId,
        type: 'camera',
        cameraLetter: const Value('A'),
        cameraNumber: const Value(1),
      ),
    );

    final elements = await db.getCameraPlanElementsForShot(shotId);
    expect(elements, hasLength(1));
    expect(elements.first.type, 'camera');
  });

  Widget host(Widget child) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(theme: AppTheme.dark, home: child),
  );

  /// Deja que Drift responda y la pantalla se repinte.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('sin escenas se pueden crear plantas', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late int projectId;
    await tester.runAsync(() async {
      projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Sin guion'),
      );
      final siteId = await db.insertSite(
        LocationSitesCompanion.insert(projectId: projectId, name: 'Bosque'),
      );
      final setId = await db.insertLocation(
        LocationBasePlansCompanion.insert(
          projectId: projectId,
          siteId: Value(siteId),
          locationName: 'Cabaña',
        ),
      );
      await FloorPlanRepository(
        db,
      ).createLightSetup(projectId: projectId, setId: setId);
    });

    await tester.pumpWidget(host(CameraPlanScreen(projectId: projectId)));
    await settle(tester);

    expect(find.text('Sin escenas todavía.'), findsNothing);
    expect(find.text('Bosque'), findsWidgets);
    expect(find.text('Cabaña'), findsWidgets);
    expect(find.text('Setup A'), findsOneWidget);
    expect(find.text('Plantas libres'), findsOneWidget);
    expect(find.text('Esquema de luz'), findsWidgets);
    expect(find.text('Plano maestro'), findsOneWidget);
    expect(find.text('Boceto'), findsWidgets);
    expect(tester.takeException(), isNull);

    // Tocar una miniatura abre la pantalla de trabajo en esa planta.
    await tester.tap(find.text('Setup A'));
    await settle(tester);
    expect(find.text('Esquema de luz · Cabaña'), findsOneWidget);
    expect(find.text('Plano del set'), findsOneWidget);
    expect(find.text('Esquema siguiente'), findsNothing);
    expect(find.byTooltip('Esquema siguiente'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Desde el navegador se cambia de planta sin volver al mapa.
    await tester.tap(find.text('Plano del set'));
    await settle(tester);
    expect(find.text('Plano de set'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('el plano enseña su esquema de luz', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late int projectId;
    late int shotId;
    await tester.runAsync(() async {
      projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Capas'),
      );
      final sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 1,
          name: 'Escena 1',
          locationCanonical: 'INT. SALA - DÍA',
          locationPureName: 'SALA',
        ),
      );
      shotId = await db.insertShot(
        ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: 1,
        ),
      );
      final setup = await FloorPlanRepository(
        db,
      ).createLightSetup(projectId: projectId, name: 'Noche');
      await db.assignLightSetupToShot(shotId, setup.id);
    });

    await tester.pumpWidget(
      host(
        CameraPlanEditor.shot(
          projectId: projectId,
          shotId: shotId,
          shotLabel: 'Esc 1 · Plano 1',
        ),
      ),
    );
    await settle(tester);

    // La barra de capas dice qué luz y qué plano se están viendo.
    expect(find.text('Luz: Noche'), findsOneWidget);
    expect(find.text('Cámara: Esc 1 · Plano 1'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
  });

  group('un solo lienzo', () {
    late int projectId;
    late int siteId;
    late int setId;
    late int shotId;

    Future<void> seed(WidgetTester tester, {required String siteJson}) async {
      tester.view.physicalSize = const Size(1400, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.runAsync(() async {
        projectId = await db.insertProject(
          ProjectsCompanion.insert(name: 'Lienzo'),
        );
        siteId = await db.insertSite(
          LocationSitesCompanion.insert(
            projectId: projectId,
            name: 'Hospital',
            floorPlanJson: Value(siteJson),
          ),
        );
        setId = await db.insertLocation(
          LocationBasePlansCompanion.insert(
            projectId: projectId,
            siteId: Value(siteId),
            locationName: 'Urgencias',
          ),
        );
        final sceneId = await db.insertScene(
          ScenesCompanion.insert(
            projectId: projectId,
            number: 1,
            name: 'Escena 1',
            locationCanonical: 'INT. URGENCIAS - DÍA',
            locationPureName: 'URGENCIAS',
            locationSiteId: Value(siteId),
            locationId: Value(setId),
          ),
        );
        shotId = await db.insertShot(
          ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: 1,
          ),
        );
      });
    }

    String element(String type, double x, double y, {String? lightType}) =>
        '{"type":"$type","x":$x,"y":$y,"rotation":0,"label":"$type",'
        '"lightType":${lightType == null ? 'null' : '"$lightType"'},'
        '"cameraLetter":"A","cameraNumber":1,"pathPoints":[]}';

    testWidgets('mover una pared del entorno desde un plano la guarda en '
        'la localización', (tester) async {
      await seed(
        tester,
        siteJson: '{"version":2,"elements":[${element('wall', 300, 300)}]}',
      );
      await tester.pumpWidget(
        host(
          CameraPlanEditor.shot(
            projectId: projectId,
            shotId: shotId,
            shotLabel: 'Esc 1 · Plano 1',
          ),
        ),
      );
      await settle(tester);

      final canvas = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CameraPlanPainter,
      );
      final origin = tester.getTopLeft(canvas);
      await tester.dragFrom(
        origin + const Offset(300, 300),
        const Offset(100, 50),
      );
      await settle(tester);

      // El aviso dice a qué afecta el cambio.
      expect(
        find.textContaining('Entorno · cambia en toda la localización'),
        findsOneWidget,
      );

      final site = await tester.runAsync(() => db.getSiteById(siteId));
      final moved = FloorPlanJson.decode(site!.floorPlanJson).single;
      expect(moved.position.dx, greaterThan(350));
      expect(moved.position.dy, greaterThan(320));
      final rows = await tester.runAsync(
        () => db.getCameraPlanElementsForShot(shotId),
      );
      expect(rows, isEmpty);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('«Ordenar capas» pasa la luz a un esquema y la cámara al '
        'plano', (tester) async {
      await seed(
        tester,
        siteJson:
            '{"version":2,"elements":['
            '${element('wall', 300, 300)},'
            '${element('light', 500, 200, lightType: 'hmi')},'
            '${element('camera', 600, 400)}]}',
      );
      await tester.pumpWidget(
        host(
          CameraPlanEditor.shot(
            projectId: projectId,
            shotId: shotId,
            shotLabel: 'Esc 1 · Plano 1',
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Luz: sin esquema'), findsOneWidget);

      await tester.tap(find.text('Ordenar capas'));
      await settle(tester);

      final site = await tester.runAsync(() => db.getSiteById(siteId));
      expect(FloorPlanJson.decode(site!.floorPlanJson).map((e) => e.type), [
        ElementType.wall,
      ]);
      final setups = await tester.runAsync(
        () => db.getLightSetupsForProject(projectId),
      );
      expect(setups!.single.name, 'Setup A');
      expect(setups.single.locationBasePlanId, setId);
      expect(
        FloorPlanJson.decode(setups.single.planJson).single.lightType,
        LightType.hmi,
      );
      final shot = await tester.runAsync(
        () => (db.select(
          db.shots,
        )..where((s) => s.id.equals(shotId))).getSingle(),
      );
      expect(shot!.lightSetupId, setups.single.id);
      final rows = await tester.runAsync(
        () => db.getCameraPlanElementsForShot(shotId),
      );
      expect(rows!.map((r) => r.type), ['camera']);
      expect(find.text('Luz: Setup A'), findsOneWidget);
      expect(find.text('Ordenar capas'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('la zona del set se marca arrastrando y se ve en el mapa', (
      tester,
    ) async {
      await seed(
        tester,
        siteJson: '{"version":2,"elements":[${element('wall', 300, 300)}]}',
      );
      await tester.pumpWidget(
        host(
          CameraPlanEditor.set(
            projectId: projectId,
            setId: setId,
            setName: 'Urgencias',
          ),
        ),
      );
      await settle(tester);

      await tester.tap(find.text('Marcar zona'));
      await settle(tester);
      final canvas = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CameraPlanPainter,
      );
      final origin = tester.getTopLeft(canvas);
      await tester.dragFrom(
        origin + const Offset(100, 100),
        const Offset(300, 200),
      );
      await settle(tester);

      final set = await tester.runAsync(() => db.getLocationById(setId));
      final zone = SetZone.decode(set!.sitePlacementJson)!;
      expect(zone.width, greaterThan(200));
      expect(zone.height, greaterThan(120));
      expect(find.text('Marcar zona'), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
