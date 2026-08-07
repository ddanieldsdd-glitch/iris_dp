import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Extrae colores dominantes de una still (lightbox / meta del moodboard).
///
/// Usa el codec Flutter (`instantiateImageCodec`) — el mismo que pinta
/// `Image.file` — y cuantiza buckets (no tiras promedio) para una paleta
/// tipo ShotDeck visible incluso en planos oscuros.
abstract final class MoodboardPaletteExtractor {
  static const defaultSwatches = 10;
  static const _sampleWidth = 160;

  static Future<List<Color>> fromFile(
    String path, {
    int count = defaultSwatches,
  }) async {
    try {
      final file = File(path);
      if (!await file.exists()) return const [];
      return fromBytes(await file.readAsBytes(), count: count);
    } catch (_) {
      return const [];
    }
  }

  static Future<List<Color>> fromBytes(
    Uint8List bytes, {
    int count = defaultSwatches,
  }) async {
    if (bytes.isEmpty) return const [];
    final target = count.clamp(3, 16);

    try {
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: _sampleWidth,
      );
      final frame = await codec.getNextFrame();
      final image = frame.image;
      final w = image.width;
      final h = image.height;
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (data == null) return const [];

      final buckets = <int, _Bucket>{};
      // Muestreo cada N píxeles para velocidad.
      final step = math.max(1, (w * h / 8000).ceil());
      final bd = data.buffer.asUint8List();
      for (var i = 0; i < w * h; i += step) {
        final idx = i * 4;
        if (idx + 2 >= bd.length) break;
        final r = bd[idx];
        final g = bd[idx + 1];
        final b = bd[idx + 2];
        final a = bd[idx + 3];
        if (a < 32) continue;
        final lum = 0.2126 * r + 0.7152 * g + 0.0722 * b;
        // Solo descartar extremos absolutos (ruido sensor / flare).
        if (lum < 4 || lum > 252) continue;
        // Buckets 5 bits ≈ 32 niveles por canal.
        final key = ((r >> 3) << 10) | ((g >> 3) << 5) | (b >> 3);
        final bucket = buckets.putIfAbsent(key, _Bucket.new);
        bucket.r += r;
        bucket.g += g;
        bucket.b += b;
        bucket.n++;
      }

      if (buckets.isEmpty) {
        // Fallback: promedio global si la imagen es casi negra/blanca.
        var rSum = 0, gSum = 0, bSum = 0, n = 0;
        for (var i = 0; i < w * h; i += step) {
          final idx = i * 4;
          if (idx + 2 >= bd.length) break;
          rSum += bd[idx];
          gSum += bd[idx + 1];
          bSum += bd[idx + 2];
          n++;
        }
        if (n == 0) return const [];
        return [
          Color.fromARGB(255, rSum ~/ n, gSum ~/ n, bSum ~/ n),
        ];
      }

      final ranked = buckets.values.toList()
        ..sort((a, b) => b.n.compareTo(a.n));

      final colors = <Color>[];
      for (final b in ranked) {
        if (colors.length >= target) break;
        final c = Color.fromARGB(
          255,
          (b.r / b.n).round().clamp(0, 255),
          (b.g / b.n).round().clamp(0, 255),
          (b.b / b.n).round().clamp(0, 255),
        );
        if (colors.any((x) => _distance(x, c) < 32)) continue;
        colors.add(c);
      }

      // Si tras dedupe quedan pocos, rellenar con siguientes buckets.
      if (colors.length < math.min(4, target)) {
        for (final b in ranked) {
          if (colors.length >= target) break;
          final c = Color.fromARGB(
            255,
            (b.r / b.n).round().clamp(0, 255),
            (b.g / b.n).round().clamp(0, 255),
            (b.b / b.n).round().clamp(0, 255),
          );
          if (colors.any((x) => _distance(x, c) < 18)) continue;
          colors.add(c);
        }
      }

      return colors;
    } catch (_) {
      return const [];
    }
  }

  static double _distance(Color a, Color b) {
    final dr = (a.r - b.r) * 255.0;
    final dg = (a.g - b.g) * 255.0;
    final db = (a.b - b.b) * 255.0;
    return math.sqrt(dr * dr + dg * dg + db * db);
  }

  static String toHex(Color c) {
    final r = (c.r * 255.0).round().clamp(0, 255);
    final g = (c.g * 255.0).round().clamp(0, 255);
    final b = (c.b * 255.0).round().clamp(0, 255);
    return '#${r.toRadixString(16).padLeft(2, '0')}'
            '${g.toRadixString(16).padLeft(2, '0')}'
            '${b.toRadixString(16).padLeft(2, '0')}'
        .toUpperCase();
  }

  static Color? fromHex(String hex) {
    var h = hex.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.length != 6) return null;
    final v = int.tryParse(h, radix: 16);
    if (v == null) return null;
    return Color(0xFF000000 | v);
  }
}

class _Bucket {
  int r = 0;
  int g = 0;
  int b = 0;
  int n = 0;
}
