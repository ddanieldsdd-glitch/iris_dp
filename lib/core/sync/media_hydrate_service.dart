import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import 'cloud_media_service.dart';
import 'media_entity_keys.dart';
import 'media_entity_types.dart';
import 'media_file_stamp.dart';
import 'media_slots.dart';
import 'primary_reference_repair.dart' as repair_refs;
import '../utils/error_log.dart';

/// Descarga imágenes remotas y actualiza rutas locales en Drift.
class MediaHydrateService {
  final AppDatabase _db;
  final CloudMediaService _cloud;

  MediaHydrateService(this._db, this._cloud);

  Future<int> hydrateProject(int projectId, String projectCloudId) async {
    final assets = await _cloud.fetchProjectAssets(projectCloudId);
    var downloaded = 0;

    final strokes = <Map<String, dynamic>>[];
    for (final asset in assets) {
      if (asset['entity_type'] == MediaEntityType.sketchStrokes) {
        strokes.add(asset);
        continue;
      }
      try {
        if (await _hydrateAsset(projectId, projectCloudId, asset)) {
          downloaded++;
        }
      } catch (e, st) {
        // Un archivo que falle no deja sin bajar el resto.
        await ErrorLog.record(
          e,
          st,
          context: 'Bajar ${asset['entity_type']} ${asset['entity_key']}',
        );
      }
    }

    // Los trazos, después: van junto a la ruta actual de su imagen, que puede
    // haber cambiado en esta misma pasada (versión nueva con otro nombre).
    for (final asset in strokes) {
      try {
        if (await _hydrateStrokes(projectId, projectCloudId, asset)) {
          downloaded++;
        }
      } catch (e, st) {
        await ErrorLog.record(
          e,
          st,
          context: 'Bajar trazos ${asset['entity_key']}',
        );
      }
    }

    return downloaded;
  }

  /// Escribe los trazos de un boceto junto a su imagen. Devuelve si los bajó.
  Future<bool> _hydrateStrokes(
    int projectId,
    String projectCloudId,
    Map<String, dynamic> asset,
  ) async {
    final parsed = parseSketchStrokesKey(asset['entity_key'] as String? ?? '');
    final storagePath = asset['storage_path'] as String?;
    if (parsed == null || storagePath == null) return false;
    final (imageType, imageKey) = parsed;
    final image = await _localPathOf(projectId, imageType, imageKey);
    if (image == null || !File(image).existsSync()) return false;
    final target = sketchStrokesPathOf(image);
    if (File(target).existsSync() &&
        !await _cloudIsNewer(projectId, projectCloudId, asset, target)) {
      return false;
    }
    final bytes = await _cloud.downloadStorageBytes(storagePath);
    await File(target).writeAsBytes(bytes, flush: true);
    await _markDownloaded(projectId, projectCloudId, asset, target);
    return true;
  }

  /// Ruta local de la imagen de un medio (de los de siempre o de un hueco).
  Future<String?> _localPathOf(
    int projectId,
    String entityType,
    String entityKey,
  ) async {
    final slot = mediaSlotFor(entityType);
    if (slot == null) {
      return _resolveLocalPath(
        projectId: projectId,
        entityType: entityType,
        entityKey: entityKey,
      );
    }
    final parsed = parseMediaSlotKey(entityKey);
    if (parsed == null) return null;
    final (uid, index) = parsed;
    final rows = await _db
        .customSelect(
          slot.selectForProject,
          variables: [Variable.withInt(projectId)],
        )
        .get();
    final row = rows.where((r) => r.read<String?>('uid') == uid).firstOrNull;
    if (row == null) return null;
    final raw = row.read<String?>('path');
    if (!slot.isList) return raw;
    final paths = decodeSlotPaths(raw);
    final at = index ?? 0;
    return at < paths.length ? paths[at] : null;
  }

