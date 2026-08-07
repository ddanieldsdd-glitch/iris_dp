import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/pdf_export/storyboard_pdf.dart';
import 'package:iris_dp/features/storyboard/storyboard_export_style.dart';
import 'package:iris_dp/features/storyboard/storyboard_group_export_options.dart';
import 'package:iris_dp/features/storyboard/storyboard_shot_image_exporter.dart';
import 'package:iris_dp/features/storyboard/storyboard_shot_sheet_pdf.dart';
import 'package:iris_dp/features/storyboard/storyboard_shot_export_meta.dart';

/// PNG 1×1 mínimo válido.
final _tinyPng = Uint8List.fromList([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Future<({Project project, Scene scene, Shot shot})> _seed(AppDatabase db) async {
  final projectId = await db.insertProject(
    ProjectsCompanion.insert(name: 'My Project'),
  );
  final project = (await db.getProject(projectId))!;
  final sceneId = await db.insertScene(
    ScenesCompanion.insert(
      projectId: projectId,
      number: 2,
      name: 'Escena test',
      locationCanonical: 'INT. SALA - DÍA',
      locationPureName: 'SALA',
      intExt: const Value('INT'),
      dayNight: const Value('DÍA'),
    ),
  );
  final scene = (await db.getSceneById(sceneId))!;

  final dir = Directory.systemTemp.createTempSync('iris_export_test');
  final imagePath = '${dir.path}/ref.png';
  await File(imagePath).writeAsBytes(_tinyPng);

  final shotId = await db.insertShot(
    ShotsCompanion.insert(
      sceneId: sceneId,
      projectId: projectId,
      number: 1,
      lens: const Value('24mm'),
      referenceImagePath: Value(imagePath),
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

  group('storyboard export bytes', () {
    test('SB group PDF builds', () async {
      final data = await _seed(db);
      final bytes = await StoryboardPdfExporter.buildBytes(
        project: data.project,
        scenes: [data.scene],
        shotsByScene: {data.scene.id: [data.shot]},
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
        shotsByScene: {data.scene.id: [data.shot]},
        groupChoice: StoryboardGroupExportChoice.sequences(
          StoryboardSequenceLayout.shotList,
        ),
        db: db,
      );
      expect(bytes.length, greaterThan(100));
    });

    test('asShots DETAIL PDF builds', () async {
      final data = await _seed(db);
      final bytes = await StoryboardPdfExporter.buildBytes(
        project: data.project,
        scenes: [data.scene],
        shotsByScene: {data.scene.id: [data.shot]},
        groupChoice: StoryboardGroupExportChoice.asShots(
          StoryboardExportStyle.detail,
        ),
        db: db,
      );
      expect(bytes.length, greaterThan(100));
    });

    test('S2 single shot sheet PDF builds', () async {
      final data = await _seed(db);
      final meta = await StoryboardShotExportMeta.resolve(
        db: db,
        project: data.project,
        scene: data.scene,
        shot: data.shot,
      );
      final bytes = await StoryboardShotSheetPdf.buildBytes(
        project: data.project,
        scene: data.scene,
        shot: data.shot,
        style: StoryboardExportStyle.detail,
        meta: meta,
        db: db,
      );
      expect(bytes.length, greaterThan(100));
    });

    test('S3 single shot plan PDF builds', () async {
      final data = await _seed(db);
      final meta = await StoryboardShotExportMeta.resolve(
        db: db,
        project: data.project,
        scene: data.scene,
        shot: data.shot,
      );
      final bytes = await StoryboardShotSheetPdf.buildBytes(
        project: data.project,
        scene: data.scene,
        shot: data.shot,
        style: StoryboardExportStyle.shotPlan,
        meta: meta,
        db: db,
      );
      expect(bytes.length, greaterThan(100));
    });

    test('S1 PNG render builds', () async {
      final data = await _seed(db);
      final png = await StoryboardShotImageExporter.render(
        shot: data.shot,
        scene: data.scene,
        style: StoryboardExportStyle.basic,
      );
      expect(png, isNot(null));
      expect(png!.length, greaterThan(50));
    });
  });
}
