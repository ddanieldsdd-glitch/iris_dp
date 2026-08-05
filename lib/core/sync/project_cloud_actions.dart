import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cloud/cloud_providers.dart';
import '../cloud/cloud_session.dart';
import '../cloud/supabase_config.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../sync/project_sync_service.dart';

/// Operaciones de proyecto vinculadas a Supabase (crear / editar / eliminar).
abstract final class ProjectCloudActions {
  ProjectCloudActions._();

  static ProjectSyncService? _service(WidgetRef ref) {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return null;
    return ProjectSyncService(ref.read(databaseProvider), client);
  }

  static Future<void> deleteProject(WidgetRef ref, Project project) async {
    final db = ref.read(databaseProvider);
    final sync = _service(ref);

    if (sync != null &&
        SupabaseConfig.isConfigured &&
        ref.read(supabaseClientProvider)?.auth.currentUser != null) {
      await sync.deleteProject(project);
      return;
    }

    if (project.cloudId != null) {
      await CloudSessionStore.tombstoneCloudProject(project.cloudId!);
    }
    await db.deleteProjectFully(project.id);
  }

  static Future<int> createProject(
    WidgetRef ref, {
    required String name,
    String? director,
    String status = 'preproduction',
    int iconCode = 0xe3f4,
    int? groupId,
  }) async {
    final db = ref.read(databaseProvider);
    final sync = _service(ref);
    final workspaceId = await CloudSessionStore.workspaceId();
    final loggedIn =
        ref.read(supabaseClientProvider)?.auth.currentUser != null;

    if (sync != null &&
        SupabaseConfig.isConfigured &&
        loggedIn &&
        workspaceId != null) {
      return sync.createProject(
        workspaceId: workspaceId,
        name: name,
        directorDisplay: director,
        status: status,
        iconCode: iconCode,
      );
    }

    return db.insertProject(
      ProjectsCompanion.insert(
        name: name,
        director: Value(director),
        status: Value(status),
        iconCode: Value(iconCode),
        groupId: Value(groupId),
      ),
    );
  }

  static Future<void> saveProject(WidgetRef ref, Project project) async {
    final db = ref.read(databaseProvider);
    await db.updateProject(project);

    final sync = _service(ref);
    if (sync == null ||
        !SupabaseConfig.isConfigured ||
        ref.read(supabaseClientProvider)?.auth.currentUser == null) {
      return;
    }

    if (project.cloudId != null) {
      await sync.updateProject(project);
      return;
    }

    final workspaceId = await CloudSessionStore.workspaceId();
    if (workspaceId != null) {
      await sync.pushLocalProjects(workspaceId);
    }
  }
}
