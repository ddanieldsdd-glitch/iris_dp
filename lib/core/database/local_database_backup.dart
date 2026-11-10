import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;

import '../storage/app_storage_config.dart';
import '../utils/error_log.dart';
import 'app_database.dart';

/// Una copia de la base de datos guardada en este equipo.
class DatabaseCopy {
  final String path;
  final String label;
  final DateTime when;
  final int sizeBytes;

  const DatabaseCopy({
    required this.path,
    required this.label,
    required this.when,
    required this.sizeBytes,
  });

  /// Por qué se hizo, como se enseña al usuario.
  String get title {
    if (label == LocalDatabaseBackup.dailyLabel) return 'Copia diaria';
    if (label == 'antes-de-descargar') return 'Antes de descargar de la nube';
    if (label == 'antes-de-mezclar') return 'Antes de mezclar con la nube';
    if (label == LocalDatabaseBackup.beforeRestoreLabel) {
      return 'Antes de restaurar una copia';
    }
    if (label.startsWith('antes-de-esquema')) {
      return 'Antes de actualizar la app';
    }
    return label.replaceAll('-', ' ');
  }
}

/// Copias de la base de datos local: antes de una operación que reemplaza
/// contenido, como descargar un proyecto de la nube, y una al día.
///
/// Son solo los datos: las imágenes siguen en su carpeta y no se copian.
abstract final class LocalDatabaseBackup {
  /// Copias que se conservan por etiqueta.
  static const keep = 5;

  static const dailyLabel = 'diaria';
  static const dailyKept = 7;
  static const beforeRestoreLabel = 'antes-de-restaurar';

  static const _restoreSuffix = '.restaurar';
  static final _nameParts = RegExp(
    r'^(.*?)-\d{4}-\d{2}-\d{2}(?:-\d{6})?(?:-\d+)?$',
  );

  static Future<String?> _databaseFile([String? override]) async {
    if (override != null) return override;
    if (AppStorageConfig.isConfigured) {
      return AppStorageConfig.current!.databaseFile;
    }
    try {
      return (await AppStorageConfig.defaultPaths()).databaseFile;
    } catch (_) {
      // Sin acceso a las rutas de la app no hay archivo que copiar.
      return null;
    }
  }

  static String _two(int n) => n.toString().padLeft(2, '0');

