import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/core/utils/shot_reference_import.dart';
import 'package:iris_dp/shared/shot_images/shot_image_menu.dart';

/// Un PNG de 1 × 1.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA'
  '60e6kgAAAABJRU5ErkJggg==',
);

void main() {
  late AppDatabase db;
  late Directory docs;
  late Shot shot;
  Object? clipboard;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    docs = Directory.systemTemp.createTempSync('iris_paste_');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('com.iris_dp/export_file_saver'),
      (call) async => call.method == 'readClipboard' ? clipboard : null,
    );
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    await db.close();
    if (docs.existsSync()) docs.deleteSync(recursive: true);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.runAsync(() async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Pegar'),
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
      final id = await db.insertShot(
        ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: 3,
        ),
      );
      shot = (await db.getShotById(id))!;
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 120,
                height: 84,
                child: ShotImagePasteTarget(
                  shot: shot,
                  child: const ColoredBox(
                    color: Colors.grey,
                    child: Center(child: Text('Ref.')),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> hoverAndPaste(WidgetTester tester) async {
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      mouse.hover(tester.getCenter(find.text('Ref.'))),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  test('la imagen copiada se guarda como referencia del plano', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // Solo aquí se guarda de verdad: la carpeta de la app va a una temporal.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (call) async => docs.path,
        );
    clipboard = {'kind': 'image', 'bytes': _png, 'extension': '.png'};
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Pegar'),
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
    final id = await db.insertShot(
      ShotsCompanion.insert(sceneId: sceneId, projectId: projectId, number: 3),
    );
    final problem = await pasteShotImageFromClipboard(
      db,
      (await db.getShotById(id))!,
    );
    expect(problem, isNull);
    final path = (await db.getShotById(id))!.referenceImagePath;
    expect(path, isNotNull);
    expect(File(path!).readAsBytesSync(), _png);

    // Pegar otra la añade: el plano lleva una imagen por encuadre y la
    // primera sigue siendo la principal.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(
      await pasteShotImageFromClipboard(db, (await db.getShotById(id))!),
      isNull,
    );
    final after = (await db.getShotById(id))!;
    final references = await db.watchReferencesForShot(id).first;
    expect(references, hasLength(2));
    expect(after.referenceImagePath, path);
    expect(referenceImagesOf(after, references), [
      path,
      references.last.imagePath,
    ]);

    // Al quitar la principal, pasa a serlo la siguiente.
    await deleteShotReferenceEntry(
      db: db,
      shot: after,
      reference: references.first,
    );
    expect(
      (await db.getShotById(id))!.referenceImagePath,
      references.last.imagePath,
    );

    // Un enlace que no se puede descargar se explica, no se calla.
    clipboard = {'kind': 'empty', 'types': <String>[]};
    expect(
      await pasteShotImageFromClipboard(db, (await db.getShotById(id))!),
      contains('no hay una imagen'),
    );
  });

  testWidgets('si lo copiado no es una imagen, lo dice', (tester) async {
    clipboard = {'kind': 'empty', 'types': <String>[]};
    await open(tester);
    await hoverAndPaste(tester);

    expect(
      find.textContaining('En el portapapeles no hay una imagen'),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 5));
  });
}
