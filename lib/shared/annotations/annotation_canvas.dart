import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'annotation_brush_engine.dart';
import 'annotation_brushes.dart';
import 'annotation_document.dart';
import 'annotation_layers.dart';
import 'annotation_shape_recognizer.dart';

/// Transforma un documento normalizado al mismo viewport que un plano.
class AnnotationViewport {
  final Size documentSize;
  final Offset offset;
  final double scale;

  const AnnotationViewport({
    required this.documentSize,
    this.offset = Offset.zero,
    this.scale = 1,
  });

  Offset localToDocument(Offset local) => (local - offset) / scale;
}

class AnnotationCanvasController extends ChangeNotifier {
  AnnotationCanvasController({
    AnnotationDocument document = const AnnotationDocument(),
  }) : _document = document;

  AnnotationDocument _document;

  /// Capas ya rasterizadas del lienzo (también para las miniaturas).
  final AnnotationCompositor compositor = AnnotationCompositor();

  /// Último tamaño de documento con el que se pintó.
  Size lastSize = Size.zero;

  VoidCallback? _cancelLive;

  /// Descarta el trazo a medio dibujar (al empezar un gesto de dos dedos).
  void cancelLiveStroke() => _cancelLive?.call();

  /// El trazo a medio hacer aquí, cada vez que cambia (`null`: se levantó
  /// el lápiz). Para enseñarlo en vivo en otro equipo.
  ValueChanged<AnnotationStroke?>? onLiveStroke;
  AnnotationStroke? _reported;

  void _reportLive(AnnotationStroke? stroke) {
    final last = _reported;
    if (stroke == null && last == null) return;
    if (stroke != null &&
        last != null &&
        stroke.points.length == last.points.length) {
      return;
    }
    _reported = stroke;
    onLiveStroke?.call(stroke);
  }

  /// El trazo que otro equipo está haciendo ahora: se pinta encima.
  AnnotationStroke? get remoteStroke => _remoteStroke;
  AnnotationStroke? _remoteStroke;
  set remoteStroke(AnnotationStroke? stroke) {
    if (identical(stroke, _remoteStroke)) return;
    _remoteStroke = stroke;
    notifyListeners();
  }

  @override
  void dispose() {
    compositor.dispose();
    super.dispose();
  }

  final List<AnnotationDocument> _undo = [];
  final List<AnnotationDocument> _redo = [];
  AnnotationDocument? _noteDragBaseline;
  String? _selectedStampId;

  AnnotationDocument get document => _document;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// Sello seleccionado con la herramienta «Mover».
  String? get selectedStampId => _selectedStampId;

  AnnotationStamp? get selectedStamp {
    final id = _selectedStampId;
    if (id == null) return null;
    for (final stamp in _document.stamps) {
      if (stamp.id == id) return stamp;
    }
    return null;
  }

  void selectStamp(String? id) {
    if (_selectedStampId == id &&
        _selStrokes.isEmpty &&
        _selStamps.length == (id == null ? 0 : 1)) {
      return;
    }
    setSelection(strokes: const [], stamps: [?id]);
  }

  // ─── Selección de varios trazos y sellos ─────────────────────────────────

  final Set<String> _selStrokes = {};
  final Set<String> _selStamps = {};
  bool _lifted = false;
  Offset _liftOffset = Offset.zero;

  Set<String> get selectedStrokeIds => Set.unmodifiable(_selStrokes);
  Set<String> get selectedStampIds => Set.unmodifiable(_selStamps);
  bool get hasSelection => _selStrokes.isNotEmpty || _selStamps.isNotEmpty;
  int get selectionCount => _selStrokes.length + _selStamps.length;

  /// Mientras se arrastra la selección, se pinta aparte y desplazada
  /// [liftOffset] (fracción del folio) sin tocar el documento.
  bool get isLifted => _lifted;
  Offset get liftOffset => _liftOffset;

  void setSelection({
    required Iterable<String> strokes,
    required Iterable<String> stamps,
  }) {
    _selStrokes
      ..clear()
      ..addAll(strokes);
    _selStamps
      ..clear()
      ..addAll(stamps);
    // Un sello solo conserva sus tiradores de giro y haz.
    _selectedStampId = _selStrokes.isEmpty && _selStamps.length == 1
        ? _selStamps.first
        : null;
    notifyListeners();
  }

  void clearSelection() {
    if (!hasSelection && _selectedStampId == null) return;
    setSelection(strokes: const [], stamps: const []);
  }

  /// Selecciona lo que queda dentro del lazo [polygon] (coordenadas 0–1):
  /// trazos con la mayoría de sus puntos dentro y sellos con el centro
  /// dentro. Solo en capas visibles y sin bloquear.
  void selectInLasso(List<Offset> polygon) {
    if (polygon.length < 3) {
      clearSelection();
      return;
    }
    final doc = _document;
    final usable = {
      for (final layer in doc.effectiveLayers)
        if (layer.visible && !layer.locked) layer.id,
    };
    setSelection(
      strokes: [
        for (final stroke in doc.strokes)
          if (usable.contains(doc.strokeLayerId(stroke)) &&
              stroke.points.isNotEmpty &&
              stroke.points
                          .where(
                            (q) => _insidePolygon(Offset(q.x, q.y), polygon),
                          )
                          .length *
                      2 >
                  stroke.points.length)
            stroke.id,
      ],
      stamps: [
        for (final stamp in doc.stamps)
          if (usable.contains(doc.stampLayerId(stamp)) &&
              _insidePolygon(Offset(stamp.x, stamp.y), polygon))
            stamp.id,
      ],
    );
  }

  /// Caja de la selección en píxeles de un folio de [size].
  Rect? selectionBounds(Size size) {
    if (!hasSelection) return null;
    Rect? box;
    void add(Rect r) => box = box == null ? r : box!.expandToInclude(r);
    final unit = math.min(size.width, size.height) / 1000;
    for (final stroke in _document.strokes) {
      if (!_selStrokes.contains(stroke.id) || stroke.points.isEmpty) continue;
      var minX = double.infinity, minY = double.infinity;
      var maxX = -double.infinity, maxY = -double.infinity;
      for (final q in stroke.points) {
        minX = math.min(minX, q.x);
        maxX = math.max(maxX, q.x);
        minY = math.min(minY, q.y);
        maxY = math.max(maxY, q.y);
      }
      final pad = stroke.width * unit;
      add(
        Rect.fromLTRB(
          minX * size.width,
          minY * size.height,
          maxX * size.width,
          maxY * size.height,
        ).inflate(pad),
      );
    }
    for (final stamp in _document.stamps) {
      if (!_selStamps.contains(stamp.id)) continue;
      add(
        Rect.fromCircle(
          center: AnnotationBrushes.stampCenter(stamp, size),
          radius: AnnotationBrushes.stampRadius(stamp, size),
        ),
      );
    }
    return box;
  }

