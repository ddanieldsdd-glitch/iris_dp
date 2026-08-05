import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import '../cloud/cloudinary_config.dart';
import '../database/database_provider.dart';
import 'cloud_media_service.dart';
import 'media_hydrate_service.dart';
import 'media_ingest_service.dart';
import 'media_upload_queue.dart';

final cloudMediaServiceProvider = Provider<CloudMediaService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null || !CloudinaryConfig.isConfigured) return null;
  return CloudMediaService(client);
});

final mediaUploadQueueProvider = Provider<MediaUploadQueue?>((ref) {
  final cloud = ref.watch(cloudMediaServiceProvider);
  if (cloud == null) return null;
  final db = ref.watch(databaseProvider);
  final queue = MediaUploadQueue(db: db, cloud: cloud);
  ref.onDispose(queue.dispose);
  return queue;
});

final mediaHydrateServiceProvider = Provider<MediaHydrateService?>((ref) {
  final cloud = ref.watch(cloudMediaServiceProvider);
  if (cloud == null) return null;
  return MediaHydrateService(ref.watch(databaseProvider), cloud);
});

final mediaIngestServiceProvider = Provider<MediaIngestService?>((ref) {
  final queue = ref.watch(mediaUploadQueueProvider);
  if (queue == null) return null;
  return MediaIngestService(
    db: ref.watch(databaseProvider),
    uploadQueue: queue,
  );
});

final mediaUploadProgressProvider = StreamProvider<MediaUploadQueueProgress>((ref) {
  final queue = ref.watch(mediaUploadQueueProvider);
  if (queue == null) {
    return Stream.value(const MediaUploadQueueProgress());
  }
  return queue.progressStream;
});

final mediaUploadHasWorkProvider = Provider<bool>((ref) {
  final progress = ref.watch(mediaUploadProgressProvider);
  return progress.maybeWhen(
    data: (p) => p.hasWork,
    orElse: () => false,
  );
});
