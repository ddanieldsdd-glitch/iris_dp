import 'package:drift/drift.dart';

import '../database/app_database.dart';

/// A qué proyecto de la nube pertenece una clave en vivo ([LiveKey]): lo que
/// se edita o se escribe en él va solo a su canal, no a los de los demás
/// proyectos (fase 0 de colaboración). Lo que no se encuentra devuelve nulo
/// y se queda en el canal del espacio propio.
class LiveKeyProjects {
  LiveKeyProjects(this._db);

  final AppDatabase _db;
  final _cache = <String, String?>{};

  Future<String?> cloudIdOf(String key) async {
    if (_cache.containsKey(key)) return _cache[key];
    final projectId = await _projectIdOf(key);
    String? cloudId;
    if (projectId != null) {
      final project = await (_db.select(
        _db.projects,
      )..where((p) => p.id.equals(projectId))).getSingleOrNull();
      cloudId = project?.cloudId ?? project?.mirrorCloudId;
    }
    // Un proyecto que aún no ha subido se vuelve a mirar la próxima vez.
    if (cloudId != null) _cache[key] = cloudId;
    return cloudId;
  }

  Future<int?> _projectIdOf(String key) async {
    final colon = key.indexOf(':');
    if (colon < 0) return _shot(key);
    final kind = key.substring(0, colon);
    final rest = key.substring(colon + 1);
    switch (kind) {
      case 'site':
        return _one(
          _db.locationSites,
          _db.locationSites.uid,
          _db.locationSites.projectId,
          rest,
        );
      case 'set':
        return _one(
          _db.locationBasePlans,
          _db.locationBasePlans.uid,
          _db.locationBasePlans.projectId,
          rest,
        );
      case 'lightSetup':
        return _one(
          _db.lightSetups,
          _db.lightSetups.uid,
          _db.lightSetups.projectId,
          rest,
        );
      case 'scene':
        return _one(_db.scenes, _db.scenes.uid, _db.scenes.projectId, rest);
      case 'drawing':
        // «drawing:<destino>:<uid>»: el uid es de un plano o, en un boceto
        // de planta, de un esquema de luz.
        final uid = rest.substring(rest.lastIndexOf(':') + 1);
        return await _shot(uid) ??
            await _one(
              _db.lightSetups,
              _db.lightSetups.uid,
              _db.lightSetups.projectId,
              uid,
            );
    }
    return null;
  }

  Future<int?> _shot(String uid) =>
      _one(_db.shots, _db.shots.uid, _db.shots.projectId, uid);

  Future<int?> _one<T extends HasResultSet, R>(
    ResultSetImplementation<T, R> table,
    GeneratedColumn<String> uid,
    GeneratedColumn<int> projectId,
    String value,
  ) async {
    final row =
        await (_db.selectOnly(table)
              ..addColumns([projectId])
              ..where(uid.equals(value))
              ..limit(1))
            .getSingleOrNull();
    return row?.read(projectId);
  }
}
