import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../cloud/cloud_session.dart';
import '../cloud/project_role.dart';
import '../utils/error_log.dart';

/// Push/pull de proyectos entre Drift (cache) y Supabase.
class ProjectSyncService {
  final AppDatabase _db;
  final SupabaseClient _client;
  final _uuid = const Uuid();

  ProjectSyncService(this._db, this._client);

  /// Reintenta borrados pendientes en la nube (p. ej. sin conexión previa).
  Future<void> processPendingDeletions() async {
    final tombstones = await CloudSessionStore.tombstonedCloudProjectIds();
    for (final cloudId in tombstones) {
      try {
        await _client.from('cloud_projects').delete().eq('id', cloudId);
        await CloudSessionStore.clearTombstone(cloudId);
      } catch (e, st) {
        // Se reintentará en la próxima pasada, pero queda constancia.
        await ErrorLog.recordUnlessOffline(
          e,
          st,
          context: 'Borrar un proyecto de la nube',
        );
      }
    }
  }

  /// Descarga proyectos visibles para el usuario y los refleja en cache local.
  Future<int> pullProjects(String workspaceId) async {
    final rows = await _client
        .from('cloud_projects')
        .select()
        .eq('workspace_id', workspaceId)
        .order('sort_order');

    final tombstones = await CloudSessionStore.tombstonedCloudProjectIds();
    final cloudIds = <String>{};
    var count = 0;

    for (final row in rows as List) {
      final cloudId = row['id'] as String;
      if (tombstones.contains(cloudId)) {
        try {
          await _client.from('cloud_projects').delete().eq('id', cloudId);
          await CloudSessionStore.clearTombstone(cloudId);
        } catch (e, st) {
          ErrorLog.recordUnlessOffline(
            e,
            st,
            context: 'Borrar en la nube un proyecto ya borrado aquí',
          );
          continue;
        }
      }

      cloudIds.add(cloudId);
      final existing = await (_db.select(
        _db.projects,
      )..where((p) => p.cloudId.equals(cloudId))).getSingleOrNull();

      final companion = ProjectsCompanion(
        cloudId: Value(cloudId),
        name: Value(row['name'] as String),
        director: Value(row['director_display'] as String?),
        description: Value(row['description'] as String?),
        clientName: Value(row['client_name'] as String?),
        status: Value(row['status'] as String? ?? 'preproduction'),
        iconCode: Value(row['icon_code'] as int? ?? 0xe3f4),
        coverImagePath: const Value(null),
        sortOrder: Value(row['sort_order'] as int? ?? 0),
        syncUpdatedAt: Value(
          DateTime.tryParse(row['updated_at'] as String? ?? ''),
        ),
        updatedAt: Value(DateTime.now()),
      );

      if (existing != null) {
        final cloudUpdated = DateTime.tryParse(
          row['updated_at'] as String? ?? '',
        );
        final localUpdated = existing.syncUpdatedAt ?? existing.updatedAt;
        if (cloudUpdated != null && localUpdated.isAfter(cloudUpdated)) {
          continue;
        }
        await (_db.update(
          _db.projects,
        )..where((p) => p.id.equals(existing.id))).write(companion);
      } else {
        await _db.into(_db.projects).insert(companion);
      }
      count++;
    }

    await _purgeOrphanCloudProjects(cloudIds);
    return count;
  }

  Future<void> _purgeOrphanCloudProjects(Set<String> cloudIds) async {
    final linked = await (_db.select(
      _db.projects,
    )..where((p) => p.cloudId.isNotNull())).get();
    for (final local in linked) {
      final id = local.cloudId;
      if (id != null && !cloudIds.contains(id)) {
        await _db.deleteProjectFully(local.id);
      }
    }
  }

  /// Sube proyectos locales sin cloudId al workspace.
  Future<int> pushLocalProjects(String workspaceId) async {
    final locals = await (_db.select(
      _db.projects,
    )..where((p) => p.cloudId.isNull() & p.mirrorCloudId.isNull())).get();

    var count = 0;
    for (final project in locals) {
      final cloudId = _uuid.v4();
      final payload = {
        'id': cloudId,
        'workspace_id': workspaceId,
        'name': project.name,
        'director_display': project.director,
        'description': project.description,
        'client_name': project.clientName,
        'status': project.status,
        'icon_code': project.iconCode,
        'sort_order': project.sortOrder,
      };
      await _client.from('cloud_projects').upsert(payload);

      await (_db.update(
        _db.projects,
      )..where((p) => p.id.equals(project.id))).write(
        ProjectsCompanion(
          cloudId: Value(cloudId),
          syncUpdatedAt: Value(DateTime.now()),
        ),
      );
      count++;
    }
    return count;
  }

