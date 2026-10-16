import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'annotation_brush_engine.dart';
import 'annotation_brushes.dart';
import 'annotation_document.dart';

/// Pinta un documento capa a capa, como Procreate: cada capa es una imagen
/// que se mezcla con lo de debajo según su opacidad y su modo.
///
/// Cada capa se rasteriza una vez y se guarda; al añadir un trazo solo se
/// pinta ese trazo encima de la imagen anterior. Al deshacer o cambiar algo
/// en medio, se rehace solo esa capa.
class AnnotationCompositor {
  AnnotationCompositor({this.pixelRatio = 1});

  /// Píxeles de imagen por píxel de documento (la densidad de pantalla).
  double pixelRatio;

  final Map<String, _LayerRaster> _cache = {};

  /// Veces que se ha rasterizado una capa (para las pruebas de rendimiento).
  int rasterizations = 0;

  static final Expando<AnnotationCompositor> _shared = Expando(
    'annotation-compositor',
  );

  /// Compositor propio de una lista de trazos, para quien pinta un
  /// documento sin guardar su propio compositor (miniaturas, exportación).
  static AnnotationCompositor sharedFor(AnnotationDocument document) =>
      _shared[document.strokes] ??= AnnotationCompositor();

  void dispose() {
    for (final entry in _cache.values) {
      entry.image?.dispose();
    }
    _cache.clear();
  }

  /// Imagen de la capa [layerId] con sus trazos, o `null` si está vacía.
  ui.Image? layerImage(AnnotationDocument document, String layerId, Size size) {
    final strokes = [
      for (final stroke in document.strokes)
        if (document.strokeLayerId(stroke) == layerId) stroke,
    ];
    final cached = _cache[layerId];
    if (strokes.isEmpty) {
      cached?.image?.dispose();
      _cache.remove(layerId);
      return null;
    }
    if (cached != null && cached.size == size && cached.ratio == pixelRatio) {
      if (_sameStrokes(cached.strokes, strokes)) return cached.image;
      if (_isPrefix(cached.strokes, strokes) && cached.image != null) {
        final image = _render(
          size,
          strokes.sublist(cached.strokes.length),
          base: cached.image,
        );
        cached.image!.dispose();
        _cache[layerId] = _LayerRaster(size, pixelRatio, strokes, image);
        return image;
      }
    }
    cached?.image?.dispose();
    final image = _render(size, strokes);
    _cache[layerId] = _LayerRaster(size, pixelRatio, strokes, image);
    return image;
  }

  /// Pinta [strokes] encima de [base] y devuelve la imagen nueva. El
  /// difumino necesita leer lo pintado hasta él: ahí se cierra la imagen
  /// parcial y se sigue sobre ella.
  ui.Image _render(
    Size size,
    List<AnnotationStroke> strokes, {
    ui.Image? base,
  }) {
    rasterizations++;
    final w = (size.width * pixelRatio).ceil().clamp(1, 8192);
    final h = (size.height * pixelRatio).ceil().clamp(1, 8192);
    var current = base;
    var start = 0;
    while (start < strokes.length) {
      var end = start;
      while (end < strokes.length && !BrushEngine.isSmudge(strokes[end])) {
        end++;
      }
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      if (current != null) _drawImage(canvas, current, size);
      canvas.scale(pixelRatio);
      for (var i = start; i < end; i++) {
        _paintStroke(canvas, size, strokes[i]);
      }
      // Un difumino justo después: lee la imagen hecha hasta aquí.
      if (end < strokes.length) {
        final snapshot = _finish(recorder, w, h);
        final next = ui.PictureRecorder();
        final c2 = Canvas(next);
        _drawImage(c2, snapshot, size);
        c2.scale(pixelRatio);
        BrushEngine.paintSmudge(c2, size, strokes[end], snapshot, pixelRatio);
        final smudged = _finish(next, w, h);
        snapshot.dispose();
        if (current != base) current?.dispose();
        current = smudged;
        start = end + 1;
        continue;
      }
      final image = _finish(recorder, w, h);
      if (current != base) current?.dispose();
      current = image;
      start = end;
    }
    return current!;
  }

  static ui.Image _finish(ui.PictureRecorder recorder, int w, int h) {
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    return image;
  }

