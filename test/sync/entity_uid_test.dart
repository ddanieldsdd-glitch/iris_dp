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

/// B1: escenas, planos e imágenes tienen una identidad permanente.
void main() {
  late AppDatabase db;
  late int projectId;
  late int sceneId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'lala'));
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'INT. CASA - DÍA',
        locationCanonical: 'INT. CASA - DÍA',
        locationPureName: 'CASA',
      ),
    );
  });

  Future<int> addStill(int sortOrder) => db
      .into(db.moodboardImages)
      .insert(
        MoodboardImagesCompanion.insert(
          projectId: projectId,
          imagePath: '/tmp/still-$sortOrder.png',
          sortOrder: Value(sortOrder),
        ),
      );

  test('cada fila nueva recibe un uid distinto', () async {
    final a = await addStill(0);
    final b = await addStill(0);
    final stills = await db.select(db.moodboardImages).get();
    final byId = {for (final s in stills) s.id: s.uid};
    expect(byId[a], isNotNull);
    expect(byId[a], isNot(byId[b]));
    final scene = await (db.select(
      db.scenes,
    )..where((s) => s.id.equals(sceneId))).getSingle();
    expect(scene.uid, isNotNull);
  });

  test('dos imágenes en el mismo puesto ya no comparten clave', () async {
    await addStill(0);
    await addStill(0);
    final bundle = await ProjectContentBundle.export(db, projectId);
    final keys = [
      for (final m in bundle['moodboardImages'] as List) (m as Map)['mediaKey'],
    ];
    expect(keys.toSet(), hasLength(2));
    expect(
      keys.every((k) => MediaEntityKeys.uidOf(k as String) != null),
      isTrue,
    );
  });

  test('el uid viaja en el bundle y se conserva al importar', () async {
    await addStill(0);
    await db
        .into(db.shots)
        .insert(
          ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: 1,
          ),
        );
    final bundle = await ProjectContentBundle.export(db, projectId);
    final target = await db.insertProject(
      ProjectsCompanion.insert(name: 'otro dispositivo'),
    );
    await ProjectContentBundle.importBundle(db, target, bundle);

    Future<Set<String?>> uids(String table, int project) async => {
      for (final r
          in await db
              .customSelect(
                'SELECT uid FROM $table WHERE project_id = ?',
                variables: [Variable.withInt(project)],
              )
              .get())
        r.read<String?>('uid'),
    };
    for (final table in ['scenes', 'shots', 'moodboard_images']) {
      expect(
        await uids(table, target),
        await uids(table, projectId),
        reason: table,
      );
    }
  });

  test('el uid no cuenta para la huella del contenido', () async {
    final before = await ProjectContentBundle.computeLocalHash(db, projectId);
    await db.customStatement("UPDATE scenes SET uid = 'otro'");
    final after = await ProjectContentBundle.computeLocalHash(db, projectId);
    expect(after, before);
  });

  test('migrar al esquema 47 da uid a lo que no lo tiene', () async {
    final dir = Directory.systemTemp.createTempSync('iris_uid_migration');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/iris_dp.db');
    final old = AppDatabase.forTesting(NativeDatabase(file));
    final project = await old.insertProject(
      ProjectsCompanion.insert(name: 'antiguo'),
    );
    await old.insertScene(
      ScenesCompanion.insert(
        projectId: project,
        number: 1,
        name: 'EXT. CALLE - NOCHE',
        locationCanonical: 'EXT. CALLE - NOCHE',
        locationPureName: 'CALLE',
        uid: const Value(null),
      ),
    );
    await old.close();

    final migrated = AppDatabase.forTesting(
      NativeDatabase(
        file,
        setup: (raw) => raw.execute('PRAGMA user_version = 46'),
      ),
    );
    addTearDown(migrated.close);
    final scene = await migrated.select(migrated.scenes).getSingle();
    expect(scene.uid, isNotNull);
    expect(scene.uid, hasLength(32));
  });

  test(
    'una imagen de localización se descarga en su sitio por su uid',
    () async {
      final siteId = await db
          .into(db.locationSites)
          .insert(
            LocationSitesCompanion.insert(projectId: projectId, name: 'Casa'),
          );
      final imageId = await db
          .into(db.siteImages)
          .insert(
            SiteImagesCompanion.insert(
              siteId: siteId,
              imagePath: '/no/existe/en/este/dispositivo.png',
            ),
          );
      final uid = (await (db.select(
        db.siteImages,
      )..where((i) => i.id.equals(imageId))).getSingle()).uid!;

      final cloud = _FakeCloud([
        {
          'entity_type': MediaEntityType.site,
          'entity_key': MediaEntityKeys.byUid(uid),
          'delivery_url': 'https://res.cloudinary.com/x/casa.jpg',
          'public_id': 'iris/ws/p/site/$uid',
        },
      ]);
      final downloaded = await MediaHydrateService(
        db,
        cloud,
      ).hydrateProject(projectId, 'cloud-1');

      expect(downloaded, 1);
      final image = await (db.select(
        db.siteImages,
      )..where((i) => i.id.equals(imageId))).getSingle();
      expect(image.imagePath, '/descargas/site_image.jpg');
    },
  );
}

class _FakeCloud extends CloudMediaService {
  _FakeCloud(this.assets)
    : super(SupabaseClient('http://127.0.0.1:9', 'clave'));

  final List<Map<String, dynamic>> assets;

  @override
  Future<List<Map<String, dynamic>>> fetchProjectAssets(
    String projectCloudId,
  ) async => assets;

  @override
  Future<String?> downloadToLocal({
    required int localProjectId,
    required String deliveryUrl,
    required String subfolder,
    required String fileName,
  }) async => '/descargas/site_image.jpg';
}
