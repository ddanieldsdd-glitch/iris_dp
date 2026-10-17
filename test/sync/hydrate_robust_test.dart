import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/cloud_media_service.dart';
import 'package:iris_dp/core/sync/media_entity_keys.dart';
import 'package:iris_dp/core/sync/media_entity_types.dart';
import 'package:iris_dp/core/sync/media_hydrate_service.dart';
import 'package:iris_dp/core/sync/media_upload_queue.dart';
import 'package:iris_dp/core/utils/error_log.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Visto en el iPad: un archivo que fallaba cortaba la descarga entera, y lo
/// bajado volvía a la cola para subirse.
class _FakeCloud extends CloudMediaService {
  _FakeCloud(this.assets, this.dir)
    : super(SupabaseClient('http://127.0.0.1:9', 'clave'));

  final List<Map<String, dynamic>> assets;
  final Directory dir;
  final uploads = <String>[];

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
    if (deliveryUrl.contains('rota')) throw const SocketException('sin red');
    return (File('${dir.path}/$fileName')..writeAsBytesSync([1, 2])).path;
  }

  @override
  Future<CloudUploadResult?> uploadFile({
    required String localPath,
    required String publicId,
    required String projectCloudId,
    required String entityType,
    required String entityKey,
    required int sortOrder,
    String? source,
    int? bytesOriginalOverride,
  }) async {
    uploads.add(entityKey);
    return CloudUploadResult(
      publicId: publicId,
      deliveryUrl: '',
      bytesOriginal: 1,
      bytesStored: 1,
      contentHash: 'h',
    );
  }
}

void main() {
  late AppDatabase db;
  late int projectId;
  late Directory dir;
  late Directory logs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'iris_cloud_workspace_id': 'ws'});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    dir = Directory.systemTemp.createTempSync('iris_hydrate');
    logs = Directory.systemTemp.createTempSync('iris_hydrate_logs');
    ErrorLog.directoryOverride = logs;
    addTearDown(() {
      ErrorLog.directoryOverride = null;
      dir.deleteSync(recursive: true);
      logs.deleteSync(recursive: true);
    });
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'lala', cloudId: const Value('cloud-1')),
    );
  });

  Future<String> addStill(String path) async {
    final id = await db
        .into(db.moodboardImages)
        .insert(
          MoodboardImagesCompanion.insert(
            projectId: projectId,
            imagePath: path,
          ),
        );
    return (await (db.select(
      db.moodboardImages,
    )..where((m) => m.id.equals(id))).getSingle()).uid!;
  }

  Map<String, dynamic> asset(String uid, String url) => {
    'entity_type': MediaEntityType.moodboard,
    'entity_key': MediaEntityKeys.byUid(uid),
    'delivery_url': url,
    'public_id': 'iris/ws/cloud-1/moodboard/$uid',
  };

  test('un archivo que falla no deja sin bajar el resto, y se anota', () async {
    final broken = await addStill('/no/existe/1.png');
    final good = await addStill('/no/existe/2.png');
    final cloud = _FakeCloud([
      asset(broken, 'https://res.cloudinary.com/x/rota'),
      asset(good, 'https://res.cloudinary.com/x/buena'),
    ], dir);

    final downloaded = await MediaHydrateService(
      db,
      cloud,
    ).hydrateProject(projectId, 'cloud-1');

    expect(downloaded, 1);
    final log = await (await ErrorLog.file()).readAsString();
    expect(log, contains('sin red'));
  });

  test('lo recién bajado no vuelve a subirse', () async {
    final uid = await addStill('/no/existe/1.png');
    final cloud = _FakeCloud([
      asset(uid, 'https://res.cloudinary.com/x/buena'),
    ], dir);
    await MediaHydrateService(db, cloud).hydrateProject(projectId, 'cloud-1');

    final queue = MediaUploadQueue(db: db, cloud: cloud, isEnabled: () => true);
    await queue.scanAndEnqueueProject(projectId);
    await queue.startWorker();

    expect(cloud.uploads, isEmpty);
  });

  Map<String, dynamic> versioned(String uid, String hash) => {
    ...asset(uid, 'https://res.cloudinary.com/x/v$hash'),
    'content_hash': hash.padRight(64, '0'),
  };

  test(
    'un boceto redibujado encima del mismo archivo se vuelve a subir',
    () async {
      final uid = await addStill('/no/existe/1.png');
      final cloud = _FakeCloud([versioned(uid, 'aaaaaaaa')], dir);
      await MediaHydrateService(db, cloud).hydrateProject(projectId, 'cloud-1');
      final still = await db.select(db.moodboardImages).getSingle();

      // Se dibuja encima: misma ruta, otro contenido y otra fecha.
      await Future<void>.delayed(const Duration(milliseconds: 20));
      File(still.imagePath).writeAsBytesSync([7, 7, 7, 7]);
      final queue = MediaUploadQueue(
        db: db,
        cloud: cloud,
        isEnabled: () => true,
      );
      await queue.scanAndEnqueueProject(projectId);
      await queue.startWorker();

      expect(cloud.uploads, ['uid:$uid']);
    },
  );

  test('una versión nueva en la nube se baja con otro nombre', () async {
    final uid = await addStill('/no/existe/1.png');
    await MediaHydrateService(
      db,
      _FakeCloud([versioned(uid, 'aaaaaaaa')], dir),
    ).hydrateProject(projectId, 'cloud-1');
    final first = (await db.select(db.moodboardImages).getSingle()).imagePath;

    await MediaHydrateService(
      db,
      _FakeCloud([versioned(uid, 'bbbbbbbb')], dir),
    ).hydrateProject(projectId, 'cloud-1');
    final second = (await db.select(db.moodboardImages).getSingle()).imagePath;

    expect(second, isNot(first));
    expect(second, contains('bbbbbbbb'));
    expect(File(first).existsSync(), isFalse);
  });

  test(
    'si aquí se tocó el archivo, la versión de la nube no lo pisa',
    () async {
      final uid = await addStill('/no/existe/1.png');
      await MediaHydrateService(
        db,
        _FakeCloud([versioned(uid, 'aaaaaaaa')], dir),
      ).hydrateProject(projectId, 'cloud-1');
      final local = (await db.select(db.moodboardImages).getSingle()).imagePath;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      File(local).writeAsBytesSync([5, 5, 5]);

      await MediaHydrateService(
        db,
        _FakeCloud([versioned(uid, 'bbbbbbbb')], dir),
      ).hydrateProject(projectId, 'cloud-1');

      expect(
        (await db.select(db.moodboardImages).getSingle()).imagePath,
        local,
      );
      expect(File(local).readAsBytesSync(), [5, 5, 5]);
    },
  );
}
