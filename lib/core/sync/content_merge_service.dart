import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../database/app_database.dart';
import '../database/local_database_backup.dart';
import 'bundle_merge.dart';
import 'content_sync_base_store.dart';
import 'device_label.dart';
import 'project_content_bundle.dart';
import 'project_content_sync_service.dart';
import 'sync_merge_store.dart';

class MergeOutcome {
  final int discarded;
  final int mine;

  const MergeOutcome({required this.discarded, required this.mine});
}

/// Resuelve sin preguntar un proyecto cambiado aquí y en la nube: mezcla lo
/// de los dos lados sobre la base, lo aplica aquí y sube el resultado.
class ContentMergeService {
  final AppDatabase _db;
  final SupabaseClient _client;

  ContentMergeService(this._db, this._client);

  /// Si otro equipo sube mientras se mezcla, se vuelve a mezclar con lo
  /// suyo, como mucho estas veces.
  static const maxAttempts = 3;

  /// Devuelve cuántas ediciones se descartaron ([MergeOutcome.mine]: de las
  /// de este equipo), o `null` si no se pudo mezclar (sin base guardada, o la
  /// nube no paraba de cambiar): entonces queda para revisarlo como antes.
  Future<MergeOutcome?> mergeAndSync(int localProjectId, String cloudId) async {
    final syncBase = await ContentSyncBaseStore.load(_db, localProjectId);
    if (syncBase == null) return null;
    final base = await ContentBaseBundleStore.load(
      _db,
      localProjectId,
      localHash: syncBase.localHash,
      cloudHash: syncBase.cloudHash,
    );
    if (base == null) return null;

    final sync = ProjectContentSyncService(_db, _client);
    final project = await _db.getProject(localProjectId);
    // La última edición de aquí: se fija antes de importar la mezcla.
    final localAt = project?.contentSyncUpdatedAt ?? project?.updatedAt;
    final local = await ProjectContentBundle.export(_db, localProjectId);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final row = await sync.fetchSnapshotRow(cloudId);
      final content = row?['content'];
      if (row == null || content is! Map) return null;
      final cloud = Map<String, dynamic>.from(content);
      final cloudHash =
          row['content_hash'] as String? ?? ProjectContentBundle.hashBundle(cloud);
      final cloudAt = DateTime.tryParse(row['updated_at'] as String? ?? '');
      final newer = cloudAt != null &&
              (localAt == null || cloudAt.isAfter(localAt))
          ? MergeSide.cloud
          : MergeSide.local;

      final result = BundleMerge.merge(
        baseLocal: base.local,
        baseCloud: base.cloud,
        local: local,
        cloud: cloud,
        newer: newer,
      );

      // Primero la nube, con la condición de siempre: si alguien subió
      // entretanto no se escribe nada y aquí sigue todo igual.
      final String mergedHash;
      try {
        mergedHash = await sync.uploadBundle(
          cloudId,
          result.merged,
          expectedCloudHash: cloudHash,
        );
      } on CloudContentChanged {
        continue;
      }

      // Después aquí, como una descarga.
      await LocalDatabaseBackup.create(_db, label: 'antes-de-mezclar');
      await ProjectContentBundle.importBundle(_db, localProjectId, result.merged);
      final imported = await ProjectContentBundle.export(_db, localProjectId);
      await ContentSyncBaseStore.save(
        _db,
        localProjectId,
        ContentSyncBase(
          localHash: ProjectContentBundle.hashBundle(imported),
          cloudHash: mergedHash,
        ),
      );
      await ContentBaseBundleStore.save(
        _db,
        localProjectId,
        local: imported,
        cloud: result.merged,
      );
      await (_db.update(_db.projects)
            ..where((p) => p.id.equals(localProjectId)))
          .write(ProjectsCompanion(
        contentSyncUpdatedAt: Value(DateTime.now().toUtc()),
      ));
      final now = DateTime.now();
      final cloudDevice = row['updated_device'] as String?;
      await SyncConflictLog.addAll(_db, [
        for (final d in result.discards)
          SyncConflictEntry(
            projectId: localProjectId,
            collection: d.collection,
            elementUid: d.uid,
            elementLabel: d.label,
            field: d.field,
            keptValue: _encode(d.kept),
            discardedValue: _encode(d.discarded),
            discardedSide: d.discardedSide?.name ?? 'cascada',
            discardedDevice: switch (d.discardedSide) {
              MergeSide.cloud => cloudDevice,
              MergeSide.local => deviceLabel(),
              null => null,
            },
            createdAt: now,
          ),
      ]);

      return MergeOutcome(
        discarded: result.discards.length,
        mine: result.discards
            .where((d) => d.discardedSide == MergeSide.local)
            .length,
      );
    }
    // La nube no paraba de cambiar: aquí no se tocó nada y la próxima pasada
    // lo vuelve a intentar.
    return null;
  }

  static String? _encode(Object? v) {
    if (v == null) return null;
    if (v is String) return v;
    return jsonEncode(v);
  }
}