  /// Baja un medio y lo coloca. Devuelve si lo bajó.
  Future<bool> _hydrateAsset(
    int projectId,
    String projectCloudId,
    Map<String, dynamic> asset,
  ) async {
    final entityType = asset['entity_type'] as String?;
    final entityKey = asset['entity_key'] as String?;
    if (entityType == null || entityKey == null) return false;

    final slot = mediaSlotFor(entityType);
    if (slot != null) {
      final newPath = await _hydrateSlot(
        projectId,
        projectCloudId,
        slot,
        entityKey,
        asset,
      );
      if (newPath == null) return false;
      await _markDownloaded(projectId, projectCloudId, asset, newPath);
      return true;
    }
    // Tipos que ya no se usan (p. ej. la referencia principal subida como
    // imagen aparte): bajarlos solo crearía copias.
    if (!_legacyTypes.contains(entityType)) return false;
    final deliveryUrl = asset['delivery_url'] as String?;
    final publicId = asset['public_id'] as String?;
    if (deliveryUrl == null || publicId == null) return false;

    final localPath = await _resolveLocalPath(
      projectId: projectId,
      entityType: entityType,
      entityKey: entityKey,
    );
    if (localPath != null &&
        File(localPath).existsSync() &&
        !await _cloudIsNewer(projectId, projectCloudId, asset, localPath)) {
      return false;
    }

    // La ruta llegó de otro equipo, pero la nube tiene justo lo que se subió
    // desde aquí: se vuelve al original en vez de bajar una copia.
    final original = await _ownUploadStillCurrent(projectId, asset);
    if (original != null) {
      await _applyLocalPath(
        projectId: projectId,
        entityType: entityType,
        entityKey: entityKey,
        newPath: original,
      );
      await _markDownloaded(projectId, projectCloudId, asset, original);
      return true;
    }

    final ext = p.extension(publicId);
    final safeExt = ext.isEmpty ? '.jpg' : ext;
    // Con la versión en el nombre: una nueva no pisa la ruta de la anterior
    // (la pantalla la tendría en caché) y queda claro cuál es cuál.
    final fileName =
        '${entityType}_${entityKey.hashCode.abs()}${_versionSuffix(asset)}'
                '$safeExt'
            .replaceAll(':', '_');
    final newPath = await _cloud.downloadToLocal(
      localProjectId: projectId,
      deliveryUrl: deliveryUrl,
      subfolder: _subfolderFor(entityType),
      fileName: fileName,
    );
    if (newPath == null) return false;

    await _applyLocalPath(
      projectId: projectId,
      entityType: entityType,
      entityKey: entityKey,
      newPath: newPath,
    );
    await _markDownloaded(projectId, projectCloudId, asset, newPath);
    _deleteReplacedDownload(localPath, newPath, entityType);
    return true;
  }

  /// Si la nube tiene una versión de este medio distinta de la que había la
  /// última vez que coincidió con el archivo de aquí, y aquí no se ha tocado
  /// desde entonces. Si se tocó aquí, gana lo de aquí (es lo que se subirá).
  Future<bool> _cloudIsNewer(
    int projectId,
    String projectCloudId,
    Map<String, dynamic> asset,
    String localPath,
  ) async {
    final cloudHash = asset['content_hash'] as String?;
    if (cloudHash == null) return false;
    final row = await (_db.select(_db.pendingMediaUploads)..where(
          (t) =>
              t.projectId.equals(projectId) &
              t.entityType.equals(asset['entity_type'] as String) &
              t.entityKey.equals(asset['entity_key'] as String),
        ))
        .getSingleOrNull();
    if (row == null) {
      // Sin historia (bajado o subido antes de las versiones): lo de aquí
      // se toma como la versión de la nube.
      await _markDownloaded(projectId, projectCloudId, asset, localPath);
      return false;
    }
    if (row.remoteHash == cloudHash) return false;
    if (row.status != 'done' || row.localPath != localPath) return false;
    if (row.remoteHash == null) {
      // Fila de antes de las versiones: ahora se sabe cuál es la de la nube.
      await (_db.update(_db.pendingMediaUploads)
            ..where((t) => t.id.equals(row.id)))
          .write(PendingMediaUploadsCompanion(remoteHash: Value(cloudHash)));
      return false;
    }
    final unchangedHere =
        row.fileStamp == null || row.fileStamp == mediaFileStamp(localPath);
    return unchangedHere;
  }

