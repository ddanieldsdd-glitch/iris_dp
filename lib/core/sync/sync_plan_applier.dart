import 'package:drift/drift.dart' show Value;
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../cloud/cloud_session.dart';
import 'project_content_sync_service.dart';
import 'project_content_bundle.dart' show bundleIntOr;
import 'sync_plan.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Aplica un [SyncPlan] confirmado por el usuario.
class SyncPlanApplier {
  final AppDatabase _db;
  final SupabaseClient _client;
  final _uuid = const Uuid();

  SyncPlanApplier(this._db, this._client);

  Future<({int pushed, int pulled, int deleted})> apply(
    SyncPlan plan,
    String workspaceId,
  ) async {
    var pushed = 0;
    var pulled = 0;
    var deleted = 0;

    for (final item in plan.items) {
      if (item.choice == SyncResolutionChoice.skip) continue;

      final applied = await _applyItem(item, workspaceId);
      pushed += applied.pushed;
      pulled += applied.pulled;
      deleted += applied.deleted;
    }

    return (pushed: pushed, pulled: pulled, deleted: deleted);
  }

  Future<({int pushed, int pulled, int deleted})> _applyItem(
    SyncPlanItem item,
    String workspaceId,
  ) async {
    if (item.choice == SyncResolutionChoice.skip) {
      return (pushed: 0, pulled: 0, deleted: 0);
    }

    if (item.action == SyncPlanAction.conflict) {
      if (item.choice == SyncResolutionChoice.useLocal) {
        return _pushLocalProject(item.localProject!);
      }
      if (item.choice == SyncResolutionChoice.useCloud) {
        return _pullCloudRow(item.cloudRow!, item.localProjectId);
      }
      return (pushed: 0, pulled: 0, deleted: 0);
    }

    if (item.action == SyncPlanAction.contentConflict) {
      if (item.choice == SyncResolutionChoice.useLocal) {
        return _pushContent(item.localProjectId!, item.cloudId!);
      }
      if (item.choice == SyncResolutionChoice.useCloud) {
        return _pullContent(item.localProjectId!, item.cloudId!);
      }
      return (pushed: 0, pulled: 0, deleted: 0);
    }

    return switch (item.action) {
      SyncPlanAction.pushNewLocal =>
        _pushNewLocal(item.localProject!, workspaceId),
      SyncPlanAction.importFromCloud =>
        _importCloudRow(item.cloudRow!),
      SyncPlanAction.updateLocalFromCloud =>
        _pullCloudRow(item.cloudRow!, item.localProjectId),
      SyncPlanAction.updateCloudFromLocal =>
        _pushLocalProject(item.localProject!),
      SyncPlanAction.deleteLocal =>
        _deleteLocal(item.localProjectId!),
      SyncPlanAction.deleteCloud =>
        _deleteCloud(item.cloudId!, item.localProjectId),
      SyncPlanAction.pushContentLocal =>
        _pushContent(item.localProjectId!, item.cloudId!),
      SyncPlanAction.pullContentCloud =>
        _pullContent(item.localProjectId!, item.cloudId!),
      SyncPlanAction.conflict ||
      SyncPlanAction.contentConflict =>
        (pushed: 0, pulled: 0, deleted: 0),
    };
  }

  Future<({int pushed, int pulled, int deleted})> _pushContent(
    int localProjectId,
    String cloudId,
  ) async {
    try {
      final sync = ProjectContentSyncService(_db, _client);
      await sync.upload(localProjectId, cloudId);
      return (pushed: 1, pulled: 0, deleted: 0);
    } on SnapshotsTableMissing {
      return (pushed: 0, pulled: 0, deleted: 0);
    }
  }

  Future<({int pushed, int pulled, int deleted})> _pullContent(
    int localProjectId,
    String cloudId,
  ) async {
    final sync = ProjectContentSyncService(_db, _client);
    final ok = await sync.download(localProjectId, cloudId);
    return (pushed: 0, pulled: ok ? 1 : 0, deleted: 0);
  }

