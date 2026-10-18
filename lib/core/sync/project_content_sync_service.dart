import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../database/local_database_backup.dart';
import 'content_sync_base_store.dart';
import 'device_label.dart';
import 'sync_merge_store.dart';
import 'project_content_bundle.dart';

/// La tabla `cloud_project_snapshots` aún no está en Supabase (migración 007).
class SnapshotsTableMissing implements Exception {
  const SnapshotsTableMissing();
}

/// La nube ya no tiene la versión con la que se decidió subir: otro
/// dispositivo ha subido entretanto. No se sube; la próxima sincronización lo
/// presenta como conflicto.
class CloudContentChanged implements Exception {
  const CloudContentChanged();
}

/// La columna `updated_device` aún no está en Supabase (migración 011).
bool isMissingDeviceColumn(PostgrestException error) =>
    error.message.contains('updated_device');

/// Se deja de enviar `updated_device` al ver que falta la columna.
bool hasDeviceColumn = true;

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

  /// Tras cada subida: el canal en vivo lo avisa a los otros equipos (ver
  /// `RealtimeHub`). Sin canal, no hace nada.
  static Future<void> Function(String projectCloudId, String hash)? onUploaded;

  /// Sube el contenido local solo si la nube sigue en [expectedCloudHash], la
  /// huella que se vio al decidir subir (`null`: no había copia en la nube).
  /// Si ha cambiado, lanza [CloudContentChanged] y no escribe nada.
  Future<void> upload(
    int localProjectId,
    String projectCloudId, {
    required String? expectedCloudHash,
  }) async {
    final bundle = await ProjectContentBundle.export(_db, localProjectId);
    final hash = await uploadBundle(
      projectCloudId,
      bundle,
      expectedCloudHash: expectedCloudHash,
    );

    final syncedAt = DateTime.now().toUtc();
    await (_db.update(_db.projects)
          ..where((p) => p.id.equals(localProjectId)))
        .write(ProjectsCompanion(
      contentSyncUpdatedAt: Value(syncedAt),
    ));
    // Este dispositivo y la nube quedan iguales: punto de partida para
    // saber quién cambia después.
    await ContentSyncBaseStore.save(_db, localProjectId,
      ContentSyncBase(localHash: hash, cloudHash: hash),
    );
    // Lo subido es la base para mezclar la próxima vez.
    await ContentBaseBundleStore.save(
      _db,
      localProjectId,
      local: bundle,
      cloud: bundle,
    );
  }

  /// Escribe [bundle] en la nube con la misma condición que [upload], sin
  /// tocar nada de aquí. Devuelve su huella.
  Future<String> uploadBundle(
    String projectCloudId,
    Map<String, dynamic> bundle, {
    required String? expectedCloudHash,
  }) async {
    final hash = ProjectContentBundle.hashBundle(bundle);
    final summary = ProjectContentBundle.summarize(bundle);
    final row = {
      'project_id': projectCloudId,
      'content': bundle,
      'content_hash': hash,
      'scene_count': summary.sceneCount,
      'shot_count': summary.shotCount,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (hasDeviceColumn) 'updated_device': deviceLabel(),
    };

    try {
      await _write(projectCloudId, expectedCloudHash, row);
    } on PostgrestException catch (e) {
      // Supabase sin la migración 011: se sube igual, sin decir el equipo.
      if (!isMissingDeviceColumn(e)) rethrow;
      hasDeviceColumn = false;
      row.remove('updated_device');
      await _write(projectCloudId, expectedCloudHash, row);
    }
    unawaited(onUploaded?.call(projectCloudId, hash));
    return hash;
  }

  /// Inserta (no había copia) o actualiza solo si la nube sigue igual.
  Future<void> _write(
    String projectCloudId,
    String? expectedCloudHash,
    Map<String, dynamic> row,
  ) async {
    try {
      if (expectedCloudHash == null) {
        // Sin copia en la nube: si alguien la ha creado entretanto, el insert
        // choca con la clave y no se pisa.
        await _client.from('cloud_project_snapshots').insert(row);
      } else if (!await _updateIfUnchanged(
        projectCloudId,
        expectedCloudHash,
        row,
      )) {
        throw const CloudContentChanged();
      }
    } on PostgrestException catch (e) {
      // El aviso de columna que falta también nombra la tabla.
      if (isMissingDeviceColumn(e)) rethrow;
      if (isMissingSnapshotsTable(e)) throw const SnapshotsTableMissing();
      if (e.code == '23505') throw const CloudContentChanged();
      rethrow;
    }
  }

  /// Escribe [row] solo si la copia de la nube tiene la huella [expected].
  /// Devuelve si se escribió.
  Future<bool> _updateIfUnchanged(
    String projectCloudId,
    String expected,
    Map<String, dynamic> row,
  ) async {
    final updated = await _client
        .from('cloud_project_snapshots')
        .update(row)
        .eq('project_id', projectCloudId)
        .eq('content_hash', expected)
        .select('project_id');
    if (updated.isNotEmpty) return true;

    // Copias antiguas sin `content_hash`: la huella se calcula del contenido,
    // como hace el plan.
    final current = await fetchSnapshotRow(projectCloudId);
    if (current == null || current['content_hash'] != null) return false;
    final content = current['content'];
    if (content is! Map ||
        !ProjectContentBundle.bundleMatchesHash(
          Map<String, dynamic>.from(content),
          expected,
        )) {
      return false;
    }
    final legacy = await _client
        .from('cloud_project_snapshots')
        .update(row)
        .eq('project_id', projectCloudId)
        .isFilter('content_hash', null)
        .select('project_id');
    return legacy.isNotEmpty;
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

    final bundle = Map<String, dynamic>.from(content);
    if (!ProjectContentBundle.hasMeaningfulContent(bundle)) return false;

    // La descarga reemplaza el contenido local: antes se guarda una copia de
    // la base de datos por si hay que volver atrás.
    final local = await ProjectContentBundle.export(_db, localProjectId);
    if (ProjectContentBundle.hasMeaningfulContent(local)) {
      await LocalDatabaseBackup.create(_db, label: 'antes-de-descargar');
    }

    await ProjectContentBundle.importBundle(_db, localProjectId, bundle);
    final imported = await ProjectContentBundle.export(_db, localProjectId);
    await ContentSyncBaseStore.save(_db, localProjectId,
      ContentSyncBase(
        localHash: ProjectContentBundle.hashBundle(imported),
        cloudHash:
            row['content_hash'] as String? ??
            ProjectContentBundle.hashBundle(bundle),
      ),
    );
    await ContentBaseBundleStore.save(
      _db,
      localProjectId,
      local: imported,
      cloud: bundle,
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

        // Sin sincronización previa no se sabe quién tiene la buena: lo
        // decide el usuario en el plan.
        final base = await ContentSyncBaseStore.load(_db, localId);
        if (base == null) continue;
        final local = await ProjectContentBundle.export(_db, localId);
        if (!ProjectContentBundle.bundleMatchesHash(local, base.localHash)) {
          // Solo si la nube no ha cambiado desde entonces; si ha cambiado
          // es un conflicto y queda pendiente para revisarlo.
          await sync.upload(
            localId,
            cloudId,
            expectedCloudHash: base.cloudHash,
          );
        }
        await (_db.update(_db.cloudSyncQueue)
              ..where((q) => q.id.equals(item.id)))
            .write(const CloudSyncQueueCompanion(processed: Value(true)));
        processed++;
      } catch (e) {
        if (e is CloudContentChanged) continue;
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