  void beginLift() {
    if (!hasSelection) return;
    _lifted = true;
    _liftOffset = Offset.zero;
    notifyListeners();
  }

  void updateLift(Offset offset) {
    if (!_lifted) return;
    _liftOffset = offset;
    notifyListeners();
  }

  /// Suelta la selección: la mueve de verdad (un solo paso de deshacer).
  void endLift() {
    if (!_lifted) return;
    final d = _liftOffset;
    _lifted = false;
    _liftOffset = Offset.zero;
    if (d == Offset.zero) {
      notifyListeners();
      return;
    }
    translateSelection(d);
  }

  void translateSelection(Offset d) {
    if (!hasSelection) return;
    _commit(
      _document.copyWith(
        strokes: [
          for (final stroke in _document.strokes)
            _selStrokes.contains(stroke.id)
                ? stroke.copyWith(
                    points: [
                      for (final q in stroke.points)
                        AnnotationPoint(
                          x: q.x + d.dx,
                          y: q.y + d.dy,
                          pressure: q.pressure,
                          tilt: q.tilt,
                          azimuth: q.azimuth,
                        ),
                    ],
                    // El azar del pincel no cambia al moverlo.
                    seed: BrushEngine.seedFor(stroke),
                  )
                : stroke,
        ],
        stamps: [
          for (final stamp in _document.stamps)
            _selStamps.contains(stamp.id)
                ? stamp.copyWith(x: stamp.x + d.dx, y: stamp.y + d.dy)
                : stamp,
        ],
      ),
    );
  }

  void deleteSelection() {
    if (!hasSelection) return;
    final strokes = Set.of(_selStrokes);
    final stamps = Set.of(_selStamps);
    _selStrokes.clear();
    _selStamps.clear();
    _selectedStampId = null;
    _commit(
      _document.copyWith(
        strokes: _document.strokes
            .where((s) => !strokes.contains(s.id))
            .toList(),
        stamps: _document.stamps.where((s) => !stamps.contains(s.id)).toList(),
      ),
    );
  }

  void replaceDocument(
    AnnotationDocument document, {
    bool clearHistory = true,
  }) {
    _document = document;
    _selectedStampId = null;
    if (clearHistory) {
      _undo.clear();
      _redo.clear();
    }
    notifyListeners();
  }

  void addStroke(AnnotationStroke stroke) {
    _commit(_document.copyWith(strokes: [..._document.strokes, stroke]));
  }

  void addNote(AnnotationNote note) {
    _commit(_document.copyWith(notes: [..._document.notes, note]));
  }

  void addStamp(AnnotationStamp stamp) {
    _commit(_document.copyWith(stamps: [..._document.stamps, stamp]));
  }

  void updateStamp(
    String id, {
    double? x,
    double? y,
    double? rotation,
    double? size,
    int? colorArgb,
    String? label,
    double? spread,
    double? reach,
    double? lensMm,
    bool commit = true,
  }) {
    final index = _document.stamps.indexWhere((stamp) => stamp.id == id);
    if (index < 0) return;
    final next = List<AnnotationStamp>.from(_document.stamps);
    next[index] = next[index].copyWith(
      x: x,
      y: y,
      rotation: rotation,
      size: size,
      colorArgb: colorArgb,
      label: label,
      spread: spread,
      reach: reach,
      lensMm: lensMm,
    );
    final document = _document.copyWith(stamps: next);
    if (commit) {
      _commit(document);
    } else {
      _document = document;
      notifyListeners();
    }
  }

  void removeStamp(String id) {
    final next = _document.stamps.where((stamp) => stamp.id != id).toList();
    if (next.length == _document.stamps.length) return;
    if (_selectedStampId == id) _selectedStampId = null;
    _selStamps.remove(id);
    _commit(_document.copyWith(stamps: next));
  }

  // ─── Capas ────────────────────────────────────────────────────────────────

  List<AnnotationLayer> get layers => _document.effectiveLayers;

  AnnotationLayer? layerById(String? id) {
    for (final layer in layers) {
      if (layer.id == id) return layer;
    }
    return null;
  }

  int _layerSerial = 0;

  String _newLayerId() =>
      'l${DateTime.now().microsecondsSinceEpoch}_${_layerSerial++}';

  /// Añade una capa encima de [aboveId] (o arriba del todo) y devuelve su id.
  String addLayer({String? name, String? aboveId}) {
    final current = List.of(layers);
    final id = _newLayerId();
    final index = aboveId == null
        ? current.length
        : current.indexWhere((layer) => layer.id == aboveId) + 1;
    final layer = AnnotationLayer(
      id: id,
      name: name ?? 'Capa ${current.length + 1}',
    );
    current.insert(index.clamp(0, current.length), layer);
    _commit(_document.copyWith(layers: current));
    return id;
  }

  void updateLayer(
    String id, {
    String? name,
    bool? visible,
    bool? locked,
    double? opacity,
    AnnotationLayerBlend? blend,
    bool? alphaLock,
    bool? clip,
    bool commit = true,
  }) {
    final current = List.of(layers);
    final index = current.indexWhere((layer) => layer.id == id);
    if (index < 0) return;
    current[index] = current[index].copyWith(
      name: name,
      visible: visible,
      locked: locked,
      opacity: opacity,
      blend: blend,
      alphaLock: alphaLock,
      clip: clip,
    );
    final next = _document.copyWith(layers: current);
    if (commit) {
      _commit(next);
    } else {
      _document = next;
      notifyListeners();
    }
  }

  /// Quita la capa y lo que tiene. Siempre queda al menos una.
  void removeLayer(String id) {
    final current = layers;
    if (current.length <= 1) return;
    final doc = _document;
    _commit(
      doc.copyWith(
        layers: current.where((layer) => layer.id != id).toList(),
        strokes: doc.strokes
            .where((stroke) => doc.strokeLayerId(stroke) != id)
            .toList(),
        stamps: doc.stamps
            .where((stamp) => doc.stampLayerId(stamp) != id)
            .toList(),
      ),
    );
  }

  /// Mueve la capa a [index] (0 = abajo del todo).
  void moveLayer(String id, int index) {
    final current = List.of(layers);
    final from = current.indexWhere((layer) => layer.id == id);
    if (from < 0) return;
    final layer = current.removeAt(from);
    current.insert(index.clamp(0, current.length), layer);
    if (from == current.indexOf(layer)) return;
    // Los trazos sin capa caen en la de abajo: se les fija la suya antes
    // de que cambie cuál es.
    _commit(_pinLayers(_document).copyWith(layers: current));
  }

