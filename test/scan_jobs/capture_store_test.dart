import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/rig/scan_capture.dart';
import 'package:iris_dp/features/scan_jobs/capture_store.dart';
import 'package:iris_dp/features/scan_jobs/captures_list.dart';

/// La captura del iPhone queda como fila del set con su zip por uid.
void main() {
  late AppDatabase db;
  late Directory docs;
  late int projectId;

  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    docs = Directory.systemTemp.createTempSync('iris_captures');
    CaptureStore.debugRoot = docs;
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'C'));
  });

  tearDown(() async {
    await db.close();
    CaptureStore.debugRoot = null;
    docs.deleteSync(recursive: true);
  });

  /// La carpeta que deja el plugin: fotos y `capture.json`.
  Directory captureFolder(int photos) {
    final dir = Directory('${docs.path}/IRIS Capturas/Pasillo 2026-11-03T114624Z.iriscapture')
      ..createSync(recursive: true);
    for (var i = 0; i < photos; i++) {
      File('${dir.path}/$i.jpg').writeAsBytesSync([i, 1, 2]);
    }
    File('${dir.path}/capture.json').writeAsStringSync(
      jsonEncode({
        'version': 1,
        'frames': [for (var i = 0; i < photos; i++) {'file': '$i.jpg'}],
      }),
    );
    return dir;
  }

  test('zip del plugin: se renombra por uid y se borra la carpeta', () async {
    final folder = captureFolder(3);
    final zip = '${folder.path}.zip';
    final encoder = ZipFileEncoder()..create(zip);
    await encoder.addDirectory(folder);
    await encoder.close();

    final c = await CaptureStore.register(
      db,
      projectId: projectId,
      path: zip,
      name: 'Pasillo',
      setId: 7,
    );
    expect(c.photoCount, 3);
    expect(c.status, CaptureStatus.onPhone);
    expect(c.setId, 7);
    expect(c.originInstallId, isNotNull);
    final stored = await CaptureStore.zipFor(c.uid!);
    expect(stored.existsSync(), isTrue);
    expect(c.bytes, stored.lengthSync());
    expect(File(zip).existsSync(), isFalse);
    expect(folder.existsSync(), isFalse);
  });

  test('si el sistema no comprimió, se comprime aquí', () async {
    final folder = captureFolder(2);
    final c = await CaptureStore.register(
      db,
      projectId: projectId,
      path: folder.path,
      name: 'Pasillo',
    );
    expect(c.photoCount, 2);
    final stored = await CaptureStore.zipFor(c.uid!);
    final names = ZipDecoder()
        .decodeBytes(stored.readAsBytesSync())
        .files
        .map((f) => f.name)
        .toSet();
    expect(names, containsAll(['0.jpg', '1.jpg', 'capture.json']));
    expect(folder.existsSync(), isFalse);
  });

  test('una captura que no llegó a registrarse aparece y se recupera',
      () async {
    // Lo que pasó en el iPhone: carpeta y zip del plugin, sin fila.
    final folder = captureFolder(4);
    final zip = '${folder.path}.zip';
    final encoder = ZipFileEncoder()..create(zip);
    await encoder.addDirectory(folder);
    await encoder.close();
    // Y otra ya registrada, que no cuenta.
    final done = captureFolder(1).renameSync('${docs.path}/x.iriscapture');
    await CaptureStore.register(
      db,
      projectId: projectId,
      path: done.path,
      name: 'Hecha',
    );

    final orphans = await CaptureStore.orphans(db);
    expect(orphans, hasLength(1));
    expect(orphans.single.name, 'Pasillo');
    expect(orphans.single.path, zip);

    final c = await CaptureStore.register(
      db,
      projectId: projectId,
      path: orphans.single.path,
      name: orphans.single.name,
      setId: 3,
    );
    expect(c.photoCount, 4);
    expect(await CaptureStore.orphans(db), isEmpty);
  });

  test('borrar una suelta quita zip y carpeta', () async {
    final folder = captureFolder(2);
    final zip = File('${folder.path}.zip')..writeAsBytesSync([1]);
    final o = (await CaptureStore.orphans(db)).single;
    await CaptureStore.deleteOrphan(o);
    expect(zip.existsSync(), isFalse);
    expect(folder.existsSync(), isFalse);
  });

  test('gran angular 0,5x: fotos sin pose, el PC no inventa escala', () async {
    final folder = captureFolder(3);
    File('${folder.path}/capture.json').writeAsStringSync(
      jsonEncode({
        'version': 1,
        'lens': 'ultraWide',
        'frames': [
          for (var i = 0; i < 3; i++)
            {
              'file': '$i.jpg',
              'width': 4032,
              'height': 3024,
              'attitude': [1, 0, 0, 0],
            },
        ],
      }),
    );
    final package = CapturePackage.read(folder.path)!;
    expect(package.frames, isEmpty);
    expect(package.writeSidecars(), 0);

    final c = await CaptureStore.register(
      db,
      projectId: projectId,
      path: folder.path,
      name: 'Baño',
    );
    expect(c.photoCount, 3);
  });

  testWidgets('iPhone 390: estados sin desbordes', (tester) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(390, 844) * 3;
    addTearDown(tester.view.reset);

    await tester.runAsync(() async {
      for (final (name, status, progress) in [
        ('Pasillo norte con un nombre muy largo de verdad', 'en_iphone', 0.0),
        ('Quirófano', 'enviando', 0.4),
        ('Hall', 'construyendo', 0.7),
        ('Azotea', 'error', 0.0),
      ]) {
        await db.insertCapture(
          LocationCapturesCompanion.insert(
            projectId: projectId,
            setId: const Value(1),
            name: name,
            status: Value(status),
            progress: Value(progress),
            photoCount: const Value(212),
            bytes: const Value(734003200),
            error: Value(status == 'error' ? 'RealityScan no alineó' : null),
          ),
        );
      }
      await db.insertCapture(
        LocationCapturesCompanion.insert(
          projectId: projectId,
          setId: const Value(2),
          name: 'Otro set',
        ),
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: CapturesList(projectId: projectId, setId: 1),
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(tester.takeException(), isNull);
    expect(find.text('Quirófano'), findsOneWidget);
    expect(find.text('Otro set'), findsNothing);
    expect(find.text('Enviando al PC · 40 %'), findsOneWidget);
    expect(find.text('Error: RealityScan no alineó'), findsOneWidget);
    expect(find.text('212 fotos · 700 MB'), findsNWidgets(4));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));
  });
}
