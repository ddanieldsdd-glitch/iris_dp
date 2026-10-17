import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'project_content_bundle.dart';

/// Tablas de la mezcla, en SQL directo (sin generar código): la base de cada
/// proyecto y el historial de lo que la mezcla descartó.
abstract final class SyncMergeTables {
  static Future<void> create(AppDatabase db) async {
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS sync_content_bases (
        project_id INTEGER NOT NULL PRIMARY KEY,
        bundle_gz TEXT NOT NULL,
        saved_at INTEGER NOT NULL
      )''');
    await db.customStatement('''
      CREATE TABLE IF NOT EXISTS sync_conflict_log (
        id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        collection TEXT NOT NULL,
        element_uid TEXT,
        element_label TEXT,
        field TEXT,
        kept_value TEXT,
        discarded_value TEXT,
        discarded_side TEXT NOT NULL,
        discarded_device TEXT,
        created_at INTEGER NOT NULL
      )''');
    await db.customStatement(
      'CREATE INDEX IF NOT EXISTS idx_sync_conflict_log_project '
      'ON sync_conflict_log (project_id, created_at)',
    );
  }
}

/// El último contenido en el que este equipo y la nube coincidieron, por
/// proyecto: el punto de partida para mezclar lo que cambió en cada lado.
///
/// Se guarda dos veces: como lo exportó este equipo y como estaba en la
/// nube. Es lo mismo, pero hay datos que viajan con los ids locales de cada
/// equipo (biblia, stills, dibujos) y cada lado se compara con el suyo.
class ContentBaseBundles {
  final Map<String, dynamic> local;
  final Map<String, dynamic> cloud;

  const ContentBaseBundles({required this.local, required this.cloud});
}

abstract final class ContentBaseBundleStore {
  static Future<void> save(
    AppDatabase db,
    int projectId, {
    required Map<String, dynamic> local,
    required Map<String, dynamic> cloud,
  }) async {
    final packed = base64Encode(
      gzip.encode(utf8.encode(jsonEncode({'local': local, 'cloud': cloud}))),
    );
    await db.customStatement(
      'INSERT OR REPLACE INTO sync_content_bases '
      '(project_id, bundle_gz, saved_at) VALUES (?, ?, ?)',
      [projectId, packed, DateTime.now().millisecondsSinceEpoch],
    );
  }

  /// La base guardada, solo si corresponde a las huellas de la última
  /// sincronización ([localHash] y [cloudHash]). Si no, no sirve para mezclar.
  static Future<ContentBaseBundles?> load(
    AppDatabase db,
    int projectId, {
    required String localHash,
    required String cloudHash,
  }) async {
    final row = await db
        .customSelect(
          'SELECT bundle_gz FROM sync_content_bases WHERE project_id = ?',
          variables: [Variable.withInt(projectId)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    try {
      final both = jsonDecode(
        utf8.decode(gzip.decode(base64Decode(row.read<String>('bundle_gz')))),
      );
      final local = Map<String, dynamic>.from(both['local'] as Map);
      final cloud = Map<String, dynamic>.from(both['cloud'] as Map);
      if (!ProjectContentBundle.bundleMatchesHash(local, localHash) ||
          !ProjectContentBundle.bundleMatchesHash(cloud, cloudHash)) {
        return null;
      }
      return ContentBaseBundles(local: local, cloud: cloud);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> has(AppDatabase db, int projectId) async =>
      await db
          .customSelect(
            'SELECT 1 FROM sync_content_bases WHERE project_id = ?',
            variables: [Variable.withInt(projectId)],
          )
          .getSingleOrNull() !=
      null;

  static Future<void> clear(AppDatabase db, int projectId) =>
      db.customStatement(
        'DELETE FROM sync_content_bases WHERE project_id = ?',
        [projectId],
      );
}

/// Una edición que la mezcla descartó porque el mismo dato cambió en los dos
/// lados y la otra era más reciente.
class SyncConflictEntry {
  final int? id;
  final int projectId;
  final String collection;
  final String? elementUid;
  final String? elementLabel;

  /// `null`: se decidió el bloque entero (p. ej. toda la biblia).
  final String? field;
  final String? keptValue;
  final String? discardedValue;

  /// `local` o `cloud`.
  final String discardedSide;
  final String? discardedDevice;
  final DateTime createdAt;

  const SyncConflictEntry({
    this.id,
    required this.projectId,
    required this.collection,
    this.elementUid,
    this.elementLabel,
    this.field,
    this.keptValue,
    this.discardedValue,
    required this.discardedSide,
    this.discardedDevice,
    required this.createdAt,
  });
}

abstract final class SyncConflictLog {
  /// Lo descartado se guarda entero hasta este tamaño (una biblia entera
  /// puede ser grande; para recuperarla están las copias de la base).
  static const maxValueChars = 20000;

  static String? _clip(String? v) =>
      v == null || v.length <= maxValueChars ? v : v.substring(0, maxValueChars);

  static Future<void> addAll(
    AppDatabase db,
    Iterable<SyncConflictEntry> entries,
  ) async {
    for (final e in entries) {
      await db.customStatement(
        'INSERT INTO sync_conflict_log (project_id, collection, element_uid, '
        'element_label, field, kept_value, discarded_value, discarded_side, '
        'discarded_device, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          e.projectId,
          e.collection,
          e.elementUid,
          e.elementLabel,
          e.field,
          _clip(e.keptValue),
          _clip(e.discardedValue),
          e.discardedSide,
          e.discardedDevice,
          e.createdAt.millisecondsSinceEpoch,
        ],
      );
    }
  }

  static Future<List<SyncConflictEntry>> list(
    AppDatabase db, {
    int? projectId,
    int limit = 200,
  }) async {
    final rows = await db
        .customSelect(
          'SELECT * FROM sync_conflict_log '
          '${projectId == null ? '' : 'WHERE project_id = ? '}'
          'ORDER BY created_at DESC, id DESC LIMIT ?',
          variables: [
            if (projectId != null) Variable.withInt(projectId),
            Variable.withInt(limit),
          ],
        )
        .get();
    return [
      for (final r in rows)
        SyncConflictEntry(
          id: r.read<int>('id'),
          projectId: r.read<int>('project_id'),
          collection: r.read<String>('collection'),
          elementUid: r.read<String?>('element_uid'),
          elementLabel: r.read<String?>('element_label'),
          field: r.read<String?>('field'),
          keptValue: r.read<String?>('kept_value'),
          discardedValue: r.read<String?>('discarded_value'),
          discardedSide: r.read<String>('discarded_side'),
          discardedDevice: r.read<String?>('discarded_device'),
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            r.read<int>('created_at'),
          ),
        ),
    ];
  }
}