  /// El archivo que este equipo subió para este medio, si la nube sigue
  /// teniendo esa misma subida (mismo `public_id` o ruta de Storage) y el
  /// archivo sigue aquí. Una versión nueva de otro equipo lleva otro id.
  Future<String?> _ownUploadStillCurrent(
    int projectId,
    Map<String, dynamic> asset,
  ) async {
    final cloudIds = {
      asset['public_id'] as String?,
      asset['storage_path'] as String?,
    }..remove(null);
    if (cloudIds.isEmpty) return null;
    final row = await (_db.select(_db.pendingMediaUploads)..where(
          (t) =>
              t.projectId.equals(projectId) &
              t.entityType.equals(asset['entity_type'] as String) &
              t.entityKey.equals(asset['entity_key'] as String),
        ))
        .getSingleOrNull();
    if (row == null ||
        row.status != 'done' ||
        !cloudIds.contains(row.publicId)) {
      return null;
    }
    final cloudHash = asset['content_hash'] as String?;
    if (row.remoteHash != null &&
        cloudHash != null &&
        row.remoteHash != cloudHash) {
      return null;
    }
    return File(row.localPath).existsSync() ? row.localPath : null;
  }

  /// Lo que se acaba de bajar ya está en la nube: se anota como subido desde
  /// esta ruta para que la cola no lo vuelva a subir (la copia que llega no
  /// es idéntica al original y lo sustituiría por una recomprimida).
  Future<void> _markDownloaded(
    int projectId,
    String projectCloudId,
    Map<String, dynamic> asset,
    String localPath,
  ) async {
    final entityType = asset['entity_type'] as String;
    final entityKey = asset['entity_key'] as String;
    await (_db.delete(_db.pendingMediaUploads)..where(
          (t) =>
              t.projectId.equals(projectId) &
              t.entityType.equals(entityType) &
              t.entityKey.equals(entityKey),
        ))
        .go();
    await _db
        .into(_db.pendingMediaUploads)
        .insert(
          PendingMediaUploadsCompanion.insert(
            projectId: projectId,
            projectCloudId: Value(projectCloudId),
            entityType: entityType,
            entityKey: entityKey,
            localPath: localPath,
            publicId: Value(
              asset['public_id'] as String? ?? asset['storage_path'] as String?,
            ),
            status: const Value('done'),
            fileStamp: Value(mediaFileStamp(localPath)),
            remoteHash: Value(asset['content_hash'] as String?),
          ),
        );
  }

  static const _legacyTypes = {
    MediaEntityType.moodboard,
    MediaEntityType.shotReference,
    MediaEntityType.site,
    MediaEntityType.location,
    MediaEntityType.shootDocument,
    MediaEntityType.projectCover,
  };

  Future<int> repairDuplicatePrimaryReferences(int projectId) =>
      repair_refs.repairDuplicatePrimaryReferences(_db, projectId);


  String _subfolderFor(String entityType) {
    return switch (entityType) {
      MediaEntityType.moodboard => 'visual_bible/moodboard',
      MediaEntityType.shotReference => 'references',
      MediaEntityType.site => 'sites/cloud',
      MediaEntityType.location => 'locations/cloud',
      MediaEntityType.shootDocument => 'shoot_documents/cloud',
      MediaEntityType.projectCover => 'cover',
      _ => 'cloud_cache',
    };
  }

  Future<String?> _resolveLocalPath({
    required int projectId,
    required String entityType,
    required String entityKey,
  }) async {
    return _lookupExistingPath(
      projectId: projectId,
      entityType: entityType,
      entityKey: entityKey,
    );
  }

