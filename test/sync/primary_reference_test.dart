import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/cloud_media_service.dart';
import 'package:iris_dp/core/sync/media_entity_keys.dart';
import 'package:iris_dp/core/sync/media_entity_types.dart';
import 'package:iris_dp/core/sync/media_hydrate_service.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Visto en el iPad (2026-10-16): la referencia principal de cada plano salía
/// dos veces. La principal es una de sus referencias, no otra imagen.
class _FakeCloud extends CloudMediaService {
  _FakeCloud(this.assets, this.downloadTo)
    : super(SupabaseClient('http://127.0.0.1:9', 'clave'));

  final List<Map<String, dynamic>> assets;
  final String downloadTo;
  var downloads = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchProjectAssets(String id) async =>
      assets;

  @override
  Future<String?> downloadToLocal({
    required int localProjectId,
    required String deliveryUrl,
    required String subfolder,
    required String fileName,
  }) async {
    downloads++;
    return downloadTo;
  }
}

void main() {
  late AppDatabase db;
  late int projectId;
  late int shotId;
  late Directory dir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    dir = Directory.systemTemp.createTempSync('iris_primary');
    addTearDown(() => dir.deleteSync(recursive: true));
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'lala'));
    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'INT. CASA - DÍA',
        locationCanonical: 'INT. CASA - DÍA',
        locationPureName: 'CASA',
      ),
    );
    shotId = await db
        .into(db.shots)
        .insert(
          ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: 1,
          ),
        );
  });

  String file(String name, List<int> bytes) =>
      (File('${dir.path}/$name')..writeAsBytesSync(bytes)).path;

  Future<ShotReference> addReference(String path, {bool primary = true}) async {
    await db.insertShotReference(
      ShotReferencesCompanion.insert(shotId: shotId, imagePath: path),
    );
    if (primary) {
      await (db.update(db.shots)..where((s) => s.id.equals(shotId))).write(
        ShotsCompanion(referenceImagePath: Value(path)),
      );
    }
    return (await db.select(db.shotReferences).get()).last;
  }

  test('al importar, la principal apunta a su referencia', () async {
    final reference = await addReference('/Users/mac/refs/a.png');
    final bundle = await ProjectContentBundle.export(db, projectId);
    final shotRow = Map<String, dynamic>.from(
      (bundle['shots'] as List).single as Map,
    );
    expect(shotRow['primaryReferenceUid'], reference.uid);

    final target = await db.insertProject(
      ProjectsCompanion.insert(name: 'otro'),
    );
    await ProjectContentBundle.importBundle(db, target, bundle);

    final shot = await (db.select(
      db.shots,
    )..where((s) => s.projectId.equals(target))).getSingle();
    final imported = await (db.select(
      db.shotReferences,
    )..where((r) => r.shotId.equals(shot.id))).getSingle();
    expect(shot.referenceImagePath, imported.imagePath);
  });

  test('al bajar la referencia, la principal la sigue', () async {
    final reference = await addReference('/Users/mac/refs/a.png');
    final local = file('bajada.jpg', [1, 2, 3]);
    final hydrate = MediaHydrateService(
      db,
      _FakeCloud([
        {
          'entity_type': MediaEntityType.shotReference,
          'entity_key': MediaEntityKeys.byUid(reference.uid!),
          'delivery_url': 'https://res.cloudinary.com/x/a',
          'public_id': 'iris/ws/p/shot_reference/${reference.uid}',
        },
      ], local),
    );

    await hydrate.hydrateProject(projectId, 'cloud-1');

    final shot = await (db.select(
      db.shots,
    )..where((s) => s.id.equals(shotId))).getSingle();
    expect(shot.referenceImagePath, local);
  });

  test('lo subido como «referencia principal» aparte no se baja', () async {
    final cloud = _FakeCloud([
      {
        'entity_type': MediaEntityType.shotMainReference,
        'entity_key': 'uid:lo-que-sea',
        'delivery_url': 'https://res.cloudinary.com/x/b',
        'public_id': 'iris/ws/p/shot_main_reference/x',
      },
    ], '/descargas/b.jpg');

    await MediaHydrateService(db, cloud).hydrateProject(projectId, 'cloud-1');

    expect(cloud.downloads, 0);
  });

  test(
    'una principal copiada aparte se repara si es la misma imagen',
    () async {
      final ref = file('shot_reference_1.jpg', [9, 9, 9]);
      final copy = file('shot_main_reference_x.jpg', [9, 9, 9]);
      final other = file('otra.jpg', [1]);
      await addReference(ref, primary: false);
      await (db.update(db.shots)..where((s) => s.id.equals(shotId))).write(
        ShotsCompanion(referenceImagePath: Value(copy)),
      );
      final hydrate = MediaHydrateService(db, _FakeCloud(const [], other));

      expect(await hydrate.repairDuplicatePrimaryReferences(projectId), 1);
      final shot = await (db.select(
        db.shots,
      )..where((s) => s.id.equals(shotId))).getSingle();
      expect(shot.referenceImagePath, ref);
    },
  );

  test(
    'al importar, lo que este equipo ya tiene se queda con su archivo',
    () async {
      // Visto en el Mac (2026-10-17): la descarga dejó todas las referencias
      // con rutas del iPad aunque los originales estaban en disco.
      final original = file('shot_76_original.png', [4, 4, 4]);
      final reference = await addReference(original);
      final bundle = await ProjectContentBundle.export(db, projectId);
      // El bundle llega del iPad: misma fila (uid), ruta del iPad.
      final row = Map<String, dynamic>.from(
        (bundle['shotReferences'] as List).single as Map,
      );
      row['imagePath'] =
          '/var/mobile/Containers/Data/Application/X/references/shot_reference_1.jpg';
      bundle['shotReferences'] = [row];
      (bundle['shots'] as List).single['referenceImagePath'] = row['imagePath'];

      await ProjectContentBundle.importBundle(db, projectId, bundle);

      final imported = await db.select(db.shotReferences).getSingle();
      expect(imported.uid, reference.uid);
      expect(imported.imagePath, original);
      final shot = await db.select(db.shots).getSingle();
      expect(shot.referenceImagePath, original);
    },
  );
}
