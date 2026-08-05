import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_storage_config.dart';

/// Resumen de un almacenamiento local candidato (actual u otro).
class StorageLocationSnapshot {
  final String label;
  final String databasePath;
  final String documentsPath;
  final int projectCount;
  final int assetFileCount;
  final int moodboardCount;
  final List<String> projectNames;

  const StorageLocationSnapshot({
    required this.label,
    required this.databasePath,
    required this.documentsPath,
    required this.projectCount,
    required this.assetFileCount,
    required this.moodboardCount,
    required this.projectNames,
  });

  bool get hasProjects => projectCount > 0;

  int get richnessScore =>
      projectCount * 100 + moodboardCount * 5 + assetFileCount;
}

/// Propuesta de mover datos desde otra ubicación al almacenamiento actual.
class StorageRelocationProposal {
  final StorageLocationSnapshot source;
  final StorageLocationSnapshot target;
  final List<String> reasons;

  const StorageRelocationProposal({
    required this.source,
    required this.target,
    required this.reasons,
  });
}

/// Detecta bases de datos y carpetas de proyectos fuera del almacenamiento activo.
abstract final class LegacyStorageDiscovery {
  LegacyStorageDiscovery._();

  static Future<List<StorageLocationSnapshot>> discoverCandidates() async {
    final candidates = <StorageLocationSnapshot>[];
    final seenDb = <String>{};

    Future<void> addCandidate({
      required String label,
      required String databasePath,
      required String documentsPath,
    }) async {
      final dbFile = File(databasePath);
      if (!await dbFile.exists()) return;
      final normalizedDb = p.normalize(databasePath);
      if (seenDb.contains(normalizedDb)) return;
      seenDb.add(normalizedDb);

      final stats = await _readDatabaseStats(databasePath);
      final assetCount = await _countAssetFiles(documentsPath);

      candidates.add(
        StorageLocationSnapshot(
          label: label,
          databasePath: normalizedDb,
          documentsPath: p.normalize(documentsPath),
          projectCount: stats.projectCount,
          assetFileCount: assetCount,
          moodboardCount: stats.moodboardCount,
          projectNames: stats.projectNames,
        ),
      );
    }

    final support = await getApplicationSupportDirectory();
    final docs = await getApplicationDocumentsDirectory();
    final home = Platform.environment['HOME'];

    await addCandidate(
      label: 'Documentos de la app (legacy)',
      databasePath: p.join(docs.path, 'iris_dp.db'),
      documentsPath: p.join(docs.path, 'iris_dp'),
    );

    if (home != null) {
      await addCandidate(
        label: 'Documentos del usuario',
        databasePath: p.join(home, 'Documents', 'iris_dp', 'app_data', 'iris_dp.db'),
        documentsPath: p.join(home, 'Documents', 'iris_dp', 'documentos'),
      );
      await addCandidate(
        label: 'Carpeta IRIS DP ARCHIVOS',
        databasePath: p.join(
          home,
          'Library',
          'Containers',
          'com.example.irisDp',
          'Data',
          'Library',
          'Application Support',
          'com.example.irisDp',
          'iris_dp',
          'app_data',
          'iris_dp.db',
        ),
        documentsPath: p.join(home, 'Documents', '5 IRIS DP ARCHIVOS'),
      );
    }

    final containerRoot = p.join(
      support.path,
      '..',
      '..',
      'Documents',
    );
    await addCandidate(
      label: 'Sandbox Documentos',
      databasePath: p.join(containerRoot, 'iris_dp.db'),
      documentsPath: p.join(containerRoot, 'iris_dp'),
    );

    await addCandidate(
      label: 'Application Support (legacy)',
      databasePath: p.join(support.path, 'iris_dp', 'app_data', 'iris_dp.db'),
      documentsPath: p.join(support.path, 'iris_dp', 'documentos'),
    );

    if (AppStorageConfig.isConfigured) {
      final current = AppStorageConfig.current!;
      await addCandidate(
        label: 'Almacenamiento actual',
        databasePath: current.databaseFile,
        documentsPath: current.documentsPath,
      );
    }

    candidates.sort((a, b) => b.richnessScore.compareTo(a.richnessScore));
    return candidates;
  }