  /// Copia la capa con todo su contenido justo encima. Devuelve la nueva.
  String? duplicateLayer(String id) {
    final source = layerById(id);
    if (source == null) return null;
    final doc = _pinLayers(_document);
    final newId = _newLayerId();
    final current = List.of(layers);
    current.insert(
      current.indexWhere((layer) => layer.id == id) + 1,
      AnnotationLayer(
        id: newId,
        name: '${source.name} copia',
        visible: source.visible,
        opacity: source.opacity,
        blend: source.blend,
        alphaLock: source.alphaLock,
        clip: source.clip,
      ),
    );
    var serial = 0;
    String copyId(String old) => '$old-$newId-${serial++}';
    _commit(
      doc.copyWith(
        layers: current,
        strokes: [
          ...doc.strokes,
          for (final stroke in doc.strokes)
            if (stroke.layerId == id)
              AnnotationStroke(
                id: copyId(stroke.id),
                tool: stroke.tool,
                colorArgb: stroke.colorArgb,
                width: stroke.width,
                points: stroke.points,
                inputKind: stroke.inputKind,
                opacity: stroke.opacity,
                closed: stroke.closed,
                brushId: stroke.brushId,
                layerId: newId,
                // Misma semilla: la copia sale idéntica.
                seed: BrushEngine.seedFor(stroke),
                alphaLocked: stroke.alphaLocked,
              ),
        ],
        stamps: [
          ...doc.stamps,
          for (final stamp in doc.stamps)
            if (stamp.layerId == id)
              AnnotationStamp(
                id: copyId(stamp.id),
                kind: stamp.kind,
                x: stamp.x,
                y: stamp.y,
                rotation: stamp.rotation,
                size: stamp.size,
                colorArgb: stamp.colorArgb,
                label: stamp.label,
                layerId: newId,
              ),
        ],
      ),
    );
    return newId;
  }

  /// Junta la capa con la de abajo. Su opacidad pasa a los trazos.
  void mergeDown(String id) {
    final current = layers;
    final index = current.indexWhere((layer) => layer.id == id);
    if (index <= 0) return;
    final upper = current[index];
    final lower = current[index - 1];
    final doc = _pinLayers(_document);
    _commit(
      doc.copyWith(
        layers: [...current]..removeAt(index),
        strokes: [
          for (final stroke in doc.strokes)
            stroke.layerId == upper.id
                ? stroke.copyWith(
                    layerId: lower.id,
                    opacity: stroke.opacity * upper.opacity,
                  )
                : stroke,
        ],
        stamps: [
          for (final stamp in doc.stamps)
            stamp.layerId == upper.id
                ? stamp.copyWith(layerId: lower.id)
                : stamp,
        ],
      ),
    );
  }

  /// Aplica las capas y el papel de un estilo. En un folio vacío las capas
  /// se sustituyen; si ya hay dibujo, las que faltan se añaden encima.
  void applyLayout(List<AnnotationLayer> styleLayers, AnnotationPaper paper) {
    final doc = _document;
    final hasContent = doc.strokes.isNotEmpty || doc.stamps.isNotEmpty;
    final List<AnnotationLayer> next;
    if (!hasContent) {
      next = styleLayers;
    } else {
      final current = doc.effectiveLayers;
      next = [
        ...current,
        for (final layer in styleLayers)
          if (!current.any((l) => l.id == layer.id)) layer,
      ];
    }
    final pinned = hasContent ? _pinLayers(doc) : doc;
    _commit(pinned.copyWith(layers: next, paper: paper));
  }

  /// Papel con imagen (de [PaperLibrary]); `null` vuelve al papel liso.
  void setPaperImage(String? id) {
    if (id == _document.paperImage) return;
    _commit(
      id == null
          ? _document.copyWith(clearPaperImage: true)
          : _document.copyWith(
              paperImage: id,
              paper: _document.paper ?? AnnotationPaper.ivory,
            ),
    );
  }

  void setPaper(AnnotationPaper? paper) {
    if (paper == _document.paper && _document.paperImage == null) return;
    _commit(
      paper == null
          ? _document.copyWith(clearPaper: true, clearPaperImage: true)
          : _document.copyWith(paper: paper, clearPaperImage: true),
    );
  }

  /// Fija en cada trazo y sello la capa en la que se ve ahora, para que
  /// reordenar o quitar capas no los cambie de sitio.
  static AnnotationDocument _pinLayers(AnnotationDocument doc) {
    final layers = doc.effectiveLayers;
    return doc.copyWith(
      layers: layers,
      strokes: [
        for (final stroke in doc.strokes)
          stroke.layerId == doc.strokeLayerId(stroke)
              ? stroke
              : stroke.copyWith(layerId: doc.strokeLayerId(stroke)),
      ],
      stamps: [
        for (final stamp in doc.stamps)
          stamp.layerId == doc.stampLayerId(stamp)
              ? stamp
              : stamp.copyWith(layerId: doc.stampLayerId(stamp)),
      ],
    );
  }

  /// Sello bajo [point] (píxeles de documento de tamaño [size]).
  String? hitTestStamp(Offset point, Size size) {
    for (final stamp in _document.stamps.reversed) {
      final center = AnnotationBrushes.stampCenter(stamp, size);
      final radius = math.max(12.0, AnnotationBrushes.stampRadius(stamp, size));
      if ((point - center).distance <= radius * 1.15) return stamp.id;
    }
    return null;
  }

  /// Agrupa los cambios de un arrastre en un solo paso de deshacer.
  void beginGesture() => beginNoteDrag();

  void endGesture() => endNoteDrag();

  void beginNoteDrag() {
    _noteDragBaseline ??= _document;
  }

  void updateNote(
    String id, {
    String? text,
    double? x,
    double? y,
    double? width,
    double? height,
    int? colorArgb,
    bool commit = true,
  }) {
    final index = _document.notes.indexWhere((note) => note.id == id);
    if (index < 0) return;
    final nextNotes = List<AnnotationNote>.from(_document.notes);
    nextNotes[index] = nextNotes[index].copyWith(
      text: text,
      x: x,
      y: y,
      width: width,
      height: height,
      colorArgb: colorArgb,
    );
    final next = _document.copyWith(notes: nextNotes);
    if (commit) {
      _commit(next);
    } else {
      _document = next;
      notifyListeners();
    }
  }

  void endNoteDrag() {
    final baseline = _noteDragBaseline;
    _noteDragBaseline = null;
    if (baseline == null || baseline == _document) return;
    _undo.add(baseline);
    if (_undo.length > 80) _undo.removeAt(0);
    _redo.clear();
    notifyListeners();
  }