  Future<String?> _lookupExistingPath({
    required int projectId,
    required String entityType,
    required String entityKey,
  }) async {
    final uid = MediaEntityKeys.uidOf(entityKey);
    if (uid != null) {
      return (await _rowByUid(projectId, entityType, uid))?.path;
    }
    if (entityType == MediaEntityType.moodboard) {
      final parsed = _parseMoodboardKey(entityKey);
      if (parsed == null) return null;
      final (groupKey, sortOrder) = parsed;
      final images = await (_db.select(_db.moodboardImages)
            ..where((m) => m.projectId.equals(projectId)))
          .get();
      if (groupKey == null) {
        final img = images.cast<MoodboardImage?>().firstWhere(
              (m) => m!.sortOrder == sortOrder && m.groupId == null,
              orElse: () => null,
            );
        return img?.imagePath;
      }
      final groups = await (_db.select(_db.moodboardGroups)
            ..where((g) => g.projectId.equals(projectId)))
          .get();
      final group = groups.cast<MoodboardGroup?>().firstWhere(
            (g) => g != null && 'mbg:${g.sortOrder}:${g.name}' == groupKey,
            orElse: () => null,
          );
      if (group == null) return null;
      final img = images.cast<MoodboardImage?>().firstWhere(
            (m) => m!.groupId == group.id && m.sortOrder == sortOrder,
            orElse: () => null,
          );
      return img?.imagePath;
    }

    if (entityType == MediaEntityType.projectCover) {
      final project = await _db.getProject(projectId);
      return project?.coverImagePath;
    }

    if (entityType == MediaEntityType.shotReference) {
      final shotKey = _extractAfterPrefix(entityKey, 'shot:');
      final sortOrder = _extractTrailingInt(entityKey, 'ref:');
      if (shotKey == null || sortOrder == null) return null;
      final parts = shotKey.split(':ref:');
      final key = parts.first;
      final shot = await _findShotByKey(projectId, key);
      if (shot == null) return null;
      final refs = await (_db.select(_db.shotReferences)
            ..where((r) => r.shotId.equals(shot.id)))
          .get();
      final ref = refs.cast<ShotReference?>().firstWhere(
            (r) => r!.sortOrder == sortOrder,
            orElse: () => null,
          );
      return ref?.imagePath;
    }

    return null;
  }

  Future<void> _applyLocalPath({
    required int projectId,
    required String entityType,
    required String entityKey,
    required String newPath,
  }) async {
    final uid = MediaEntityKeys.uidOf(entityKey);
    if (uid != null) {
      final row = await _rowByUid(projectId, entityType, uid);
      final table = _uidTables[entityType];
      if (row != null && table != null) {
        await _db.customUpdate(
          'UPDATE ${table.table} SET image_path = ? WHERE id = ?',
          variables: [Variable.withString(newPath), Variable.withInt(row.id)],
          updates: {table.info(_db)},
        );
        // Si era la principal del plano, la principal la sigue.
        if (entityType == MediaEntityType.shotReference) {
          await _db.customUpdate(
            'UPDATE shots SET reference_image_path = ? '
            'WHERE reference_image_path = ? AND id = '
            '(SELECT shot_id FROM shot_references WHERE id = ?)',
            variables: [
              Variable.withString(newPath),
              Variable.withString(row.path),
              Variable.withInt(row.id),
            ],
            updates: {_db.shots},
          );
        }
      }
      return;
    }
    if (entityType == MediaEntityType.moodboard) {
      final parsed = _parseMoodboardKey(entityKey);
      if (parsed == null) return;
      final (groupKey, sortOrder) = parsed;
      final images = await (_db.select(_db.moodboardImages)
            ..where((m) => m.projectId.equals(projectId)))
          .get();
      MoodboardImage? target;
      if (groupKey == null) {
        target = images.cast<MoodboardImage?>().firstWhere(
              (m) => m!.sortOrder == sortOrder && m.groupId == null,
              orElse: () => null,
            );
      } else {
        final groups = await (_db.select(_db.moodboardGroups)
              ..where((g) => g.projectId.equals(projectId)))
            .get();
        final group = groups.cast<MoodboardGroup?>().firstWhere(
              (g) => g != null && 'mbg:${g.sortOrder}:${g.name}' == groupKey,
              orElse: () => null,
            );
        if (group != null) {
          target = images.cast<MoodboardImage?>().firstWhere(
                (m) => m!.groupId == group.id && m.sortOrder == sortOrder,
                orElse: () => null,
              );
        }
      }
      if (target != null) {
        await (_db.update(_db.moodboardImages)
              ..where((m) => m.id.equals(target!.id)))
            .write(MoodboardImagesCompanion(imagePath: Value(newPath)));
      }
      return;
    }

    if (entityType == MediaEntityType.projectCover) {
      final project = await _db.getProject(projectId);
      if (project != null) {
        await _db.updateProject(
          project.copyWith(coverImagePath: Value(newPath)),
        );
      }
      return;
    }

    if (entityType == MediaEntityType.shotReference) {
      final shotKey = _extractAfterPrefix(entityKey, 'shot:');
      final sortOrder = _extractTrailingInt(entityKey, 'ref:');
      if (shotKey == null || sortOrder == null) return;
      final key = shotKey.split(':ref:').first;
      final shot = await _findShotByKey(projectId, key);
      if (shot == null) return;
      final refs = await (_db.select(_db.shotReferences)
            ..where((r) => r.shotId.equals(shot.id)))
          .get();
      final ref = refs.cast<ShotReference?>().firstWhere(
            (r) => r!.sortOrder == sortOrder,
            orElse: () => null,
          );
      if (ref != null) {
        await (_db.update(_db.shotReferences)
              ..where((r) => r.id.equals(ref.id)))
            .write(ShotReferencesCompanion(imagePath: Value(newPath)));
      }
    }
  }

