import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Carga imágenes en formato compatible con el paquete `pdf` (PNG/JPEG).
abstract final class PdfSafeImage {
  static const _cacheKey = #pdfSafeImageCache;

  /// Ejecuta [build] con una caché de imágenes: dentro, cargar la misma
  /// imagen varias veces (moodboard y secciones) la lee y reduce una vez.
  static Future<T> withExportCache<T>(Future<T> Function() build) =>
      runZoned(build, zoneValues: {_cacheKey: <String, Future<Uint8List?>>{}});

  static bool _isPng(Uint8List bytes) =>
      bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47;

  static bool _isJpeg(Uint8List bytes) =>
      bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF;

  static bool isPdfCompatible(Uint8List bytes) =>
      _isPng(bytes) || _isJpeg(bytes);

  /// Lee y normaliza a PNG/JPEG. Convierte HEIC/WebP vía decodificador Flutter.
  static Future<Uint8List?> loadFromPath(String? path) async {
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      final bytes = await file.readAsBytes();
      return await ensurePdfCompatible(bytes);
    } catch (_) {
      return null;
    }
  }

  /// Carga una imagen limitando su lado mayor para reducir memoria y tamaño
  /// del PDF. Conserva el original cuando ya es compatible y suficientemente
  /// pequeño.
  static Future<Uint8List?> loadFromPathMaxEdge(
    String? path, {
    int maxEdge = 2048,
  }) {
    if (path == null || maxEdge <= 0) return Future.value();
    final cache = Zone.current[_cacheKey] as Map<String, Future<Uint8List?>>?;
    if (cache == null) return _loadMaxEdge(path, maxEdge);
    return cache.putIfAbsent('$maxEdge|$path', () => _loadMaxEdge(path, maxEdge));
  }

  static Future<Uint8List?> _loadMaxEdge(String path, int maxEdge) async {
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return null;
      // Las medidas salen de la cabecera, sin decodificar la imagen entera.
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      final descriptor = await ui.ImageDescriptor.encoded(buffer);
      final width = descriptor.width;
      final height = descriptor.height;
      descriptor.dispose();
      buffer.dispose();
      if (width <= maxEdge && height <= maxEdge && isPdfCompatible(bytes)) {
        return bytes;
      }

      final scale = maxEdge / (width > height ? width : height);
      final targetWidth = (width * scale).round().clamp(1, maxEdge);
      final targetHeight = (height * scale).round().clamp(1, maxEdge);
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      final resizedFrame = await codec.getNextFrame();
      final data = await resizedFrame.image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      resizedFrame.image.dispose();
      codec.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  static Uint8List? loadFromPathSync(String? path) {
    if (path == null) return null;
    final file = File(path);
    if (!file.existsSync()) return null;
    try {
      final bytes = file.readAsBytesSync();
      if (isPdfCompatible(bytes)) return bytes;
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<Uint8List?> ensurePdfCompatible(Uint8List bytes) async {
    if (bytes.isEmpty) return null;
    if (isPdfCompatible(bytes)) return bytes;

    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}
