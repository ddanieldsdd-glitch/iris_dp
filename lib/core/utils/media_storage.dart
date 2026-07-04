import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class MediaStorage {
  static Future<Directory?> _documentsDir() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return null;
    }
  }

  static Future<Directory?> projectDirectory(int projectId) async {
    final dir = await _documentsDir();
    if (dir == null) return null;
    final projectDir = Directory(
      p.join(dir.path, 'iris_dp', 'projects', '$projectId'),
    );
    if (!await projectDir.exists()) {
      await projectDir.create(recursive: true);
    }
    return projectDir;
  }

  static Future<void> deleteProjectDirectory(int projectId) async {
    final dir = await _documentsDir();
    if (dir == null) return;
    final projectDir = Directory(
      p.join(dir.path, 'iris_dp', 'projects', '$projectId'),
    );
    if (await projectDir.exists()) {
      await projectDir.delete(recursive: true);
    }
  }

  static Future<String?> copyFileIntoProject({
    required int projectId,
    required String sourcePath,
    required String subfolder,
    required String fileName,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) return null;

    final destDir = await projectDirectory(projectId);
    if (destDir == null) return null;

    final targetDir = Directory(p.join(destDir.path, subfolder));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    final destPath = p.join(targetDir.path, fileName);
    await source.copy(destPath);
    return destPath;
  }

  static Future<String?> duplicateScriptFile({
    required int sourceProjectId,
    required int destProjectId,
    String? sourcePath,
  }) async {
    if (sourcePath == null || sourcePath.isEmpty) return null;
    final source = File(sourcePath);
    if (!await source.exists()) return null;

    final ext = p.extension(sourcePath);
    final safeExt = ext.isEmpty ? '.pdf' : ext;
    return copyFileIntoProject(
      projectId: destProjectId,
      sourcePath: sourcePath,
      subfolder: 'script',
      fileName: 'guion$safeExt',
    );
  }

  static Future<String?> duplicateImageFile({
    required int destProjectId,
    required String sourcePath,
    required String subfolder,
    required String prefix,
  }) async {
    if (sourcePath.isEmpty) return null;
    final source = File(sourcePath);
    if (!await source.exists()) return null;

    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    return copyFileIntoProject(
      projectId: destProjectId,
      sourcePath: sourcePath,
      subfolder: subfolder,
      fileName: '${prefix}_${DateTime.now().microsecondsSinceEpoch}$ext',
    );
  }

  static Future<String> copyLocationImage({
    required int projectId,
    required int locationId,
    required String sourcePath,
  }) async {
    final dir = await _documentsDir();
    if (dir == null) {
      throw StateError('Almacenamiento no disponible');
    }
    final destDir = Directory(
      p.join(dir.path, 'iris_dp', 'projects', '$projectId', 'locations', '$locationId'),
    );
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final destPath = p.join(
      destDir.path,
      'img_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  static Future<String> copyProjectScript({
    required int projectId,
    required String sourcePath,
  }) async {
    final dir = await _documentsDir();
    if (dir == null) {
      throw StateError('Almacenamiento no disponible');
    }
    final destDir = Directory(
      p.join(dir.path, 'iris_dp', 'projects', '$projectId', 'script'),
    );
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final ext = p.extension(sourcePath);
    final safeExt = ext.isEmpty ? '.pdf' : ext;
    final destPath = p.join(destDir.path, 'guion$safeExt');
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  static Future<String> copySiteImage({
    required int projectId,
    required int siteId,
    required String sourcePath,
  }) async {
    final dir = await _documentsDir();
    if (dir == null) {
      throw StateError('Almacenamiento no disponible');
    }
    final destDir = Directory(
      p.join(dir.path, 'iris_dp', 'projects', '$projectId', 'sites', '$siteId'),
    );
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final destPath = p.join(
      destDir.path,
      'img_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  static Future<String> copyShotReference({
    required int projectId,
    required int shotId,
    required String sourcePath,
  }) async {
    final dir = await _documentsDir();
    if (dir == null) {
      throw StateError('Almacenamiento no disponible');
    }
    final destDir = Directory(
      p.join(dir.path, 'iris_dp', 'projects', '$projectId', 'references'),
    );
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final ext = p.extension(sourcePath).isEmpty ? '.jpg' : p.extension(sourcePath);
    final destPath = p.join(
      destDir.path,
      'shot_${shotId}_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(sourcePath).copy(destPath);
    return destPath;
  }

  static Future<String> writeShotReferenceBytes({
    required int projectId,
    required int shotId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final dir = await _documentsDir();
    if (dir == null) {
      throw StateError('Almacenamiento no disponible');
    }
    final destDir = Directory(
      p.join(dir.path, 'iris_dp', 'projects', '$projectId', 'references'),
    );
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    var ext = p.extension(fileName);
    if (ext.isEmpty) ext = '.jpg';
    final destPath = p.join(
      destDir.path,
      'shot_${shotId}_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(destPath).writeAsBytes(bytes, flush: true);
    return destPath;
  }

  static Future<String> writeProjectFileBytes({
    required int projectId,
    required String subfolder,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final destDir = await projectDirectory(projectId);
    if (destDir == null) {
      throw StateError('Almacenamiento no disponible');
    }
    final targetDir = Directory(p.join(destDir.path, subfolder));
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }
    final destPath = p.join(targetDir.path, fileName);
    await File(destPath).writeAsBytes(bytes, flush: true);
    return destPath;
  }

  static Future<String> copyLocationScan({
    required int projectId,
    required String scopeFolder,
    required int scopeId,
    required String sourcePath,
    required String prefix,
  }) async {
    final dir = await _documentsDir();
    if (dir == null) {
      throw StateError('Almacenamiento no disponible');
    }
    final destDir = Directory(
      p.join(
        dir.path,
        'iris_dp',
        'projects',
        '$projectId',
        scopeFolder,
        '$scopeId',
        'scans',
      ),
    );
    if (!await destDir.exists()) {
      await destDir.create(recursive: true);
    }

    final ext = p.extension(sourcePath).isEmpty ? '' : p.extension(sourcePath);
    final destPath = p.join(
      destDir.path,
      '${prefix}_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
    await File(sourcePath).copy(destPath);
    return destPath;
  }
}
