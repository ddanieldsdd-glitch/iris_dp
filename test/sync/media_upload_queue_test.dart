import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/cloud_media_service.dart';
import 'package:iris_dp/core/sync/media_upload_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Cloudinary simulado: falla las primeras [failures] subidas de cada clave.
class _FakeCloud extends CloudMediaService {
  _FakeCloud({this.failures = 0})
    : super(SupabaseClient('http://127.0.0.1:9', 'clave'));

  final int failures;
  final attempts = <String, int>{};

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
    final n = attempts[entityKey] = (attempts[entityKey] ?? 0) + 1;
    if (n <= failures) throw StateError('sin red');
    return CloudUploadResult(
      publicId: publicId,
      deliveryUrl: 'https://res.cloudinary.com/x/$publicId',
      bytesOriginal: 10,
      bytesStored: 5,
      contentHash: 'h',
    );
  }
}

void main() {
  late AppDatabase db;
  late int projectId;
  late String imagePath;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'iris_cloud_workspace_id': 'ws-1',
    });
    MediaUploadQueue.retryDelay = Duration.zero;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'lala', cloudId: const Value('cloud-1')),
    );
    final dir = Directory.systemTemp.createTempSync('iris_queue_test');
    addTearDown(() => dir.deleteSync(recursive: true));
    imagePath = '${dir.path}/still.png';
    File(imagePath).writeAsBytesSync([1, 2, 3]);
  });

  MediaUploadQueue queueWith(CloudMediaService cloud) =>
      MediaUploadQueue(db: db, cloud: cloud, isEnabled: () => true);

  Future<List<PendingMediaUpload>> rows() =>
      db.select(db.pendingMediaUploads).get();

  Future<bool> enqueue(MediaUploadQueue queue) => queue.enqueue(
    projectId: projectId,
    projectCloudId: 'cloud-1',
    entityType: 'moodboard',
    entityKey: 'moodboard:ungrouped:0',
    localPath: imagePath,
    sortOrder: 0,
    publicId: 'ws-1/cloud-1/still',
  );

  test('una subida cortada a medias vuelve a la cola al arrancar', () async {
    await db
        .into(db.pendingMediaUploads)
        .insert(
          PendingMediaUploadsCompanion.insert(
            projectId: projectId,
            projectCloudId: const Value('cloud-1'),
            entityType: 'moodboard',
            entityKey: 'moodboard:ungrouped:0',
            localPath: imagePath,
            publicId: const Value('ws-1/cloud-1/still'),
            status: const Value('processing'),
          ),
        );

    await queueWith(_FakeCloud()).startWorker();

    expect((await rows()).single.status, 'done');
  });

  test('tras fallar del todo, volver a encolar reutiliza la fila', () async {
    final cloud = _FakeCloud(failures: MediaUploadQueue.maxRetries);
    final queue = queueWith(cloud);
    await enqueue(queue);
    await queue.startWorker();
    expect((await rows()).single.status, 'failed');

    // Antes: se creaba otra fila y la siguiente vez rompía con
    // «too many elements».
    await enqueue(queue);
    await queue.startWorker();
    await enqueue(queue);
    await queue.startWorker();

    final all = await rows();
    expect(all, hasLength(1));
    expect(all.single.status, 'done');
  });

  test('las fallidas se pueden reintentar', () async {
    final queue = queueWith(_FakeCloud(failures: MediaUploadQueue.maxRetries));
    await enqueue(queue);
    await queue.startWorker();
    expect((await rows()).single.status, 'failed');

    expect(await queue.retryFailed(), 1);
    await queue.startWorker();

    expect((await rows()).single.status, 'done');
  });

  test('el progreso cuenta pendientes, subidas y fallidas', () async {
    final queue = queueWith(_FakeCloud(failures: MediaUploadQueue.maxRetries));
    final progress = <MediaUploadQueueProgress>[];
    final sub = queue.progressStream.listen(progress.add);
    addTearDown(sub.cancel);

    await enqueue(queue);
    await queue.startWorker();
    await Future<void>.delayed(Duration.zero);

    expect(progress.last.failed, 1);
    expect(progress.last.pending, 0);
    expect(progress.last.hasWork, isFalse);
  });

  test('una imagen ya subida no se vuelve a subir en cada sincronización', () async {
    final cloud = _FakeCloud();
    final queue = queueWith(cloud);
    expect(await enqueue(queue), isTrue);
    await queue.startWorker();

    expect(await enqueue(queue), isFalse);
    await queue.startWorker();

    expect(cloud.attempts['moodboard:ungrouped:0'], 1);
    expect((await rows()).single.status, 'done');
  });

  test('si el archivo cambia, se sube de nuevo', () async {
    final cloud = _FakeCloud();
    final queue = queueWith(cloud);
    await enqueue(queue);
    await queue.startWorker();

    final other = '${File(imagePath).parent.path}/otro.png';
    File(other).writeAsBytesSync([4, 5, 6]);
    final queued = await queue.enqueue(
      projectId: projectId,
      projectCloudId: 'cloud-1',
      entityType: 'moodboard',
      entityKey: 'moodboard:ungrouped:0',
      localPath: other,
      sortOrder: 0,
      publicId: 'ws-1/cloud-1/still',
    );
    await queue.startWorker();

    expect(queued, isTrue);
    expect(cloud.attempts['moodboard:ungrouped:0'], 2);
  });
}
