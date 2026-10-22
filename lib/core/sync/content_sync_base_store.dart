import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';

/// Huellas del contenido de un proyecto en la última sincronización: la de
/// este dispositivo y la de la nube.
///
/// Con ellas se sabe quién ha cambiado desde entonces sin comparar horas, que
/// se guardan redondeadas y dependen del reloj de cada dispositivo.
class ContentSyncBase {
  final String localHash;
  final String cloudHash;

  const ContentSyncBase({required this.localHash, required this.cloudHash});
}

/// Las huellas viven en el propio proyecto (`Projects.contentSyncBase*`): si
/// se restaura una copia de la base, vuelven con el contenido al que
/// corresponden. Antes estaban en las preferencias del equipo; se copian a la
/// base la primera vez que se leen.
abstract final class ContentSyncBaseStore {
  static String _legacyLocalKey(int projectId) =>
      'iris_content_sync_base_local_$projectId';
  static String _legacyCloudKey(int projectId) =>
      'iris_content_sync_base_cloud_$projectId';

  static Future<ContentSyncBase?> load(AppDatabase db, int projectId) async {
    final project = await db.getProject(projectId);
    if (project == null) return null;
    final local = project.contentSyncBaseLocal;
    final cloud = project.contentSyncBaseCloud;
    if (local != null && cloud != null) {
      return ContentSyncBase(localHash: local, cloudHash: cloud);
    }

    final prefs = await SharedPreferences.getInstance();
    final legacyLocal = prefs.getString(_legacyLocalKey(projectId));
    final legacyCloud = prefs.getString(_legacyCloudKey(projectId));
    if (legacyLocal == null || legacyCloud == null) return null;
    final base = ContentSyncBase(
      localHash: legacyLocal,
      cloudHash: legacyCloud,
    );
    await save(db, projectId, base);
    return base;
  }

  static Future<void> save(
    AppDatabase db,
    int projectId,
    ContentSyncBase base,
  ) async {
    await (db.update(db.projects)..where((p) => p.id.equals(projectId))).write(
      ProjectsCompanion(
        contentSyncBaseLocal: Value(base.localHash),
        contentSyncBaseCloud: Value(base.cloudHash),
      ),
    );
    await _forgetLegacy(projectId);
  }

  static Future<void> clear(AppDatabase db, int projectId) async {
    await (db.update(db.projects)..where((p) => p.id.equals(projectId))).write(
      const ProjectsCompanion(
        contentSyncBaseLocal: Value(null),
        contentSyncBaseCloud: Value(null),
      ),
    );
    await _forgetLegacy(projectId);
  }

  static Future<void> _forgetLegacy(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_legacyLocalKey(projectId));
    await prefs.remove(_legacyCloudKey(projectId));
  }
}