  static Future<StorageLocationSnapshot?> currentSnapshot() async {
    if (!AppStorageConfig.isConfigured) return null;
    final current = AppStorageConfig.current!;
    final stats = await _readDatabaseStats(current.databaseFile);
    final assetCount = await _countAssetFiles(current.documentsPath);
    return StorageLocationSnapshot(
      label: 'Almacenamiento actual',
      databasePath: p.normalize(current.databaseFile),
      documentsPath: p.normalize(current.documentsPath),
      projectCount: stats.projectCount,
      assetFileCount: assetCount,
      moodboardCount: stats.moodboardCount,
      projectNames: stats.projectNames,
    );
  }

  static Future<StorageRelocationProposal?> findRelocationProposal() async {
    if (!AppStorageConfig.isConfigured) return null;

    final target = await currentSnapshot();
    if (target == null) return null;

    final candidates = await discoverCandidates();
    StorageLocationSnapshot? bestSource;

    for (final candidate in candidates) {
      if (candidate.databasePath == target.databasePath) continue;
      if (!candidate.hasProjects) continue;
      if (candidate.richnessScore <= target.richnessScore) continue;

      final sharedProjects = candidate.projectNames
          .where(
            (name) => target.projectNames.any(
              (t) => t.toLowerCase() == name.toLowerCase(),
            ),
          )
          .toList();

      final targetLooksEmpty =
          target.moodboardCount == 0 && target.assetFileCount <= 2;
      final sourceRicher = candidate.richnessScore > target.richnessScore + 5;

      if (sourceRicher || (sharedProjects.isNotEmpty && targetLooksEmpty)) {
        if (bestSource == null ||
            candidate.richnessScore > bestSource.richnessScore) {
          bestSource = candidate;
        }
      }
    }

    if (bestSource == null) return null;

    final reasons = <String>[
      '${bestSource.projectCount} proyecto(s): ${bestSource.projectNames.join(', ')}',
      '${bestSource.moodboardCount} imágenes en moodboard',
      '${bestSource.assetFileCount} archivos de media detectados',
      'Origen: ${bestSource.label}',
    ];

    return StorageRelocationProposal(
      source: bestSource,
      target: target,
      reasons: reasons,
    );
  }

  static Future<({int projectCount, int moodboardCount, List<String> projectNames})>
      _readDatabaseStats(String databasePath) async {
    try {
      final projectResult = await Process.run('sqlite3', [
        databasePath,
        'SELECT COUNT(*) FROM projects;',
      ]);
      final moodboardResult = await Process.run('sqlite3', [
        databasePath,
        'SELECT COUNT(*) FROM moodboard_images;',
      ]);
      final namesResult = await Process.run('sqlite3', [
        databasePath,
        'SELECT name FROM projects ORDER BY name;',
      ]);

      if (projectResult.exitCode != 0) {
        return (projectCount: 0, moodboardCount: 0, projectNames: const <String>[]);
      }

      final projectCount = int.tryParse(projectResult.stdout.toString().trim()) ?? 0;
      final moodboardCount =
          moodboardResult.exitCode == 0
              ? int.tryParse(moodboardResult.stdout.toString().trim()) ?? 0
              : 0;
      final projectNames = namesResult.exitCode == 0
          ? namesResult.stdout
              .toString()
              .split('\n')
              .map((line) => line.trim())
              .where((line) => line.isNotEmpty)
              .toList(growable: false)
          : const <String>[];

      return (
        projectCount: projectCount,
        moodboardCount: moodboardCount,
        projectNames: List<String>.from(projectNames),
      );
    } catch (_) {
      return (projectCount: 0, moodboardCount: 0, projectNames: const <String>[]);
    }
  }

  static Future<int> _countAssetFiles(String documentsPath) async {
    final projectsDir = Directory(p.join(documentsPath, 'projects'));
    if (!await projectsDir.exists()) {
      final legacy = Directory(p.join(documentsPath));
      if (!await legacy.exists()) return 0;
      return _countImagesRecursive(legacy);
    }
    return _countImagesRecursive(projectsDir);
  }

  static Future<int> _countImagesRecursive(Directory dir) async {
    var count = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      final ext = p.extension(entity.path).toLowerCase();
      if ({'.png', '.jpg', '.jpeg', '.webp', '.gif', '.pdf'}.contains(ext)) {
        count++;
      }
    }
    return count;
  }
}
