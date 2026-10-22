import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;

import '../storage/app_storage_config.dart';
import 'app_database.dart';

/// Copias de la base de datos local antes de una operación que reemplaza
/// contenido, como descargar un proyecto de la nube.
abstract final class LocalDatabaseBackup {
  /// Copias que se conservan por etiqueta.
  static const keep = 5;

  /// Crea `<base>.<label>-<fecha>` junto a la base de datos y devuelve su
  /// ruta. Devuelve `null` si la base no está en disco (p. ej. en tests).
  static Future<String?> create(
    AppDatabase db, {
    required String label,
    @visibleForTesting String? databaseFileOverride,
  }) async {
    final String databaseFile;
    if (databaseFileOverride != null) {
      databaseFile = databaseFileOverride;
    } else if (AppStorageConfig.isConfigured) {
      databaseFile = AppStorageConfig.current!.databaseFile;
    } else {
      try {
        databaseFile = (await AppStorageConfig.defaultPaths()).databaseFile;
      } catch (_) {
        // Sin acceso a las rutas de la app no hay archivo que copiar.
        return null;
      }
    }
    final source = File(databaseFile);
    if (!source.existsSync()) return null;

    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    final stamp =
        '${now.year}-${two(now.month)}-${two(now.day)}-'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
    // Dos descargas en el mismo segundo (dos proyectos en una pasada)
    // generaban el mismo nombre y la segunda fallaba: se numera.
    var target = '$databaseFile.$label-$stamp';
    for (var n = 2; File(target).existsSync(); n++) {
      target = '$databaseFile.$label-$stamp-$n';
    }
    // VACUUM INTO escribe una copia coherente aunque la base esté en uso.
    await db.customStatement('VACUUM INTO ?', [target]);
    _prune(databaseFile, label);
    return target;
  }

  static void _prune(String databaseFile, String label) {
    final prefix = '${p.basename(databaseFile)}.$label-';
    final copies =
        Directory(p.dirname(databaseFile))
            .listSync()
            .whereType<File>()
            .where((f) => p.basename(f.path).startsWith(prefix))
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    for (final old in copies.skip(keep)) {
      try {
        old.deleteSync();
      } catch (_) {}
    }
  }
}
