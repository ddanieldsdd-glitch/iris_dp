import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/foundation.dart' show compute;
import 'package:path/path.dart' as p;

import '../../../core/database/app_database.dart';
import '../../../core/storage/app_storage_config.dart';
import '../../../core/sync/project_content_bundle.dart';
import '../../../core/utils/image_fingerprint.dart';

/// Una copia del guion técnico (todo el contenido del proyecto) de justo
/// antes de importar un Word: para volver atrás si la importación no era.
class ImportSnapshot {
  final File file;
  final DateTime at;

  /// El Word que se iba a importar, o por qué se guardó.
  final String reason;

  const ImportSnapshot({
    required this.file,
    required this.at,
    required this.reason,
  });
}

/// Copias por proyecto que se guardan: las más viejas se borran.
const _keep = 8;

Future<Directory> _dir() async {
  Directory root;
  try {
    root = await AppStorageConfig.appDataDirectory();
  } catch (_) {
    // Sin carpetas elegidas: las de siempre de la app.
    root = Directory((await AppStorageConfig.defaultPaths()).appDataPath);
  }
  final dir = Directory(p.join(root.path, 'copias_guion_tecnico'));
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Guarda el contenido del proyecto tal como está ahora.
Future<ImportSnapshot> saveImportSnapshot(
  AppDatabase db,
  int projectId, {
  required String reason,
}) async {
  final bundle = await ProjectContentBundle.export(db, projectId);
  final at = DateTime.now();
  final dir = await _dir();
  final file = File(
    p.join(dir.path, 'p${projectId}_${at.millisecondsSinceEpoch}.json'),
  );
  await file.writeAsString(
    jsonEncode({
      'projectId': projectId,
      'at': at.toIso8601String(),
      'reason': reason,
      'bundle': bundle,
    }),
    flush: true,
  );
  // Solo las últimas.
  final all = await listImportSnapshots(projectId);
  for (final old in all.skip(_keep)) {
    try {
      await old.file.delete();
    } catch (_) {}
  }
  return ImportSnapshot(file: file, at: at, reason: reason);
}

/// Copias del proyecto, la más reciente primero.
Future<List<ImportSnapshot>> listImportSnapshots(int projectId) async {
  final dir = await _dir();
  final out = <ImportSnapshot>[];
  await for (final entry in dir.list()) {
    if (entry is! File) continue;
    final name = p.basename(entry.path);
    if (!name.startsWith('p${projectId}_') || !name.endsWith('.json')) {
      continue;
    }
    final ms = int.tryParse(
      name.substring('p${projectId}_'.length, name.length - 5),
    );
    if (ms == null) continue;
    String reason = '';
    try {
      final head = jsonDecode(await entry.readAsString());
      if (head is Map) reason = head['reason'] as String? ?? '';
    } catch (_) {
      continue;
    }
    out.add(
      ImportSnapshot(
        file: entry,
        at: DateTime.fromMillisecondsSinceEpoch(ms),
        reason: reason,
      ),
    );
  }
  out.sort((a, b) => b.at.compareTo(a.at));
  return out;
}

/// Vuelve el proyecto a como estaba en [snapshot]. Antes guarda lo de ahora,
/// por si también se quiere deshacer esto.
Future<void> restoreImportSnapshot(
  AppDatabase db,
  int projectId,
  ImportSnapshot snapshot,
) async {
  final data = jsonDecode(await snapshot.file.readAsString());
  if (data is! Map || data['bundle'] is! Map) {
    throw const FormatException('La copia está dañada.');
  }
  await saveImportSnapshot(db, projectId, reason: 'Antes de volver atrás');
  await ProjectContentBundle.importBundle(
    db,
    projectId,
    Map<String, dynamic>.from(data['bundle'] as Map),
  );
  await db.touchProjectContent(projectId);
}

/// Quita las imágenes de referencia repetidas de cada plano (la misma foto
/// dos veces, p. ej. la original y la que traía un Word). Se queda la de
/// más calidad. Devuelve cuántas quitó.
Future<int> removeDuplicateReferences(AppDatabase db, int projectId) async {
  var removed = 0;
  final shots = await db.getShotsForProject(projectId);
  for (final shot in shots) {
    final refs = await db.watchReferencesForShot(shot.id).first;
    if (refs.length < 2) continue;
    final prints = <ShotReference, String>{};
    for (final ref in refs) {
      final fp = await compute(visualFingerprintOfFile, ref.imagePath);
      if (fp != null) prints[ref] = fp;
    }
    // Primero las que mejor se conservan: las nuestras y las más grandes.
    int weight(ShotReference r) {
      final f = File(r.imagePath);
      final size = f.existsSync() ? f.lengthSync() : 0;
      return (r.source == 'document' ? 0 : 1 << 40) + size;
    }

    final ordered = prints.keys.toList()
      ..sort((a, b) => weight(b).compareTo(weight(a)));
    final kept = <ShotReference>[];
    final replaced = <String, String>{};
    for (final ref in ordered) {
      final twin = kept
          .where((k) => sameImage(prints[k]!, prints[ref]!))
          .firstOrNull;
      if (twin == null) {
        kept.add(ref);
        continue;
      }
      await db.deleteShotReference(ref.id);
      replaced[ref.imagePath] = twin.imagePath;
      removed++;
    }
    // La principal del plano sigue a la que se queda.
    final main = shot.referenceImagePath;
    if (main != null && replaced.containsKey(main)) {
      await db.updateShotFields(
        shot.id,
        ShotsCompanion(referenceImagePath: Value(replaced[main])),
      );
    }
  }
  if (removed > 0) await db.touchProjectContent(projectId);
  return removed;
}