  /// Crea proyecto en nube y cache local.
  Future<int> createProject({
    required String workspaceId,
    required String name,
    String? directorDisplay,
    String? description,
    String status = 'preproduction',
    int iconCode = 0xe3f4,
  }) async {
    final cloudId = _uuid.v4();
    await _client.from('cloud_projects').insert({
      'id': cloudId,
      'workspace_id': workspaceId,
      'name': name,
      'director_display': directorDisplay,
      'description': description,
      'status': status,
      'icon_code': iconCode,
    });

    return _db
        .into(_db.projects)
        .insert(
          ProjectsCompanion.insert(
            name: name,
            director: Value(directorDisplay),
            description: Value(description),
            status: Value(status),
            iconCode: Value(iconCode),
            cloudId: Value(cloudId),
            syncUpdatedAt: Value(DateTime.now()),
          ),
        );
  }

  Future<void> updateProject(Project project) async {
    if (project.cloudId == null) return;
    await _client
        .from('cloud_projects')
        .update({
          'name': project.name,
          'director_display': project.director,
          'description': project.description,
          'client_name': project.clientName,
          'status': project.status,
          'icon_code': project.iconCode,
          'sort_order': project.sortOrder,
        })
        .eq('id', project.cloudId!);

    await (_db.update(_db.projects)..where((p) => p.id.equals(project.id)))
        .write(ProjectsCompanion(syncUpdatedAt: Value(DateTime.now())));
  }

  Future<void> deleteProject(Project project) async {
    if (project.cloudId != null) {
      try {
        await _client
            .from('cloud_projects')
            .delete()
            .eq('id', project.cloudId!);
        await CloudSessionStore.clearTombstone(project.cloudId!);
      } catch (e, st) {
        // Se vuelve a intentar en la próxima sincronización.
        ErrorLog.recordUnlessOffline(
          e,
          st,
          context: 'Borrar el proyecto en la nube',
        );
        await CloudSessionStore.tombstoneCloudProject(project.cloudId!);
      }
    }
    await _db.deleteProjectFully(project.id);
  }
}

/// Una persona del equipo de un proyecto, o una invitación que aún no ha
/// aceptado ([userId] nulo).
class ProjectTeamEntry {
  const ProjectTeamEntry({
    required this.role,
    this.userId,
    this.name,
    this.email,
    this.invitationId,
  });

  final String? userId;
  final String? name;
  final String? email;
  final ProjectRole? role;
  final String? invitationId;

  bool get pending => userId == null;
}

/// Equipo de un proyecto compartido: invitar con un papel, aceptar las
/// invitaciones propias, cambiar papeles y quitar a alguien (019).
class ProjectInviteService {
  final SupabaseClient _client;

  ProjectInviteService(this._client);