  String? hitTestStroke(double nx, double ny, {double threshold = 0.02}) {
    final p = Offset(nx, ny);
    final usable = {
      for (final layer in _document.effectiveLayers)
        if (layer.visible && !layer.locked) layer.id,
    };
    for (final stroke in _document.strokes.reversed) {
      if (stroke.tool == AnnotationToolType.eraseArea) continue;
      if (!usable.contains(_document.strokeLayerId(stroke))) continue;
      final pts = [for (final q in stroke.points) Offset(q.x, q.y)];
      if (pts.isEmpty) continue;
      if ((AnnotationBrushes.isAreaTool(stroke.tool) || stroke.closed) &&
          pts.length >= 3 &&
          _insidePolygon(p, pts)) {
        return stroke.id;
      }
      final reach =
          threshold +
          (stroke.tool == AnnotationToolType.wash ||
                  stroke.tool == AnnotationToolType.airbrush
              ? stroke.width / 1000
              : 0);
      if (pts.length == 1) {
        if ((pts.single - p).distance <= reach) return stroke.id;
        continue;
      }
      final path = stroke.closed ? [...pts, pts.first] : pts;
      for (var i = 1; i < path.length; i++) {
        if (_distToSegment(p, path[i - 1], path[i]) <= reach) return stroke.id;
      }
    }
    return null;
  }

  static bool _insidePolygon(Offset p, List<Offset> poly) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i];
      final b = poly[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  static double _distToSegment(Offset p, Offset a, Offset b) {
    final ab = b - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(
      0.0,
      1.0,
    );
    return (p - (a + ab * t)).distance;
  }

  void removeNote(String id) {
    final next = _document.notes.where((note) => note.id != id).toList();
    if (next.length == _document.notes.length) return;
    _commit(_document.copyWith(notes: next));
  }

  String? hitTestNote(double nx, double ny) {
    for (final note in _document.notes.reversed) {
      if (note.containsNormalized(nx, ny)) return note.id;
    }
    return null;
  }

  void removeStroke(String id) {
    final next = _document.strokes.where((stroke) => stroke.id != id).toList();
    if (next.length == _document.strokes.length) return;
    _commit(_document.copyWith(strokes: next));
  }

  void clear() {
    if (_document.isEmpty) return;
    _selectedStampId = null;
    _commit(
      AnnotationDocument(
        layers: _document.layers,
        paper: _document.paper,
        paperImage: _document.paperImage,
      ),
    );
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_document);
    _document = _undo.removeLast();
    _dropStaleSelection();
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_document);
    _document = _redo.removeLast();
    _dropStaleSelection();
    notifyListeners();
  }

  void _dropStaleSelection() {
    if (selectedStamp == null) _selectedStampId = null;
    final strokes = {for (final s in _document.strokes) s.id};
    final stamps = {for (final s in _document.stamps) s.id};
    _selStrokes.removeWhere((id) => !strokes.contains(id));
    _selStamps.removeWhere((id) => !stamps.contains(id));
  }

  void _commit(AnnotationDocument next) {
    _undo.add(_document);
    if (_undo.length > 80) _undo.removeAt(0);
    _redo.clear();
    _document = next;
    _dropStaleSelection();
    notifyListeners();
  }
}

class AnnotationCanvas extends StatefulWidget {
  final AnnotationCanvasController controller;
  final bool enabled;
  final AnnotationToolType tool;
  final Color color;
  final double width;
  final bool acceptTouch;
  final bool acceptMouse;
  final AnnotationViewport? viewport;
  final ValueChanged<AnnotationDocument>? onChanged;
  final Widget? child;
  final bool interactiveNotes;
  final String? selectedNoteId;
  final ValueChanged<String?>? onNoteSelected;
  final Future<void> Function(AnnotationNote note)? onNoteEditRequested;

  /// Opacidad del trazo nuevo (0–1).
  final double opacity;

  /// Sello que coloca la herramienta [AnnotationToolType.stamp].
  final AnnotationStampKind stampKind;

  /// Tamaño del sello nuevo, en fracción del lado corto.
  final double stampSize;

  /// Mantener quieto el lápiz al final del trazo lo convierte en recta,
  /// polilínea, rectángulo o elipse.
  final bool straightenOnHold;

  /// Pide el texto para la herramienta [AnnotationToolType.text].
  final Future<String?> Function()? onTextRequested;

  /// Se llama al tocar un sello ya seleccionado (para ponerle nombre).
  final Future<void> Function(AnnotationStamp stamp)? onStampEditRequested;

  /// Pincel del catálogo con el que se pinta [tool] (su familia).
  final String? brushId;

  /// Capa en la que caen los trazos y sellos nuevos.
  final String? layerId;

  /// Bloqueo de alfa de la capa activa: los trazos solo cubren lo pintado.
  final bool alphaLocked;

  /// Estabilizador (0–1): suaviza el temblor del trazo a costa de que
  /// siga al lápiz con algo de retraso.
  final double streamline;

  /// Zoom con el que se ve el folio: sube la resolución de las capas.
  final double resolutionScale;

  /// Rejilla con imán para los sellos (fracción del lado corto), o `null`.
  final double? gridStep;

  /// Imán de las rectas (p. ej. hacia los puntos de fuga): recibe inicio y
  /// final en píxeles y devuelve el final ajustado, o `null` para usar el
  /// ajuste a 45°.
  final Offset? Function(Offset start, Offset end, Size size)? lineSnap;

  const AnnotationCanvas({
    super.key,
    required this.controller,
    required this.enabled,
    required this.tool,
    required this.color,
    required this.width,
    this.acceptTouch = false,
    this.acceptMouse = true,
    this.viewport,
    this.onChanged,
    this.child,
    this.interactiveNotes = false,
    this.selectedNoteId,
    this.onNoteSelected,
    this.onNoteEditRequested,
    this.opacity = 1,
    this.stampKind = AnnotationStampKind.camera,
    this.stampSize = 0.07,
    this.straightenOnHold = true,
    this.onTextRequested,
    this.onStampEditRequested,
    this.brushId,
    this.layerId,
    this.alphaLocked = false,
    this.streamline = 0,
    this.resolutionScale = 1,
    this.lineSnap,
    this.gridStep,
  });

  @override
  State<AnnotationCanvas> createState() => _AnnotationCanvasState();
}

enum _StampDrag { move, rotate, beam, group, lasso }

class _AnnotationCanvasState extends State<AnnotationCanvas> {
  static const _holdDelay = Duration(milliseconds: 450);
  static const _holdSlop = 3.0;

  int? _activePointer;
  AnnotationToolType _activeTool = AnnotationToolType.pen;
  AnnotationInputKind _inputKind = AnnotationInputKind.unknown;
  final List<AnnotationPoint> _livePoints = [];
  Size _documentSize = Size.zero;

  Timer? _holdTimer;
  Offset? _holdAnchor;
  RecognizedShapeKind? _snapped;
  bool _snappedClosed = false;

  AnnotationStamp? _liveStamp;
  Offset? _downDoc;
  Offset _stampStart = Offset.zero;
  Offset _moveStart = Offset.zero;
  _StampDrag? _stampDrag;

