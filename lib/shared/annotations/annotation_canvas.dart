import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'annotation_document.dart';

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
  final List<AnnotationDocument> _undo = [];
  final List<AnnotationDocument> _redo = [];
  AnnotationDocument? _noteDragBaseline;

  AnnotationDocument get document => _document;
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  void replaceDocument(
    AnnotationDocument document, {
    bool clearHistory = true,
  }) {
    _document = document;
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
    for (final stroke in _document.strokes.reversed) {
      for (final point in stroke.points) {
        final dx = point.x - nx;
        final dy = point.y - ny;
        if (math.sqrt(dx * dx + dy * dy) <= threshold) {
          return stroke.id;
        }
      }
    }
    return null;
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
    _commit(const AnnotationDocument());
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_document);
    _document = _undo.removeLast();
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_document);
    _document = _redo.removeLast();
    notifyListeners();
  }

  void _commit(AnnotationDocument next) {
    _undo.add(_document);
    if (_undo.length > 80) _undo.removeAt(0);
    _redo.clear();
    _document = next;
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
  });

  @override
  State<AnnotationCanvas> createState() => _AnnotationCanvasState();
}

class _AnnotationCanvasState extends State<AnnotationCanvas> {
  int? _activePointer;
  AnnotationInputKind _inputKind = AnnotationInputKind.unknown;
  final List<AnnotationPoint> _livePoints = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(AnnotationCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
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

  AnnotationPoint _pointFor(PointerEvent event, Size size) {
    final viewport = widget.viewport;
    final documentSize = viewport?.documentSize ?? size;
    final documentPosition =
        viewport?.localToDocument(event.localPosition) ?? event.localPosition;
    final pressureRange = event.pressureMax - event.pressureMin;
    final normalizedPressure = pressureRange > 0
        ? ((event.pressure - event.pressureMin) / pressureRange).clamp(
            0.05,
            1.0,
          )
        : 1.0;
    return AnnotationPoint(
      x: (documentPosition.dx / documentSize.width).clamp(0.0, 1.0),
      y: (documentPosition.dy / documentSize.height).clamp(0.0, 1.0),
      pressure: normalizedPressure,
    );
  }

  void _onPointerDown(PointerDownEvent event, Size size) {
    if (_activePointer != null || !_accepts(event)) return;
    final effectiveTool = event.kind == PointerDeviceKind.invertedStylus
        ? AnnotationToolType.eraser
        : widget.tool;
    if (effectiveTool == AnnotationToolType.eraser) {
      final point = _pointFor(event, size);
      final hit = widget.controller.hitTestStroke(point.x, point.y);
      if (hit != null) {
        widget.controller.removeStroke(hit);
      }
      return;
    }
    _activePointer = event.pointer;
    _inputKind = _kindFor(event.kind);
    _livePoints
      ..clear()
      ..add(_pointFor(event, size));
    setState(() {});
  }

  void _onPointerMove(PointerMoveEvent event, Size size) {
    if (event.pointer != _activePointer) return;
    if (event.kind == PointerDeviceKind.invertedStylus ||
        widget.tool == AnnotationToolType.eraser) {
      final point = _pointFor(event, size);
      final hit = widget.controller.hitTestStroke(point.x, point.y);
      if (hit != null) {
        widget.controller.removeStroke(hit);
      }
      return;
    }
    _livePoints.add(_pointFor(event, size));
    setState(() {});
  }

  void _onPointerUp(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    if (widget.tool == AnnotationToolType.eraser ||
        event.kind == PointerDeviceKind.invertedStylus) {
      _activePointer = null;
      return;
    }
    if (_livePoints.isNotEmpty) {
      widget.controller.addStroke(
        AnnotationStroke(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          tool: widget.tool,
          colorArgb: widget.color.toARGB32(),
          width: widget.width,
          inputKind: _inputKind,
          points: List.of(_livePoints),
        ),
      );
    }
    _activePointer = null;
    _inputKind = AnnotationInputKind.unknown;
    _livePoints.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final live = _livePoints.isEmpty
            ? null
            : AnnotationStroke(
                id: 'live',
                tool: widget.tool,
                colorArgb: widget.color.toARGB32(),
                width: widget.width,
                inputKind: _inputKind,
                points: List.of(_livePoints),
              );
        return Stack(
          fit: StackFit.expand,
          children: [
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => _onPointerDown(event, size),
              onPointerMove: (event) => _onPointerMove(event, size),
              onPointerUp: _onPointerUp,
              onPointerCancel: _onPointerUp,
              child: CustomPaint(
                foregroundPainter: AnnotationPainter(
                  document: widget.controller.document,
                  liveStroke: live,
                  viewport: widget.viewport,
                  paintNotes: !widget.interactiveNotes,
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
  final AnnotationViewport? viewport;
  final bool paintNotes;

  const AnnotationPainter({
    required this.document,
    this.liveStroke,
    this.viewport,
    this.paintNotes = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final documentSize = viewport?.documentSize ?? size;
    if (viewport != null) {
      canvas.save();
      canvas.translate(viewport!.offset.dx, viewport!.offset.dy);
      canvas.scale(viewport!.scale);
    }
    for (final stroke in document.strokes) {
      _paintStroke(canvas, documentSize, stroke);
    }
    if (liveStroke != null) {
      _paintStroke(canvas, documentSize, liveStroke!);
    }
    if (paintNotes) {
      for (final note in document.notes) {
        _paintNote(canvas, documentSize, note);
      }
    }
    if (viewport != null) canvas.restore();
  }

  void _paintStroke(Canvas canvas, Size size, AnnotationStroke stroke) {
    if (stroke.points.isEmpty) return;
    final color = Color(stroke.colorArgb);
    final scale = math.min(size.width, size.height) / 1000;
    final opacity = stroke.tool == AnnotationToolType.highlighter ? 0.35 : 1.0;
    final points = stroke.points
        .map((point) => Offset(point.x * size.width, point.y * size.height))
        .toList();

    if (stroke.tool == AnnotationToolType.arrow && points.length >= 2) {
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = math.max(1, stroke.width * scale)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      canvas.drawLine(points.first, points.last, paint);
      _paintArrowHead(canvas, points[points.length - 2], points.last, paint);
      return;
    }

    if (points.length == 1) {
      canvas.drawCircle(
        points.single,
        math.max(0.75, stroke.width * scale / 2),
        Paint()..color = color.withValues(alpha: opacity),
      );
      return;
    }

    for (var i = 1; i < points.length; i++) {
      final pressure =
          (stroke.points[i - 1].pressure + stroke.points[i].pressure) / 2;
      final paint = Paint()
        ..color = color.withValues(alpha: opacity)
        ..strokeWidth = math.max(
          0.75,
          stroke.width * scale * (0.35 + pressure * 0.65),
        )
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawLine(points[i - 1], points[i], paint);
    }
  }

  void _paintArrowHead(Canvas canvas, Offset start, Offset end, Paint paint) {
    final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
    final head = math.max(10, paint.strokeWidth * 4);
    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - head * math.cos(angle - 0.45),
        end.dy - head * math.sin(angle - 0.45),
      )
      ..moveTo(end.dx, end.dy)
      ..lineTo(
        end.dx - head * math.cos(angle + 0.45),
        end.dy - head * math.sin(angle + 0.45),
      );
    canvas.drawPath(path, paint);
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
      oldDelegate.viewport != viewport ||
      oldDelegate.paintNotes != paintNotes;
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

class _InteractiveAnnotationNoteState extends State<_InteractiveAnnotationNote> {
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
