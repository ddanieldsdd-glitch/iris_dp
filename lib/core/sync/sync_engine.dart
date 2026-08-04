import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import '../cloud/cloud_session.dart';
import '../database/database_provider.dart';
import 'media_sync_service.dart';
import 'project_sync_service.dart';

/// Orquestador de sincronización cloud ↔ cache local.
class SyncEngine {
  final Ref _ref;

  SyncEngine(this._ref);

  ProjectSyncService? get _projects {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) return null;
    return ProjectSyncService(_ref.read(databaseProvider), client);
  }

  MediaSyncService? get _media {
    final client = _ref.read(supabaseClientProvider);
    if (client == null) return null;
    return MediaSyncService(client);
  }

  Future<SyncResult> syncAll() async {
    final projects = _projects;
    if (projects == null) {
      return SyncResult.skipped('Modo local');
    }

    final workspaceId = await CloudSessionStore.workspaceId();
    if (workspaceId == null) {
      return SyncResult.skipped('Sin workspace');
    }

    final inviteService = ProjectInviteService(_ref.read(supabaseClientProvider)!);
    final accepted = await inviteService.acceptPendingInvitations();

    final pushed = await projects.pushLocalProjects(workspaceId);
    final pulled = await projects.pullProjects(workspaceId);

    var mediaSynced = 0;
    final media = _media;
    if (media != null) {
      final db = _ref.read(databaseProvider);
      final allProjects = await db.watchProjects().first;
      for (final p in allProjects) {
        if (p.cloudId == null) continue;
        mediaSynced += await media.syncMoodboardForProject(
          db: db,
          localProjectId: p.id,
          projectCloudId: p.cloudId!,
        );
      }
    }

    return SyncResult(
      pushed: pushed,
      pulled: pulled,
      invitationsAccepted: accepted,
      mediaSynced: mediaSynced,
    );
  }
}

class SyncResult {
  final int pushed;
  final int pulled;
  final int invitationsAccepted;
  final int mediaSynced;
  final String? message;

  const SyncResult({
    this.pushed = 0,
    this.pulled = 0,
    this.invitationsAccepted = 0,
    this.mediaSynced = 0,
    this.message,
  });

  factory SyncResult.skipped(String reason) =>
      SyncResult(message: reason);

  bool get ok => message == null;
}

final syncEngineProvider = Provider<SyncEngine>((ref) => SyncEngine(ref));

final syncStatusProvider = FutureProvider<SyncResult>((ref) async {
  return ref.read(syncEngineProvider).syncAll();
});