  /// Dibuja una imagen de capa (en píxeles de imagen) a tamaño de documento
  /// sobre un lienzo aún sin escalar.
  void _drawImage(Canvas canvas, ui.Image image, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());
  }

  static void _paintStroke(Canvas canvas, Size size, AnnotationStroke stroke) {
    if (!stroke.alphaLocked) {
      AnnotationBrushes.paintStroke(canvas, size, stroke);
      return;
    }
    // Bloqueo de alfa: solo donde la capa ya tiene pintura.
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..blendMode = BlendMode.srcATop,
    );
    AnnotationBrushes.paintStroke(canvas, size, stroke);
    canvas.restore();
  }

  /// Pinta el documento entero: papel, capas visibles con sus sellos y el
  /// trazo que se está dibujando en su capa.
  void paint(
    Canvas canvas,
    Size size,
    AnnotationDocument document, {
    AnnotationStroke? live,
    AnnotationStamp? liveStamp,
    String? selectedStampId,
    bool paintPaper = true,
  }) {
    final rect = Offset.zero & size;
    final paper = document.paper;
    if (paintPaper && paper != null) {
      BrushEngine.paintPaper(canvas, size, paper);
    }
    final layers = document.effectiveLayers;
    final liveLayer = live == null ? null : document.strokeLayerId(live);
    final liveStampLayer = liveStamp == null
        ? null
        : document.stampLayerId(liveStamp);
    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i];
      if (!layer.visible) continue;
      final image = layerImage(document, layer.id, size);
      final stamps = [
        for (final stamp in document.stamps)
          if (document.stampLayerId(stamp) == layer.id) stamp,
      ];
      final hasLive = liveLayer == layer.id;
      final hasLiveStamp = liveStampLayer == layer.id;
      if (image == null && stamps.isEmpty && !hasLive && !hasLiveStamp) {
        continue;
      }
      _LayerBase? clipBase;
      if (layer.clip) {
        clipBase = _clipBase(document, layers, i, size);
        if (clipBase == null) continue;
      }
      canvas.saveLayer(
        rect,
        Paint()
          ..color = Color.fromRGBO(0, 0, 0, layer.opacity.clamp(0.0, 1.0))
          ..blendMode = blendFor(layer.blend),
      );
      if (image != null) {
        canvas.save();
        canvas.scale(1 / pixelRatio);
        _drawImage(canvas, image, size);
        canvas.restore();
      }
      if (hasLive) _paintLive(canvas, size, live!, image);
      for (final stamp in stamps) {
        AnnotationBrushes.paintStamp(
          canvas,
          size,
          stamp,
          selected: stamp.id == selectedStampId,
        );
      }
      if (hasLiveStamp) AnnotationBrushes.paintStamp(canvas, size, liveStamp!);
      if (clipBase != null) {
        canvas.saveLayer(rect, Paint()..blendMode = BlendMode.dstIn);
        clipBase.paint(canvas, size, pixelRatio);
        canvas.restore();
      }
      canvas.restore();
    }
  }

  void _paintLive(
    Canvas canvas,
    Size size,
    AnnotationStroke live,
    ui.Image? layer,
  ) {
    if (BrushEngine.isSmudge(live)) {
      if (layer != null) {
        BrushEngine.paintSmudge(canvas, size, live, layer, pixelRatio);
      }
      return;
    }
    _paintStroke(canvas, size, live);
  }

  /// La capa sobre la que recorta una capa con máscara: la primera de abajo
  /// que no recorta. Si está oculta, la de encima tampoco se ve.
  _LayerBase? _clipBase(
    AnnotationDocument document,
    List<AnnotationLayer> layers,
    int index,
    Size size,
  ) {
    for (var j = index - 1; j >= 0; j--) {
      final below = layers[j];
      if (below.clip) continue;
      if (!below.visible) return null;
      return _LayerBase(layerImage(document, below.id, size), [
        for (final stamp in document.stamps)
          if (document.stampLayerId(stamp) == below.id) stamp,
      ]);
    }
    return null;
  }

  static BlendMode blendFor(AnnotationLayerBlend blend) => switch (blend) {
    AnnotationLayerBlend.normal => BlendMode.srcOver,
    AnnotationLayerBlend.multiply => BlendMode.multiply,
    AnnotationLayerBlend.screen => BlendMode.screen,
    AnnotationLayerBlend.add => BlendMode.plus,
  };

  static bool _sameStrokes(List<AnnotationStroke> a, List<AnnotationStroke> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!identical(a[i], b[i])) return false;
    }
    return true;
  }

  static bool _isPrefix(
    List<AnnotationStroke> prefix,
    List<AnnotationStroke> list,
  ) {
    if (prefix.length >= list.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (!identical(prefix[i], list[i])) return false;
    }
    return true;
  }
}

class _LayerRaster {
  final Size size;
  final double ratio;
  final List<AnnotationStroke> strokes;
  final ui.Image? image;

  const _LayerRaster(this.size, this.ratio, this.strokes, this.image);
}

class _LayerBase {
  final ui.Image? image;
  final List<AnnotationStamp> stamps;

  const _LayerBase(this.image, this.stamps);

  void paint(Canvas canvas, Size size, double ratio) {
    if (image != null) {
      canvas.save();
      canvas.scale(1 / ratio);
      canvas.drawImage(image!, Offset.zero, Paint());
      canvas.restore();
    }
    for (final stamp in stamps) {
      AnnotationBrushes.paintStamp(canvas, size, stamp);
    }
  }
}
