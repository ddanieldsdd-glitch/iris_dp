import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cloud/cloud_providers.dart';
import '../database/app_database.dart';
import '../database/database_provider.dart';
import '../sync/media_hydrate_service.dart';
import '../sync/media_sync_providers.dart';
import '../sync/project_content_bundle.dart';
import '../sync/project_content_sync_service.dart';
import 'admin_service.dart';

/// Copias de consulta de los proyectos de invitados en el equipo del
/// administrador. La copia no tiene `cloudId`, así que nunca se sube ni se
/// sincroniza: lo que se toque en ella se queda en este equipo. Además, la
/// nube no deja al administrador escribir en proyectos ajenos.
class GuestMirrorService {
  GuestMirrorService(this._db, this._client, this._hydrate);

  final AppDatabase _db;
  final SupabaseClient _client;
  final MediaHydrateService? _hydrate;

  Future<Project?> localCopy(String cloudId) => (_db.select(
    _db.projects,
  )..where((p) => p.mirrorCloudId.equals(cloudId))).getSingleOrNull();

  /// Crea o refresca la copia. Devuelve su id local.
  Future<int> refresh(
    GuestProject project, {
    void Function(String step)? onStep,
  }) async {
    onStep?.call('Bajando el proyecto…');
    final companion = ProjectsCompanion(
      name: Value(project.name),
      director: Value(project.director),
      status: Value(project.status ?? 'preproduction'),
      iconCode: Value(project.iconCode),
      mirrorCloudId: Value(project.cloudId),
      cloudId: const Value(null),
      updatedAt: Value(DateTime.now()),
    );
    final existing = await localCopy(project.cloudId);
    final int localId;
    if (existing != null) {
      localId = existing.id;
      await (_db.update(
        _db.projects,
      )..where((p) => p.id.equals(localId))).write(companion);
    } else {
      localId = await _db.into(_db.projects).insert(companion);
    }

    final row = await ProjectContentSyncService(
      _db,
      _client,
    ).fetchSnapshotRow(project.cloudId);
    final content = row?['content'];
    if (content is Map) {
      final bundle = Map<String, dynamic>.from(content);
      if (ProjectContentBundle.hasMeaningfulContent(bundle)) {
        await ProjectContentBundle.importBundle(_db, localId, bundle);
      }
    }

    final hydrate = _hydrate;
    if (hydrate != null) {
      onStep?.call('Bajando las imágenes…');
      await hydrate.hydrateProject(localId, project.cloudId);
    }
    return localId;
  }

  /// Borra la copia de este equipo. El proyecto del invitado no se toca.
  Future<void> remove(String cloudId) async {
    final copy = await localCopy(cloudId);
    if (copy != null) await _db.deleteProjectFully(copy.id);
  }
}

final guestMirrorServiceProvider = Provider<GuestMirrorService?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return GuestMirrorService(
    ref.watch(databaseProvider),
    client,
    ref.watch(mediaHydrateServiceProvider),
  );
});
