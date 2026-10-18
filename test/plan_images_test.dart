import 'dart:io';
import 'dart:math' as math;

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
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';
import 'package:iris_dp/features/camera_plan/plan_images.dart';
import 'package:iris_dp/features/camera_plan/plan_trash_service.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:iris_dp/shared/annotations/sketch_pad.dart';
import 'package:iris_dp/shared/pdf_export/camera_plan_pdf.dart';

class _TempDocs extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String root;
  _TempDocs(this.root);

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

void main() {
  late AppDatabase db;
  late PlanImageStore store;
  late int projectId;
  late int siteId;
  late int setId;
  late int sceneId;
  late int shotId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = PlanImageStore(db);
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'I'));
    siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'Casa'),
    );
    setId = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        locationName: 'Patio',
      ),
    );
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 5,
        name: 'Escena 5',
        locationCanonical: 'EXT. PATIO - NOCHE',
        locationPureName: 'PATIO',
        locationSiteId: Value(siteId),
        locationId: Value(setId),
      ),
    );
    shotId = await db.insertShot(
      ShotsCompanion.insert(sceneId: sceneId, projectId: projectId, number: 1),
    );
  });

  tearDown(() => db.close());

  /// Una fila sin archivo: para lo que no necesita leer la imagen.
  Future<PlanImage> row({
    required String type,
    required int target,
    double x = 100,
    double y = 100,
    bool above = false,
    String? path,
  }) async {
    final id = await db
        .into(db.planImages)
        .insert(
          PlanImagesCompanion.insert(
            projectId: projectId,
            targetType: type,
            targetId: target,
            path: Value(path),
            x: x,
            y: y,
            w: 400,
            h: 300,
            above: Value(above),
          ),
        );
    return (await store.get(id))!;
  }

  group('geometría', () {
    test('poner a escala con dos puntos de medida conocida', () {
      // 100 unidades en la imagen son 10 m; a 2 cm por unidad deberían ser
      // 500 unidades: la imagen crece ×5 desde el primer punto.
      final rect = calibratePlanImage(
        rect: const Rect.fromLTWH(0, 0, 200, 100),
        from: const Offset(0, 0),
        to: const Offset(100, 0),
        meters: 10,
        metersPerUnit: 0.02,
      );
      expect(rect.width, closeTo(1000, 0.001));
      expect(rect.height, closeTo(500, 0.001));
      expect(rect.topLeft, Offset.zero);
    });

    test('tocar dentro de una imagen girada', () async {
      final image = (await row(type: 'set', target: setId, x: 0, y: 0))
          .copyWith(rotation: math.pi / 2);
      // Girada 90°, ocupa 300 de ancho y 400 de alto alrededor de su centro.
      expect(planImageContains(image, const Offset(200, 330)), isTrue);
      expect(planImageContains(image, const Offset(20, 20)), isFalse);
    });
  });

  test('guardar, ver por capas, comentar y traer al frente', () async {
    final docs = Directory.systemTemp.createTempSync('iris_img');
    addTearDown(() => docs.deleteSync(recursive: true));
    final previous = PathProviderPlatform.instance;
    PathProviderPlatform.instance = _TempDocs(docs.path);
    addTearDown(() => PathProviderPlatform.instance = previous);

    final png = await renderSketchPng(
      const AnnotationDocument(),
      size: const Size(400, 200),
    );
    final wide = await store.add(
      projectId: projectId,
      scope: FloorPlanScope.set,
      targetId: setId,
      bytes: png,
      extension: '.png',
      source: PlanImageSource.pasted,
      center: const Offset(500, 500),
      longSide: 600,
    );
    expect(wide.w, closeTo(600, 0.01));
    expect(wide.h, closeTo(300, 0.01));
    expect(File(wide.path!).existsSync(), isTrue);
    await row(type: 'shot', target: shotId);
    await row(type: 'set', target: 999);

    final seen = await store.forLayers(
      projectId: projectId,
      setId: setId,
      shotId: shotId,
    );
    expect(seen, hasLength(2));

    var commented = await store.addComment(
      wide,
      author: 'gaffer',
      text: 'Con el M18 fuera no llega',
    );
    commented = await store.addComment(commented, author: 'dp', text: 'Vale');
    expect(PlanImageComment.decode(commented.commentsJson), hasLength(2));
    commented = await store.removeComment(commented, 0);
    expect(
      PlanImageComment.decode(commented.commentsJson).single.text,
      'Vale',
    );

    final front = await store.bringToFront(wide);
    expect(front.sortOrder, greaterThan(seen.last.sortOrder));
  });

  test('las imágenes viajan con su capa y su cámara', () async {
    await row(type: 'set', target: setId).then(
      (i) => store.save(i.copyWith(linkedShotId: Value(shotId))),
    );
    await row(type: 'site', target: siteId);
    final bundle = await ProjectContentBundle.export(db, projectId);
    final target = await db.insertProject(ProjectsCompanion.insert(name: 'o'));
    await ProjectContentBundle.importBundle(db, target, bundle);

    final images = await (db.select(
      db.planImages,
    )..where((i) => i.projectId.equals(target))).get();
    expect(images, hasLength(2));
    final set = (await (db.select(
      db.locationBasePlans,
    )..where((s) => s.projectId.equals(target))).get()).single;
    final shot = (await db.getShotsForProject(target)).single;
    final onSet = images.singleWhere((i) => i.targetType == 'set');
    expect(onSet.targetId, set.id);
    expect(onSet.linkedShotId, shot.id);
  });

  test('borrar el set se lleva sus imágenes y restaurarlo las devuelve',
      () async {
    final trash = PlanTrashService(db);
    await row(type: 'set', target: setId);
    await row(type: 'shot', target: shotId);
    final trashId = await trash.deleteSet(setId);
    expect(await db.select(db.planImages).get(), isEmpty);
    await trash.restore(trashId!);
    expect(await db.select(db.planImages).get(), hasLength(2));

    // Vaciar la planta del plano también quita sus imágenes.
    final cleared = await trash.clearPlan(FloorPlanScope.shot, shotId);
    expect(cleared, isNotNull);
    expect(
      (await db.select(db.planImages).get()).map((i) => i.targetType),
      ['set'],
    );
  });

  test('el PDF lleva las imágenes y sus comentarios como notas', () async {
    final dir = Directory.systemTemp.createTempSync('iris_pdf');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/maps.png')
      ..writeAsBytesSync(
        await renderSketchPng(
          const AnnotationDocument(),
          size: const Size(40, 30),
        ),
      );
    final image = await row(type: 'site', target: siteId, path: file.path);
    await store.addComment(image, author: 'dp', text: 'Luna por la izquierda');
    final shot = (await db.getShotById(shotId))!;
    final result = await CameraPlanPdfDiagram.imagesForShot(db, shot);
    expect(result.images, hasLength(1));
    expect(result.images.single.note, 1);
    expect(result.notes.single, contains('Luna por la izquierda'));
  });

  testWidgets('en el editor, tocar una imagen de debajo la elige y se puede '
      'poner encima o moverla', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late PlanImage image;
    await tester.runAsync(() async {
      image = await row(type: 'set', target: setId, x: 200, y: 200);
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: CameraPlanEditor.set(
            projectId: projectId,
            setId: setId,
            setName: 'Patio',
          ),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await settle();
    final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is CameraPlanPainter,
    );
    final state = tester.state(find.byType(CameraPlanEditor)) as dynamic;
    final view = state.debugView as ({Offset offset, double scale});
    Offset onScreen(Offset plan) =>
        tester.getTopLeft(canvas) + view.offset + plan * view.scale;

    // En medio de la imagen, sin nada encima: la elige.
    await tester.tapAt(onScreen(const Offset(400, 350)));
    await settle();
    expect(find.text('Encima'), findsOneWidget);

    await tester.tap(find.text('Encima'));
    await settle();
    var saved = await tester.runAsync(() => store.get(image.id));
    expect(saved!.above, isTrue);

    await tester.dragFrom(
      onScreen(const Offset(400, 350)),
      const Offset(100, 50),
    );
    await settle();
    saved = await tester.runAsync(() => store.get(image.id));
    expect(saved!.x, greaterThan(200));
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
