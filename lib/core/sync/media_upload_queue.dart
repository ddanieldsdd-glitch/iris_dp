import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';

import '../cloud/cloud_session.dart';
import '../cloud/cloudinary_config.dart';
import '../database/app_database.dart';
import 'cloud_media_service.dart';
import 'cloudinary_public_id.dart';
import 'media_entity_keys.dart';
import 'media_entity_types.dart';
import 'media_file_stamp.dart';
import 'media_slots.dart';

/// Progreso global de la cola de subidas.
class MediaUploadQueueProgress {
  final int pending;
  final int completed;
  final int failed;
  final int total;
  final int bytesSaved;
  final bool isProcessing;

  const MediaUploadQueueProgress({
    this.pending = 0,
    this.completed = 0,
    this.failed = 0,
    this.total = 0,
    this.bytesSaved = 0,
    this.isProcessing = false,
  });

  bool get hasWork => pending > 0 || isProcessing;
}

/// Cola persistente con worker en background (máx. 3 uploads paralelos).
class MediaUploadQueue {
  MediaUploadQueue({
    required AppDatabase db,
    required CloudMediaService cloud,
    @visibleForTesting bool Function()? isEnabled,
  })  : _db = db,
        _cloud = cloud,
        _isEnabled = isEnabled ?? (() => CloudinaryConfig.isConfigured);

  final AppDatabase _db;
  final CloudMediaService _cloud;
  final bool Function() _isEnabled;

  static const maxConcurrency = 3;
  static const maxRetries = 5;

  /// Se llama al terminar cada tanda con los proyectos (`cloudId`) que
  /// subieron algo: el canal en vivo avisa a los demás equipos para que las
  /// bajen ya (ver [AutoSyncScheduler]).
  static void Function(String projectCloudId)? onProjectUploaded;

  /// Cada cuánto se avisa como mínimo mientras dura una subida larga.
  static const _announceEvery = Duration(seconds: 10);

  /// La pasada del worker en curso, si hay una.
  Future<void>? _run;

  /// Espera antes de reintentar: se dobla en cada fallo.
  @visibleForTesting
  static Duration retryDelay = const Duration(seconds: 1);

  /// Cuándo puede reintentarse cada fila que falló (por id).
  final _notBefore = <int, DateTime>{};
  int _bytesSavedSession = 0;
  final _progressController =
      StreamController<MediaUploadQueueProgress>.broadcast();

  Stream<MediaUploadQueueProgress> get progressStream =>
      _progressController.stream;

  Future<int> _count(String status) async {
    final count = _db.pendingMediaUploads.id.count();
    final row = await (_db.selectOnly(_db.pendingMediaUploads)
          ..addColumns([count])
          ..where(_db.pendingMediaUploads.status.equals(status)))
        .getSingle();
    return row.read(count) ?? 0;
  }

  Future<void> notifyProgress({bool processing = false}) async {
    if (_progressController.isClosed) return;
    final pending = await _count('pending') + await _count('processing');
    final done = await _count('done');
    final failed = await _count('failed');
    _progressController.add(MediaUploadQueueProgress(
      pending: pending,
      completed: done,
      failed: failed,
      total: pending + done + failed,
      bytesSaved: _bytesSavedSession,
      isProcessing: processing,
    ));
  }

