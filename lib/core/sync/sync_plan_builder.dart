import '../database/app_database.dart';
import '../cloud/cloud_session.dart';
import 'content_sync_base_store.dart';
import 'project_content_bundle.dart';
import 'project_content_sync_service.dart';
import 'sync_merge_store.dart';
import 'sync_plan.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Construye un [SyncPlan] comparando local vs nube sin aplicar cambios.
class SyncPlanBuilder {
  final AppDatabase _db;
  final SupabaseClient _client;

  SyncPlanBuilder(this._db, this._client);

  Future<SyncPlan> build(String workspaceId) async {
    final rows = await _client
        .from('cloud_projects')
        .select()
        .eq('workspace_id', workspaceId)
        .order('sort_order');

    final tombstones = await CloudSessionStore.tombstonedCloudProjectIds();
    final locals = await _db.select(_db.projects).get();
    final localsByCloudId = {
      for (final p in locals)
        if (p.cloudId != null) p.cloudId!: p,
    };
    final cloudIds = <String>{};
    final items = <SyncPlanItem>[];

    for (final local in locals) {
      if (local.cloudId == null) {
        items.add(
          SyncPlanItem(
            action: SyncPlanAction.pushNewLocal,
            title: local.name,
            description: 'Proyecto nuevo en este dispositivo — subir a la nube',
            localProjectId: local.id,
            localProject: local,
          ),
        );
      }
    }

    for (final row in rows as List) {
      final cloudId = row['id'] as String;
      cloudIds.add(cloudId);

      if (tombstones.contains(cloudId)) {
        items.add(
          SyncPlanItem(
            action: SyncPlanAction.deleteCloud,
            title: row['name'] as String? ?? 'Proyecto',
            description:
                'Eliminado en este dispositivo — borrar también en la nube',
            cloudId: cloudId,
            cloudRow: Map<String, dynamic>.from(row),
          ),
        );
        continue;
      }

      final local = localsByCloudId[cloudId];
      if (local == null) {
        items.add(
          SyncPlanItem(
            action: SyncPlanAction.importFromCloud,
            title: row['name'] as String? ?? 'Proyecto',
            description: 'Existe en la nube pero no en este dispositivo',
            cloudId: cloudId,
            cloudRow: Map<String, dynamic>.from(row),
          ),
        );
        continue;
      }

      final diffs = _diffProject(local, row);
      if (diffs.isEmpty) continue;

      final cloudUpdated =
          DateTime.tryParse(row['updated_at'] as String? ?? '');

      if (cloudUpdated == null) {
        items.add(
          SyncPlanItem(
            action: SyncPlanAction.conflict,
            title: local.name,
            description: 'Datos distintos — elige qué versión conservar',
            localProjectId: local.id,
            cloudId: cloudId,
            localProject: local,
            cloudRow: Map<String, dynamic>.from(row),
            diffs: diffs,
          ),
        );
        continue;
      }

      final localUpdated = local.syncUpdatedAt ?? local.updatedAt;

      if (localUpdated.isAfter(cloudUpdated)) {
        items.add(
          SyncPlanItem(
            action: SyncPlanAction.updateCloudFromLocal,
            title: local.name,
            description: 'Cambios locales más recientes — subir a la nube',
            localProjectId: local.id,
            cloudId: cloudId,
            localProject: local,
            cloudRow: Map<String, dynamic>.from(row),
            diffs: diffs,
          ),
        );
      } else if (cloudUpdated.isAfter(localUpdated)) {
        items.add(
          SyncPlanItem(
            action: SyncPlanAction.updateLocalFromCloud,
            title: local.name,
            description: 'Cambios en la nube más recientes — descargar aquí',
            localProjectId: local.id,
            cloudId: cloudId,
            localProject: local,
            cloudRow: Map<String, dynamic>.from(row),
            diffs: diffs,
          ),
        );
      } else {
        items.add(
          SyncPlanItem(
            action: SyncPlanAction.conflict,
            title: local.name,
            description:
                'Modificado en ambos sitios — elige qué versión conservar',
            localProjectId: local.id,
            cloudId: cloudId,
            localProject: local,
            cloudRow: Map<String, dynamic>.from(row),
            diffs: diffs,
          ),
        );
      }
    }

    for (final local in locals) {
      final cid = local.cloudId;
      if (cid == null || cloudIds.contains(cid)) continue;
      if (tombstones.contains(cid)) continue;

      items.add(
        SyncPlanItem(
          action: SyncPlanAction.deleteLocal,
          title: local.name,
          description:
              'Ya no está en la nube (borrado en otro dispositivo)',
          localProjectId: local.id,
          cloudId: cid,
          localProject: local,
        ),
      );
    }

    await _appendContentItems(items, locals, tombstones);

    return SyncPlan(items: items);
  }

