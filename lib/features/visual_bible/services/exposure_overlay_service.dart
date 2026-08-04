import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Modo de overlay de exposición.
enum ExposureOverlayMode { falseColor, zebra }

/// Genera overlay de falso color o zebra sobre una imagen.
class ExposureOverlayService {
  ExposureOverlayService._();

  static Future<ui.Image?> applyOverlay(
    ui.Image source, {
    ExposureOverlayMode mode = ExposureOverlayMode.falseColor,
    double zebraThreshold = 0.85,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImage(source, Offset.zero, Paint());

    final overlayPaint = Paint()..blendMode = BlendMode.srcOver;
    final data = await source.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) return null;

    final w = source.width;
    final h = source.height;

    for (var y = 0; y < h; y += 2) {
      for (var x = 0; x < w; x += 2) {
        final idx = (y * w + x) * 4;
        final r = data.getUint8(idx) / 255;
        final g = data.getUint8(idx + 1) / 255;
        final b = data.getUint8(idx + 2) / 255;
        final luma = 0.2126 * r + 0.7152 * g + 0.0722 * b;

        Color? overlayColor;
        if (mode == ExposureOverlayMode.zebra) {
          if (luma >= zebraThreshold) {
            overlayColor = const Color(0xAAFF00FF);
          }
        } else {
          overlayColor = _falseColorForLuma(luma);
        }

        if (overlayColor != null) {
          overlayPaint.color = overlayColor;
          canvas.drawRect(
            Rect.fromLTWH(x.toDouble(), y.toDouble(), 2, 2),
            overlayPaint,
          );
        }
      }
    }

    final picture = recorder.endRecording();
    return picture.toImage(w, h);
  }

  static Color _falseColorForLuma(double luma) {
    if (luma < 0.05) return const Color(0xCC000080);
    if (luma < 0.15) return const Color(0xCC0000FF);
    if (luma < 0.30) return const Color(0xCC00FFFF);
    if (luma < 0.45) return const Color(0xCC00FF00);
    if (luma < 0.60) return const Color(0xCCFFFF00);
    if (luma < 0.75) return const Color(0xCCFF8000);
    if (luma < 0.90) return const Color(0xCCFF0000);
    return const Color(0xCCFFFFFF);
  }
}
