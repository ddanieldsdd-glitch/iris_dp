import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/bundle_merge.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';

/// Las capturas del iPhone son filas del proyecto: migran desde el esquema
/// 58, viajan en el bundle con su set y se mezclan campo a campo por uid.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('una base del esquema 58 gana la tabla de capturas', () async {
    final dir = Directory.systemTemp.createTempSync('iris_captures_mig');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/iris_dp.db');

    final fresh = AppDatabase.forTesting(NativeDatabase(file));
    await fresh.insertProject(ProjectsCompanion.insert(name: 'lala'));
    await fresh.customStatement('DROP TABLE location_captures');
    await fresh.close();

    final reopened = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (raw) => raw.execute('PRAGMA user_version = 58'),
      ),
    );
    addTearDown(reopened.close);
    final projectId = (await reopened.watchProjects().first).single.id;
    await reopened.insertCapture(
      LocationCapturesCompanion.insert(projectId: projectId, name: 'Nave'),
    );
    expect(
      await reopened.watchCapturesForProject(projectId).first,
      hasLength(1),
    );
  });

  test('ida y vuelta: estado, fotos y su set', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Captura'),
    );
    final siteId = await db.insertSite(
      LocationSitesCompanion.insert(projectId: projectId, name: 'HOSPITAL'),
    );
    final setId = await db
        .into(db.locationBasePlans)
        .insert(
          LocationBasePlansCompanion.insert(
            projectId: projectId,
            locationName: 'PASILLO',
            siteId: Value(siteId),
          ),
        );
    await db.insertCapture(
      LocationCapturesCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        setId: Value(setId),
        name: 'Pasillo 1',
        photoCount: const Value(184),
        bytes: const Value(612000000),
        originInstallId: const Value('iphone'),
      ),
    );
    final uid = (await db.watchCapturesForProject(projectId).first).single.uid!;
    await db.updateCapture(
      uid,
      const LocationCapturesCompanion(
        status: Value('construyendo'),
        progress: Value(0.35),
        builderInstallId: Value('pc'),
      ),
    );

    final bundle = await ProjectContentBundle.export(db, projectId);
    final target = await db.insertProject(
      ProjectsCompanion.insert(name: 'descargado'),
    );
    await ProjectContentBundle.importBundle(db, target, bundle);

    final back = (await db.watchCapturesForProject(target).first).single;
    expect(back.uid, uid);
    expect(back.name, 'Pasillo 1');
    expect(back.photoCount, 184);
    expect(back.bytes, 612000000);
    expect(back.status, 'construyendo');
    expect(back.progress, closeTo(0.35, 1e-9));
    expect(back.originInstallId, 'iphone');
    expect(back.builderInstallId, 'pc');
    final sets = await db.watchSetsForSite(back.siteId!).first;
    expect(sets.single.id, back.setId);
    expect(sets.single.locationName, 'PASILLO');
  });

  test('el estado del PC y el nombre del iPhone se juntan', () {
    Map<String, dynamic> capture({String? name, String? status}) => {
      'uid': 'c1',
      'siteKey': null,
      'setKey': null,
      'name': name ?? 'Pasillo',
      'status': status ?? 'en_iphone',
      'progress': 0.0,
    };
    Map<String, dynamic> bundle(Map<String, dynamic> c) => {
      'version': 8,
      'project': <String, dynamic>{},
      'locationCaptures': [c],
    };
    final base = bundle(capture());
    final result = BundleMerge.merge(
      baseLocal: base,
      baseCloud: base,
      local: bundle(capture(name: 'Pasillo norte')),
      cloud: bundle(capture(status: 'listo')),
      newer: MergeSide.local,
    );
    final merged = (result.merged['locationCaptures'] as List).single as Map;
    expect(merged['name'], 'Pasillo norte');
    expect(merged['status'], 'listo');
    expect(result.discards, isEmpty);
  });
}
