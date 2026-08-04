import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../storyboard/storyboard_image_palette.dart';

/// Resultado de extracción de color desde imagen.
class ColorExtractionResult {
  final List<Color> palette;
  final int? estimatedKelvin;

  const ColorExtractionResult({
    required this.palette,
    this.estimatedKelvin,
  });
}

/// Extrae paleta y temperatura de color estimada desde imágenes.
class ColorExtractionService {
  ColorExtractionService._();

  /// Swatches para bloques narrativos de color (tira ancha bajo la imagen).
  static const blockPaletteSwatches = 12;

  static Future<ColorExtractionResult> extractFromFile(
    String path, {
    int swatches = blockPaletteSwatches,
  }) async {
    final file = File(path);
    if (!await file.exists()) {
      return const ColorExtractionResult(palette: []);
    }
    return extractFromBytes(await file.readAsBytes(), swatches: swatches);
  }

  static Future<ColorExtractionResult> extractFromBytes(
    Uint8List bytes, {
    int swatches = blockPaletteSwatches,
  }) async {
    final palette = await StoryboardImagePalette.extractFromBytes(
      bytes,
      swatches: swatches,
    );
    final dominant = palette.isNotEmpty ? palette[palette.length ~/ 2] : null;
    return ColorExtractionResult(
      palette: palette,
      estimatedKelvin: dominant != null ? _estimateKelvin(dominant) : null,
    );
  }

  static List<String> paletteToHex(List<Color> colors) => colors
      .map(
        (c) =>
            '#${c.toARGB32().toRadixString(16).substring(2).toUpperCase()}',
      )
      .toList();

  /// Estimación simple de temperatura de color desde RGB.
  static int? _estimateKelvin(Color color) {
    final r = color.r * 255;
    final g = color.g * 255;
    final b = color.b * 255;

    if (r < 1 && g < 1 && b < 1) return null;

    var temp = 6500.0;
    if (b > r && b > g) {
      temp = 7000 + (b - math.max(r, g)) * 8;
    } else if (r > b && r > g) {
      temp = 3200 + (g / math.max(r, 1)) * 800;
    } else {
      temp = 4500 + (g - b) * 2;
    }
    return temp.clamp(2000, 12000).round();
  }
}
