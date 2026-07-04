import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

/// Carga imágenes en formato compatible con el paquete `pdf` (PNG/JPEG).
abstract final class PdfSafeImage {
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

  static bool isPdfCompatible(Uint8List bytes) => _isPng(bytes) || _isJpeg(bytes);

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
