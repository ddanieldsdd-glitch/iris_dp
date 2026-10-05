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
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_marks.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';

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
    expect(find.text('Plano maestro'), findsOneWidget);
    expect(find.textContaining('Boceto'), findsWidgets);
    expect(find.text('Sin escenas en este set.'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Tocar una miniatura abre la pantalla de trabajo en esa planta.
    await tester.tap(find.text('Setup A'));
    await settle(tester);
    expect(find.text('Esquema de luz · Cabaña'), findsOneWidget);
    // Paleta a la izquierda y lista de material a la derecha.
    expect(find.text('LUCES'), findsOneWidget);
    // Las luces van por familias; al abrir una salen sus tipos.
    expect(find.text('LED'), findsOneWidget);
    expect(find.text('Tungsteno'), findsOneWidget);
    await tester.tap(find.text('LED'));
    await settle(tester);
    expect(find.text('Panel'), findsOneWidget);
    expect(find.text('Tubo'), findsOneWidget);
    expect(find.text('GRIP · CORTA'), findsOneWidget);
    expect(find.text('Lista de material'), findsOneWidget);

    // El navegador de plantas entra plegado.
    expect(find.text('Plano del set'), findsNothing);
    await tester.tap(find.byTooltip('Mostrar plantas'));
    await settle(tester);
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

    testWidgets('soltar con inercia también guarda, y marca el proyecto '
        'como modificado', (tester) async {
      await seed(
        tester,
        siteJson: '{"version":2,"elements":[${element('wall', 300, 300)}]}',
      );
      await tester.runAsync(
        () => (db.update(db.projects)..where((p) => p.id.equals(projectId)))
            .write(
              ProjectsCompanion(contentSyncUpdatedAt: Value(DateTime(2020))),
            ),
      );
      await tester.pumpWidget(
        host(
          CameraPlanEditor.site(
            projectId: projectId,
            siteId: siteId,
            siteName: 'Hospital',
          ),
        ),
      );
      await settle(tester);

      final canvas = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CameraPlanPainter,
      );
      final origin = tester.getTopLeft(canvas);
      await tester.flingFrom(
        origin + const Offset(300, 300),
        const Offset(160, 0),
        2000,
      );
      await settle(tester);

      final site = await tester.runAsync(() => db.getSiteById(siteId));
      final moved = FloorPlanJson.decode(site!.floorPlanJson).single;
      expect(moved.position.dx, greaterThan(400));

      final after = await tester.runAsync(() => db.getProject(projectId));
      expect(after!.contentSyncUpdatedAt!.year, greaterThan(2020));

      // Arrastrar en vacío mueve el lienzo, no lo último seleccionado.
      await tester.dragFrom(
        origin + const Offset(900, 600),
        const Offset(-80, -40),
      );
      await settle(tester);
      final same = await tester.runAsync(() => db.getSiteById(siteId));
      expect(
        FloorPlanJson.decode(same!.floorPlanJson).single.position,
        moved.position,
      );
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('el inicio enseña localización, set, escena y plano, y la '
        'etiqueta cambia el esquema', (tester) async {
      await seed(
        tester,
        siteJson: '{"version":2,"elements":[${element('wall', 300, 300)}]}',
      );
      await tester.pumpWidget(host(CameraPlanScreen(projectId: projectId)));
      await settle(tester);

      expect(find.text('Hospital'), findsWidgets);
      expect(find.text('Urgencias'), findsWidgets);
      expect(find.text('Escena 1'), findsOneWidget);
      // El plano aún no tiene luz: sale en el tiro «Sin luz».
      expect(find.text('P1'), findsOneWidget);
      expect(find.text('Sin luz'), findsOneWidget);
      expect(find.text('1 plano'), findsOneWidget);

      await tester.tap(find.byTooltip('Esquema de luz del plano'));
      await settle(tester);
      await tester.tap(find.text('Nuevo esquema'));
      await settle(tester);

      final shot = await tester.runAsync(
        () => (db.select(
          db.shots,
        )..where((s) => s.id.equals(shotId))).getSingle(),
      );
      expect(shot!.lightSetupId, isNotNull);
      // En la leyenda del set y en el tiro de la escena.
      expect(find.text('Setup A'), findsNWidgets(2));
      expect(find.text('Sin luz'), findsNothing);
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

    testWidgets('paredes punto a punto, deshacer, rehacer, duplicar y '
        'borrar', (tester) async {
      await seed(tester, siteJson: '{"version":2,"elements":[]}');
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

      Future<List<PlanElement>> setElements() async {
        final set = await tester.runAsync(() => db.getLocationById(setId));
        return FloorPlanJson.decode(set!.floorPlanJson);
      }

      // Herramienta Pared: tres toques encadenan dos tramos.
      await tester.tap(find.text('Pared').first);
      await settle(tester);
      final canvas = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CameraPlanPainter,
      );
      final origin = tester.getTopLeft(canvas);
      for (final point in const [
        Offset(200, 200),
        Offset(500, 200),
        Offset(500, 400),
      ]) {
        await tester.tapAt(origin + point);
        await settle(tester);
      }
      var walls = await setElements();
      expect(walls, hasLength(2));
      expect(walls.every(PlanSegment.isSegment), isTrue);
      expect(PlanSegment.start(walls[0]), const Offset(200, 200));
      expect(PlanSegment.end(walls[0]), const Offset(500, 200));
      // El segundo empieza donde acaba el primero.
      expect(PlanSegment.start(walls[1]), PlanSegment.end(walls[0]));
      expect(PlanSegment.end(walls[1]), const Offset(500, 400));

      await tester.tap(find.text('Terminar'));
      await settle(tester);

      // Deshacer quita el último tramo; rehacer lo devuelve.
      await tester.tap(find.byTooltip('Deshacer'));
      await settle(tester);
      expect(await setElements(), hasLength(1));
      await tester.tap(find.byTooltip('Rehacer'));
      await settle(tester);
      expect(await setElements(), hasLength(2));

      // Seleccionar el primer tramo, duplicarlo y borrar la copia.
      await tester.tapAt(origin + const Offset(350, 200));
      await settle(tester);
      expect(find.textContaining('Longitud: 6.00 m'), findsOneWidget);
      await tester.tap(find.text('Duplicar'));
      await settle(tester);
      walls = await setElements();
      expect(walls, hasLength(3));
      expect(PlanSegment.start(walls[2]), const Offset(230, 230));
      await tester.tap(find.text('Eliminar'));
      await settle(tester);
      expect(await setElements(), hasLength(2));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('la zona del set se mueve y se redimensiona con asas', (
      tester,
    ) async {
      await seed(tester, siteJson: '{"version":2,"elements":[]}');
      await tester.runAsync(() async {
        final set = (await db.getLocationById(setId))!;
        await db.updateLocation(
          set.copyWith(
            sitePlacementJson: Value(
              SetZone.encode(const Rect.fromLTWH(200, 200, 300, 200)),
            ),
          ),
        );
      });
      await tester.pumpWidget(
        host(
          CameraPlanEditor.site(
            projectId: projectId,
            siteId: siteId,
            siteName: 'Hospital',
          ),
        ),
      );
      await settle(tester);
      // Desde el plano maestro no hay set activo: la zona se ajusta desde el
      // set.
      expect(find.byTooltip('Zona del set'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));

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
      await tester.tap(find.byTooltip('Zona del set'));
      await settle(tester);
      await tester.tap(find.text('Mover o redimensionar la zona'));
      await settle(tester);

      final state = tester.state(find.byType(CameraPlanEditor));
      // ignore: avoid_dynamic_calls
      final view =
          (state as dynamic).debugView as ({Offset offset, double scale});
      Offset onScreen(Offset p) =>
          tester.getTopLeft(
            find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is CameraPlanPainter,
            ),
          ) +
          view.offset +
          p * view.scale;

      // Arrastrar la esquina inferior derecha la agranda.
      await tester.dragFrom(
        onScreen(const Offset(500, 400)),
        Offset(100 * view.scale, 100 * view.scale),
      );
      await settle(tester);
      // Arrastrar el interior la mueve.
      await tester.dragFrom(
        onScreen(const Offset(350, 350)),
        Offset(50 * view.scale, 0),
      );
      await settle(tester);
      await tester.tap(find.text('Listo'));
      await settle(tester);

      final set = await tester.runAsync(() => db.getLocationById(setId));
      final zone = SetZone.decode(set!.sitePlacementJson)!;
      expect(zone.width, closeTo(400, 25));
      expect(zone.height, closeTo(300, 25));
      expect(zone.left, closeTo(250, 25));
      expect(zone.top, closeTo(200, 25));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('fotómetro: al seleccionar un actor se lee su luz, y el '
        'mapa de exposición se pinta', (tester) async {
      await seed(tester, siteJson: '{"version":2,"elements":[]}');
      await tester.runAsync(() async {
        final setup = await FloorPlanRepository(
          db,
        ).createLightSetup(projectId: projectId, setId: setId, name: 'Setup A');
        await db.updateLightSetup(
          setup.copyWith(
            planJson: Value(
              '{"version":2,"elements":['
              '{"type":"light","x":120,"y":300,"rotation":90,'
              '"lightType":"hmi","cameraLetter":"A","cameraNumber":1,'
              '"pathPoints":[],"props":{"intensity":100}}]}',
            ),
          ),
        );
        await db.assignLightSetupToShot(shotId, setup.id);
        await db.insertCameraPlanElement(
          CameraPlanElementsCompanion.insert(
            shotId: shotId,
            type: 'actor',
            x: const Value(400),
            y: const Value(300),
            label: const Value('Gala'),
          ),
        );
        await db.insertCameraPlanElement(
          CameraPlanElementsCompanion.insert(
            shotId: shotId,
            type: 'camera',
            x: const Value(400),
            y: const Value(500),
          ),
        );
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

      final canvas = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CameraPlanPainter,
      );
      await tester.tapAt(tester.getTopLeft(canvas) + const Offset(400, 300));
      await settle(tester);

      expect(find.text('Qué aporta cada fuente'), findsOneWidget);
      expect(find.textContaining('Clave ('), findsOneWidget);
      expect(find.text('sin relleno'), findsOneWidget);
      expect(find.text('estimado'), findsOneWidget);
      expect(find.textContaining('para T2.8'), findsOneWidget);

      // La cámara lleva los ajustes de exposición.
      await tester.tapAt(tester.getTopLeft(canvas) + const Offset(400, 500));
      await settle(tester);
      expect(find.text('Exposición'), findsOneWidget);
      expect(find.text('Diafragma de trabajo'), findsOneWidget);

      await tester.tap(find.byTooltip('Mapa de exposición'));
      await settle(tester);
      expect(find.byTooltip('Volver a los haces de luz'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('pulsar el asa de giro y arrastrar gira el elemento, aunque '
        'se tarde en empezar a arrastrar', (tester) async {
      await seed(tester, siteJson: '{"version":2,"elements":[]}');
      await tester.runAsync(() async {
        await db.insertCameraPlanElement(
          CameraPlanElementsCompanion.insert(
            shotId: shotId,
            type: 'actor',
            x: const Value(400),
            y: const Value(300),
            label: const Value('Gala'),
          ),
        );
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

      final state = tester.state(find.byType(CameraPlanEditor));
      // ignore: avoid_dynamic_calls
      final view =
          (state as dynamic).debugView as ({Offset offset, double scale});
      final canvas = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CameraPlanPainter,
      );
      Offset onScreen(Offset p) =>
          tester.getTopLeft(canvas) + view.offset + p * view.scale;

      await tester.tapAt(onScreen(const Offset(400, 300)));
      await settle(tester);

      final reach = CameraPlanPainter.rotationHandleDistance(view.scale);
      final gesture = await tester.startGesture(
        onScreen(Offset(400, 300 - reach)),
      );
      // Pulsación sostenida: antes esto deseleccionaba y ya no giraba.
      await tester.pump(const Duration(milliseconds: 200));
      for (final p in const [
        Offset(430, 270),
        Offset(450, 290),
        Offset(460, 300),
      ]) {
        await gesture.moveTo(onScreen(p));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await gesture.up();
      await settle(tester);

      final rows = await tester.runAsync(
        () => db.getCameraPlanElementsForShot(shotId),
      );
      expect(rows!.single.rotation, closeTo(90, 2));
      expect(rows.single.x, closeTo(400, 0.5));
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('un actor tiene varias posiciones, cada una con su giro', (
      tester,
    ) async {
      await seed(tester, siteJson: '{"version":2,"elements":[]}');
      await tester.runAsync(() async {
        await db.insertCameraPlanElement(
          CameraPlanElementsCompanion.insert(
            shotId: shotId,
            type: 'actor',
            x: const Value(400),
            y: const Value(300),
            label: const Value('Gala'),
          ),
        );
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

      final state = tester.state(find.byType(CameraPlanEditor));
      // ignore: avoid_dynamic_calls
      final view =
          (state as dynamic).debugView as ({Offset offset, double scale});
      final canvas = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CameraPlanPainter,
      );
      Offset onScreen(Offset p) =>
          tester.getTopLeft(canvas) + view.offset + p * view.scale;

      await tester.tapAt(onScreen(const Offset(400, 300)));
      await settle(tester);
      expect(find.text('POSICIONES'), findsOneWidget);
      expect(find.text('Una sola posición'), findsOneWidget);

      // Nueva posición: aparece a un lado del actor, ya seleccionada.
      await tester.ensureVisible(find.text('Posición'));
      await tester.tap(find.text('Posición'));
      await settle(tester);
      expect(find.text('2 posiciones'), findsOneWidget);

      Future<PlanElement> actor() async {
        final row = (await db.getCameraPlanElementsForShot(shotId)).single;
        return PlanElement.fromDb(
          row,
          pathRows: await db.getPathPointsForElement(row.id),
        );
      }

      final mark = (await tester.runAsync(actor))!.pathPoints.single;
      expect((mark - const Offset(400, 300)).distance, closeTo(80, 1));

      // Se gira con su asa sin girar al actor.
      final reach = CameraPlanPainter.rotationHandleDistance(view.scale);
      final gesture = await tester.startGesture(
        onScreen(mark + Offset(0, -reach)),
      );
      await tester.pump(const Duration(milliseconds: 200));
      for (final step in const [
        Offset(30, -30),
        Offset(50, -10),
        Offset(60, 0),
      ]) {
        await gesture.moveTo(onScreen(mark + step));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await gesture.up();
      await settle(tester);

      final saved = (await tester.runAsync(actor))!;
      expect(saved.rotation, 0);
      expect(PlanMarks.rotationAt(saved, 0), closeTo(90, 2));
      expect(saved.pathPoints.single, mark);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
    });

    testWidgets('una luz del esquema se puede ajustar solo en un plano', (
      tester,
    ) async {
      await seed(tester, siteJson: '{"version":2,"elements":[]}');
      late int setupId;
      await tester.runAsync(() async {
        final setup = await FloorPlanRepository(
          db,
        ).createLightSetup(projectId: projectId, setId: setId, name: 'Setup A');
        setupId = setup.id;
        await db.updateLightSetup(
          setup.copyWith(
            planJson: Value(
              '{"version":2,"elements":['
              '{"type":"light","x":300,"y":300,"rotation":90,'
              '"lightType":"hmi","cameraLetter":"A","cameraNumber":1,'
              '"pathPoints":[],"props":{"intensity":100,"uid":"key"}}]}',
            ),
          ),
        );
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

      final canvas = find.byWidgetPredicate(
        (w) => w is CustomPaint && w.painter is CameraPlanPainter,
      );
      await tester.tapAt(tester.getTopLeft(canvas) + const Offset(300, 300));
      await settle(tester);

      // Se ajusta solo en este plano y se apaga.
      Finder switchOf(String label) => find.descendant(
        of: find
            .ancestor(of: find.text(label), matching: find.byType(Row))
            .first,
        matching: find.byType(Switch),
      );
      await tester.ensureVisible(switchOf('Ajustar solo en este plano'));
      await tester.tap(switchOf('Ajustar solo en este plano'));
      await settle(tester);
      expect(
        tester.widget<Switch>(switchOf('Ajustada solo en este plano')).value,
        isTrue,
      );
      await tester.ensureVisible(switchOf('Encendida'));
      await tester.tap(switchOf('Encendida'));
      await settle(tester);

      // El esquema sigue con la luz encendida; el plano la tiene apagada.
      final setup = await tester.runAsync(() => db.getLightSetupById(setupId));
      final shared = FloorPlanJson.decode(setup!.planJson).single;
      expect(shared.props['off'], isNot(true));
      final shot = await tester.runAsync(
        () => (db.select(
          db.shots,
        )..where((s) => s.id.equals(shotId))).getSingle(),
      );
      final own = LightOverrides.decode(shot!.lightOverridesJson);
      expect(own.keys, ['key']);
      expect(own['key']!.props['off'], isTrue);
      // Y así llega a quien pinta el plano.
      final layers = await tester.runAsync(
        () => FloorPlanRepository(db).layersForShot(shot),
      );
      expect(layers!.light.single.props['off'], isTrue);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(milliseconds: 50));
    });
  });
}