  (String?, int)? _parseMoodboardKey(String entityKey) {
    if (!entityKey.startsWith('moodboard:')) return null;
    final rest = entityKey.substring('moodboard:'.length);
    final lastColon = rest.lastIndexOf(':');
    if (lastColon < 0) return null;
    final sortOrder = int.tryParse(rest.substring(lastColon + 1));
    if (sortOrder == null) return null;
    final groupPart = rest.substring(0, lastColon);
    if (groupPart == 'ungrouped') return (null, sortOrder);
    return (groupPart, sortOrder);
  }

  String? _extractAfterPrefix(String key, String prefix) {
    if (!key.startsWith(prefix)) return null;
    return key.substring(prefix.length);
  }

  int? _extractTrailingInt(String key, String segment) {
    final idx = key.lastIndexOf(segment);
    if (idx < 0) return null;
    return int.tryParse(key.substring(idx + segment.length));
  }

  Future<Shot?> _findShotByKey(int projectId, String shotKey) async {
    // shotKey format: scene:3:2
    final parts = shotKey.split(':');
    if (parts.length < 3 || parts[0] != 'scene') return null;
    final sceneNum = int.tryParse(parts[1]);
    final shotNum = int.tryParse(parts[2]);
    if (sceneNum == null || shotNum == null) return null;

    final scenes = await (_db.select(_db.scenes)
          ..where(
            (s) => s.projectId.equals(projectId) & s.number.equals(sceneNum),
          ))
        .get();
    if (scenes.isEmpty) return null;
    final sceneId = scenes.first.id;

    final shots = await (_db.select(_db.shots)
          ..where(
            (s) =>
                s.projectId.equals(projectId) &
                s.sceneId.equals(sceneId) &
                s.number.equals(shotNum),
          ))
        .get();
    return shots.isEmpty ? null : shots.first;
  }

  /// Tablas de imágenes con uid y cómo llegar a su proyecto.
  static final _uidTables = <String, _UidTable>{
    MediaEntityType.moodboard: _UidTable(
      'moodboard_images',
      'SELECT i.id, i.image_path FROM moodboard_images i '
          'WHERE i.project_id = ? AND i.uid = ?',
      (db) => db.moodboardImages,
    ),
    MediaEntityType.shotReference: _UidTable(
      'shot_references',
      'SELECT i.id, i.image_path FROM shot_references i '
          'JOIN shots s ON s.id = i.shot_id '
          'WHERE s.project_id = ? AND i.uid = ?',
      (db) => db.shotReferences,
    ),
    MediaEntityType.site: _UidTable(
      'site_images',
      'SELECT i.id, i.image_path FROM site_images i '
          'JOIN location_sites s ON s.id = i.site_id '
          'WHERE s.project_id = ? AND i.uid = ?',
      (db) => db.siteImages,
    ),
    MediaEntityType.location: _UidTable(
      'location_images',
      'SELECT i.id, i.image_path FROM location_images i '
          'JOIN location_base_plans b ON b.id = i.location_id '
          'WHERE b.project_id = ? AND i.uid = ?',
      (db) => db.locationImages,
    ),
  };

