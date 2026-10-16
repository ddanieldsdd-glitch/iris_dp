import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;

import '../database/app_database.dart';
import 'cloud_media_service.dart';
import 'media_entity_keys.dart';
import 'media_entity_types.dart';
import 'media_slots.dart';

/// Descarga imágenes remotas y actualiza rutas locales en Drift.
class MediaHydrateService {
  final AppDatabase _db;
  final CloudMediaService _cloud;

  MediaHydrateService(this._db, this._cloud);

  Future<int> hydrateProject(int projectId, String projectCloudId) async {
    final assets = await _cloud.fetchProjectAssets(projectCloudId);
    var downloaded = 0;

    for (final asset in assets) {
      final entityType = asset['entity_type'] as String?;
      final entityKey = asset['entity_key'] as String?;
      final slot = entityType == null ? null : mediaSlotFor(entityType);
      if (slot != null && entityKey != null) {
        if (await _hydrateSlot(projectId, slot, entityKey, asset)) {
          downloaded++;
        }
        continue;
      }
      final deliveryUrl = asset['delivery_url'] as String?;
      final publicId = asset['public_id'] as String?;
      if (entityType == null ||
          entityKey == null ||
          deliveryUrl == null ||
          publicId == null) {
        continue;
      }

      final localPath = await _resolveLocalPath(
        projectId: projectId,
        entityType: entityType,
        entityKey: entityKey,
      );

      if (localPath != null && File(localPath).existsSync()) continue;

      final ext = p.extension(publicId);
      final safeExt = ext.isEmpty ? '.jpg' : ext;
      final fileName =
          '${entityType}_${entityKey.hashCode.abs()}$safeExt'.replaceAll(':', '_');

      final subfolder = _subfolderFor(entityType);
      final newPath = await _cloud.downloadToLocal(
        localProjectId: projectId,
        deliveryUrl: deliveryUrl,
        subfolder: subfolder,
        fileName: fileName,
      );
      if (newPath == null) continue;

      await _applyLocalPath(
        projectId: projectId,
        entityType: entityType,
        entityKey: entityKey,
        newPath: newPath,
      );
      downloaded++;
    }

    return downloaded;
  }

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
  /// coloca en su fila por el uid. Devuelve si lo bajó.
  Future<bool> _hydrateSlot(
    int projectId,
    MediaSlot slot,
    String entityKey,
    Map<String, dynamic> asset,
  ) async {
    final parsed = parseMediaSlotKey(entityKey);
    if (parsed == null) return false;
    final (uid, index) = parsed;
    final rows = await _db
        .customSelect(
          slot.selectForProject,
          variables: [Variable.withInt(projectId)],
        )
        .get();
    final row = rows.where((r) => r.read<String?>('uid') == uid).firstOrNull;
    if (row == null) return false;
    final id = row.read<int>('id');
    final raw = row.read<String?>('path');

    List<String> list() => decodeSlotPaths(raw);

    final current = slot.isList
        ? (index != null && index < list().length ? list()[index] : null)
        : raw;
    if (current != null && current.isNotEmpty && File(current).existsSync()) {
      return false;
    }

    final String? newPath;
    if (slot.kind == MediaKind.file) {
      final storagePath = asset['storage_path'] as String?;
      if (storagePath == null) return false;
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
      if (url == null) return false;
      newPath = await _cloud.downloadToLocal(
        localProjectId: projectId,
        deliveryUrl: url,
        subfolder: slot.subfolder,
        fileName: '${slot.entityType}_$uid${index ?? ''}.jpg',
      );
    }
    if (newPath == null) return false;

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
    return true;
  }
}

class _UidTable {
  final String table;
  final String select;
  final TableInfo Function(AppDatabase) info;

  const _UidTable(this.table, this.select, this.info);
}
