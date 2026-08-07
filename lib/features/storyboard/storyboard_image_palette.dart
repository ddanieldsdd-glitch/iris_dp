import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../luka_export/unreal_coords.dart';
import 'storyboard_export_helpers.dart';

/// Color ámbar Artemis para overlays de óptica.
const kArtemisLensAccent = Color(0xFFE8912D);

/// Extrae una tira de colores dominantes de una imagen (estilo Artemis).
class StoryboardImagePalette {
  StoryboardImagePalette._();

  static const _sampleWidth = 200;

  static Future<List<Color>> extractFromBytes(
    Uint8List bytes, {
    int swatches = 8,
  }) async {
    if (bytes.isEmpty) return List.filled(swatches, const Color(0xFF808080));

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
      if (data == null) return List.filled(swatches, const Color(0xFF808080));

      final colors = <Color>[];
      final stripW = (w / swatches).ceil();

      for (var i = 0; i < swatches; i++) {
        var rSum = 0, gSum = 0, bSum = 0, count = 0;
        final x0 = i * stripW;
        final x1 = math.min((i + 1) * stripW, w);

        for (var y = 0; y < h; y++) {
          for (var x = x0; x < x1; x++) {
            final idx = (y * w + x) * 4;
            rSum += data.getUint8(idx);
            gSum += data.getUint8(idx + 1);
            bSum += data.getUint8(idx + 2);
            count++;
          }
        }
        if (count == 0) {
          colors.add(const Color(0xFF808080));
        } else {
          colors.add(
            Color.fromARGB(255, rSum ~/ count, gSum ~/ count, bSum ~/ count),
          );
        }
      }
      return colors;
    } catch (_) {
      return List.filled(swatches, const Color(0xFF808080));
    }
  }
}

/// Etiqueta compacta «24mm : 61°».
String lensArtemisLabel(String? lens, {double sensorWidthMm = kDefaultSensorWidthMm}) {
  final mm = parseFocalLengthMm(lens);
  final fov = horizontalFovDegrees(lens, sensorWidthMm: sensorWidthMm).round();
  return '${mm.round()}mm : $fov°';
}

/// Dibuja el indicador de FOV estilo Artemis (semicírculo + texto).
void paintArtemisLensIndicator(
  Canvas canvas,
  Offset topLeft,
  double width, {
  required String? lens,
  double sensorWidthMm = kDefaultSensorWidthMm,
}) {
  final fovDeg = horizontalFovDegrees(lens, sensorWidthMm: sensorWidthMm);
  final label = lensArtemisLabel(lens, sensorWidthMm: sensorWidthMm);

  const iconH = 52.0;
  const textGap = 6.0;
  final tp = TextPainter(
    text: TextSpan(
      text: label,
      style: const TextStyle(
        color: kArtemisLensAccent,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width);

  final cx = topLeft.dx + width / 2;
  final cy = topLeft.dy + iconH * 0.55;
  const radius = iconH * 0.42;

  canvas.drawArc(
    Rect.fromCircle(center: Offset(cx, cy), radius: radius),
    math.pi,
    math.pi,
    false,
    Paint()
      ..color = const Color(0xCC2A2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3,
  );

  final sweep = (fovDeg.clamp(8, 175) / 180) * math.pi;
  final start = -math.pi / 2 - sweep / 2;
  canvas.drawArc(
    Rect.fromCircle(center: Offset(cx, cy), radius: radius - 1.5),
    start,
    sweep,
    true,
    Paint()..color = kArtemisLensAccent.withValues(alpha: 0.95),
  );

  canvas.drawCircle(
    Offset(cx, cy),
    3,
    Paint()..color = kArtemisLensAccent,
  );

  tp.paint(canvas, Offset(topLeft.dx + (width - tp.width) / 2, topLeft.dy + iconH + textGap));
}

/// Altura total del indicador Artemis (para posicionamiento).
double artemisLensIndicatorHeight(String? lens, {double width = 120}) {
  final tp = TextPainter(
    text: TextSpan(
      text: lensArtemisLabel(lens),
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
    ),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: width);
  return 52 + 6 + tp.height;
}

/// Icono FOV compacto para PDF (semicírculo ámbar).
Future<Uint8List> renderFovIconBytes(double fovDeg, {double width = 72, double height = 36}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
  final cx = width / 2;
  final cy = height - 2;
  final radius = height * 0.78;

  canvas.drawArc(
    Rect.fromCircle(center: Offset(cx, cy), radius: radius),
    math.pi,
    math.pi,
    false,
    Paint()
      ..color = const Color(0xFF666666)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2,
  );

  final sweep = (fovDeg.clamp(8, 175) / 180) * math.pi;
  final start = -math.pi / 2 - sweep / 2;
  canvas.drawArc(
    Rect.fromCircle(center: Offset(cx, cy), radius: radius - 1),
    start,
    sweep,
    true,
    Paint()..color = kArtemisLensAccent.withValues(alpha: 0.95),
  );

  final picture = recorder.endRecording();
  final img = await picture.toImage(width.ceil(), height.ceil());
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  if (data == null) {
    return Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
    ]);
  }
  return data.buffer.asUint8List();
}
