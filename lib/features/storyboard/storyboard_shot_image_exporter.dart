import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import 'storyboard_export_helpers.dart';
import 'storyboard_export_style.dart';
import 'storyboard_image_palette.dart';

/// Renderiza un fotograma a PNG estilo Artemis (RAW / S1).
class StoryboardShotImageExporter {
  static const maxLongEdge = 3840;

  static Future<Uint8List?> render({
    required Shot shot,
    required Scene scene,
    required StoryboardExportStyle style,
    double sensorWidthMm = kDefaultSensorWidthMm,
  }) async {
    if (style.singleShotUsesPdf) return null;

    final path = shot.referenceImagePath;
    ui.Image? image;
    if (path != null && File(path).existsSync()) {
      try {
        final bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        image = frame.image;
      } catch (_) {
        image = null;
      }
    }

    if (image == null) {
      return _renderPlaceholder(style, shot.lens, sensorWidthMm);
    }

    final iw = image.width;
    final ih = image.height;
    final scale = maxLongEdge / math.max(iw, ih);
    final w = scale >= 1 ? iw.toDouble() : iw * scale;
    final h = scale >= 1 ? ih.toDouble() : ih * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, iw.toDouble(), ih.toDouble()),
      Rect.fromLTWH(0, 0, w, h),
      Paint(),
    );

    if (style == StoryboardExportStyle.basic) {
      const badgeW = 128.0;
      const pad = 18.0;
      final badgeH = artemisLensIndicatorHeight(shot.lens, width: badgeW);
      paintArtemisLensIndicator(
        canvas,
        Offset(w - badgeW - pad, h - badgeH - pad),
        badgeW,
        lens: shot.lens,
        sensorWidthMm: sensorWidthMm,
      );
    }

    image.dispose();

    final picture = recorder.endRecording();
    final out = await picture.toImage(w.ceil(), h.ceil());
    final byteData = await out.toByteData(format: ui.ImageByteFormat.png);
    out.dispose();
    if (byteData == null) {
      return _renderPlaceholder(style, shot.lens, sensorWidthMm);
    }
    return byteData.buffer.asUint8List();
  }

  static Future<Uint8List?> _renderPlaceholder(
    StoryboardExportStyle style,
    String? lens,
    double sensorWidthMm,
  ) async {
    const w = 1920.0;
    const h = 1080.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, w, h),
      Paint()..color = const Color(0xFF2A2A2A),
    );
    final tp = TextPainter(
      text: const TextSpan(
        text: 'Sin referencia',
        style: TextStyle(color: Color(0xFF888888), fontSize: 28),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset((w - tp.width) / 2, (h - tp.height) / 2));

    if (style == StoryboardExportStyle.basic) {
      paintArtemisLensIndicator(
        canvas,
        const Offset(w - 146, h - 100),
        128,
        lens: lens,
        sensorWidthMm: sensorWidthMm,
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(w.toInt(), h.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    img.dispose();
    return byteData?.buffer.asUint8List();
  }
}

/// Ángulo del sol según día/noche de la escena (diagrama simplificado).
double sunAngleFromDayNight(String dayNight) {
  final dn = dayNight.toUpperCase();
  if (dn.contains('NOCHE') || dn.contains('NIGHT')) return math.pi * 1.05;
  if (dn.contains('AMANECER') || dn.contains('ATARDECER')) return math.pi * 0.35;
  return math.pi * 0.15;
}