  /// Lazo de selección en curso (píxeles de documento).
  List<Offset>? _lasso;
  Offset _groupStart = Offset.zero;
  bool _stampDragMoved = false;
  bool _tappedSelected = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.controller._cancelLive = _cancelLive;
  }

  void _cancelLive() {
    if (_activePointer == null) return;
    _holdTimer?.cancel();
    _activePointer = null;
    _livePoints.clear();
    _liveStamp = null;
    _snapped = null;
    _snappedClosed = false;
    if (_activeTool == AnnotationToolType.select) {
      if (_stampDrag == _StampDrag.group) {
        widget.controller.updateLift(Offset.zero);
        widget.controller.endLift();
      }
      _stampDrag = null;
      _lasso = null;
      widget.controller.endGesture();
    }
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(AnnotationCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
    if (oldWidget.tool == AnnotationToolType.select &&
        widget.tool != AnnotationToolType.select) {
      widget.controller.selectStamp(null);
    }
  }

  @override
  void dispose() {
    if (widget.controller._cancelLive == _cancelLive) {
      widget.controller._cancelLive = null;
    }
    _holdTimer?.cancel();
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    widget.onChanged?.call(widget.controller.document);
    if (mounted) setState(() {});
  }

  bool _accepts(PointerEvent event) {
    if (!widget.enabled) return false;
    return switch (event.kind) {
      PointerDeviceKind.stylus || PointerDeviceKind.invertedStylus => true,
      PointerDeviceKind.touch => widget.acceptTouch,
      PointerDeviceKind.mouse ||
      PointerDeviceKind.trackpad => widget.acceptMouse,
      _ => false,
    };
  }

  AnnotationInputKind _kindFor(PointerDeviceKind kind) => switch (kind) {
    PointerDeviceKind.stylus => AnnotationInputKind.stylus,
    PointerDeviceKind.invertedStylus => AnnotationInputKind.invertedStylus,
    PointerDeviceKind.touch => AnnotationInputKind.touch,
    PointerDeviceKind.mouse ||
    PointerDeviceKind.trackpad => AnnotationInputKind.mouse,
    _ => AnnotationInputKind.unknown,
  };

  /// Posición en píxeles del documento.
  Offset _docOffset(PointerEvent event) =>
      widget.viewport?.localToDocument(event.localPosition) ??
      event.localPosition;

  AnnotationPoint _pointFor(PointerEvent event) {
    final documentPosition = _docOffset(event);
    final pressureRange = event.pressureMax - event.pressureMin;
    final normalizedPressure = pressureRange > 0
        ? ((event.pressure - event.pressureMin) / pressureRange).clamp(
            0.05,
            1.0,
          )
        : 1.0;
    final stylus =
        event.kind == PointerDeviceKind.stylus ||
        event.kind == PointerDeviceKind.invertedStylus;
    return AnnotationPoint(
      x: (documentPosition.dx / _documentSize.width).clamp(0.0, 1.0),
      y: (documentPosition.dy / _documentSize.height).clamp(0.0, 1.0),
      pressure: normalizedPressure,
      tilt: stylus ? event.tilt : 0,
      azimuth: stylus ? event.orientation : 0,
    );
  }

  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  void _eraseAt(PointerEvent event) {
    final docPoint = _docOffset(event);
    final stampHit = widget.controller.hitTestStamp(docPoint, _documentSize);
    if (stampHit != null) {
      widget.controller.removeStamp(stampHit);
      return;
    }
    final point = _pointFor(event);
    final hit = widget.controller.hitTestStroke(point.x, point.y);
    if (hit != null) widget.controller.removeStroke(hit);
  }

  void _onPointerDown(PointerDownEvent event, Size size) {
    if (_activePointer != null || !_accepts(event)) return;
    _documentSize = widget.viewport?.documentSize ?? size;
    final tool = event.kind == PointerDeviceKind.invertedStylus
        ? AnnotationToolType.eraser
        : widget.tool;
    _activePointer = event.pointer;
    _activeTool = tool;
    _inputKind = _kindFor(event.kind);
    final docPoint = _docOffset(event);
    _downDoc = docPoint;

    switch (tool) {
      case AnnotationToolType.eraser:
        _eraseAt(event);
        return;
      case AnnotationToolType.select:
        _beginSelect(docPoint);
        return;
      case AnnotationToolType.stamp:
        final raw = _pointFor(event);
        final p = _snapToGrid(Offset(raw.x, raw.y));
        _liveStamp = AnnotationStamp(
          id: _newId(),
          kind: widget.stampKind,
          x: p.dx,
          y: p.dy,
          rotation: -math.pi / 2,
          size: widget.stampSize,
          colorArgb: widget.color.toARGB32(),
          layerId: widget.layerId,
        );
        setState(() {});
        return;
      case AnnotationToolType.text:
        return;
      default:
        _snapped = null;
        _snappedClosed = false;
        _livePoints
          ..clear()
          ..add(_pointFor(event));
        _restartHold(event.localPosition);
        setState(() {});
    }
  }

  void _beginSelect(Offset docPoint) {
    final controller = widget.controller;
    final selected = controller.selectedStamp;
    _stampDragMoved = false;
    _tappedSelected = false;
    if (selected != null &&
        AnnotationBrushes.hasBeam(selected.kind) &&
        (docPoint - AnnotationBrushes.beamHandle(selected, _documentSize))
                .distance <=
            16) {
      _stampDrag = _StampDrag.beam;
      controller.beginGesture();
      return;
    }
    if (selected != null &&
        selected.kind != AnnotationStampKind.text &&
        (docPoint - AnnotationBrushes.stampHandle(selected, _documentSize))
                .distance <=
            16) {
      _stampDrag = _StampDrag.rotate;
      controller.beginGesture();
      return;
    }
    final hit = controller.hitTestStamp(docPoint, _documentSize);
    final bounds = controller.selectionBounds(_documentSize)?.inflate(8);
    final insideSelection =
        controller.selectionCount > 1 &&
        bounds != null &&
        bounds.contains(docPoint);
    if (hit == null || insideSelection) {
      // Dentro de la selección: se mueve todo junto.
      if (insideSelection) {
        _startGroupMove(docPoint);
        return;
      }
      // Un trazo: se selecciona y se mueve.
      final p = Offset(
        docPoint.dx / _documentSize.width,
        docPoint.dy / _documentSize.height,
      );
      final stroke = controller.hitTestStroke(p.dx, p.dy, threshold: 0.012);
      if (stroke != null) {
        if (!controller.selectedStrokeIds.contains(stroke)) {
          controller.setSelection(strokes: [stroke], stamps: const []);
        }
        _startGroupMove(docPoint);
        return;
      }
      // Nada debajo: lazo.
      controller.clearSelection();
      _stampDrag = _StampDrag.lasso;
      _lasso = [docPoint];
      return;
    }
    _tappedSelected = hit == controller.selectedStampId;
    controller.selectStamp(hit);
    final stamp = controller.selectedStamp!;
    _stampStart = Offset(stamp.x, stamp.y);
    _moveStart = docPoint;
    _stampDrag = _StampDrag.move;
    controller.beginGesture();
  }

  void _startGroupMove(Offset docPoint) {
    _stampDrag = _StampDrag.group;
    _groupStart = docPoint;
    widget.controller.beginLift();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    final docPoint = _docOffset(event);
    switch (_activeTool) {
      case AnnotationToolType.eraser:
        _eraseAt(event);
        return;
      case AnnotationToolType.select:
        _dragSelected(docPoint);
        return;
      case AnnotationToolType.stamp:
        final stamp = _liveStamp;
        final down = _downDoc;
        if (stamp == null || down == null) return;
        final delta = docPoint - down;
        if (delta.distance < 8) return;
        _liveStamp = stamp.copyWith(rotation: _snapAngle(delta.direction));
        setState(() {});
        return;
      case AnnotationToolType.text:
        return;
      case AnnotationToolType.line:
        final start = _livePoints.first;
        final end = _pointFor(event);
        _livePoints
          ..clear()
          ..addAll(_snappedLine(start, end));
        setState(() {});
        return;
      default:
        if (_snapped == RecognizedShapeKind.line) {
          // Tras enderezar, la recta sigue al lápiz desde su origen.
          final start = _livePoints.first;
          _livePoints
            ..clear()
            ..addAll(_snappedLine(start, _pointFor(event)));
          setState(() {});
          return;
        }
        if (_snapped != null) return;
        _livePoints.add(_stabilized(_pointFor(event)));
        final anchor = _holdAnchor;
        if (anchor == null ||
            (event.localPosition - anchor).distance > _holdSlop) {
          _restartHold(event.localPosition);
        }
        setState(() {});
    }
  }

  void _dragSelected(Offset docPoint) {
    final controller = widget.controller;
    if (_stampDrag == _StampDrag.lasso) {
      final lasso = _lasso;
      if (lasso != null && (docPoint - lasso.last).distance > 2) {
        lasso.add(docPoint);
        setState(() {});
      }
      return;
    }
    if (_stampDrag == _StampDrag.group) {
      final d = docPoint - _groupStart;
      controller.updateLift(
        Offset(d.dx / _documentSize.width, d.dy / _documentSize.height),
      );
      return;
    }
    final stamp = controller.selectedStamp;
    final down = _downDoc;
    if (stamp == null || _stampDrag == null || down == null) return;
    if ((docPoint - down).distance > 3) _stampDragMoved = true;
    if (_stampDrag == _StampDrag.rotate) {
      final center = AnnotationBrushes.stampCenter(stamp, _documentSize);
      controller.updateStamp(
        stamp.id,
        rotation: _snapAngle((docPoint - center).direction),
        commit: false,
      );
    } else if (_stampDrag == _StampDrag.beam) {
      final center = AnnotationBrushes.stampCenter(stamp, _documentSize);
      final v = docPoint - center;
      final r = math.max(
        1.0,
        AnnotationBrushes.stampRadius(stamp, _documentSize),
      );
      var diff = v.direction - stamp.rotation;
      while (diff > math.pi) {
        diff -= 2 * math.pi;
      }
      while (diff < -math.pi) {
        diff += 2 * math.pi;
      }
      controller.updateStamp(
        stamp.id,
        spread: (diff.abs() * 2).clamp(0.09, 2.97),
        reach: (v.distance / r).clamp(0.8, 12.0),
        commit: false,
      );
    } else {
      final delta = docPoint - _moveStart;
      final p = _snapToGrid(
        Offset(
          _stampStart.dx + delta.dx / _documentSize.width,
          _stampStart.dy + delta.dy / _documentSize.height,
        ),
      );
      controller.updateStamp(
        stamp.id,
        x: p.dx.clamp(0.0, 1.0),
        y: p.dy.clamp(0.0, 1.0),
        commit: false,
      );
    }
  }

  /// Ajusta una posición normalizada a la rejilla con imán.
  Offset _snapToGrid(Offset p) {
    final step = widget.gridStep;
    if (step == null || step <= 0) return p;
    final px = step * _documentSize.shortestSide;
    final x = (p.dx * _documentSize.width / px).round() * px;
    final y = (p.dy * _documentSize.height / px).round() * px;
    return Offset(x / _documentSize.width, y / _documentSize.height);
  }

  Future<void> _onPointerUp(PointerEvent event) async {
    if (event.pointer != _activePointer) return;
    _holdTimer?.cancel();
    _activePointer = null;
    final tool = _activeTool;
    switch (tool) {
      case AnnotationToolType.eraser:
        return;
      case AnnotationToolType.select:
        if (_stampDrag == _StampDrag.lasso) {
          final lasso = _lasso ?? const [];
          _lasso = null;
          _stampDrag = null;
          final w = _documentSize.width, h = _documentSize.height;
          widget.controller.selectInLasso([
            for (final q in lasso) Offset(q.dx / w, q.dy / h),
          ]);
          setState(() {});
          return;
        }
        if (_stampDrag == _StampDrag.group) {
          _stampDrag = null;
          if (event is PointerUpEvent) {
            widget.controller.endLift();
          } else {
            widget.controller.updateLift(Offset.zero);
            widget.controller.endLift();
          }
          return;
        }
        widget.controller.endGesture();
        final stamp = widget.controller.selectedStamp;
        if (_tappedSelected && !_stampDragMoved && stamp != null) {
          await widget.onStampEditRequested?.call(stamp);
        }
        _stampDrag = null;
        return;
      case AnnotationToolType.stamp:
        final stamp = _liveStamp;
        _liveStamp = null;
        if (stamp != null && event is PointerUpEvent) {
          widget.controller.addStamp(stamp);
        }
        setState(() {});
        return;
      case AnnotationToolType.text:
        if (event is! PointerUpEvent) return;
        final p = _pointFor(event);
        final text = (await widget.onTextRequested?.call())?.trim();
        if (text == null || text.isEmpty) return;
        widget.controller.addStamp(
          AnnotationStamp(
            id: _newId(),
            kind: AnnotationStampKind.text,
            x: p.x,
            y: p.y,
            size: widget.stampSize * 0.6,
            colorArgb: widget.color.toARGB32(),
            label: text,
            layerId: widget.layerId,
          ),
        );
        return;
      default:
        _commitLiveStroke(tool);
    }
  }

  void _commitLiveStroke(AnnotationToolType tool) {
    final points = List.of(_livePoints);
    final closed = _snappedClosed;
    final inputKind = _inputKind;
    _livePoints.clear();
    _snapped = null;
    _snappedClosed = false;
    _inputKind = AnnotationInputKind.unknown;
    final valid = switch (tool) {
      AnnotationToolType.fill || AnnotationToolType.hatch => points.length >= 3,
      AnnotationToolType.line || AnnotationToolType.arrow => points.length >= 2,
      _ => points.isNotEmpty,
    };
    if (valid) {
      widget.controller.addStroke(
        AnnotationStroke(
          id: _newId(),
          tool: tool,
          colorArgb: widget.color.toARGB32(),
          width: widget.width,
          inputKind: inputKind,
          points: points,
          opacity: widget.opacity,
          closed: closed,
          brushId: tool == widget.tool ? widget.brushId : null,
          layerId: widget.layerId,
          alphaLocked: widget.alphaLocked,
        ),
      );
    }
    setState(() {});
  }

  /// Con estabilizador, el punto nuevo se acerca al anterior.
  AnnotationPoint _stabilized(AnnotationPoint raw) {
    final k = widget.streamline.clamp(0.0, 1.0);
    if (k == 0 || _livePoints.isEmpty) return raw;
    final prev = _livePoints.last;
    final follow = 1 - k * 0.85;
    return AnnotationPoint(
      x: prev.x + (raw.x - prev.x) * follow,
      y: prev.y + (raw.y - prev.y) * follow,
      pressure: raw.pressure,
      tilt: raw.tilt,
      azimuth: raw.azimuth,
    );
  }

  void _restartHold(Offset local) {
    _holdAnchor = local;
    _holdTimer?.cancel();
    if (!widget.straightenOnHold ||
        !AnnotationBrushes.canStraighten(_activeTool)) {
      return;
    }
    _holdTimer = Timer(_holdDelay, _straighten);
  }

  /// Sustituye el trazo vivo por la forma limpia que reconoce.
  void _straighten() {
    if (_activePointer == null || _livePoints.length < 2 || _snapped != null) {
      return;
    }
    final w = _documentSize.width;
    final h = _documentSize.height;
    final shape = AnnotationShapeRecognizer.recognize([
      for (final p in _livePoints) Offset(p.x * w, p.y * h),
    ]);
    if (shape == null) return;
    // Un área a lazo siempre se queda cerrada.
    final area = AnnotationBrushes.isAreaTool(_activeTool);
    if (area && !shape.closed && shape.kind != RecognizedShapeKind.polyline) {
      return;
    }
    final pressure =
        _livePoints.map((p) => p.pressure).reduce((a, b) => a + b) /
        _livePoints.length;
    _livePoints
      ..clear()
      ..addAll([
        for (final p in shape.points)
          AnnotationPoint(
            x: (p.dx / w).clamp(0.0, 1.0),
            y: (p.dy / h).clamp(0.0, 1.0),
            pressure: pressure,
          ),
      ]);
    if (shape.kind == RecognizedShapeKind.line && _livePoints.length == 2) {
      final snapped = _snappedLine(_livePoints.first, _livePoints.last);
      _livePoints
        ..clear()
        ..addAll(snapped);
    }
    _snapped = shape.kind;
    _snappedClosed = shape.closed && !area;
    HapticFeedback.selectionClick();
    if (mounted) setState(() {});
  }

  List<AnnotationPoint> _snappedLine(AnnotationPoint a, AnnotationPoint b) {
    final w = _documentSize.width;
    final h = _documentSize.height;
    final start = Offset(a.x * w, a.y * h);
    final end = Offset(b.x * w, b.y * h);
    final snapped =
        widget.lineSnap?.call(start, end, _documentSize) ??
        AnnotationShapeRecognizer.snapLine(start, end).last;
    return [
      a,
      AnnotationPoint(
        x: (snapped.dx / w).clamp(0.0, 1.0),
        y: (snapped.dy / h).clamp(0.0, 1.0),
        pressure: a.pressure,
      ),
    ];
  }

  static double _snapAngle(double angle) {
    const step = math.pi / 4;
    final nearest = (angle / step).round() * step;
    return (angle - nearest).abs() <= AnnotationShapeRecognizer.angleSnap
        ? nearest
        : angle;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final docSize = widget.viewport?.documentSize ?? size;
        final longest = math.max(1.0, docSize.longestSide);
        widget.controller.lastSize = docSize;
        widget.controller.compositor.pixelRatio = math.min(
          (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1) *
              widget.resolutionScale,
          4096 / longest,
        );
        final live = _livePoints.isEmpty
            ? null
            : AnnotationStroke(
                id: 'live',
                tool: _activeTool,
                colorArgb: widget.color.toARGB32(),
                width: widget.width,
                inputKind: _inputKind,
                points: List.of(_livePoints),
                opacity: widget.opacity,
                closed: _snappedClosed,
                brushId: _activeTool == widget.tool ? widget.brushId : null,
                layerId: widget.layerId,
                alphaLocked: widget.alphaLocked,
              );
        widget.controller._reportLive(live);
        return Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => _onPointerDown(event, size),
              onPointerMove: _onPointerMove,
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerUp,
              child: CustomPaint(
                foregroundPainter: AnnotationPainter(
                  document: widget.controller.document,
                  liveStroke: live ?? widget.controller.remoteStroke,
                  liveStamp: _liveStamp,
                  selectedStampId: widget.tool == AnnotationToolType.select
                      ? widget.controller.selectedStampId
                      : null,
                  liftedStrokes: widget.controller.isLifted
                      ? widget.controller.selectedStrokeIds
                      : const {},
                  liftedStamps: widget.controller.isLifted
                      ? widget.controller.selectedStampIds
                      : const {},
                  liftOffset: Offset(
                    widget.controller.liftOffset.dx * docSize.width,
                    widget.controller.liftOffset.dy * docSize.height,
                  ),
                  selectionRect:
                      widget.tool == AnnotationToolType.select &&
                          (widget.controller.selectionCount > 1 ||
                              widget.controller.selectedStrokeIds.isNotEmpty)
                      ? widget.controller
                            .selectionBounds(docSize)
                            ?.shift(
                              Offset(
                                widget.controller.liftOffset.dx * docSize.width,
                                widget.controller.liftOffset.dy *
                                    docSize.height,
                              ),
                            )
                      : null,
                  lasso: _lasso,
                  viewport: widget.viewport,
                  paintNotes: !widget.interactiveNotes,
                  compositor: widget.controller.compositor,
                ),
                child: widget.child ?? const SizedBox.expand(),
              ),
            ),
            if (widget.interactiveNotes)
              ...widget.controller.document.notes.map(
                (note) => _InteractiveAnnotationNote(
                  note: note,
                  canvasSize: size,
                  controller: widget.controller,
                  selected: widget.selectedNoteId == note.id,
                  onSelect: () => widget.onNoteSelected?.call(note.id),
                  onEdit: () => widget.onNoteEditRequested?.call(note),
                ),
              ),
          ],
        );
      },
    );
  }
}

