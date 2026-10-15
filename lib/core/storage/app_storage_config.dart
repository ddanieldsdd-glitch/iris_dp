import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'ios_container_paths.dart';

/// Rutas configurables de almacenamiento de IRIS DP.
class StoragePaths {
  final String appDataPath;
  final String documentsPath;

  const StoragePaths({
    required this.appDataPath,
    required this.documentsPath,
  });

  String get databaseFile => p.join(appDataPath, 'iris_dp.db');

  String projectsRoot(String projectId) =>
      p.join(documentsPath, 'projects', projectId);

  Map<String, dynamic> toJson() => {
        'appDataPath': appDataPath,
        'documentsPath': documentsPath,
        'configured': true,
      };

  factory StoragePaths.fromJson(Map<String, dynamic> json) => StoragePaths(
        appDataPath: json['appDataPath'] as String,
        documentsPath: json['documentsPath'] as String,
      );
}

/// Configuración persistente (bootstrap en Application Support).
abstract final class AppStorageConfig {
  AppStorageConfig._();

  static StoragePaths? _cached;

  static StoragePaths? get current => _cached;

  static bool get isConfigured => _cached != null;

  static Future<File> _bootstrapFile() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'iris_dp'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return File(p.join(dir.path, 'storage_config.json'));
  }

  static Future<void> ensureLoaded() async {
    _cached ??= await load();
  }

  static Future<StoragePaths?> load() async {
    try {
      final file = await _bootstrapFile();
      if (!await file.exists()) {
        await IosContainerPaths.detect();
        return null;
      }
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      if (json['configured'] != true) {
        await IosContainerPaths.detect();
        return null;
      }
      final stored = StoragePaths.fromJson(json);
      await IosContainerPaths.detect(configuredPath: stored.appDataPath);
      return await _followIosContainer(stored, file);
    } catch (_) {
      return null;
    }
  }

  /// En iOS, lleva las rutas guardadas al contenedor actual y las vuelve a
  /// guardar si han cambiado.
  static Future<StoragePaths> _followIosContainer(
    StoragePaths stored,
    File file,
  ) async {
    final root = IosContainerPaths.currentRoot;
    if (root == null) return stored;
    final moved = StoragePaths(
      appDataPath: IosContainerPaths.rebase(stored.appDataPath, root),
      documentsPath: IosContainerPaths.rebase(stored.documentsPath, root),
    );
    if (moved.appDataPath == stored.appDataPath &&
        moved.documentsPath == stored.documentsPath) {
      return stored;
    }
    await file.writeAsString(jsonEncode(moved.toJson()), flush: true);
    return moved;
  }

  static Future<void> save(StoragePaths paths) async {
    await Directory(paths.appDataPath).create(recursive: true);
    await Directory(paths.documentsPath).create(recursive: true);
    await Directory(p.join(paths.documentsPath, 'projects'))
        .create(recursive: true);
    final file = await _bootstrapFile();
    await file.writeAsString(jsonEncode(paths.toJson()), flush: true);
    _cached = paths;
  }

  static Future<StoragePaths> defaultPaths() async {
    final docs = await getApplicationDocumentsDirectory();
    final support = await getApplicationSupportDirectory();
    return StoragePaths(
      appDataPath: p.join(support.path, 'iris_dp', 'app_data'),
      documentsPath: p.join(docs.path, 'iris_dp', 'documentos'),
    );
  }

  static Future<Directory> appDataDirectory() async {
    await ensureLoaded();
    final root = _cached?.appDataPath;
    if (root == null) {
      throw StateError('Almacenamiento no configurado');
    }
    final dir = Directory(root);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<Directory> documentsDirectory() async {
    await ensureLoaded();
    final root = _cached?.documentsPath;
    if (root == null) {
      throw StateError('Almacenamiento no configurado');
    }
    final dir = Directory(root);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