  Future<({int id, String path})?> _rowByUid(
    int projectId,
    String entityType,
    String uid,
  ) async {
    final table = _uidTables[entityType];
    if (table == null) return null;
    final row = await _db
        .customSelect(
          table.select,
          variables: [Variable.withInt(projectId), Variable.withString(uid)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    return (id: row.read<int>('id'), path: row.read<String>('image_path'));
  }

  /// Baja el archivo de un hueco (storyboard, boceto de luz, guion…) y lo
  /// coloca en su fila por el uid. Devuelve la ruta bajada, o nulo.
  Future<String?> _hydrateSlot(
    int projectId,
    String projectCloudId,
    MediaSlot slot,
    String entityKey,
    Map<String, dynamic> asset,
  ) async {
    final parsed = parseMediaSlotKey(entityKey);
    if (parsed == null) return null;
    final (uid, index) = parsed;
    final rows = await _db
        .customSelect(
          slot.selectForProject,
          variables: [Variable.withInt(projectId)],
        )
        .get();
    final row = rows.where((r) => r.read<String?>('uid') == uid).firstOrNull;
    if (row == null) return null;
    final id = row.read<int>('id');
    final raw = row.read<String?>('path');

    List<String> list() => decodeSlotPaths(raw);

    final current = slot.isList
        ? (index != null && index < list().length ? list()[index] : null)
        : raw;
    if (current != null &&
        current.isNotEmpty &&
        File(current).existsSync() &&
        !await _cloudIsNewer(projectId, projectCloudId, asset, current)) {
      return null;
    }

    final original = await _ownUploadStillCurrent(projectId, asset);
    final String? newPath;
    if (original != null) {
      newPath = original;
    } else if (slot.kind == MediaKind.file) {
      final storagePath = asset['storage_path'] as String?;
      if (storagePath == null) return null;
      final meta = asset['metadata'];
      final name = meta is Map && meta['file_name'] is String
          ? meta['file_name'] as String
          : p.basename(storagePath);
      newPath = await _cloud.downloadStorageFile(
        localProjectId: projectId,
        storagePath: storagePath,
        subfolder: slot.subfolder,
        fileName: name,
      );
    } else {
      final url = asset['delivery_url'] as String?;
      if (url == null) return null;
      newPath = await _cloud.downloadToLocal(
        localProjectId: projectId,
        deliveryUrl: url,
        subfolder: slot.subfolder,
        fileName:
            '${slot.entityType}_$uid${index ?? ''}${_versionSuffix(asset)}.jpg',
      );
    }
    if (newPath == null) return null;

    final String value;
    if (slot.isList) {
      final paths = list();
      final at = index ?? 0;
      while (paths.length <= at) {
        paths.add('');
      }
      paths[at] = newPath;
      value = jsonEncode(paths);
    } else {
      value = newPath;
    }
    await _db.customUpdate(
      'UPDATE ${slot.table} SET ${slot.column} = ? WHERE id = ?',
      variables: [Variable.withString(value), Variable.withInt(id)],
      updates: {
        for (final t in _db.allTables)
          if (t.actualTableName == slot.table) t,
      },
    );
    if (current != null && original == null) {
      _deleteReplacedDownload(current, newPath, slot.entityType);
    }
    return newPath;
  }

  /// `_<8 primeros de la huella>` del medio, o vacío si no la trae.
  static String _versionSuffix(Map<String, dynamic> asset) {
    final hash = asset['content_hash'] as String?;
    return hash == null || hash.length < 8 ? '' : '_${hash.substring(0, 8)}';
  }

  /// Borra la versión anterior si la bajó la app (no un archivo del usuario).
  static void _deleteReplacedDownload(
    String? old,
    String replacement,
    String entityType,
  ) {
    if (old == null || old == replacement) return;
    if (!p.basename(old).startsWith('${entityType}_')) return;
    // Con sus trazos: los de la versión nueva los pone después la pasada de
    // trazos, junto a la imagen nueva.
    try {
      final strokes = File(sketchStrokesPathOf(old));
      if (strokes.existsSync()) strokes.deleteSync();
      File(old).deleteSync();
    } catch (_) {}
  }
}

class _UidTable {
  final String table;
  final String select;
  final TableInfo Function(AppDatabase) info;

  const _UidTable(this.table, this.select, this.info);
}