  static String _day(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  /// Crea `<base>.<label>-<fecha>` junto a la base de datos y devuelve su
  /// ruta. Devuelve `null` si la base no está en disco (p. ej. en tests).
  static Future<String?> create(
    AppDatabase db, {
    required String label,
    int kept = keep,
    @visibleForTesting String? databaseFileOverride,
  }) async {
    final databaseFile = await _databaseFile(databaseFileOverride);
    if (databaseFile == null) return null;
    final source = File(databaseFile);
    if (!source.existsSync()) return null;

    final now = DateTime.now();
    final stamp =
        '${_day(now)}-'
        '${_two(now.hour)}${_two(now.minute)}${_two(now.second)}';
    // Dos descargas en el mismo segundo (dos proyectos en una pasada)
    // generaban el mismo nombre y la segunda fallaba: se numera.
    var target = '$databaseFile.$label-$stamp';
    for (var n = 2; File(target).existsSync(); n++) {
      target = '$databaseFile.$label-$stamp-$n';
    }
    // VACUUM INTO escribe una copia coherente aunque la base esté en uso.
    await db.customStatement('VACUUM INTO ?', [target]);
    _prune(
      p.dirname(databaseFile),
      '${p.basename(databaseFile)}.$label-',
      kept,
    );
    return target;
  }

  static void _prune(String folder, String prefix, int kept) {
    final copies =
        Directory(folder)
            .listSync()
            .whereType<File>()
            .where((f) => p.basename(f.path).startsWith(prefix))
            .toList()
          ..sort((a, b) => b.path.compareTo(a.path));
    for (final old in copies.skip(kept)) {
      try {
        old.deleteSync();
      } catch (e, st) {
        ErrorLog.record(e, st, context: 'Borrar una copia antigua');
      }
    }
  }

  /// La copia del día, si aún no se ha hecho. Con [secondFolder], además se
  /// deja otra allí (un disco o una carpeta de iCloud Drive). Devuelve la
  /// ruta de la copia nueva, o `null` si no tocaba.
  static Future<String?> createDailyIfDue(
    AppDatabase db, {
    String? secondFolder,
    DateTime? now,
    @visibleForTesting String? databaseFileOverride,
  }) async {
    try {
      final databaseFile = await _databaseFile(databaseFileOverride);
      if (databaseFile == null) return null;
      final base = p.basename(databaseFile);
      final today = '$base.$dailyLabel-${_day(now ?? DateTime.now())}';
      final folder = Directory(p.dirname(databaseFile));
      if (!folder.existsSync()) return null;
      final done = folder.listSync().any(
        (f) => p.basename(f.path).startsWith(today),
      );
      if (done) return null;
      final copy = await create(
        db,
        label: dailyLabel,
        kept: dailyKept,
        databaseFileOverride: databaseFileOverride,
      );
      if (copy != null && secondFolder != null && secondFolder.isNotEmpty) {
        await File(copy).copy(p.join(secondFolder, p.basename(copy)));
        _prune(secondFolder, '$base.$dailyLabel-', dailyKept);
      }
      return copy;
    } catch (e, st) {
      await ErrorLog.record(e, st, context: 'Copia diaria');
      return null;
    }
  }

  /// Las copias de este equipo, de la más nueva a la más antigua.
  static Future<List<DatabaseCopy>> list({
    @visibleForTesting String? databaseFileOverride,
  }) async {
    final databaseFile = await _databaseFile(databaseFileOverride);
    if (databaseFile == null) return const [];
    final folder = Directory(p.dirname(databaseFile));
    if (!folder.existsSync()) return const [];
    final prefix = '${p.basename(databaseFile)}.';
    final copies = <DatabaseCopy>[];
    for (final file in folder.listSync().whereType<File>()) {
      final name = p.basename(file.path);
      if (!name.startsWith(prefix) ||
          name.endsWith('-wal') ||
          name.endsWith('-shm') ||
          name.endsWith(_restoreSuffix)) {
        continue;
      }
      final rest = name.substring(prefix.length);
      final stat = file.statSync();
      copies.add(
        DatabaseCopy(
          path: file.path,
          label: _nameParts.firstMatch(rest)?.group(1) ?? rest,
          when: stat.modified,
          sizeBytes: stat.size,
        ),
      );
    }
    copies.sort((a, b) => b.when.compareTo(a.when));
    return copies;
  }

  /// Deja anotado que al abrir la app se vuelva a [copy]: con la base abierta
  /// no se puede cambiar el archivo.
  static Future<void> scheduleRestore(
    DatabaseCopy copy, {
    @visibleForTesting String? databaseFileOverride,
  }) async {
    final databaseFile = await _databaseFile(databaseFileOverride);
    if (databaseFile == null) {
      throw StateError('No se encuentra la base de datos');
    }
    await File(
      '$databaseFile$_restoreSuffix',
    ).writeAsString(copy.path, flush: true);
  }

  /// Antes de abrir la base: si hay una restauración anotada, guarda lo
  /// actual como copia y pone la elegida en su lugar. Devuelve si la hizo.
  static bool applyPendingRestore(String databasePath, {DateTime? now}) {
    final marker = File('$databasePath$_restoreSuffix');
    if (!marker.existsSync()) return false;
    try {
      final chosen = File(marker.readAsStringSync().trim());
      if (!chosen.existsSync()) return false;
      final current = File(databasePath);
      final at = now ?? DateTime.now();
      final stamp =
          '${_day(at)}-${_two(at.hour)}${_two(at.minute)}${_two(at.second)}';
      if (current.existsSync()) {
        final safe = '$databasePath.$beforeRestoreLabel-$stamp';
        current.copySync(safe);
        for (final suffix in ['-wal', '-shm']) {
          final extra = File('$databasePath$suffix');
          if (extra.existsSync()) extra.copySync('$safe$suffix');
        }
      }
      // Los -wal y -shm son de la base que se va.
      for (final suffix in ['-wal', '-shm']) {
        final extra = File('$databasePath$suffix');
        if (extra.existsSync()) extra.deleteSync();
      }
      chosen.copySync(databasePath);
      for (final suffix in ['-wal', '-shm']) {
        final extra = File('${chosen.path}$suffix');
        if (extra.existsSync()) extra.copySync('$databasePath$suffix');
      }
      return true;
    } finally {
      marker.deleteSync();
    }
  }

  /// Tras restaurar, la app no debe creer que la copia coincide con la nube:
  /// la siguiente pasada descargaría encima. Sin punto de partida, cada
  /// proyecto distinto se presenta para elegir qué versión conservar.
  static void forgetSyncBases(void Function(String sql) execute) {
    for (final sql in const [
      'UPDATE projects SET content_sync_base_local = NULL, '
          'content_sync_base_cloud = NULL',
      'DELETE FROM sync_content_bases',
    ]) {
      try {
        execute(sql);
      } catch (e) {
        // Una copia muy antigua puede no tener esa tabla o columna.
        ErrorLog.record(e, null, context: 'Tras restaurar una copia');
      }
    }
  }
}
