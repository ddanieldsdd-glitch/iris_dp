import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_storage_config.dart';
import 'legacy_storage_discovery.dart';

class StorageMigrationResult {
  final bool success;
  final String message;
  final int projectsCopied;
  final int pathsUpdated;

  const StorageMigrationResult({
    required this.success,
    required this.message,
    this.projectsCopied = 0,
    this.pathsUpdated = 0,
  });
}

/// Mueve base de datos y archivos de un almacenamiento legacy al actual.
abstract final class LocalStorageMigrationService {
  LocalStorageMigrationService._();

  static const _dismissedPrefix = 'iris_reloc_dismiss_';

  static Future<bool> wasProposalDismissed(String sourceDatabasePath) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$_dismissedPrefix$sourceDatabasePath') ?? false;
  }

  static Future<void> dismissProposal(String sourceDatabasePath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_dismissedPrefix$sourceDatabasePath', true);
  }

  static Future<StorageMigrationResult> migrateToCurrentStorage(
    StorageRelocationProposal proposal,
  ) async {
    if (!AppStorageConfig.isConfigured) {
      return const StorageMigrationResult(
        success: false,
        message: 'El almacenamiento no está configurado.',
      );
    }

    final target = AppStorageConfig.current!;
    final source = proposal.source;
    final sourceDb = File(source.databasePath);
    if (!await sourceDb.exists()) {
      return const StorageMigrationResult(
        success: false,
        message: 'No se encontró la base de datos de origen.',
      );
    }

    try {
      final targetDbFile = File(target.databaseFile);
      if (await targetDbFile.exists()) {
        final sourceModified = await sourceDb.lastModified();
        final targetModified = await targetDbFile.lastModified();
        if (targetModified.isAfter(sourceModified)) {
          return StorageMigrationResult(
            success: false,
            message: 'El almacenamiento actual tiene datos más recientes '
                '(${targetModified.toLocal()}). '
                'No se ha sobrescrito nada.',
          );
        }
        final backup = File(
          '${target.databaseFile}.pre-migration-${DateTime.now().millisecondsSinceEpoch}',
        );
        await targetDbFile.copy(backup.path);
      }

      await Directory(p.dirname(target.databaseFile)).create(recursive: true);
      await sourceDb.copy(target.databaseFile);

      final projectsCopied = await _copyProjectFolders(
        source.documentsPath,
        target.documentsPath,
      );

      final pathsUpdated = await _rewriteStoredPaths(
        databasePath: target.databaseFile,
        oldRoot: source.documentsPath,
        newRoot: target.documentsPath,
      );

      return StorageMigrationResult(
        success: true,
        message: 'Proyectos movidos a ${target.documentsPath}. '
            'Reinicia la app para ver todo el contenido.',
        projectsCopied: projectsCopied,
        pathsUpdated: pathsUpdated,
      );
    } catch (e) {
      return StorageMigrationResult(
        success: false,
        message: 'Error al mover datos: $e',
      );
    }
  }

  static Future<int> _copyProjectFolders(String sourceDocs, String targetDocs) async {
    final sourceProjects = Directory(p.join(sourceDocs, 'projects'));
    if (!await sourceProjects.exists()) return 0;

    final targetProjects = Directory(p.join(targetDocs, 'projects'));
    await targetProjects.create(recursive: true);

    var copied = 0;
    await for (final entity in sourceProjects.list()) {
      if (entity is! Directory) continue;
      final dest = Directory(p.join(targetProjects.path, p.basename(entity.path)));
      if (await dest.exists()) {
        await dest.delete(recursive: true);
      }
      await _copyDirectory(entity, dest);
      copied++;
    }
    return copied;
  }

  static Future<void> _copyDirectory(Directory source, Directory dest) async {
    await dest.create(recursive: true);
    await for (final entity in source.list(recursive: false)) {
      final newPath = p.join(dest.path, p.basename(entity.path));
      if (entity is Directory) {
        await _copyDirectory(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }

  static Future<int> _rewriteStoredPaths({
    required String databasePath,
    required String oldRoot,
    required String newRoot,
  }) async {
    if (oldRoot == newRoot) return 0;

    const tablesColumns = [
      ('projects', 'cover_image_path'),
      ('projects', 'script_file_path'),
      ('shots', 'reference_image_path'),
      ('shots', 'camera_plan_image_path'),
      ('shot_references', 'image_path'),
      ('location_sites', 'scan_path'),
      ('site_images', 'image_path'),
      ('location_base_plans', 'image_path'),
      ('location_base_plans', 'scan_path'),
      ('location_images', 'image_path'),
      ('project_annotated_pdfs', 'pdf_path'),
      ('bible_section_evidence', 'image_path'),
      ('lighting_setups', 'reference_image_path'),
      ('camera_tests', 'image_paths'),
      ('moodboard_images', 'image_path'),
      ('optics_lab_samples', 'image_path'),
    ];

    var total = 0;
    for (final (table, column) in tablesColumns) {
      final sql =
          "UPDATE $table SET $column = REPLACE($column, '${_escapeSql(oldRoot)}', '${_escapeSql(newRoot)}') "
          "WHERE $column LIKE '${_escapeSql(oldRoot)}%';";
      final result = await Process.run('sqlite3', [databasePath, sql]);
      if (result.exitCode == 0) {
        final changed = int.tryParse(result.stdout.toString().trim()) ?? 0;
        total += changed;
      }
    }
    return total;
  }

  static String _escapeSql(String value) => value.replaceAll("'", "''");
}
