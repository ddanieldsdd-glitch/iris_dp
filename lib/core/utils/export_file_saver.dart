import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// Error cuando el plugin nativo de macOS no está disponible (recompilar app).
class MacFileAccessException implements Exception {
  MacFileAccessException([this.message =
      'Acceso a archivos no disponible. Cierra la app y ejecuta: flutter run -d macos']);

  final String message;

  @override
  String toString() => message;
}

/// Selector de archivos compatible con sandbox macOS (lee bytes en nativo).
class UserFilePicker {
  UserFilePicker._();

  static const _macChannel = MethodChannel('com.iris_dp/export_file_saver');

  static bool get _useMacNative => !kIsWeb && Platform.isMacOS;

  static Future<void> _ensureMacPlugin() async {
    try {
      final ok = await _macChannel.invokeMethod<bool>('ping');
      if (ok != true) {
        throw MacFileAccessException();
      }
    } on MissingPluginException {
      throw MacFileAccessException();
    }
  }

  static Uint8List? _decodeBytes(Object? raw) {
    if (raw == null) return null;
    if (raw is Uint8List) return raw;
    if (raw is ByteData) {
      return raw.buffer.asUint8List(raw.offsetInBytes, raw.lengthInBytes);
    }
    if (raw is List<int>) return Uint8List.fromList(raw);
    return null;
  }

  static Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    bool allowMultiple = false,
  }) async {
    if (_useMacNative) {
      await _ensureMacPlugin();
      final imageOnly = type == FileType.image;
      final extensions = imageOnly
          ? <String>[]
          : _extensionsForType(type, allowedExtensions);

      final raw = await _macChannel.invokeMethod<List<Object?>>('pickFiles', {
        'dialogTitle': dialogTitle ?? 'Seleccionar archivo',
        'allowMultiple': allowMultiple,
        'allowedExtensions': extensions,
        'imageOnly': imageOnly,
      });
      if (raw == null || raw.isEmpty) return null;

      final files = <PlatformFile>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final map = Map<Object?, Object?>.from(item);
        final name = map['name'] as String? ?? 'archivo';
        final bytes = _decodeBytes(map['bytes']);
        if (bytes == null || bytes.isEmpty) {
          throw StateError('No se pudo leer el archivo seleccionado');
        }
        files.add(
          PlatformFile(
            name: name,
            size: bytes.length,
            bytes: bytes,
            path: map['path'] as String?,
          ),
        );
      }

      if (files.isEmpty) return null;
      return FilePickerResult(files);
    }

    return FilePicker.platform.pickFiles(
      dialogTitle: dialogTitle,
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
      withData: type == FileType.image || type == FileType.custom,
    );
  }

  static Future<PlatformFile?> pickImage({String? dialogTitle}) async {
    final result = await pickFiles(
      dialogTitle: dialogTitle ?? 'Seleccionar imagen',
      type: FileType.image,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }

  static List<String> _extensionsForType(
    FileType type,
    List<String>? allowedExtensions,
  ) {
    if (type == FileType.custom && allowedExtensions != null) {
      return allowedExtensions;
    }
    return switch (type) {
      FileType.image => ['jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif'],
      FileType.video => ['mp4', 'mov', 'm4v', 'avi', 'mkv'],
      FileType.audio => ['mp3', 'wav', 'aac', 'm4a'],
      _ => allowedExtensions ?? [],
    };
  }
}

/// Guarda archivos exportados tras preguntar al usuario dónde guardarlos.
class ExportFileSaver {
  ExportFileSaver._();

  static const _macChannel = MethodChannel('com.iris_dp/export_file_saver');

  static bool get _useMacNative => !kIsWeb && Platform.isMacOS;

  static Future<void> _ensureMacPlugin() async {
    try {
      final ok = await _macChannel.invokeMethod<bool>('ping');
      if (ok != true) throw MacFileAccessException();
    } on MissingPluginException {
      throw MacFileAccessException();
    }
  }