class AnnotationPainter extends CustomPainter {
  final AnnotationDocument document;
  final AnnotationStroke? liveStroke;
  final AnnotationStamp? liveStamp;
  final String? selectedStampId;
  final AnnotationViewport? viewport;
  final bool paintNotes;

  /// Guarda las capas ya rasterizadas entre fotogramas. Sin él se usa uno
  /// compartido por documento.
  final AnnotationCompositor? compositor;

  /// Selección que se está arrastrando: se pinta desplazada [liftOffset].
  final Set<String> liftedStrokes;
  final Set<String> liftedStamps;
  final Offset liftOffset;

  /// Caja de la selección y lazo en curso (píxeles de documento).
  final Rect? selectionRect;
  final List<Offset>? lasso;

  const AnnotationPainter({
    required this.document,
    this.liveStroke,
    this.liveStamp,
    this.selectedStampId,
    this.viewport,
    this.paintNotes = true,
    this.compositor,
    this.liftedStrokes = const {},
    this.liftedStamps = const {},
    this.liftOffset = Offset.zero,
    this.selectionRect,
    this.lasso,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final documentSize = viewport?.documentSize ?? size;
    if (viewport != null) {
      canvas.save();
      canvas.translate(viewport!.offset.dx, viewport!.offset.dy);
      canvas.scale(viewport!.scale);
    }
    final live = liveStroke;
    (compositor ?? AnnotationCompositor.sharedFor(document)).paint(
      canvas,
      documentSize,
      document,
      live: live,
      liveStamp: liveStamp,
      selectedStampId: selectedStampId,
      liftedStrokes: liftedStrokes,
      liftedStamps: liftedStamps,
      liftOffset: liftOffset,
    );
    _paintSelection(canvas);
    if (live != null &&
        AnnotationBrushes.isAreaTool(live.tool) &&
        live.points.length > 1) {
      _paintLassoOutline(canvas, documentSize, live);
    }
    if (paintNotes) {
      for (final note in document.notes) {
        _paintNote(canvas, documentSize, note);
      }
    }
    if (viewport != null) canvas.restore();
  }

  /// Caja punteada de la selección y lazo en curso.
  void _paintSelection(Canvas canvas) {
    final blue = Paint()
      ..color = const Color(0xFF2997FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = selectionRect;
    if (rect != null) {
      canvas.drawRect(rect, Paint()..color = const Color(0x142997FF));
      _dashedPath(canvas, Path()..addRect(rect), blue);
    }
    final points = lasso;
    if (points != null && points.length > 1) {
      final path = Path()..addPolygon(points, false);
      canvas.drawPath(path, Paint()..color = const Color(0x0F2997FF));
      _dashedPath(canvas, path, blue);
    }
  }

  static void _dashedPath(Canvas canvas, Path path, Paint paint) {
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 12) {
        canvas.drawPath(
          metric.extractPath(d, math.min(metric.length, d + 6)),
          paint,
        );
      }
    }
  }

