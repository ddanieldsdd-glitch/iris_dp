import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' show Value, OrderingTerm;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/cloud_session.dart';
import '../cloud/cloudinary_config.dart';
import '../database/app_database.dart';
import 'cloud_media_service.dart';
import 'cloudinary_public_id.dart';
import 'media_entity_keys.dart';
import 'media_entity_types.dart';

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
  })  : _db = db,
        _cloud = cloud;

  final AppDatabase _db;
  final CloudMediaService _cloud;

  static const maxConcurrency = 3;
  static const maxRetries = 5;

  bool _running = false;
  int _bytesSavedSession = 0;
  final _progressController =
      StreamController<MediaUploadQueueProgress>.broadcast();

  Stream<MediaUploadQueueProgress> get progressStream =>
      _progressController.stream;

  MediaUploadQueueProgress _currentProgress({bool processing = false}) {
    // Counts computed synchronously from DB in notifyProgress
    return MediaUploadQueueProgress(
      bytesSaved: _bytesSavedSession,
      isProcessing: processing,
    );
  }

  Future<void> notifyProgress({bool processing = false}) async {
    final pending = await (_db.select(_db.pendingMediaUploads)
          ..where((t) => t.status.equals('pending')))
        .get();
    final done = await (_db.select(_db.pendingMediaUploads)
          ..where((t) => t.status.equals('done')))
        .get();
    final failed = await (_db.select(_db.pendingMediaUploads)
          ..where((t) => t.status.equals('failed')))
        .get();
    _progressController.add(MediaUploadQueueProgress(
      pending: pending.length,
      completed: done.length,
      failed: failed.length,
      total: pending.length + done.length + failed.length,
      bytesSaved: _bytesSavedSession,
      isProcessing: processing,
    ));
  }

  Future<void> enqueue({
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
    if (!CloudinaryConfig.isConfigured) return;
    if (!File(localPath).existsSync()) return;

    final existing = await (_db.select(_db.pendingMediaUploads)
          ..where(
            (t) =>
                t.projectId.equals(projectId) &
                t.entityType.equals(entityType) &
                t.entityKey.equals(entityKey),
          ))
        .getSingleOrNull();

    if (existing != null && existing.status != 'failed') {
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
      ));
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
            ),
          );
    }

    await notifyProgress();
    unawaited(startWorker());
  }

  Future<void> startWorker() async {
    if (_running || !CloudinaryConfig.isConfigured) return;
    _running = true;
    await notifyProgress(processing: true);

    try {
      while (true) {
        final batch = await (_db.select(_db.pendingMediaUploads)
              ..where((t) => t.status.equals('pending'))
              ..orderBy([
                (t) => OrderingTerm.desc(t.priority),
                (t) => OrderingTerm.asc(t.sortOrder),
                (t) => OrderingTerm.asc(t.id),
              ])
              ..limit(maxConcurrency))
            .get();

        if (batch.isEmpty) break;

        await Future.wait(batch.map(_processOne));
        await notifyProgress(processing: true);
      }
    } finally {
      _running = false;
      await notifyProgress();
    }
  }

  Future<void> _processOne(PendingMediaUpload row) async {
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

      final result = await _cloud.uploadFile(
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
      ));
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
        await Future<void>.delayed(Duration(seconds: 1 << retries.clamp(0, 4)));
      }
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
    if (!CloudinaryConfig.isConfigured) return 0;

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
      final entityKey =
          MediaEntityKeys.moodboard(groupKey: groupKey, sortOrder: img.sortOrder);
      final publicId = group != null
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

      await enqueue(
        projectId: projectId,
        projectCloudId: cloudId,
        entityType: MediaEntityType.moodboard,
        entityKey: entityKey,
        localPath: img.imagePath,
        sortOrder: img.sortOrder,
        publicId: publicId,
        source: MediaIngestSource.sync,
      );
      count++;
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
      final shotKey = 'scene:${scene.number}:${shot.number}';
      final refs = await (_db.select(_db.shotReferences)
            ..where((r) => r.shotId.equals(shot.id))
            ..orderBy([(r) => OrderingTerm.asc(r.sortOrder)]))
          .get();

      for (final ref in refs) {
        if (!File(ref.imagePath).existsSync()) continue;
        await enqueue(
          projectId: projectId,
          projectCloudId: cloudId,
          entityType: MediaEntityType.shotReference,
          entityKey: MediaEntityKeys.shotReference(
            shotKey: shotKey,
            sortOrder: ref.sortOrder,
          ),
          localPath: ref.imagePath,
          sortOrder: ref.sortOrder,
          publicId: CloudinaryPublicId.shotReference(
            workspaceId: workspaceId,
            projectCloudId: cloudId,
            sceneNumber: scene.number,
            shotNumber: shot.number,
            refSortOrder: ref.sortOrder,
          ),
          source: MediaIngestSource.sync,
        );
        count++;
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
        await enqueue(
          projectId: projectId,
          projectCloudId: cloudId,
          entityType: MediaEntityType.site,
          entityKey: MediaEntityKeys.siteImage(
            siteKey: siteKey,
            sortOrder: img.sortOrder,
          ),
          localPath: img.imagePath,
          sortOrder: img.sortOrder,
          publicId: CloudinaryPublicId.siteImage(
            workspaceId: workspaceId,
            projectCloudId: cloudId,
            siteSortOrder: site.sortOrder,
            siteName: site.name,
            imageSortOrder: img.sortOrder,
          ),
          source: MediaIngestSource.sync,
        );
        count++;
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
        await enqueue(
          projectId: projectId,
          projectCloudId: cloudId,
          entityType: MediaEntityType.location,
          entityKey: MediaEntityKeys.locationImage(
            setKey: setKey,
            sortOrder: img.sortOrder,
          ),
          localPath: img.imagePath,
          sortOrder: img.sortOrder,
          publicId: CloudinaryPublicId.locationImage(
            workspaceId: workspaceId,
            projectCloudId: cloudId,
            setSortOrder: set.sortOrder,
            setName: set.locationName,
            imageSortOrder: img.sortOrder,
          ),
          source: MediaIngestSource.sync,
        );
        count++;
      }
    }

    // Project cover
    if (project.coverImagePath != null &&
        File(project.coverImagePath!).existsSync()) {
      await enqueue(
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
      );
      count++;
    }

    unawaited(startWorker());
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
}
