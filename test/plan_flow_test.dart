import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris_dp/core/sync/plan_library_store.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/settings/app_prefs.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_links.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';
import 'package:iris_dp/features/camera_plan/plan_guide.dart';
import 'package:iris_dp/features/camera_plan/plan_prefs.dart';
import 'package:iris_dp/features/camera_plan/plan_start_from.dart';
import 'package:iris_dp/features/camera_plan/project_focus.dart';
import 'package:iris_dp/features/camera_plan/shot_create.dart';
import 'package:iris_dp/features/technical_script/technical_script_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late int projectId;
  late int sceneId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.ensureLoaded();
    await AppPrefs.reloadForTest();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Escena 1',
        locationCanonical: 'INT. CASA - DÍA',
        locationPureName: 'CASA',
      ),
    );
  });

  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<Scene> scene() =>
      (db.select(db.scenes)..where((s) => s.id.equals(sceneId))).getSingle();

  Future<int> addShot(
    int number, {
    int? setupId,
    String? lens,
    String? action,
  }) => db.insertShot(
    ShotsCompanion.insert(
      sceneId: sceneId,
      projectId: projectId,
      number: number,
      sortOrder: Value(number - 1),
      lens: Value(lens),
      lightSetupId: Value(setupId),
      action: Value(action),
    ),
  );

  PlanElement camera() => PlanElement(
    id: -1,
    type: ElementType.camera,
    position: const Offset(120, 340),
    rotation: 30,
  );

  Future<List<PlanElement>> elementsOf(int shotId) => FloorPlanRepository(
    db,
  ).loadElements(scope: FloorPlanScope.shot, shotId: shotId);

  group('plano nuevo', () {
    test('nace como el anterior: set, lente y cámara en su sitio', () async {
      final setup = await FloorPlanRepository(
        db,
      ).createLightSetup(projectId: projectId);
      final first = await addShot(1, setupId: setup.id, lens: '35mm');
      final link = camera()..props[CameraLinks.setupCameraKey] = 'cam-del-set';
      await FloorPlanRepository(db).saveElements(
        scope: FloorPlanScope.shot,
        shotId: first,
        elements: [link],
      );

      final id = await createShotInScene(db, await scene(), [
        (await db.getShotById(first))!,
      ]);

      final created = (await db.getShotById(id))!;
      expect(created.number, 2);
      expect(created.lightSetupId, setup.id);
      expect(created.lens, '35mm');
      final copies = await elementsOf(id);
      expect(copies, hasLength(1));
      expect(copies.single.position, const Offset(120, 340));
      expect(CameraLinks.setupCameraOf(copies.single), 'cam-del-set');
    });

    test('con el ajuste apagado nace en blanco', () async {
      await AppPrefs.instance.setIn(
        PlanPrefs.newShotLikePrevious,
        const SettingsScope.global(),
        false,
      );
      final setup = await FloorPlanRepository(
        db,
      ).createLightSetup(projectId: projectId);
      final first = await addShot(1, setupId: setup.id, lens: '35mm');

      final id = await createShotInScene(db, await scene(), [
        (await db.getShotById(first))!,
      ]);

      final created = (await db.getShotById(id))!;
      expect(created.lightSetupId, isNull);
      expect(created.lens, isNull);
    });
  });

  test('un plano con set se abre aunque falte la planta maestra', () async {
    final setup = await FloorPlanRepository(
      db,
    ).createLightSetup(projectId: projectId);
    final id = await addShot(1, setupId: setup.id);
    final state = await PlanEntryState.resolve(db, (await db.getShotById(id))!);
    expect(state.site, isNull);
    expect(state.need, PlanEntryNeed.none);
  });

  test('el foco recuerda el plano y conserva el último set', () async {
    final notifier = ProjectFocusNotifier(projectId);
    await notifier.ready;
    final id = await addShot(1);
    notifier.focusSetup(7);
    notifier.focusShot((await db.getShotById(id))!);
    expect(
      notifier.debugState,
      ProjectFocus(sceneId: sceneId, shotId: id, setupId: 7),
    );

    final reopened = ProjectFocusNotifier(projectId);
    await Future<void>.delayed(Duration.zero);
    await reopened.ready;
    expect(reopened.debugState.shotId, id);
  });

  testWidgets('set nuevo: «Como el set anterior» copia sus luces', (
    tester,
  ) async {
    // Sin canal de carpetas en la prueba: una biblioteca vacía y a mano.
    PlanLibraryStore.local = PlanLibraryStore(
      Directory('${Directory.systemTemp.path}/iris_sin_biblioteca'),
    );
    addTearDown(() => PlanLibraryStore.local = null);
    late LightSetup previous;
    await tester.runAsync(() async {
      final repo = FloorPlanRepository(db);
      previous = await repo.createLightSetup(
        projectId: projectId,
        name: 'Noche',
      );
      await repo.saveElements(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: previous.id,
        elements: [
          PlanElement(
            id: -1,
            type: ElementType.light,
            position: const Offset(10, 10),
          ),
        ],
      );
      previous = (await db.getLightSetupById(previous.id))!;
    });

    LightSetup? created;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => created = await createSetupAsked(
              context,
              db,
              projectId: projectId,
              previous: previous,
            ),
            child: const Text('nuevo'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('nuevo'));
    await settle(tester);

    await tester.tap(find.byKey(const ValueKey('setup-start-previous')));
    await settle(tester);

    expect(created, isNotNull);
    expect(created!.id, isNot(previous.id));
    expect(FloorPlanJson.decode(created!.planJson), hasLength(1));
  });

  testWidgets('el guion se abre en la fila del plano pedido', (tester) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late int target;
    await tester.runAsync(() async {
      for (var n = 1; n <= 60; n++) {
        final id = await addShot(n, action: 'ACCION-$n');
        if (n == 55) target = id;
      }
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: TechnicalScriptScreen(
            projectId: projectId,
            initialShotId: target,
          ),
        ),
      ),
    );
    await settle(tester);

    final row = find.textContaining('ACCION-55', findRichText: true);
    expect(row, findsWidgets);
    final y = tester.getTopLeft(row.first).dy;
    expect(y, inInclusiveRange(0, 800));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