  void _paintLassoOutline(Canvas canvas, Size size, AnnotationStroke stroke) {
    final path = Path()
      ..addPolygon([
        for (final p in stroke.points)
          Offset(p.x * size.width, p.y * size.height),
      ], true);
    canvas.drawPath(
      path,
      Paint()
        ..color = Color(stroke.colorArgb).withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  void _paintNote(Canvas canvas, Size size, AnnotationNote note) {
    final rect = Rect.fromLTWH(
      note.x * size.width,
      note.y * size.height,
      note.width * size.width,
      note.height * size.height,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..color = Color(note.colorArgb),
    );
    final painter = TextPainter(
      text: TextSpan(
        text: note.text,
        style: TextStyle(
          color: Colors.black.withValues(alpha: 0.82),
          fontSize: 13,
          height: 1.25,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 8,
      ellipsis: '…',
    )..layout(maxWidth: math.max(0, rect.width - 16));
    painter.paint(canvas, rect.topLeft + const Offset(8, 8));
  }

  @override
  bool shouldRepaint(covariant AnnotationPainter oldDelegate) =>
      oldDelegate.document != document ||
      oldDelegate.liveStroke != liveStroke ||
      oldDelegate.liveStamp != liveStamp ||
      oldDelegate.selectedStampId != selectedStampId ||
      oldDelegate.viewport != viewport ||
      oldDelegate.paintNotes != paintNotes ||
      oldDelegate.compositor != compositor ||
      oldDelegate.liftOffset != liftOffset ||
      oldDelegate.liftedStrokes != liftedStrokes ||
      oldDelegate.selectionRect != selectionRect ||
      oldDelegate.lasso != lasso ||
      (lasso?.length ?? 0) > 0;
}

class _InteractiveAnnotationNote extends StatefulWidget {
  final AnnotationNote note;
  final Size canvasSize;
  final AnnotationCanvasController controller;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onEdit;

  const _InteractiveAnnotationNote({
    required this.note,
    required this.canvasSize,
    required this.controller,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
  });

  @override
  State<_InteractiveAnnotationNote> createState() =>
      _InteractiveAnnotationNoteState();
}

class _InteractiveAnnotationNoteState
    extends State<_InteractiveAnnotationNote> {
  Offset? _dragOrigin;
  double? _startX;
  double? _startY;

  @override
  Widget build(BuildContext context) {
    final left = widget.note.x * widget.canvasSize.width;
    final top = widget.note.y * widget.canvasSize.height;
    final width = widget.note.width * widget.canvasSize.width;
    final height = widget.note.height * widget.canvasSize.height;

    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: GestureDetector(
        onTap: widget.onSelect,
        onDoubleTap: widget.onEdit,
        onPanStart: (_) {
          widget.onSelect();
          widget.controller.beginNoteDrag();
          _dragOrigin = Offset(left, top);
          _startX = widget.note.x;
          _startY = widget.note.y;
        },
        onPanUpdate: (details) {
          if (_dragOrigin == null || _startX == null || _startY == null) return;
          final dx = details.delta.dx / widget.canvasSize.width;
          final dy = details.delta.dy / widget.canvasSize.height;
          final nextX = (_startX! + dx).clamp(0.0, 1.0 - widget.note.width);
          final nextY = (_startY! + dy).clamp(0.0, 1.0 - widget.note.height);
          _startX = nextX;
          _startY = nextY;
          widget.controller.updateNote(
            widget.note.id,
            x: nextX,
            y: nextY,
            commit: false,
          );
        },
        onPanEnd: (_) {
          widget.controller.endNoteDrag();
          _dragOrigin = null;
          _startX = null;
          _startY = null;
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Color(widget.note.colorArgb),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.selected
                  ? Colors.white.withValues(alpha: 0.85)
                  : Colors.black.withValues(alpha: 0.08),
              width: widget.selected ? 2 : 1,
            ),
            boxShadow: widget.selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              widget.note.text,
              maxLines: 8,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.82),
                fontSize: 13,
                height: 1.25,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
