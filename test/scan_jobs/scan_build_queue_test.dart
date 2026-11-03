import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
// ignore: depend_on_referenced_packages
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/camera_plan/rig/scan_builder.dart';
import 'package:iris_dp/features/scan_jobs/capture_store.dart';
import 'package:iris_dp/features/scan_jobs/scan_build_queue.dart';

class _TempDocs extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String root;
  _TempDocs(this.root);

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// La cola del PC con un constructor falso: estados, enganche al set y
/// fallos.
void main() {
  late AppDatabase db;
  late Directory docs;
  late int projectId;
  late int setId;
  late List<String> toasts;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    docs = Directory.systemTemp.createTempSync('iris_queue');
    PathProviderPlatform.instance = _TempDocs(docs.path);
    CaptureStore.debugRoot = docs;
    toasts = [];
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'Q'));
    setId = await db
        .into(db.locationBasePlans)
        .insert(
          LocationBasePlansCompanion.insert(
            projectId: projectId,
            locationName: 'PASILLO',
          ),
        );
  });

  tearDown(() async {
    await db.close();
    CaptureStore.debugRoot = null;
    docs.deleteSync(recursive: true);
  });

  Future<String> received(String name, {String status = 'en_pc'}) async {
    await db.insertCapture(
      LocationCapturesCompanion.insert(
        projectId: projectId,
        setId: Value(setId),
        name: name,
        status: Value(status),
        originInstallId: const Value('iphone'),
      ),
    );
    final uid = (await db.watchCapturesForProject(
      projectId,
    ).first).firstWhere((c) => c.name == name).uid!;
    (await CaptureStore.zipFor(uid)).writeAsBytesSync([1, 2, 3]);
    return uid;
  }

  Stream<ScanBuildProgress> fakeBuild(String zip, String name) async* {
    yield const ScanBuildProgress(
      ScanBuildStage.reconstructing,
      'Alineando',
      fraction: 0.5,
    );
    final glb = File('${docs.path}/$name.glb')..writeAsBytesSync([7, 7, 7]);
    yield ScanBuildProgress(
      ScanBuildStage.done,
      'Listo',
      result: ScanBuildResult(
        irisGlb: glb.path,
        highGlb: glb.path,
        folder: docs.path,
        images: 3,
        discarded: 0,
        metric: true,
      ),
    );
  }

  test('construye en orden, pone el GLB en el set y borra el zip', () async {
    final a = await received('Pasillo');
    // Llegó el zip antes que la fila en «en_pc»: también entra.
    final b = await received('Hall', status: 'enviando');
    final built = <String>[];
    final queue = ScanBuildQueue(
      db,
      build: (zip, name) {
        built.add(name);
        return fakeBuild(zip, name);
      },
      notify: (title, _) => toasts.add(title),
    );
    await queue.runPending();

    expect(built, ['Pasillo', 'Hall']);
    for (final uid in [a, b]) {
      final c = (await db.getCaptureByUid(uid))!;
      expect(c.status, CaptureStatus.done);
      expect(c.builderInstallId, isNotNull);
      expect((await CaptureStore.zipFor(uid)).existsSync(), isFalse);
    }
    final set = (await db.getLocationById(setId))!;
    expect(set.model3dPath, isNotNull);
    expect(set.scanSource, 'iphone_capture');
    expect(toasts, ['Escaneo listo: Pasillo', 'Escaneo listo: Hall']);
    expect(queue.state.value.idle, isTrue);
  });

  test('si RealityScan falla, queda en error con el motivo', () async {
    final uid = await received('Azotea');
    final queue = ScanBuildQueue(
      db,
      build: (_, _) => Stream.value(
        const ScanBuildProgress(ScanBuildStage.error, 'No se alinearon'),
      ),
      notify: (title, _) => toasts.add(title),
    );
    await queue.runPending();
    final c = (await db.getCaptureByUid(uid))!;
    expect(c.status, CaptureStatus.failed);
    expect(c.error, 'No se alinearon');
    // El zip se queda para reintentar.
    expect((await CaptureStore.zipFor(uid)).existsSync(), isTrue);
    expect(toasts, ['Escaneo fallido: Azotea']);
  });

  test('sin zip en este equipo no hay nada que construir', () async {
    await db.insertCapture(
      LocationCapturesCompanion.insert(
        projectId: projectId,
        name: 'En el iPhone',
      ),
    );
    final queue = ScanBuildQueue(db, build: fakeBuild);
    expect(await queue.pending(), isEmpty);
  });
}
