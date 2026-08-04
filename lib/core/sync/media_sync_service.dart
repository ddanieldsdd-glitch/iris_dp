import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../cloud/supabase_config.dart';
import '../database/app_database.dart';
import '../utils/media_storage.dart';

enum MediaSyncStatus { localOnly, pending, synced, failed }

/// Sube imágenes locales a Supabase Storage y registra en `media_assets`.
class MediaSyncService {
  final SupabaseClient _client;
  final _uuid = const Uuid();

  MediaSyncService(this._client);

  static String storagePath(String projectCloudId, String fileName) =>
      'projects/$projectCloudId/moodboard/$fileName';

  Future<String?> uploadProjectFile({
    required String projectCloudId,
    required String localPath,
    String category = 'moodboard',
  }) async {
    if (!File(localPath).existsSync()) return null;

    final ext = localPath.contains('.')
        ? localPath.substring(localPath.lastIndexOf('.'))
        : '.jpg';
    final objectName = '${_uuid.v4()}$ext';
    final path = storagePath(projectCloudId, objectName);
    final bytes = await File(localPath).readAsBytes();

    await _client.storage.from(SupabaseConfig.storageBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    await _client.from('media_assets').insert({
      'project_id': projectCloudId,
      'storage_path': path,
      'category': category,
      'local_hash': localPath.hashCode.toString(),
    });

    return path;
  }

  /// Sincroniza imágenes de moodboard pendientes para un proyecto.
  Future<int> syncMoodboardForProject({
    required AppDatabase db,
    required int localProjectId,
    required String projectCloudId,
  }) async {
    final images = await (db.select(db.moodboardImages)
          ..where((m) => m.projectId.equals(localProjectId)))
        .get();

    var count = 0;
    for (final img in images) {
      if (!File(img.imagePath).existsSync()) continue;
      try {
        await uploadProjectFile(
          projectCloudId: projectCloudId,
          localPath: img.imagePath,
          category: img.category ?? 'reference',
        );
        count++;
      } catch (_) {
        // Cola para reintento posterior
      }
    }
    return count;
  }

  /// Descarga asset remoto al cache local del proyecto.
  Future<String?> downloadToCache({
    required int localProjectId,
    required String storagePath,
    required String fileName,
  }) async {
    final bytes = await _client.storage
        .from(SupabaseConfig.storageBucket)
        .download(storagePath);

    return MediaStorage.writeProjectFileBytes(
      projectId: localProjectId,
      bytes: bytes,
      subfolder: 'cloud_cache',
      fileName: fileName,
    );
  }
}