  Future<void> _appendContentItems(
    List<SyncPlanItem> items,
    List<Project> locals,
    Set<String> tombstones,
  ) async {
    final linked = locals
        .where((p) => p.cloudId != null && !tombstones.contains(p.cloudId))
        .toList();
    if (linked.isEmpty) return;

    final contentSync = ProjectContentSyncService(_db, _client);
    final Map<String, Map<String, dynamic>> snapshots;
    try {
      snapshots = await contentSync.fetchAllSnapshots(
        linked.map((p) => p.cloudId!).toList(),
      );
    } on SnapshotsTableMissing {
      // Migración 007 no aplicada: sync de metadatos sigue funcionando.
      return;
    }

    for (final local in linked) {
      final cloudId = local.cloudId!;
      final localSummary =
          await ProjectContentBundle.summarizeLocal(_db, local.id);
      final localBundle = await ProjectContentBundle.export(_db, local.id);
      final localHash = ProjectContentBundle.hashBundle(localBundle);
      final snap = snapshots[cloudId];

      if (snap == null) {
        // Un proyecto sin escenas puede tener biblia y moodboard.
        if (localSummary.isEmpty &&
            !await ProjectContentBundle.hasLocalContent(_db, local.id)) {
          continue;
        }
        items.add(
          SyncPlanItem(
            action: SyncPlanAction.pushContentLocal,
            title: '${local.name} — contenido',
            description:
                'Escenas, planos y datos del proyecto solo en este dispositivo',
            localProjectId: local.id,
            cloudId: cloudId,
            localProject: local,
            localContentSummary: localSummary,
          ),
        );
        continue;
      }

      final cloudHash = snap['content_hash'] as String?;
      final cloudContent = snap['content'];
      final cloudSummary = cloudContent is Map<String, dynamic>
          ? ProjectContentBundle.summarize(cloudContent)
          : ContentSyncSummary(
              sceneCount: bundleIntOr(snap['scene_count'], 0),
              shotCount: bundleIntOr(snap['shot_count'], 0),
            );

      if (cloudHash == localHash ||
          ProjectContentBundle.contentMatchesSnapshot(localHash, snap)) {
        // Iguales: este es el nuevo punto de partida. Guardarlo deja las
        // huellas en la base (y en SHA-256) aunque no haya nada que subir.
        final synced = ContentSyncBase(
          localHash: localHash,
          cloudHash: cloudHash ?? localHash,
        );
        final base = await ContentSyncBaseStore.load(_db, local.id);
        final baseMoved = base?.localHash != synced.localHash ||
            base?.cloudHash != synced.cloudHash;
        if (baseMoved) {
          await ContentSyncBaseStore.save(_db, local.id, synced);
        }
        // También es la base para mezclar si un día cambian los dos lados.
        if (cloudContent is Map &&
            (baseMoved || !await ContentBaseBundleStore.has(_db, local.id))) {
          await ContentBaseBundleStore.save(
            _db,
            local.id,
            local: localBundle,
            cloud: Map<String, dynamic>.from(cloudContent),
          );
        }
        // Mismo contenido, pero con uid distintos (este equipo bajó el
        // proyecto antes de que los uid viajaran): sus imágenes no encuentran
        // su fila. Descargar no cambia nada más y deja los uid de la nube.
        if (cloudContent is Map &&
            !ProjectContentBundle.uidsMatch(
              localBundle,
              Map<String, dynamic>.from(cloudContent),
            )) {
          items.add(
            SyncPlanItem(
              action: SyncPlanAction.pullContentCloud,
              title: '${local.name} — contenido',
              description:
                  'Mismo contenido; descargar para recibir las imágenes y '
                  'archivos de la nube',
              localProjectId: local.id,
              cloudId: cloudId,
              localProject: local,
              localContentSummary: localSummary,
              cloudContentSummary: ProjectContentBundle.summarize(
                Map<String, dynamic>.from(cloudContent),
              ),
              cloudContentHash: cloudHash,
            ),
          );
        }
        continue;
      }

      final cloudNow =
          cloudHash ??
          (cloudContent is Map
              ? ProjectContentBundle.hashBundle(
                  Map<String, dynamic>.from(cloudContent),
                )
              : null);

      SyncPlanItem contentItem(SyncPlanAction action, String description) =>
          SyncPlanItem(
            action: action,
            title: '${local.name} — contenido',
            description: description,
            localProjectId: local.id,
            cloudId: cloudId,
            localProject: local,
            localContentSummary: localSummary,
            cloudContentSummary: cloudSummary,
            cloudContentHash: cloudNow,
            diffs: _contentDiffs(localSummary, cloudSummary),
          );

      // Quién ha cambiado desde la última sincronización se decide por las
      // huellas guardadas entonces, no por horas: una descarga reemplaza el
      // contenido local y no puede depender del reloj.
      final base = await ContentSyncBaseStore.load(_db, local.id);
      if (base == null) {
        if (localSummary.isEmpty &&
            !await ProjectContentBundle.hasLocalContent(_db, local.id)) {
          items.add(
            contentItem(
              SyncPlanAction.pullContentCloud,
              'Contenido en la nube — descargar a este dispositivo',
            ),
          );
        } else {
          items.add(
            contentItem(
              SyncPlanAction.contentConflict,
              'Contenido distinto aquí y en la nube — elige qué versión '
              'conservar',
            ),
          );
        }
        continue;
      }

      // La base puede ser de antes de SHA-256: se compara con su método.
      final localChanged = !ProjectContentBundle.bundleMatchesHash(
        localBundle,
        base.localHash,
      );
      // La huella de la nube sirve si está en el mismo formato que la base;
      // si no (subida ya con SHA-256), se calcula del contenido.
      final sameFormat =
          cloudHash != null &&
          ProjectContentBundle.isLegacyHash(cloudHash) ==
              ProjectContentBundle.isLegacyHash(base.cloudHash);
      // Con el contenido de la nube a mano se compara el contenido (vale la
      // huella con o sin rutas); si no, la huella guardada.
      final compareContent =
          cloudContent is Map &&
          !(sameFormat && ProjectContentBundle.isLegacyHash(base.cloudHash));
      final cloudChanged = compareContent
          ? !ProjectContentBundle.bundleMatchesHash(
              Map<String, dynamic>.from(cloudContent),
              base.cloudHash,
            )
          : cloudNow != base.cloudHash;

      if (localChanged && cloudChanged) {
        items.add(
          contentItem(
            SyncPlanAction.contentConflict,
            'Modificado aquí y en la nube — elige qué versión conservar',
          ),
        );
      } else if (localChanged) {
        items.add(
          contentItem(
            SyncPlanAction.pushContentLocal,
            'Cambios en este dispositivo — subir a la nube',
          ),
        );
      } else if (cloudChanged) {
        items.add(
          contentItem(
            SyncPlanAction.pullContentCloud,
            'Cambios en la nube — descargar a este dispositivo',
          ),
        );
      }
    }
  }

