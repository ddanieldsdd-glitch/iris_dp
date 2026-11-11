import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'annotation_canvas.dart';
import 'annotation_document.dart';
import 'annotation_layers.dart';

/// Pasa un documento de dibujo a PNG (viñeta de storyboard, PDF…).
abstract final class AnnotationRaster {
  static Future<Uint8List> toPng(
    AnnotationDocument document, {
    required Size size,
    Color? background = Colors.white,
  }) async {
    // La parte aplanada de las capas tiene que estar leída para pintarla.
    await BakedLayerImages.ensure(document);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    if (background != null) {
      canvas.drawRect(Offset.zero & size, Paint()..color = background);
    }
    AnnotationPainter(document: document).paint(canvas, size);
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      size.width.round(),
      size.height.round(),
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('No se pudo generar la imagen');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
      picture.dispose();
    }
  }
}
