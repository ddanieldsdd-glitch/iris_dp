import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/core/utils/shot_reference_import.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:iris_dp/shared/annotations/sketch_sheet_screen.dart';

/// ED.5: lo que ve la cámara del plano en el 3D se guarda como su
/// referencia (una por plano) y sale atenuada en el folio del storyboard.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  // Un PNG de 1×1.
  final png = Uint8List.fromList(const [
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
    0x0D,
    0x49,
    0x44,
    0x41,
    0x54,
    0x78,
    0x9C,
    0x63,
    0xF8,
    0xCF,
    0xC0,
    0xF0,
    0x1F,
    0x00,
    0x05,
    0x00,
    0x01,
    0xFF,
    0x89,
    0x99,
    0x3D,
    0x1D,
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

  group('referencia «cámara 3D»', () {
    late AppDatabase db;
    late Directory docs;
    late int projectId, sceneId;

    setUp(() async {
      docs = Directory.systemTemp.createTempSync('iris_cam3d_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (call) async => docs.path,
          );
      db = AppDatabase.forTesting(NativeDatabase.memory());
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
      sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 1,
          name: 'Escena 1',
          locationCanonical: 'INT. BAR - NOCHE',
          locationPureName: 'BAR',
        ),
      );
    });

    tearDown(() async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            null,
          );
      await db.close();
      docs.deleteSync(recursive: true);
    });

    test('se sustituye la anterior y no quita la imagen principal', () async {
      final id = await db.insertShot(
        ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: 1,
        ),
      );
      var shot = (await db.getShotById(id))!;
      final main = await importShotReferenceImage(
        db: db,
        shot: shot,
        sourceBytes: png,
        fileName: 'ref.png',
        source: ShotReferenceSource.manual,
      );
      shot = (await db.getShotById(id))!;
      await replaceShotCamera3dView(db: db, shot: shot, png: png);
      shot = (await db.getShotById(id))!;
      final second = await replaceShotCamera3dView(
        db: db,
        shot: shot,
        png: png,
      );
      final refs = await db.getReferencesForShot(id);
      final views = refs.where((r) => r.source == ShotReferenceSource.camera3d);
      expect(views.map((r) => r.imagePath), [second]);
      expect(refs.where((r) => r.imagePath == main), hasLength(1));
      expect((await db.getShotById(id))!.referenceImagePath, main);
    });
  });

  testWidgets('el folio enseña la vista 3D y se quita de un toque', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: SketchSheetScreen(
          title: 'Plano 1',
          initialDocument: const AnnotationDocument(),
          purpose: SketchSheetPurpose.storyboard,
          aspectRatio: 16 / 9,
          underlay: MemoryImage(png),
          underlayLabel: 'su cámara',
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Vista 3D · su cámara  ✕'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(IgnorePointer),
        matching: find.byType(Image),
      ),
      findsWidgets,
    );
    await tester.tap(find.byKey(const ValueKey('sketch-underlay')));
    await tester.pump();
    expect(find.text('Ver su cámara debajo'), findsOneWidget);
  });
}
