import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import 'annotation_brush_engine.dart';
import 'annotation_brushes.dart';
import 'annotation_document.dart';
import 'brushes/paper_library.dart';

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

  /// Lado largo máximo de la imagen de una capa. En iPad e iPhone se queda
  /// más bajo: cada capa es una textura de la GPU, y a 4096 px un dibujo con
  /// varias capas llegaba a pasar de 1 GB y cerraba la app.
  static double get maxSide => switch (defaultTargetPlatform) {
    TargetPlatform.iOS || TargetPlatform.android => 2560,
    _ => 4096,
  };

  final Map<String, _LayerRaster> _cache = {};

  /// Papel con el que se rasterizaron las capas: su grano cambia el trazo.
  String? _cachePaper;

  /// Veces que se ha rasterizado una capa (para las pruebas de rendimiento).
  int rasterizations = 0;

  /// Imágenes grandes creadas al rasterizar (capas, no recortes de
  /// difumino), para las pruebas de memoria.
  int fullImages = 0;

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

  /// Imagen de la capa [layerId] con sus trazos, o `null` si está vacía
  /// (o si su parte aplanada aún se está leyendo).
  ui.Image? layerImage(
    AnnotationDocument document,
    String layerId,
    Size size, {
    Set<String> exclude = const {},
  }) {
    final baked = _layer(document, layerId)?.baked;
    ui.Image? base;
    if (baked != null) {
      base = BakedLayerImages.peek(baked);
      // Se está decodificando: se pinta en cuanto llegue.
      if (base == null) return _cache[layerId]?.image;
    }
    final strokes = _strokesOf(document, layerId, exclude: exclude);
    final cached = _cache[layerId];
    if (strokes.isEmpty && base == null) {
      cached?.image?.dispose();
      _cache.remove(layerId);
      return null;
    }
    if (cached != null &&
        cached.size == size &&
        cached.ratio == pixelRatio &&
        cached.baked == baked) {
      if (_sameStrokes(cached.strokes, strokes)) return cached.image;
      if (_isPrefix(cached.strokes, strokes) && cached.image != null) {
        final image = _render(
          size,
          strokes.sublist(cached.strokes.length),
          base: cached.image,
        );
        cached.image!.dispose();
        _cache[layerId] = _LayerRaster(size, pixelRatio, baked, strokes, image);
        return image;
      }
    }
    cached?.image?.dispose();
    final image = _render(size, strokes, base: base);
    _cache[layerId] = _LayerRaster(size, pixelRatio, baked, strokes, image);
    return image;
  }

  static AnnotationLayer? _layer(AnnotationDocument document, String id) {
    for (final layer in document.effectiveLayers) {
      if (layer.id == id) return layer;
    }
    return null;
  }

  static List<AnnotationStroke> _strokesOf(
    AnnotationDocument document,
    String layerId, {
    Set<String> exclude = const {},
  }) => [
    for (final stroke in document.strokes)
      if (document.strokeLayerId(stroke) == layerId &&
          !exclude.contains(stroke.id))
        stroke,
  ];

  /// Pinta [strokes] encima de [base] y devuelve la imagen nueva (siempre
  /// una imagen nueva: [base] sigue siendo de quien la pasó).
  ///
  /// Todo se graba en una sola imagen del tamaño de la capa. El difumino
  /// necesita leer lo pintado hasta él: de eso solo se saca el recorte que
  /// toca su trazo, no la capa entera.
  ui.Image _render(
    Size size,
    List<AnnotationStroke> strokes, {
    ui.Image? base,
  }) {
    rasterizations++;
    final w = (size.width * pixelRatio).ceil().clamp(1, 8192);
    final h = (size.height * pixelRatio).ceil().clamp(1, 8192);
    final pictures = <ui.Picture>[];
    final crops = <ui.Image>[];
    var recorder = ui.PictureRecorder();
    var canvas = Canvas(recorder);
    if (base != null) _drawBase(canvas, base, w, h);
    canvas.scale(pixelRatio);
    try {
      for (final stroke in strokes) {
        if (!BrushEngine.isSmudge(stroke)) {
          _paintStroke(canvas, size, stroke);
          continue;
        }
        final area = BrushEngine.smudgeBounds(
          size,
          stroke,
        )?.intersect(Offset.zero & size);
        if (area == null || area.width <= 0 || area.height <= 0) continue;
        final sofar = recorder.endRecording();
        pictures.add(sofar);
        final left = (area.left * pixelRatio).floor();
        final top = (area.top * pixelRatio).floor();
        final cw = ((area.right * pixelRatio).ceil() - left).clamp(1, w);
        final ch = ((area.bottom * pixelRatio).ceil() - top).clamp(1, h);
        final cropRecorder = ui.PictureRecorder();
        Canvas(cropRecorder)
          ..translate(-left.toDouble(), -top.toDouble())
          ..drawPicture(sofar);
        final cropPicture = cropRecorder.endRecording();
        final crop = cropPicture.toImageSync(cw, ch);
        cropPicture.dispose();
        crops.add(crop);
        recorder = ui.PictureRecorder();
        canvas = Canvas(recorder)..drawPicture(sofar);
        canvas.scale(pixelRatio);
        BrushEngine.paintSmudge(
          canvas,
          size,
          stroke,
          crop,
          pixelRatio,
          sourceOrigin: Offset(left / pixelRatio, top / pixelRatio),
        );
      }
      fullImages++;
      return _finish(recorder, w, h);
    } finally {
      for (final picture in pictures) {
        picture.dispose();
      }
      for (final crop in crops) {
        crop.dispose();
      }
    }
  }

  static ui.Image _finish(ui.PictureRecorder recorder, int w, int h) {
    final picture = recorder.endRecording();
    final image = picture.toImageSync(w, h);
    picture.dispose();
    return image;
  }

  /// Dibuja la imagen de base de una capa (su raster anterior o su parte
  /// aplanada, que puede venir de otra resolución) llenando [w]×[h] píxeles
  /// de imagen, sobre un lienzo aún sin escalar.
  static void _drawBase(Canvas canvas, ui.Image image, int w, int h) {
    if (image.width == w && image.height == h) {
      canvas.drawImage(image, Offset.zero, Paint());
      return;
    }
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  /// Dibuja una imagen de capa (en píxeles de imagen) a tamaño de documento
  /// sobre un lienzo aún sin escalar.
  void _drawImage(Canvas canvas, ui.Image image, Size size) {
    canvas.drawImage(image, Offset.zero, Paint());
  }

  /// Funde en una imagen la parte aplanada de la capa [layerId] y [strokes]
  /// (los más antiguos de esa capa), en PNG base64 para el documento. La
  /// imagen se queda en [BakedLayerImages] para no tener que leerla.
  /// `null` si la parte aplanada anterior no se pudo leer.
  Future<String?> bake(
    AnnotationDocument document,
    String layerId,
    List<AnnotationStroke> strokes,
    Size size,
  ) async {
    final previous = _layer(document, layerId)?.baked;
    ui.Image? base;
    if (previous != null) {
      base = await BakedLayerImages.load(previous);
      if (base == null) return null;
    }
    final image = _withPaper(
      document,
      () => _render(size, strokes, base: base),
    );
    return BakedLayerImages.encode(image);
  }

  /// Junta dos capas en una imagen: [lower] entera y encima [upper] entera
  /// con su opacidad y su modo. Para fusionar capas con parte aplanada.
  Future<String?> mergeLayers(
    AnnotationDocument document,
    AnnotationLayer lower,
    AnnotationLayer upper,
    Size size,
  ) async {
    Future<ui.Image?> full(AnnotationLayer layer) async {
      ui.Image? base;
      if (layer.baked != null) {
        base = await BakedLayerImages.load(layer.baked!);
        if (base == null) return null;
      }
      final strokes = _strokesOf(document, layer.id);
      return _withPaper(document, () => _render(size, strokes, base: base));
    }

    final below = await full(lower);
    final above = await full(upper);
    if (below == null || above == null) {
      below?.dispose();
      above?.dispose();
      return null;
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(
      0,
      0,
      below.width.toDouble(),
      below.height.toDouble(),
    );
    canvas.drawImage(below, Offset.zero, Paint());
    canvas.saveLayer(
      rect,
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, upper.opacity.clamp(0.0, 1.0))
        ..blendMode = blendFor(upper.blend),
    );
    canvas.drawImage(above, Offset.zero, Paint());
    canvas.restore();
    final merged = _finish(recorder, below.width, below.height);
    below.dispose();
    above.dispose();
    return BakedLayerImages.encode(merged);
  }

  static T _withPaper<T>(AnnotationDocument document, T Function() body) {
    final previous = BrushEngine.paperGrain;
    BrushEngine.paperGrain = PaperLibrary.paper(document.paperImage)?.grain;
    try {
      return body();
    } finally {
      BrushEngine.paperGrain = previous;
    }
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
    Set<String> liftedStrokes = const {},
    Set<String> liftedStamps = const {},
    Offset liftOffset = Offset.zero,
  }) {
    final paperTexture = PaperLibrary.paper(document.paperImage);
    final paperKey = paperTexture?.id;
    if (paperKey != _cachePaper) {
      dispose();
      _cachePaper = paperKey;
    }
    final paper = document.paper;
    if (paintPaper && paperTexture != null) {
      BrushEngine.paintPaperImage(canvas, size, paperTexture.background);
    } else if (paintPaper && paper != null) {
      BrushEngine.paintPaper(canvas, size, paper);
    }
    final previousGrain = BrushEngine.paperGrain;
    BrushEngine.paperGrain = paperTexture?.grain;
    try {
      _paintLayers(
        canvas,
        size,
        document,
        live: live,
        liveStamp: liveStamp,
        selectedStampId: selectedStampId,
        liftedStrokes: liftedStrokes,
        liftedStamps: liftedStamps,
        liftOffset: liftOffset,
      );
    } finally {
      BrushEngine.paperGrain = previousGrain;
    }
  }

  void _paintLayers(
    Canvas canvas,
    Size size,
    AnnotationDocument document, {
    AnnotationStroke? live,
    AnnotationStamp? liveStamp,
    String? selectedStampId,
    Set<String> liftedStrokes = const {},
    Set<String> liftedStamps = const {},
    Offset liftOffset = Offset.zero,
  }) {
    final rect = Offset.zero & size;
    final layers = document.effectiveLayers;
    final liveLayer = live == null ? null : document.strokeLayerId(live);
    final liveStampLayer = liveStamp == null
        ? null
        : document.stampLayerId(liveStamp);
    for (var i = 0; i < layers.length; i++) {
      final layer = layers[i];
      if (!layer.visible) continue;
      final image = layerImage(
        document,
        layer.id,
        size,
        exclude: liftedStrokes,
      );
      final lifted = [
        for (final stroke in document.strokes)
          if (liftedStrokes.contains(stroke.id) &&
              document.strokeLayerId(stroke) == layer.id)
            stroke,
      ];
      final stamps = [
        for (final stamp in document.stamps)
          if (document.stampLayerId(stamp) == layer.id) stamp,
      ];
      final hasLive = liveLayer == layer.id;
      final hasLiveStamp = liveStampLayer == layer.id;
      if (image == null &&
          stamps.isEmpty &&
          lifted.isEmpty &&
          !hasLive &&
          !hasLiveStamp) {
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
      if (lifted.isNotEmpty) {
        canvas.save();
        canvas.translate(liftOffset.dx, liftOffset.dy);
        for (final stroke in lifted) {
          _paintStroke(canvas, size, stroke);
        }
        canvas.restore();
      }
      if (hasLive) _paintLive(canvas, size, live!, image);
      for (final stamp in stamps) {
        final moving = liftedStamps.contains(stamp.id);
        if (moving) {
          canvas.save();
          canvas.translate(liftOffset.dx, liftOffset.dy);
        }
        AnnotationBrushes.paintStamp(
          canvas,
          size,
          stamp,
          selected: stamp.id == selectedStampId,
        );
        if (moving) canvas.restore();
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
  final String? baked;
  final List<AnnotationStroke> strokes;
  final ui.Image? image;

  const _LayerRaster(
    this.size,
    this.ratio,
    this.baked,
    this.strokes,
    this.image,
  );
}

/// Las partes aplanadas de las capas, leídas de su PNG una sola vez. Las
/// comparten todos los compositores (lienzo, miniaturas, exportación).
abstract final class BakedLayerImages {
  /// Cuántas se guardan leídas a la vez (cada una es una textura grande).
  static const _keep = 6;

  static final Map<String, ui.Image> _images = {};
  static final Map<String, Future<ui.Image?>> _pending = {};

  /// Sube cada vez que termina de leerse una: quien pinta vuelve a pintar.
  static final ValueNotifier<int> loaded = ValueNotifier(0);

  /// La imagen si ya está leída; si no, empieza a leerla y da `null`.
  static ui.Image? peek(String png) {
    final image = _images.remove(png);
    if (image != null) {
      _images[png] = image;
      return image;
    }
    load(png);
    return null;
  }

  /// Lee (o da la ya leída) la imagen de [png]. `null` si está dañada.
  static Future<ui.Image?> load(String png) {
    final ready = _images[png];
    if (ready != null) return Future.value(ready);
    return _pending[png] ??= _decode(png);
  }

  /// Deja leídas todas las partes aplanadas de [document] (antes de pintarlo
  /// fuera de pantalla: PNG, PDF).
  static Future<void> ensure(AnnotationDocument document) async {
    for (final layer in document.layers) {
      final baked = layer.baked;
      if (baked != null) await load(baked);
    }
  }

  static Future<ui.Image?> _decode(String png) async {
    try {
      final codec = await ui.instantiateImageCodec(base64Decode(png));
      final frame = await codec.getNextFrame();
      codec.dispose();
      _store(png, frame.image);
      loaded.value++;
      return frame.image;
    } catch (_) {
      return null;
    } finally {
      _pending.remove(png);
    }
  }

  /// Pasa [image] a PNG base64 y la deja guardada como ya leída.
  static Future<String?> encode(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      image.dispose();
      return null;
    }
    final png = base64Encode(data.buffer.asUint8List());
    _store(png, image);
    return png;
  }

  static void _store(String png, ui.Image image) {
    _images.remove(png)?.dispose();
    _images[png] = image;
    while (_images.length > _keep) {
      final oldest = _images.keys.first;
      _images.remove(oldest)!.dispose();
    }
  }
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
