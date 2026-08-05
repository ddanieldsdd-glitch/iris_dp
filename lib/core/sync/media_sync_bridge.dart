import '../database/app_database.dart';
import 'media_ingest_service.dart';
import 'media_upload_queue.dart';

/// Puente estático para encolar uploads desde helpers sin Riverpod.
abstract final class MediaSyncBridge {
  static MediaUploadQueue? uploadQueue;
  static MediaIngestService? ingest;

  static void bind({
    MediaUploadQueue? queue,
    MediaIngestService? ingestService,
  }) {
    uploadQueue = queue;
    ingest = ingestService;
  }

  static void clear() {
    uploadQueue = null;
    ingest = null;
  }

  static Future<void> enqueueMoodboardImage({
    required AppDatabase db,
    required int projectId,
    required int imageId,
  }) async {
    final queue = uploadQueue;
    if (queue == null) return;

    final img = await (db.select(db.moodboardImages)
          ..where((m) => m.id.equals(imageId)))
        .getSingleOrNull();
    if (img == null) return;

    final project = await db.getProject(projectId);
    final cloudId = project?.cloudId;
    if (cloudId == null) return;

    await queue.scanAndEnqueueProject(projectId);
  }
}