  /// Muestra el diálogo «Guardar como…» y devuelve la ruta elegida (sin escribir aún).
  static Future<String?> pickSavePath({
    required String dialogTitle,
    required String fileName,
    required String extension,
  }) async {
    final normalized = _normalizeFileName(fileName, extension);

    if (_useMacNative) {
      await _ensureMacPlugin();
      return _macChannel.invokeMethod<String>('beginSave', {
        'dialogTitle': dialogTitle,
        'fileName': normalized,
        'allowedExtensions': [extension],
      });
    }

    try {
      final path = await FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: normalized,
        type: FileType.custom,
        allowedExtensions: [extension],
      );
      if (path == null || path.isEmpty) return null;
      return _ensureExtension(path, extension);
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ExportFileSaver.pickSavePath falló: $e\n$st');
      }
      rethrow;
    }
  }

  /// Genera bytes → diálogo guardar → escribe (macOS: un solo panel fiable).
  static Future<String?> saveGenerated({
    required String dialogTitle,
    required String fileName,
    required String extension,
    required Future<Uint8List> Function() build,
  }) async {
    final normalized = _normalizeFileName(fileName, extension);
    final bytes = await build();

    if (_useMacNative) {
      await _ensureMacPlugin();
      return _macChannel.invokeMethod<String>('saveFileWithBytes', {
        'dialogTitle': dialogTitle,
        'fileName': normalized,
        'allowedExtensions': [extension],
        'bytes': bytes,
      });
    }

    final dest = await pickSavePath(
      dialogTitle: dialogTitle,
      fileName: fileName,
      extension: extension,
    );
    if (dest == null) return null;

    return _writeBytes(
      dest,
      bytes,
      dialogTitle: dialogTitle,
      fileName: fileName,
      extension: extension,
    );
  }

  /// Pide destino → escribe bytes ya generados.
  static Future<String?> saveBytes({
    required Uint8List bytes,
    required String dialogTitle,
    required String fileName,
    required String extension,
  }) async {
    final normalized = _normalizeFileName(fileName, extension);

    if (_useMacNative) {
      await _ensureMacPlugin();
      return _macChannel.invokeMethod<String>('saveFileWithBytes', {
        'dialogTitle': dialogTitle,
        'fileName': normalized,
        'allowedExtensions': [extension],
        'bytes': bytes,
      });
    }

    final dest = await pickSavePath(
      dialogTitle: dialogTitle,
      fileName: fileName,
      extension: extension,
    );
    if (dest == null) return null;

    return _writeBytes(
      dest,
      bytes,
      dialogTitle: dialogTitle,
      fileName: fileName,
      extension: extension,
    );
  }

  static Future<String?> _writeBytes(
    String dest,
    Uint8List bytes, {
    required String dialogTitle,
    required String fileName,
    required String extension,
  }) async {
    try {
      await File(dest).writeAsBytes(bytes, flush: true);
      return dest;
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ExportFileSaver write falló en $dest: $e\n$st');
      }
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        final normalized = _normalizeFileName(fileName, extension);
        final retry = await FilePicker.platform.saveFile(
          dialogTitle: dialogTitle,
          fileName: normalized,
          type: FileType.custom,
          allowedExtensions: [extension],
          bytes: bytes,
        );
        if (retry != null && retry.isNotEmpty) {
          return _ensureExtension(retry, extension);
        }
      }
      rethrow;
    }
  }

  static Future<String?> saveLocalFile({
    required String sourcePath,
    required String dialogTitle,
    required String fileName,
    required String extension,
  }) async {
    final src = File(sourcePath);
    if (!src.existsSync()) return null;
    final bytes = await src.readAsBytes();
    return saveBytes(
      bytes: bytes,
      dialogTitle: dialogTitle,
      fileName: fileName,
      extension: extension,
    );
  }

  static Future<String?> pickDirectory({required String dialogTitle}) async {
    if (_useMacNative) {
      await _ensureMacPlugin();
      return _macChannel.invokeMethod<String>('beginDirectoryAccess', {
        'dialogTitle': dialogTitle,
      });
    }

    try {
      return await FilePicker.platform.getDirectoryPath(
        dialogTitle: dialogTitle,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('ExportFileSaver.pickDirectory falló: $e\n$st');
      }
      rethrow;
    }
  }

  static Future<void> writeToDirectory({
    required String directoryPath,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (_useMacNative) {
      await _ensureMacPlugin();
      await _macChannel.invokeMethod<void>('writeInDirectory', {
        'fileName': fileName,
        'bytes': bytes,
      });
      return;
    }

    final file = File(p.join(directoryPath, fileName));
    await file.writeAsBytes(bytes, flush: true);
  }

  static Future<void> finishDirectoryAccess() async {
    if (_useMacNative) {
      try {
        await _macChannel.invokeMethod<void>('finishPendingAccess');
      } catch (_) {}
    }
  }

  static String _normalizeFileName(String fileName, String extension) {
    final lower = extension.toLowerCase();
    if (fileName.toLowerCase().endsWith('.$lower')) return fileName;
    return '$fileName.$extension';
  }

  static String _ensureExtension(String path, String extension) {
    final lower = extension.toLowerCase();
    if (path.toLowerCase().endsWith('.$lower')) return path;
    return '$path.$extension';
  }
}