  List<SyncFieldDiff> _contentDiffs(
    ContentSyncSummary local,
    ContentSyncSummary cloud,
  ) {
    final diffs = <SyncFieldDiff>[];
    void cmp(String field, String label, int a, int b) {
      if (a != b) {
        diffs.add(SyncFieldDiff(
          field: field,
          label: label,
          localValue: '$a',
          cloudValue: '$b',
        ));
      }
    }

    cmp('scenes', 'Escenas', local.sceneCount, cloud.sceneCount);
    cmp('shots', 'Planos', local.shotCount, cloud.shotCount);
    cmp('sets', 'Sets de rodaje', local.locationSetCount, cloud.locationSetCount);
    cmp('docs', 'Docs. rodaje', local.shootDocumentCount, cloud.shootDocumentCount);
    return diffs;
  }

  List<SyncFieldDiff> _diffProject(Project local, Map<String, dynamic> row) {
    final diffs = <SyncFieldDiff>[];

    void cmp(String field, String label, String? a, String? b) {
      final na = _norm(a);
      final nb = _norm(b);
      if (na != nb) {
        diffs.add(SyncFieldDiff(
          field: field,
          label: label,
          localValue: a?.isEmpty == true ? null : a,
          cloudValue: b?.isEmpty == true ? null : b,
        ));
      }
    }

    cmp('name', 'Nombre', local.name, row['name'] as String?);
    cmp('director', 'Director', local.director, row['director_display'] as String?);
    cmp('description', 'Descripción', local.description, row['description'] as String?);
    cmp('client', 'Cliente', local.clientName, row['client_name'] as String?);
    cmp('status', 'Estado', _statusLabel(local.status),
        _statusLabel(row['status'] as String? ?? 'preproduction'));
    cmp('sort', 'Orden', '${local.sortOrder}', '${row['sort_order'] ?? 0}');
    // icon_code: omitido (cosmético; defaults distintos local vs nube no deben bloquear sync)

    return diffs;
  }

  String? _norm(String? v) => v?.trim().isEmpty == true ? null : v?.trim();

  String _statusLabel(String status) => switch (status) {
        'shooting' => 'Rodaje',
        'post' => 'Post',
        _ => 'Preproducción',
      };
}
