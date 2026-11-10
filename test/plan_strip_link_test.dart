import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_links.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/plan_target.dart';
import 'package:iris_dp/features/camera_plan/plan_workspace_screen.dart';

/// SV.2 y SV.3: la tira de planos del set, con imagen, tipo y cámara, y el
/// vínculo cámara ↔ plano con un gesto.
void main() {
  late AppDatabase db;
  late int projectId;
  late LightSetup setup;
  late int shot1;
  late int shot2;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  Future<void> seed(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'KK'));
      final siteId = await db.insertSite(
        LocationSitesCompanion.insert(projectId: projectId, name: 'Bar'),
      );
      setup = await FloorPlanRepository(
        db,
      ).createLightSetup(projectId: projectId, siteId: siteId);
      final scene = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 11,
          name: 'Escena 11',
          locationCanonical: 'INT. BAR - NOCHE',
          locationPureName: 'BAR',
          locationSiteId: Value(siteId),
          intExt: const Value('INT'),
          dayNight: const Value('NOCHE'),
        ),
      );
      shot1 = await db.insertShot(
        ShotsCompanion.insert(
          sceneId: scene,
          projectId: projectId,
          number: 3,
          lens: const Value('85mm'),
          movement: const Value('Trípode'),
        ),
      );
      shot2 = await db.insertShot(
        ShotsCompanion.insert(sceneId: scene, projectId: projectId, number: 4),
      );
      await db.assignLightSetupToShot(shot1, setup.id);
      await db.assignLightSetupToShot(shot2, setup.id);
    });
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<List<PlanElement>> camerasOf(WidgetTester tester, int shotId) async =>
      (await tester.runAsync(() async {
        final rows = await db.getCameraPlanElementsForShot(shotId);
        return [
          for (final r in rows)
            if (r.type == 'camera') PlanElement.fromDb(r),
        ];
      }))!;

  Future<List<PlanElement>> setCameras(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        final s = (await db.getLightSetupById(setup.id))!;
        return FloorPlanJson.decode(
          s.planJson,
        ).where((e) => e.type == ElementType.camera).toList();
      }))!;

  testWidgets('desde la tira: + cámara, Vincular y arrastrar', (
    tester,
  ) async {
    await seed(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: PlanWorkspaceScreen(
            projectId: projectId,
            initial: PlanTarget.lightSetup(setup.id, setup.name),
          ),
        ),
      ),
    );
    await settle(tester);

    // La cabecera dice qué set es y la tira enseña sus planos con su tipo.
    expect(find.byKey(const ValueKey('strip-set-header')), findsOneWidget);
    expect(find.textContaining('INT · NOCHE'), findsOneWidget);
    expect(find.text('11·P3'), findsOneWidget);
    expect(find.text('85mm · Trípode'), findsOneWidget);
    expect(find.text('SIN CÁMARA'), findsNWidgets(2));

    // «+ cámara» en 11·P3: una cámara del set, ya vinculada, con su focal.
    await tester.tap(find.byKey(ValueKey('strip-add-camera-$shot1')));
    await settle(tester);
    var cams = await setCameras(tester);
    expect(cams, hasLength(1));
    expect(cams.single.lens, '85mm');
    final a = await camerasOf(tester, shot1);
    expect(a, hasLength(1));
    expect(CameraLinks.setupCameraOf(a.single), isNotNull);
    expect(find.text('CAM A'), findsOneWidget);

    // Con la cámara seleccionada, «Vincular» en 11·P4 la pone en ese plano.
    expect(find.textContaining('vincula sus planos'), findsOneWidget);
    await tester.tap(find.byKey(ValueKey('strip-link-$shot2')));
    await settle(tester);
    expect(await camerasOf(tester, shot2), hasLength(1));
    // Y volver a pulsarlo la desvincula.
    await tester.tap(find.byKey(ValueKey('strip-link-$shot2')));
    await settle(tester);
    expect(await camerasOf(tester, shot2), isEmpty);

    // Arrastrar 11·P3 a un hueco de la planta crea allí la cámara B; el
    // plano ya tenía la A: se elige sustituirla.
    final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is CameraPlanPainter,
    );
    final g = await tester.startGesture(
      tester.getCenter(find.byKey(ValueKey('strip-shot-$shot1'))),
    );
    await g.moveBy(const Offset(0, 30));
    await tester.pump();
    // El lienzo grande (hay otro pequeño, el de la miniatura).
    final rects = [
      for (var i = 0; i < canvas.evaluate().length; i++)
        tester.getRect(canvas.at(i)),
    ]..sort((x, y) => (y.width * y.height).compareTo(x.width * x.height));
    await g.moveTo(rects.first.topLeft + const Offset(150, 500));
    await tester.pump();
    await g.up();
    await settle(tester);
    expect(find.textContaining('ya tiene cámara A'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('camera-replace')));
    await settle(tester);
    cams = await setCameras(tester);
    expect(cams.map((c) => c.cameraLetter).toSet(), {'A', 'B'});
    final now = await camerasOf(tester, shot1);
    expect(now.map((c) => c.cameraLetter), ['B']);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