  Future<void> invite({
    required String projectCloudId,
    required String email,
    required ProjectRole role,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('No autenticado');

    await _client.from('project_invitations').upsert({
      'project_id': projectCloudId,
      'email': email.trim().toLowerCase(),
      'role': role.code,
      'invited_by': userId,
    }, onConflict: 'project_id,email');
  }

  /// Acepta las invitaciones pendientes para el correo de esta cuenta. Lo
  /// hace el servidor (019): la cuenta invitada no puede añadirse sola al
  /// proyecto. Sin la 019, el camino de antes (que solo funciona si las
  /// reglas lo dejan).
  Future<int> acceptPendingInvitations() async {
    final user = _client.auth.currentUser;
    if (user?.email == null) return 0;
    try {
      final n = await _client.rpc('iris_accept_invitations');
      return n is int ? n : 0;
    } on PostgrestException catch (e) {
      if (!_missingFunction(e)) rethrow;
    }
    return _acceptDirectly(user!);
  }

  static bool _missingFunction(PostgrestException e) =>
      e.code == 'PGRST202' || e.message.contains('iris_accept_invitations');

  Future<int> _acceptDirectly(User user) async {
    final invites = await _client
        .from('project_invitations')
        .select()
        .eq('email', user.email!.toLowerCase())
        .isFilter('accepted_at', null);

    var count = 0;
    for (final inv in invites as List) {
      final role = inv['role'] as String? ?? ProjectRole.director.code;
      await _client.from('project_members').upsert({
        'project_id': inv['project_id'],
        'user_id': user.id,
        'role': role,
        'can_edit': ProjectRole.fromCode(role)?.canEdit ?? true,
      });
      await _client
          .from('project_invitations')
          .update({'accepted_at': DateTime.now().toIso8601String()})
          .eq('id', inv['id']);
      count++;
    }
    return count;
  }

  /// Quién está en el proyecto y a quién se ha invitado sin respuesta.
  Future<List<ProjectTeamEntry>> team(String projectCloudId) async {
    final members = await _client
        .from('project_members')
        .select('user_id, role, profiles(display_name)')
        .eq('project_id', projectCloudId);
    final invites = await _client
        .from('project_invitations')
        .select('id, email, role')
        .eq('project_id', projectCloudId)
        .isFilter('accepted_at', null);
    return [
      for (final m in members as List)
        ProjectTeamEntry(
          userId: m['user_id'] as String,
          name: (m['profiles'] as Map?)?['display_name'] as String?,
          role: ProjectRole.fromCode(m['role'] as String?),
        ),
      for (final i in invites as List)
        ProjectTeamEntry(
          invitationId: i['id'] as String,
          email: i['email'] as String?,
          role: ProjectRole.fromCode(i['role'] as String?),
        ),
    ];
  }

  Future<void> setRole(
    String projectCloudId,
    ProjectTeamEntry entry,
    ProjectRole role,
  ) async {
    if (entry.pending) {
      await _client
          .from('project_invitations')
          .update({'role': role.code})
          .eq('id', entry.invitationId!);
      return;
    }
    await _client
        .from('project_members')
        .update({'role': role.code, 'can_edit': role.canEdit})
        .eq('project_id', projectCloudId)
        .eq('user_id', entry.userId!);
  }

  /// Quita a alguien del proyecto o retira su invitación. Lo que ya tiene
  /// en su equipo no se borra: deja de recibir cambios y de poder subirlos.
  Future<void> remove(String projectCloudId, ProjectTeamEntry entry) async {
    if (entry.pending) {
      await _client
          .from('project_invitations')
          .delete()
          .eq('id', entry.invitationId!);
      return;
    }
    await _client
        .from('project_members')
        .delete()
        .eq('project_id', projectCloudId)
        .eq('user_id', entry.userId!);
  }
}

/// Workspace del DP.
class WorkspaceService {
  final SupabaseClient _client;

  WorkspaceService(this._client);

  Future<({String id, String name})> ensureOwnerWorkspace({
    required String displayName,
  }) async {
    final user = _client.auth.currentUser!;
    final userId = user.id;
    final meta = user.userMetadata ?? {};
    final role = (meta['role'] as String?) ?? 'dp';

    // Perfil obligatorio antes de workspace (FK owner_id → profiles)
    await _client.from('profiles').upsert({
      'id': userId,
      'display_name': displayName,
      'role': role == 'director' ? 'director' : 'dp',
    });

    final existing = await _client
        .from('workspace_members')
        .select('workspace_id, workspaces(name)')
        .eq('user_id', userId)
        .eq('role', 'owner')
        .maybeSingle();

    if (existing != null) {
      final ws = existing['workspaces'] as Map<String, dynamic>?;
      return (
        id: existing['workspace_id'] as String,
        name: ws?['name'] as String? ?? displayName,
      );
    }

    final wsId = const Uuid().v4();
    await _client.from('workspaces').insert({
      'id': wsId,
      'name': '$displayName — IRIS',
      'owner_id': userId,
    });
    await _client.from('workspace_members').insert({
      'workspace_id': wsId,
      'user_id': userId,
      'role': 'owner',
    });

    await _client.from('profiles').update({'role': 'dp'}).eq('id', userId);

    return (id: wsId, name: '$displayName — IRIS');
  }
}