  Future<({int pushed, int pulled, int deleted})> _pushNewLocal(
    Project project,
    String workspaceId,
  ) async {
    final cloudId = _uuid.v4();
    await _client.from('cloud_projects').upsert({
      'id': cloudId,
      'workspace_id': workspaceId,
      'name': project.name,
      'director_display': project.director,
      'description': project.description,
      'client_name': project.clientName,
      'status': project.status,
      'icon_code': project.iconCode,
      'sort_order': project.sortOrder,
    });
    await (_db.update(_db.projects)..where((p) => p.id.equals(project.id)))
        .write(ProjectsCompanion(
      cloudId: Value(cloudId),
      syncUpdatedAt: Value(DateTime.now()),
    ));
    final sync = ProjectContentSyncService(_db, _client);
    try {
      await sync.upload(project.id, cloudId);
    } on SnapshotsTableMissing {
      // Metadatos subidos; contenido cuando exista migración 007.
    }
    return (pushed: 1, pulled: 0, deleted: 0);
  }

  Future<({int pushed, int pulled, int deleted})> _pushLocalProject(
    Project project,
  ) async {
    if (project.cloudId == null) return (pushed: 0, pulled: 0, deleted: 0);
    await _client.from('cloud_projects').update({
      'name': project.name,
      'director_display': project.director,
      'description': project.description,
      'client_name': project.clientName,
      'status': project.status,
      'icon_code': project.iconCode,
      'sort_order': project.sortOrder,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', project.cloudId!);
    await (_db.update(_db.projects)..where((p) => p.id.equals(project.id)))
        .write(ProjectsCompanion(syncUpdatedAt: Value(DateTime.now().toUtc())));
    await _pushContent(project.id, project.cloudId!);
    return (pushed: 1, pulled: 0, deleted: 0);
  }

  Future<({int pushed, int pulled, int deleted})> _importCloudRow(
    Map<String, dynamic> row,
  ) async {
    final localId = await _db.into(_db.projects).insert(_companionFromRow(row));
    final cloudId = row['id'] as String;
    final sync = ProjectContentSyncService(_db, _client);
    final pulled = await sync.download(localId, cloudId);
    return (pushed: 0, pulled: pulled ? 1 : 0, deleted: 0);
  }

  Future<({int pushed, int pulled, int deleted})> _pullCloudRow(
    Map<String, dynamic> row,
    int? localProjectId,
  ) async {
    final companion = _companionFromRow(row);
    final cloudId = row['id'] as String;
    if (localProjectId != null) {
      await (_db.update(_db.projects)
            ..where((p) => p.id.equals(localProjectId)))
          .write(companion);
      await _pullContent(localProjectId, cloudId);
    } else {
      final localId = await _db.into(_db.projects).insert(companion);
      await _pullContent(localId, cloudId);
    }
    return (pushed: 0, pulled: 1, deleted: 0);
  }

  Future<({int pushed, int pulled, int deleted})> _deleteLocal(
    int localProjectId,
  ) async {
    await _db.deleteProjectFully(localProjectId);
    return (pushed: 0, pulled: 0, deleted: 1);
  }

  Future<({int pushed, int pulled, int deleted})> _deleteCloud(
    String cloudId,
    int? localProjectId,
  ) async {
    try {
      await _client.from('cloud_projects').delete().eq('id', cloudId);
      await ProjectContentSyncService(_db, _client).deleteSnapshot(cloudId);
      await CloudSessionStore.clearTombstone(cloudId);
    } catch (_) {
      await CloudSessionStore.tombstoneCloudProject(cloudId);
    }
    if (localProjectId != null) {
      await _db.deleteProjectFully(localProjectId);
    }
    return (pushed: 0, pulled: 0, deleted: 1);
  }

  ProjectsCompanion _companionFromRow(Map<String, dynamic> row) {
    final cloudId = row['id'] as String;
    return ProjectsCompanion(
      cloudId: Value(cloudId),
      name: Value(row['name'] as String),
      director: Value(row['director_display'] as String?),
      description: Value(row['description'] as String?),
      clientName: Value(row['client_name'] as String?),
      status: Value(row['status'] as String? ?? 'preproduction'),
      iconCode: Value(bundleIntOr(row['icon_code'], 0xe3f4)),
      sortOrder: Value(bundleIntOr(row['sort_order'], 0)),
      syncUpdatedAt: Value(
        DateTime.tryParse(row['updated_at'] as String? ?? '') ??
            DateTime.now().toUtc(),
      ),
      updatedAt: Value(DateTime.now().toUtc()),
    );
  }
}
