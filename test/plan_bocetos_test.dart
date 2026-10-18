import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_editor.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_screen.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/plan_data.dart';
import 'package:iris_dp/features/camera_plan/plan_sketch.dart';
import 'package:iris_dp/core/utils/shot_reference_import.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:iris_dp/shared/annotations/sketch_pad.dart';

const _drawing = AnnotationDocument(
  strokes: [
    AnnotationStroke(
      id: 'a',
      tool: AnnotationToolType.pen,
      colorArgb: 0xFFFF0000,
      width: 6,
      points: [
        AnnotationPoint(x: 0.2, y: 0.2),
        AnnotationPoint(x: 0.6, y: 0.5),
      ],
    ),
  ],
);

class _TempDocs extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String root;
  _TempDocs(this.root);

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  late AppDatabase db;
  late FloorPlanRepository repo;
  late int projectId;
  late int siteId;
  late int setId;
  late int sceneId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FloorPlanRepository(db);
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'B'));
    siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Casa'),
    );
    setId = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        locationName: 'Cocina',
      ),
    );
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 3,
        name: 'Escena 3',
        locationCanonical: 'INT. COCINA - NOCHE',
        locationPureName: 'COCINA',
        locationSiteId: Value(siteId),
        locationId: Value(setId),
      ),
    );
  });

  tearDown(() => db.close());

  Future<PlanProjectData> load() async => PlanProjectData(
    sites: await (db.select(db.locationSites)).get(),
    sets: await (db.select(db.locationBasePlans)).get(),
    setups: await db.getLightSetupsForProject(projectId),
    scenes: await db.watchScenesForProject(projectId).first,
    shots: await db.watchShotsForProject(projectId).first,
    drawingRows: await db.watchPlanAnnotationDocuments(projectId).first,
  );

  test('los bocetos son de su escena y no se mezclan con los esquemas que '
      'llevan planos', () async {
    final plan = await repo.createLightSetup(
      projectId: projectId,
      setId: setId,
    );
    final elements = await repo.createLightSetup(
      projectId: projectId,
      setId: setId,
      name: 'Boceto · Esc 3',
      kind: LightSetupKind.sketchElements,
      sceneId: sceneId,
    );
    final free = await repo.createLightSetup(
      projectId: projectId,
      name: 'Boceto · libre',
      kind: LightSetupKind.sketchFreehand,
    );

    final data = await load();
    expect(data.setupsOfSet(setId).map((s) => s.id), [plan.id]);
    expect(data.freeSetups, isEmpty);
    expect(data.sketchesOfScene(sceneId).map((s) => s.id), [elements.id]);
    expect(data.freeSketches.map((s) => s.id), [free.id]);

    // A un plano no se le puede poner un boceto como esquema.
    final scene = data.scenes.single;
    expect(
      (await repo.lightSetupsForScene(scene)).map((s) => s.id),
      [plan.id],
    );

    // Pasar un boceto con elementos a esquema de verdad: copia sin escena.
    final real = await repo.copyLightSetup(
      elements,
      setId: setId,
      kind: LightSetupKind.plan,
    );
    expect(real.kind, LightSetupKind.plan);
    expect(real.sceneId, isNull);
    expect((await load()).setupsOfSet(setId), hasLength(2));
    // Duplicar un boceto lo deja en su escena.
    final copy = await repo.duplicateLightSetup(elements);
    expect(copy.kind, LightSetupKind.sketchElements);
    expect(copy.sceneId, sceneId);
  });

  test('un boceto a mano con su imagen cuenta como dibujado', () async {
    final sketch = await repo.createLightSetup(
      projectId: projectId,
      name: 'Boceto · Esc 3',
      kind: LightSetupKind.sketchFreehand,
      sceneId: sceneId,
    );
    var data = await load();
    expect(data.sketchesForScene(data.scenes.single), isEmpty);
    await db.updateLightSetup(
      sketch.copyWith(sketchImagePath: const Value('/tmp/boceto.png')),
    );
    data = await load();
    expect(
      data.sketchesForScene(data.scenes.single).map((s) => s.id),
      [sketch.id],
    );
  });

  test('el boceto viaja con su tipo y su escena', () async {
    await repo.createLightSetup(
      projectId: projectId,
      name: 'Boceto · Esc 3',
      kind: LightSetupKind.sketchFreehand,
      sceneId: sceneId,
    );
    final bundle = await ProjectContentBundle.export(db, projectId);
    final target = await db.insertProject(ProjectsCompanion.insert(name: 'o'));
    await ProjectContentBundle.importBundle(db, target, bundle);

    final setup = (await db.getLightSetupsForProject(target)).single;
    final scene = (await db.watchScenesForProject(target).first).single;
    expect(setup.kind, LightSetupKind.sketchFreehand);
    expect(setup.sceneId, scene.id);
  });

  test('el papel cuadriculado sale en la imagen del boceto', () async {
    final blank = await renderSketchPng(
      const AnnotationDocument(),
      size: const Size(400, 300),
    );
    final grid = await renderSketchPng(
      const AnnotationDocument(),
      size: const Size(400, 300),
      gridPaper: true,
    );
    expect(grid, isNot(equals(blank)));
  });

  test('un dibujo de antes pasa a un boceto a mano con su imagen y sus '
      'trazos', () async {
    final docs = Directory.systemTemp.createTempSync('iris_bocetos');
    addTearDown(() => docs.deleteSync(recursive: true));
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TempDocs(docs.path);
    addTearDown(() => PathProviderPlatform.instance = previous);
    final shotId = await db.insertShot(
      ShotsCompanion.insert(sceneId: sceneId, projectId: projectId, number: 1),
    );
    final shot = (await db.getShotById(shotId))!;

    final sketch = await moveDrawingToFreehandSketch(
      db,
      projectId: projectId,
      document: _drawing,
      name: 'Boceto · Esc 3 · Plano 1',
      sceneId: sceneId,
      setId: setId,
      siteId: siteId,
      shot: shot,
    );
    expect(sketch.kind, LightSetupKind.sketchFreehand);
    expect(sketch.sceneId, sceneId);
    expect(File(sketch.sketchImagePath!).existsSync(), isTrue);
    expect(readSketchDocument(sketch.sketchImagePath!).strokes, hasLength(1));
    // El plano lo sigue enseñando, sin tomarlo como esquema.
    final after = (await db.getShotById(shotId))!;
    expect(planSketchEntriesOf(after), ['setup:${sketch.id}']);
    expect(after.lightSetupId, isNull);
  });

  testWidgets('en el editor ya no se dibuja encima de la planta, y un dibujo '
      'de antes avisa', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late int shotId;
    await tester.runAsync(() async {
      shotId = await db.insertShot(
        ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: 1,
        ),
      );
      await db.saveProjectAnnotationDocument(
        projectId: projectId,
        targetType: 'camera_plan_shot',
        targetId: '$shotId',
        documentJson: _drawing.encode(),
        documentSchemaVersion: 1,
      );
    });

    Future<void> settle() async {
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: CameraPlanEditor.shot(
            projectId: projectId,
            shotId: shotId,
            shotLabel: 'Esc 3 · Plano 1',
          ),
        ),
      ),
    );
    await settle();
    // Ya no hay lápiz para dibujar encima de la planta.
    expect(find.byTooltip('Dibujar a mano (ratón o Apple Pencil)'), findsNothing);
    expect(find.textContaining('tiene un dibujo a mano encima'), findsOneWidget);

    await tester.tap(find.text('Pasar a boceto…'));
    await settle();
    expect(find.text('Pasar a boceto a mano'), findsOneWidget);
    expect(find.text('Borrar dibujo'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await settle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });

  testWidgets('la escena enseña sus bocetos aparte de los esquemas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      await db.insertShot(
        ShotsCompanion.insert(sceneId: sceneId, projectId: projectId, number: 1),
      );
      await repo.createLightSetup(projectId: projectId, setId: setId);
      await repo.createLightSetup(
        projectId: projectId,
        setId: setId,
        name: 'Boceto · Esc 3',
        kind: LightSetupKind.sketchElements,
        sceneId: sceneId,
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: CameraPlanScreen(projectId: projectId),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('BOCETOS DE ESTA ESCENA'), findsOneWidget);
    expect(find.text('Boceto · Esc 3'), findsOneWidget);
    expect(find.text('Boceto a mano'), findsOneWidget);
    // El boceto no es una columna a la que soltar planos.
    expect(find.text('Setup A'), findsWidgets);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
