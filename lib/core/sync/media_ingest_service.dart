import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;

import '../cloud/cloudinary_config.dart';
import '../database/app_database.dart';
import '../utils/media_storage.dart';
import 'media_entity_types.dart';
import 'media_upload_queue.dart';

class MediaIngestContext {
  final int projectId;
  final String? projectCloudId;
  final String entityType;
  final String entityKey;
  final int sortOrder;
  final String subfolder;
  final String fileNamePrefix;
  final String source;
  final String? publicId;
  final int priority;

  const MediaIngestContext({
    required this.projectId,
    this.projectCloudId,
    required this.entityType,
    required this.entityKey,
    required this.sortOrder,
    required this.subfolder,
    this.fileNamePrefix = 'img',
    this.source = MediaIngestSource.paste,
    this.publicId,
    this.priority = 10,
  });
}

class MediaIngestResult {
  final String localPath;
  final bool queuedForUpload;

  const MediaIngestResult({
    required this.localPath,
    required this.queuedForUpload,
  });
}

/// Punto de entrada unificado: guardar local + encolar Cloudinary.
class MediaIngestService {
  MediaIngestService({
    required AppDatabase db,
    required MediaUploadQueue uploadQueue,
  })  : _db = db,
        _queue = uploadQueue;

  final AppDatabase _db;
  final MediaUploadQueue _queue;

  Future<MediaIngestResult> ingestBytes({
    required Uint8List bytes,
    required MediaIngestContext context,
    String extension = '.jpg',
  }) async {
    final path = await MediaStorage.writeProjectFileBytes(
      projectId: context.projectId,
      subfolder: context.subfolder,
      bytes: bytes,
      fileName:
          '${context.fileNamePrefix}_${DateTime.now().microsecondsSinceEpoch}$extension',
    );

    var queued = false;
    if (CloudinaryConfig.isConfigured) {
      await _queue.enqueue(
        projectId: context.projectId,
        projectCloudId: context.projectCloudId,
        entityType: context.entityType,
        entityKey: context.entityKey,
        localPath: path,
        sortOrder: context.sortOrder,
        publicId: context.publicId,
        priority: context.priority,
        source: context.source,
      );
      queued = true;
    }

    return MediaIngestResult(localPath: path, queuedForUpload: queued);
  }

  Future<void> enqueueExistingFile({
    required String localPath,
    required MediaIngestContext context,
  }) async {
    if (!CloudinaryConfig.isConfigured) return;
    await _queue.enqueue(
      projectId: context.projectId,
      projectCloudId: context.projectCloudId,
      entityType: context.entityType,
      entityKey: context.entityKey,
      localPath: localPath,
      sortOrder: context.sortOrder,
      publicId: context.publicId,
      priority: context.priority,
      source: context.source,
    );
  }
}
