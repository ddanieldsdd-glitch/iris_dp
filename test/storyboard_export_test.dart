import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/storyboard/shot_sheet_data.dart';
import 'package:iris_dp/features/storyboard/storyboard_export_style.dart';
import 'package:iris_dp/features/storyboard/storyboard_group_export_options.dart';
import 'package:iris_dp/features/storyboard/storyboard_shot_export_service.dart';
import 'package:iris_dp/shared/pdf_export/storyboard_pdf.dart';

/// PNG 1×1 mínimo válido.
final _tinyPng = Uint8List.fromList([
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
]);

Future<({Project project, Scene scene, Shot shot})> _seed(
  AppDatabase db, {
  bool withStoryboard = false,
  int? siteId,
}) async {
  final projectId = await db.insertProject(
    ProjectsCompanion.insert(name: 'My Project'),
  );
  final project = (await db.getProject(projectId))!;
  final sceneId = await db.insertScene(
    ScenesCompanion.insert(
      projectId: projectId,
      number: 2,
      name: 'Título de la escena',
      locationCanonical: 'INT. SALA - DÍA',
      locationPureName: 'SALA',
      intExt: const Value('INT'),
      dayNight: const Value('DÍA'),
      locationSiteId: Value(siteId),
    ),
  );
  final scene = (await db.getSceneById(sceneId))!;

  final dir = Directory.systemTemp.createTempSync('iris_export_test');
  final refPath = '${dir.path}/ref.png';
  await File(refPath).writeAsBytes(_tinyPng);
  String? boardPath;
  if (withStoryboard) {
    boardPath = '${dir.path}/board.png';
    await File(boardPath).writeAsBytes(_tinyPng);
  }

  final shotId = await db.insertShot(
    ShotsCompanion.insert(
      sceneId: sceneId,
      projectId: projectId,
      number: 1,
      framing: const Value('PP'),
      lens: const Value('24mm'),
      angle: const Value('Picado'),
      movement: const Value('Steadicam'),
      referenceImagePath: Value(refPath),
      storyboardImagePath: Value(boardPath),
      action: const Value('Acción test'),
      notes: const Value('Notas test'),
    ),
  );
  final shot = (await db.getShotById(shotId))!;
  return (project: project, scene: scene, shot: shot);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('hoja de un plano', () {
    for (final style in StoryboardExportStyle.values) {
      test('${style.title} sale en PDF', () async {
        final data = await _seed(db);
        final bytes = await StoryboardShotExportService.buildBytes(
          db: db,
          project: data.project,
          scene: data.scene,
          shot: data.shot,
          style: style,
        );
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      });
    }

    test('resuelve datos reales del guion técnico, sin inventar', () async {
      final data = await _seed(db);
      final sheet = await ShotSheetData.resolve(
        db: db,
        project: data.project,
        scene: data.scene,
        shot: data.shot,
      );
      expect(sheet.lensFovLabel, '24mm : 74°');
      expect(sheet.sceneSlug, 'INT. SALA - DÍA');
      expect(sheet.framing, 'PP');
      expect(sheet.angle, 'Picado');
      expect(sheet.shotIndex, 1);
      expect(sheet.totalShots, 1);
      // Sin cámara ni óptica en el proyecto no hay etiqueta inventada.
      expect(sheet.cameraLabel, isNull);
      expect(sheet.lensSeriesLabel, isNull);
      expect(sheet.imageBytes, isNotNull);
    });

    test('elige la imagen del storyboard o la de referencia', () async {
      final data = await _seed(db, withStoryboard: true);
      expect(shotHasBothImages(data.shot), isTrue);
      expect(
        ShotImageSource.storyboard.pathOf(data.shot),
        data.shot.storyboardImagePath,
      );
      expect(
        ShotImageSource.reference.pathOf(data.shot),
        data.shot.referenceImagePath,
      );
    });

    test('SHOT PLAN: sol del día de rodaje en la localización', () async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Sol'),
      );
      final siteId = await db.insertSite(
        LocationSitesCompanion.insert(projectId: projectId, name: 'PISO'),
      );
      await db.setSitePlace(
        siteId,
        latitude: 41.39,
        longitude: 2.17,
        placeLabel: 'Barcelona',
      );
      final data = await _seed(db, siteId: siteId);
      final docId = await db.insertShootDocument(
        ShootDocumentsCompanion.insert(
          projectId: data.project.id,
          name: 'Jornada 1',
          kind: const Value('technical_day'),
          shootDate: const Value('2026-04-29'),
        ),
      );
      await db.insertShootDocumentBlock(
        ShootDocumentBlocksCompanion.insert(
          documentId: docId,
          blockType: 'shot',
          shotId: Value(data.shot.id),
        ),
      );

      final sheet = await ShotSheetData.resolve(
        db: db,
        project: data.project,
        scene: data.scene,
        shot: data.shot,
        withPlanAndSun: true,
      );
      final sun = sheet.sun!;
      expect(sun.fromShootDay, isTrue);
      expect(sun.date, DateTime(2026, 4, 29));
      expect(sun.placeLabel, 'Barcelona');
      expect(sun.hourly(), isNotEmpty);
      // Sin set elegido no hay planta: queda el hueco.
      expect(sheet.planPng, isNull);
      expect(sheet.hasPlanPlace, isFalse);
    });

    test('sin coordenadas no hay sol', () async {
      final data = await _seed(db);
      final sheet = await ShotSheetData.resolve(
        db: db,
        project: data.project,
        scene: data.scene,
        shot: data.shot,
        withPlanAndSun: true,
      );
      expect(sheet.sun, isNull);
    });
  });

  test('relación de aspecto de las líneas de encuadre', () {
    expect(parseAspectRatio('2.39:1'), closeTo(2.39, 0.001));
    expect(parseAspectRatio('1,85'), closeTo(1.85, 0.001));
    expect(parseAspectRatio('16:9'), closeTo(1.778, 0.001));
    expect(parseAspectRatio('scope'), isNull);
    expect(parseAspectRatio(null), isNull);
  });

  group('storyboard en grupo', () {
    test('SB group PDF builds', () async {
      final data = await _seed(db);
      final bytes = await StoryboardPdfExporter.buildBytes(
        project: data.project,
        scenes: [data.scene],
        shotsByScene: {
          data.scene.id: [data.shot],
        },
        groupChoice: StoryboardGroupExportChoice.sequences(
          StoryboardSequenceLayout.storyboard,
        ),
        db: db,
      );
      expect(bytes.length, greaterThan(100));
    });

    test('SL group PDF builds', () async {
      final data = await _seed(db);
      final bytes = await StoryboardPdfExporter.buildBytes(
        project: data.project,
        scenes: [data.scene],
        shotsByScene: {
          data.scene.id: [data.shot],
        },
        groupChoice: StoryboardGroupExportChoice.sequences(
          StoryboardSequenceLayout.shotList,
        ),
        db: db,
      );
      expect(bytes.length, greaterThan(100));
    });

    for (final style in StoryboardExportStyle.values) {
      test('export as shots ${style.title} sale en un PDF', () async {
        final data = await _seed(db, withStoryboard: true);
        final bytes = await StoryboardPdfExporter.buildBytes(
          project: data.project,
          scenes: [data.scene],
          shotsByScene: {
            data.scene.id: [data.shot],
          },
          groupChoice: StoryboardGroupExportChoice.asShots(
            style,
            imageSource: ShotImageSource.reference,
          ),
          db: db,
        );
        expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      });
    }
  });
}