  /// Pone una imagen en la cola. Devuelve si quedó en cola: una imagen ya
  /// subida desde el mismo archivo no se vuelve a subir.
  Future<bool> enqueue({
    required int projectId,
    String? projectCloudId,
    required String entityType,
    required String entityKey,
    required String localPath,
    required int sortOrder,
    String? publicId,
    int priority = 0,
    String? source,
  }) async {
    if (!_isEnabled()) return false;
    if (!File(localPath).existsSync()) return false;

    // Los trazos de un boceto viajan con su imagen, como archivo aparte.
    if (entityType != MediaEntityType.sketchStrokes) {
      final strokes = sketchStrokesPathOf(localPath);
      if (File(strokes).existsSync()) {
        await enqueue(
          projectId: projectId,
          projectCloudId: projectCloudId,
          entityType: MediaEntityType.sketchStrokes,
          entityKey: sketchStrokesKey(entityType, entityKey),
          localPath: strokes,
          sortOrder: sortOrder,
          source: source,
        );
      }
    }

    // Una fila por imagen: se reutiliza aunque fallara antes (y se quitan
    // los duplicados que dejaban versiones anteriores).
    final rows = await (_db.select(_db.pendingMediaUploads)
          ..where(
            (t) =>
                t.projectId.equals(projectId) &
                t.entityType.equals(entityType) &
                t.entityKey.equals(entityKey),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.id)]))
        .get();
    final existing = rows.isEmpty ? null : rows.first;
    if (rows.length > 1) {
      await (_db.delete(_db.pendingMediaUploads)
            ..where((t) => t.id.isIn(rows.skip(1).map((r) => r.id))))
          .go();
    }

    // Ya subida desde este mismo archivo y sin cambios: cada sincronización
    // vuelve a recorrer las imágenes. Si el archivo cambió (un boceto
    // redibujado encima conserva la ruta), se vuelve a subir.
    final stamp = mediaFileStamp(localPath);
    if (existing != null &&
        existing.status == 'done' &&
        existing.localPath == localPath) {
      if (existing.fileStamp == stamp) return false;
      // Filas de antes de los sellos: el archivo cuenta como cambiado solo si
      // se modificó después de subirse o bajarse (un boceto redibujado).
      if (existing.fileStamp == null &&
          !File(localPath).statSync().modified.isAfter(
            existing.createdAt.add(const Duration(seconds: 2)),
          )) {
        await (_db.update(_db.pendingMediaUploads)
              ..where((t) => t.id.equals(existing.id)))
            .write(PendingMediaUploadsCompanion(fileStamp: Value(stamp)));
        return false;
      }
    }

    if (existing != null) {
      await (_db.update(_db.pendingMediaUploads)
            ..where((t) => t.id.equals(existing.id)))
          .write(PendingMediaUploadsCompanion(
        localPath: Value(localPath),
        sortOrder: Value(sortOrder),
        publicId: Value(publicId),
        priority: Value(priority),
        projectCloudId: Value(projectCloudId),
        source: Value(source),
        status: const Value('pending'),
        retries: const Value(0),
        lastError: const Value(null),
        fileStamp: Value(stamp),
      ));
      _notBefore.remove(existing.id);
    } else {
      await _db.into(_db.pendingMediaUploads).insert(
            PendingMediaUploadsCompanion.insert(
              projectId: projectId,
              projectCloudId: Value(projectCloudId),
              entityType: entityType,
              entityKey: entityKey,
              localPath: localPath,
              publicId: Value(publicId),
              sortOrder: Value(sortOrder),
              priority: Value(priority),
              source: Value(source),
              fileStamp: Value(stamp),
            ),
          );
    }

    await notifyProgress();
    unawaited(startWorker());
    return true;
  }

  /// Quita las filas de proyectos que ya no existen: la nube rechaza sus
  /// imágenes y reintentarlas no sirve de nada.
  Future<int> dropOrphans() => _db.customUpdate(
    'DELETE FROM pending_media_uploads '
    'WHERE project_id NOT IN (SELECT id FROM projects)',
    updates: {_db.pendingMediaUploads},
    updateKind: UpdateKind.delete,
  );

  /// Vuelve a poner en cola las subidas que fallaron del todo.
  Future<int> retryFailed() async {
    await dropOrphans();
    final count = await (_db.update(_db.pendingMediaUploads)
          ..where((t) => t.status.equals('failed')))
        .write(const PendingMediaUploadsCompanion(
      status: Value('pending'),
      retries: Value(0),
      lastError: Value(null),
    ));
    await notifyProgress();
    unawaited(startWorker());
    return count;
  }

  /// Arranca el worker, o devuelve la pasada en curso: al completarse, la
  /// cola está vacía o solo quedan fallidas.
  Future<void> startWorker() {
    if (!_isEnabled()) return Future.value();
    return _run ??= _work().whenComplete(() => _run = null);
  }

  Future<void> _work() async {
    await notifyProgress(processing: true);

    try {
      // Solo hay un worker: lo que esté «subiendo» al arrancar se cortó (la
      // app se cerró a medias) y vuelve a la cola.
      await (_db.update(_db.pendingMediaUploads)
            ..where((t) => t.status.equals('processing')))
          .write(const PendingMediaUploadsCompanion(status: Value('pending')));
      await dropOrphans();

      final uploaded = <String>{};
      var lastAnnounce = DateTime.now();
      void announce() {
        if (uploaded.isNotEmpty) {
          debugPrint('[medios ${_now()}] aviso a los demás: $uploaded');
        }
        final notify = onProjectUploaded;
        if (notify != null) uploaded.forEach(notify);
        uploaded.clear();
        lastAnnounce = DateTime.now();
      }

      while (true) {
        final pending = await (_db.select(_db.pendingMediaUploads)
              ..where((t) => t.status.equals('pending'))
              ..orderBy([
                (t) => OrderingTerm.desc(t.priority),
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();
        if (pending.isEmpty) {
          announce();
          break;
        }

        // Las que esperan su reintento no frenan a las demás.
        final now = DateTime.now();
        final ready = pending
            .where((r) => !(_notBefore[r.id]?.isAfter(now) ?? false))
            .take(maxConcurrency)
            .toList();
        if (ready.isEmpty) {
          final next = pending
              .map((r) => _notBefore[r.id]!)
              .reduce((a, b) => a.isBefore(b) ? a : b);
          await Future<void>.delayed(next.difference(now));
          continue;
        }

        for (final cloudId in await Future.wait(ready.map(_processOne))) {
          if (cloudId != null) uploaded.add(cloudId);
        }
        // En una subida larga los demás equipos van bajando lo que ya está.
        if (DateTime.now().difference(lastAnnounce) > _announceEvery) {
          announce();
        }
        await notifyProgress(processing: true);
      }
    } finally {
      await notifyProgress();
    }
  }

  static String _now() => DateTime.now().toIso8601String().substring(11, 23);

  /// Sube una fila. Devuelve el `cloudId` de su proyecto si se subió.
  Future<String?> _processOne(PendingMediaUpload row) async {
    await (_db.update(_db.pendingMediaUploads)
          ..where((t) => t.id.equals(row.id)))
        .write(const PendingMediaUploadsCompanion(
      status: Value('processing'),
    ));

    try {
      var cloudId = row.projectCloudId;
      if (cloudId == null || cloudId.isEmpty) {
        final project = await _db.getProject(row.projectId);
        cloudId = project?.cloudId;
      }
      if (cloudId == null || cloudId.isEmpty) {
        throw StateError('Proyecto sin cloudId');
      }

      final workspaceId = await CloudSessionStore.workspaceId();
      if (workspaceId == null) {
        throw StateError('Sin workspace');
      }

      final publicId = row.publicId ??
          _fallbackPublicId(
            workspaceId: workspaceId,
            projectCloudId: cloudId,
            entityType: row.entityType,
            entityKey: row.entityKey,
            sortOrder: row.sortOrder,
          );

      debugPrint('[medios ${_now()}] subiendo ${row.entityType} ${row.entityKey}');
      final slot = mediaSlotFor(row.entityType);
      final isFile =
          slot?.kind == MediaKind.file ||
          row.entityType == MediaEntityType.sketchStrokes ||
          row.entityType == MediaEntityType.unrealThumb;
      final result = isFile
          ? await _cloud.uploadRawFile(
              localPath: row.localPath,
              projectCloudId: cloudId,
              entityType: row.entityType,
              entityKey: row.entityKey,
              sortOrder: row.sortOrder,
              maxBytes: MediaSlot.maxFileBytes,
              source: row.source,
            )
          : await _cloud.uploadFile(
              localPath: row.localPath,
              publicId: publicId,
              projectCloudId: cloudId,
              entityType: row.entityType,
              entityKey: row.entityKey,
              sortOrder: row.sortOrder,
              source: row.source,
            );

      if (result == null) {
        throw StateError('Upload devolvió null');
      }

      _bytesSavedSession += result.bytesOriginal - result.bytesStored;

      await (_db.update(_db.pendingMediaUploads)
            ..where((t) => t.id.equals(row.id)))
          .write(PendingMediaUploadsCompanion(
        status: const Value('done'),
        projectCloudId: Value(cloudId),
        publicId: Value(result.publicId),
        lastError: const Value(null),
        remoteHash: Value(result.contentHash),
        fileStamp: Value(mediaFileStamp(row.localPath)),
      ));
      debugPrint('[medios ${_now()}] subida ${row.entityType} ${row.entityKey}');
      return cloudId;
    } catch (e, st) {
      debugPrint('MediaUploadQueue error: $e\n$st');
      final retries = row.retries + 1;
      final status = retries >= maxRetries ? 'failed' : 'pending';
      await (_db.update(_db.pendingMediaUploads)
            ..where((t) => t.id.equals(row.id)))
          .write(PendingMediaUploadsCompanion(
        status: Value(status),
        retries: Value(retries),
        lastError: Value(e.toString()),
      ));
      if (status == 'pending') {
        _notBefore[row.id] = DateTime.now().add(
          retryDelay * (1 << retries.clamp(0, 4)),
        );
      }
      return null;
    }
  }

  String _fallbackPublicId({
    required String workspaceId,
    required String projectCloudId,
    required String entityType,
    required String entityKey,
    required int sortOrder,
  }) {
    final safeKey = entityKey.replaceAll(':', '_').replaceAll('/', '_');
    return CloudinaryPublicId.build(
      workspaceId: workspaceId,
      projectCloudId: projectCloudId,
      category: entityType,
      contextPath: safeKey,
      sortOrder: sortOrder,
    );
  }

  /// Escanea un proyecto y encola imágenes locales pendientes.
  Future<int> scanAndEnqueueProject(int projectId) async {
    if (!_isEnabled()) return 0;

    final project = await _db.getProject(projectId);
    if (project == null) return 0;
    final cloudId = project.cloudId;
    if (cloudId == null) return 0;

    final workspaceId = await CloudSessionStore.workspaceId();
    if (workspaceId == null) return 0;

    var count = 0;

    // Moodboard groups + images
    final groups = await (_db.select(_db.moodboardGroups)
          ..where((g) => g.projectId.equals(projectId))
          ..orderBy([(g) => OrderingTerm.asc(g.sortOrder)]))
        .get();
    final groupById = {for (final g in groups) g.id: g};
    final groupKeyById = {
      for (final g in groups) g.id: 'mbg:${g.sortOrder}:${g.name}',
    };

    final moodImages = await (_db.select(_db.moodboardImages)
          ..where((m) => m.projectId.equals(projectId))
          ..orderBy([(m) => OrderingTerm.asc(m.sortOrder)]))
        .get();

    for (final img in moodImages) {
      if (!File(img.imagePath).existsSync()) continue;
      final group = img.groupId != null ? groupById[img.groupId!] : null;
      final groupKey = img.groupId != null ? groupKeyById[img.groupId!] : null;
      final entityKey = MediaEntityKeys.forImage(
        img.uid,
        () => MediaEntityKeys.moodboard(
          groupKey: groupKey,
          sortOrder: img.sortOrder,
        ),
      );
      final publicId = img.uid != null
          ? CloudinaryPublicId.byUid(
              workspaceId: workspaceId,
              projectCloudId: cloudId,
              category: MediaEntityType.moodboard,
              uid: img.uid!,
            )
          : group != null
          ? CloudinaryPublicId.moodboard(
              workspaceId: workspaceId,
              projectCloudId: cloudId,
              groupSortOrder: group.sortOrder,
              groupName: group.name,
              imageSortOrder: img.sortOrder,
            )
          : CloudinaryPublicId.build(
              workspaceId: workspaceId,
              projectCloudId: cloudId,
              category: MediaEntityType.moodboard,
              contextPath: 'ungrouped',
              sortOrder: img.sortOrder,
            );

      if (await enqueue(
        projectId: projectId,
        projectCloudId: cloudId,
        entityType: MediaEntityType.moodboard,
        entityKey: entityKey,
        localPath: img.imagePath,
        sortOrder: img.sortOrder,
        publicId: publicId,
        source: MediaIngestSource.sync,
      )) {
        count++;
      }
    }

    // Shot references
    final shots = await (_db.select(_db.shots)
          ..where((s) => s.projectId.equals(projectId)))
        .get();
    final scenes = await (_db.select(_db.scenes)
          ..where((s) => s.projectId.equals(projectId)))
        .get();
    final sceneById = {for (final s in scenes) s.id: s};

    for (final shot in shots) {
      final scene = sceneById[shot.sceneId];
      if (scene == null) continue;
      final shotKey =
          'scene:${scene.number}${scene.numberSuffix ?? ''}:${shot.number}';
      final refs = await (_db.select(_db.shotReferences)
            ..where((r) => r.shotId.equals(shot.id))
            ..orderBy([(r) => OrderingTerm.asc(r.sortOrder)]))
          .get();

      for (final ref in refs) {
        if (!File(ref.imagePath).existsSync()) continue;
        if (await enqueue(
          projectId: projectId,
          projectCloudId: cloudId,
          entityType: MediaEntityType.shotReference,
          entityKey: MediaEntityKeys.forImage(
            ref.uid,
            () => MediaEntityKeys.shotReference(
              shotKey: shotKey,
              sortOrder: ref.sortOrder,
            ),
          ),
          localPath: ref.imagePath,
          sortOrder: ref.sortOrder,
          publicId: ref.uid != null
              ? CloudinaryPublicId.byUid(
                  workspaceId: workspaceId,
                  projectCloudId: cloudId,
                  category: MediaEntityType.shotReference,
                  uid: ref.uid!,
                )
              : CloudinaryPublicId.shotReference(
            workspaceId: workspaceId,
            projectCloudId: cloudId,
            sceneNumber: scene.number,
            shotNumber: shot.number,
            refSortOrder: ref.sortOrder,
          ),
          source: MediaIngestSource.sync,
        )) {
          count++;
        }
      }
    }

    // Site images
    final sites = await (_db.select(_db.locationSites)
          ..where((s) => s.projectId.equals(projectId))
          ..orderBy([(s) => OrderingTerm.asc(s.sortOrder)]))
        .get();
    for (final site in sites) {
      final siteKey = 'site:${site.sortOrder}:${site.name}';
      final imgs = await (_db.select(_db.siteImages)
            ..where((i) => i.siteId.equals(site.id))
            ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
          .get();
      for (final img in imgs) {
        if (!File(img.imagePath).existsSync()) continue;
        if (await enqueue(
          projectId: projectId,
          projectCloudId: cloudId,
          entityType: MediaEntityType.site,
          entityKey: MediaEntityKeys.forImage(
            img.uid,
            () => MediaEntityKeys.siteImage(
              siteKey: siteKey,
              sortOrder: img.sortOrder,
            ),
          ),
          localPath: img.imagePath,
          sortOrder: img.sortOrder,
          publicId: img.uid != null
              ? CloudinaryPublicId.byUid(
                  workspaceId: workspaceId,
                  projectCloudId: cloudId,
                  category: MediaEntityType.site,
                  uid: img.uid!,
                )
              : CloudinaryPublicId.siteImage(
            workspaceId: workspaceId,
            projectCloudId: cloudId,
            siteSortOrder: site.sortOrder,
            siteName: site.name,
            imageSortOrder: img.sortOrder,
          ),
          source: MediaIngestSource.sync,
        )) {
          count++;
        }
      }
    }

    // Location images
    final sets = await (_db.select(_db.locationBasePlans)
          ..where((l) => l.projectId.equals(projectId))
          ..orderBy([(l) => OrderingTerm.asc(l.sortOrder)]))
        .get();
    for (final set in sets) {
      final setKey = 'set:${set.sortOrder}:${set.locationName}';
      final imgs = await (_db.select(_db.locationImages)
            ..where((i) => i.locationId.equals(set.id))
            ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
          .get();
      for (final img in imgs) {
        if (!File(img.imagePath).existsSync()) continue;
        if (await enqueue(
          projectId: projectId,
          projectCloudId: cloudId,
          entityType: MediaEntityType.location,
          entityKey: MediaEntityKeys.forImage(
            img.uid,
            () => MediaEntityKeys.locationImage(
              setKey: setKey,
              sortOrder: img.sortOrder,
            ),
          ),
          localPath: img.imagePath,
          sortOrder: img.sortOrder,
          publicId: img.uid != null
              ? CloudinaryPublicId.byUid(
                  workspaceId: workspaceId,
                  projectCloudId: cloudId,
                  category: MediaEntityType.location,
                  uid: img.uid!,
                )
              : CloudinaryPublicId.locationImage(
            workspaceId: workspaceId,
            projectCloudId: cloudId,
            setSortOrder: set.sortOrder,
            setName: set.locationName,
            imageSortOrder: img.sortOrder,
          ),
          source: MediaIngestSource.sync,
        )) {
          count++;
        }
      }
    }

    // Project cover
    if (project.coverImagePath != null &&
        File(project.coverImagePath!).existsSync()) {
      if (await enqueue(
        projectId: projectId,
        projectCloudId: cloudId,
        entityType: MediaEntityType.projectCover,
        entityKey: MediaEntityKeys.projectCover,
        localPath: project.coverImagePath!,
        sortOrder: 0,
        publicId: CloudinaryPublicId.projectCover(
          workspaceId: workspaceId,
          projectCloudId: cloudId,
        ),
        source: MediaIngestSource.sync,
      )) {
        count++;
      }
    }

    unawaited(startWorker());
    count += await _enqueueSlots(projectId, cloudId, workspaceId);
    return count;
  }

  /// Pone en cola los archivos de los huecos del proyecto (storyboard,
  /// bocetos de luz, plantas de set, guion, PDF anotados…, ver [kMediaSlots]).
  Future<int> _enqueueSlots(
    int projectId,
    String cloudId,
    String workspaceId,
  ) async {
    var count = 0;
    for (final slot in kMediaSlots) {
      final rows = await _db
          .customSelect(
            slot.selectForProject,
            variables: [Variable.withInt(projectId)],
          )
          .get();
      for (final row in rows) {
        final uid = row.read<String?>('uid');
        final raw = row.read<String?>('path');
        if (uid == null || raw == null || raw.trim().isEmpty) continue;
        final paths = slot.isList ? decodeSlotPaths(raw) : [raw];
        for (var i = 0; i < paths.length; i++) {
          final path = paths[i];
          final file = File(path);
          if (!file.existsSync()) continue;
          // Más que el límite de Storage: no se sube (ni se reintenta).
          if (slot.kind == MediaKind.file &&
              file.lengthSync() > MediaSlot.maxFileBytes) {
            continue;
          }
          final key = mediaSlotKey(uid, slot.isList ? i : null);
          if (await enqueue(
            projectId: projectId,
            projectCloudId: cloudId,
            entityType: slot.entityType,
            entityKey: key,
            localPath: path,
            sortOrder: i,
            publicId: slot.kind == MediaKind.image
                ? CloudinaryPublicId.byUid(
                    workspaceId: workspaceId,
                    projectCloudId: cloudId,
                    category: slot.entityType,
                    uid: slot.isList ? '$uid-$i' : uid,
                  )
                : null,
            source: MediaIngestSource.sync,
          )) {
            count++;
          }
        }
      }
    }
    return count;
  }


  Future<void> scanAllProjects() async {
    final projects = await _db.watchProjects().first;
    for (final p in projects) {
      if (p.cloudId == null) continue;
      await scanAndEnqueueProject(p.id);
    }
  }

  void dispose() {
    _progressController.close();
  }

  int get bytesSavedSession => _bytesSavedSession;
}
