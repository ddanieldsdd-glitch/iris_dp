import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../cloud/cloudinary_config.dart';

class MediaOptimizeResult {
  final Uint8List bytes;
  final String extension;
  final int originalBytes;
  final int optimizedBytes;

  const MediaOptimizeResult({
    required this.bytes,
    required this.extension,
    required this.originalBytes,
    required this.optimizedBytes,
  });

  int get bytesSaved => originalBytes - optimizedBytes;
}

/// Redimensiona y comprime imágenes antes de subir a Cloudinary.
abstract final class MediaOptimizer {
  static MediaOptimizeResult optimizeBytes(
    Uint8List input, {
    String extension = '.jpg',
  }) {
    final originalBytes = input.length;
    try {
      final decoded = img.decodeImage(input);
      if (decoded == null) {
        return MediaOptimizeResult(
          bytes: input,
          extension: extension,
          originalBytes: originalBytes,
          optimizedBytes: originalBytes,
        );
      }

      var image = decoded;
      const maxDim = CloudinaryConfig.maxDimension;
      if (image.width > maxDim || image.height > maxDim) {
        if (image.width >= image.height) {
          image = img.copyResize(image, width: maxDim);
        } else {
          image = img.copyResize(image, height: maxDim);
        }
      }

      final hasAlpha = image.hasAlpha;
      late Uint8List out;
      late String outExt;

      if (hasAlpha && _needsAlpha(image)) {
        out = Uint8List.fromList(img.encodePng(image));
        outExt = '.png';
      } else {
        out = Uint8List.fromList(img.encodeJpg(image, quality: 85));
        outExt = '.jpg';
      }

      return MediaOptimizeResult(
        bytes: out,
        extension: outExt,
        originalBytes: originalBytes,
        optimizedBytes: out.length,
      );
    } catch (_) {
      return MediaOptimizeResult(
        bytes: input,
        extension: extension,
        originalBytes: originalBytes,
        optimizedBytes: originalBytes,
      );
    }
  }

  static bool _needsAlpha(img.Image image) {
    final stepX = (image.width / 20).ceil().clamp(1, image.width);
    final stepY = (image.height / 20).ceil().clamp(1, image.height);
    for (var y = 0; y < image.height; y += stepY) {
      for (var x = 0; x < image.width; x += stepX) {
        final p = image.getPixel(x, y);
        if (p.a < 250) return true;
      }
    }
    return false;
  }
}
