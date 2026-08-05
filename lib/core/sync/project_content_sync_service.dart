import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import 'project_content_bundle.dart';

/// La tabla `cloud_project_snapshots` aún no está en Supabase (migración 007).
class SnapshotsTableMissing implements Exception {
  const SnapshotsTableMissing();
}

bool isMissingSnapshotsTable(Object error) {
  if (error is! PostgrestException) return false;
  return error.code == 'PGRST205' ||
      error.message.contains('cloud_project_snapshots');
}

/// Sube y descarga snapshots de contenido del proyecto en Supabase.
class ProjectContentSyncService {
  final AppDatabase _db;
  final SupabaseClient _client;

  ProjectContentSyncService(this._db, this._client);

  Future<void> upload(int localProjectId, String projectCloudId) async {
    final bundle = await ProjectContentBundle.export(_db, localProjectId);
    final hash = ProjectContentBundle.hashBundle(bundle);
    final summary = ProjectContentBundle.summarize(bundle);

    try {
      await _client.from('cloud_project_snapshots').upsert({
        'project_id': projectCloudId,
        'content': bundle,
        'content_hash': hash,
        'scene_count': summary.sceneCount,
        'shot_count': summary.shotCount,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      if (isMissingSnapshotsTable(e)) throw const SnapshotsTableMissing();
      rethrow;
    }

    final syncedAt = DateTime.now().toUtc();
    await (_db.update(_db.projects)
          ..where((p) => p.id.equals(localProjectId)))
        .write(ProjectsCompanion(
      contentSyncUpdatedAt: Value(syncedAt),
    ));
  }

  Future<bool> download(int localProjectId, String projectCloudId) async {
    Map<String, dynamic>? row;
    try {
      row = await _client
          .from('cloud_project_snapshots')
          .select()
          .eq('project_id', projectCloudId)
          .maybeSingle();
    } catch (e) {
      if (isMissingSnapshotsTable(e)) return false;
      rethrow;
    }

    if (row == null) return false;

    final content = row['content'];
    if (content is! Map) return false;

    await ProjectContentBundle.importBundle(
      _db,
      localProjectId,
      Map<String, dynamic>.from(content),
    );

    final cloudUpdated =
        DateTime.tryParse(row['updated_at'] as String? ?? '') ??
            DateTime.now();
    await (_db.update(_db.projects)
          ..where((p) => p.id.equals(localProjectId)))
        .write(ProjectsCompanion(
      contentSyncUpdatedAt: Value(cloudUpdated),
    ));
    return true;
  }

  Future<Map<String, dynamic>?> fetchSnapshotRow(String projectCloudId) async {
    try {
      final row = await _client
          .from('cloud_project_snapshots')
          .select()
          .eq('project_id', projectCloudId)
          .maybeSingle();
      if (row == null) return null;
      return Map<String, dynamic>.from(row);
    } catch (e) {
      if (isMissingSnapshotsTable(e)) return null;
      rethrow;
    }
  }

  Future<Map<String, Map<String, dynamic>>> fetchAllSnapshots(
    List<String> projectCloudIds,
  ) async {
    if (projectCloudIds.isEmpty) return {};
    try {
      final rows = await _client
          .from('cloud_project_snapshots')
          .select()
          .inFilter('project_id', projectCloudIds);
      return {
        for (final row in rows as List)
          row['project_id'] as String: Map<String, dynamic>.from(row),
      };
    } catch (e) {
      if (isMissingSnapshotsTable(e)) throw const SnapshotsTableMissing();
      rethrow;
    }
  }

  Future<void> deleteSnapshot(String projectCloudId) async {
    try {
      await _client
          .from('cloud_project_snapshots')
          .delete()
          .eq('project_id', projectCloudId);
    } catch (_) {}
  }
}

/// Cola offline de subidas de contenido pendientes.
class CloudSyncQueueService {
  final AppDatabase _db;
  final SupabaseClient? _client;

  CloudSyncQueueService(this._db, [this._client]);

  Future<void> enqueueContentUpload(int localProjectId, String cloudId) async {
    final pending = await (_db.select(_db.cloudSyncQueue)
          ..where((q) =>
              q.entityType.equals('project_content') &
              q.localEntityId.equals('$localProjectId') &
              q.processed.equals(false)))
        .get();
    if (pending.isNotEmpty) return;

    await _db.into(_db.cloudSyncQueue).insert(
          CloudSyncQueueCompanion.insert(
            entityType: 'project_content',
            localEntityId: '$localProjectId',
            operation: 'upsert',
            payloadJson: Value(jsonEncode({'cloudId': cloudId})),
          ),
        );
  }

  Future<int> processPending({SupabaseClient? client}) async {
    final supa = client ?? _client;
    if (supa == null) return 0;

    final sync = ProjectContentSyncService(_db, supa);
    final pending = await (_db.select(_db.cloudSyncQueue)
          ..where((q) => q.processed.equals(false))
          ..orderBy([(q) => OrderingTerm.asc(q.createdAt)]))
        .get();

    var processed = 0;
    for (final item in pending) {
      if (item.entityType != 'project_content') continue;
      try {
        final payload = item.payloadJson != null
            ? jsonDecode(item.payloadJson!) as Map<String, dynamic>
            : <String, dynamic>{};
        final cloudId = payload['cloudId'] as String?;
        final localId = int.tryParse(item.localEntityId);
        if (cloudId == null || localId == null) continue;

        await sync.upload(localId, cloudId);
        await (_db.update(_db.cloudSyncQueue)
              ..where((q) => q.id.equals(item.id)))
            .write(const CloudSyncQueueCompanion(processed: Value(true)));
        processed++;
      } catch (e) {
        if (e is SnapshotsTableMissing || isMissingSnapshotsTable(e)) {
          // Migración 007 pendiente en Supabase; se reintentará luego.
          break;
        }
        // Otros errores: se reintentará en el próximo sync.
      }
    }
    return processed;
  }
}
