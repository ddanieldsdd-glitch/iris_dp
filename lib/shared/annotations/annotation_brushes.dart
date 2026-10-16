import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'annotation_brush_engine.dart';
import 'annotation_document.dart';

/// Pintado de pinceles y sellos sobre un `Canvas` de Flutter.
///
/// Las coordenadas del documento son normalizadas; aquí se pasan a píxeles
/// con [size]. El grosor se expresa en milésimas del lado corto, igual que
/// el lápiz original, para que un dibujo se vea igual en iPad, escritorio,
/// imagen exportada y PDF.
abstract final class AnnotationBrushes {
  /// Pinceles que se dibujan rodeando un área.
  static bool isAreaTool(AnnotationToolType tool) =>
      tool == AnnotationToolType.fill || tool == AnnotationToolType.hatch;

  /// Pinceles de trazo libre a los que se aplica el enderezado al mantener.
  static bool canStraighten(AnnotationToolType tool) => switch (tool) {
    AnnotationToolType.pen ||
    AnnotationToolType.highlighter ||
    AnnotationToolType.pencil ||
    AnnotationToolType.ink ||
    AnnotationToolType.marker ||
    AnnotationToolType.charcoal ||
    AnnotationToolType.fill ||
    AnnotationToolType.hatch => true,
    _ => false,
  };

  /// Pinceles que dejan un trazo al arrastrar.
  static bool isStrokeTool(AnnotationToolType tool) => switch (tool) {
    AnnotationToolType.eraser ||
    AnnotationToolType.select ||
    AnnotationToolType.stamp ||
    AnnotationToolType.text => false,
    _ => true,
  };

  /// Flecha de recorrido (movimiento de cámara o de actor): sigue el trazo,
  /// discontinua.
  static const pathArrowId = 'arrow.path';

  static double unit(Size size) => math.min(size.width, size.height) / 1000;

  static void paintStroke(Canvas canvas, Size size, AnnotationStroke stroke) {
    if (stroke.points.isEmpty) return;
    if (BrushEngine.paint(canvas, size, stroke)) return;
    final s = unit(size);
    final pts = [
      for (final p in stroke.points)
        Offset(p.x * size.width, p.y * size.height),
    ];
    final base = Color(stroke.colorArgb);
    final w = math.max(0.75, stroke.width * s);
    final opacity = stroke.opacity.clamp(0.0, 1.0);

    switch (stroke.tool) {
      case AnnotationToolType.arrow:
        if (stroke.brushId == pathArrowId) {
          _pathArrow(canvas, pts, base.withValues(alpha: opacity), w);
        } else {
          _arrow(canvas, pts, base.withValues(alpha: opacity), w);
        }
      case AnnotationToolType.highlighter:
        _layered(canvas, size, 0.35 * opacity, () {
          _plainPath(canvas, pts, base, w, closed: stroke.closed);
        });
      case AnnotationToolType.pencil:
        _pencil(canvas, stroke, pts, base, w, opacity);
      case AnnotationToolType.ink:
        _ink(canvas, stroke, pts, base.withValues(alpha: opacity), w);
      case AnnotationToolType.marker:
        _layered(canvas, size, 0.6 * opacity, () {
          _plainPath(
            canvas,
            pts,
            base,
            w * 1.6,
            closed: stroke.closed,
            cap: StrokeCap.square,
          );
        });
      case AnnotationToolType.charcoal:
        _charcoal(canvas, stroke, pts, base, w, opacity);
      case AnnotationToolType.wash:
        _layered(canvas, size, 0.32 * opacity, () {
          final paint = _strokePaint(base, w * 2.4)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.35);
          canvas.drawPath(_smoothPath(pts), paint);
        });
      case AnnotationToolType.airbrush:
        _layered(canvas, size, 0.35 * opacity, () {
          final blur = MaskFilter.blur(BlurStyle.normal, w * 0.55);
          if (pts.length == 1) {
            canvas.drawCircle(
              pts.single,
              w * 0.8,
              Paint()
                ..color = base
                ..maskFilter = blur,
            );
          } else {
            canvas.drawPath(
              _smoothPath(pts),
              _strokePaint(base, w * 1.4)..maskFilter = blur,
            );
          }
        });
      case AnnotationToolType.fill:
        if (pts.length < 3) return;
        canvas.drawPath(
          _polygon(pts),
          Paint()
            ..color = base.withValues(alpha: opacity)
            ..style = PaintingStyle.fill
            ..isAntiAlias = true,
        );
      case AnnotationToolType.hatch:
        _hatch(canvas, pts, base.withValues(alpha: opacity), w, s);
      case AnnotationToolType.eraseArea:
        _plainPath(
          canvas,
          pts,
          Colors.black,
          w * 2,
          closed: stroke.closed,
          blend: BlendMode.clear,
        );
      case AnnotationToolType.line:
        _plainPath(
          canvas,
          [pts.first, pts.last],
          base.withValues(alpha: opacity),
          w,
        );
      case AnnotationToolType.pen ||
          AnnotationToolType.eraser ||
          AnnotationToolType.select ||
          AnnotationToolType.stamp ||
          AnnotationToolType.text:
        _pen(canvas, stroke, pts, base.withValues(alpha: opacity), w);
    }
  }

  // ─── Pinceles ──────────────────────────────────────────────────────────────

  static void _layered(
    Canvas canvas,
    Size size,
    double alpha,
    VoidCallback paint,
  ) {
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Colors.black.withValues(alpha: alpha.clamp(0.0, 1.0)),
    );
    paint();
    canvas.restore();
  }

  static Paint _strokePaint(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  static void _plainPath(
    Canvas canvas,
    List<Offset> pts,
    Color color,
    double width, {
    bool closed = false,
    StrokeCap cap = StrokeCap.round,
    BlendMode? blend,
  }) {
    final paint = _strokePaint(color, width)..strokeCap = cap;
    if (blend != null) paint.blendMode = blend;
    if (pts.length == 1) {
      canvas.drawCircle(
        pts.single,
        width / 2,
        Paint()
          ..color = color
          ..blendMode = blend ?? BlendMode.srcOver,
      );
      return;
    }
    canvas.drawPath(closed ? _polygon(pts) : _smoothPath(pts), paint);
  }

  static void _pen(
    Canvas canvas,
    AnnotationStroke stroke,
    List<Offset> pts,
    Color color,
    double w,
  ) {
    if (pts.length == 1) {
      canvas.drawCircle(pts.single, w / 2, Paint()..color = color);
      return;
    }
    if (stroke.closed) {
      canvas.drawPath(_polygon(pts), _strokePaint(color, w));
      return;
    }
    for (var i = 1; i < pts.length; i++) {
      final pressure =
          (stroke.points[i - 1].pressure + stroke.points[i].pressure) / 2;
      canvas.drawLine(
        pts[i - 1],
        pts[i],
        _strokePaint(color, math.max(0.75, w * (0.35 + pressure * 0.65))),
      );
    }
  }

  /// Tinta: contorno relleno con grosor según presión y puntas afiladas.
  static void _ink(
    Canvas canvas,
    AnnotationStroke stroke,
    List<Offset> pts,
    Color color,
    double w,
  ) {
    if (pts.length < 3 || stroke.closed) {
      _pen(canvas, stroke, pts, color, w);
      return;
    }
    final n = pts.length;
    final left = <Offset>[];
    final right = <Offset>[];
    for (var i = 0; i < n; i++) {
      final prev = pts[math.max(0, i - 1)];
      final next = pts[math.min(n - 1, i + 1)];
      var dir = next - prev;
      if (dir.distance == 0) dir = const Offset(1, 0);
      final normal = Offset(-dir.dy, dir.dx) / dir.distance;
      final taper = math.min(1.0, math.min(i, n - 1 - i) / 4 + 0.25);
      final half = w * (0.2 + 0.8 * stroke.points[i].pressure) * taper / 2;
      left.add(pts[i] + normal * half);
      right.add(pts[i] - normal * half);
    }
    final path = Path()..moveTo(left.first.dx, left.first.dy);
    _quadThrough(path, left);
    final back = right.reversed.toList();
    path.lineTo(back.first.dx, back.first.dy);
    _quadThrough(path, back);
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );
  }

  /// Grafito: línea base suave + grano que se reparte en el ancho.
  static void _pencil(
    Canvas canvas,
    AnnotationStroke stroke,
    List<Offset> pts,
    Color color,
    double w,
    double opacity,
  ) {
    final width = math.max(0.9, w * 0.5);
    if (pts.length > 1) {
      final path = stroke.closed ? _polygon(pts) : _smoothPath(pts);
      canvas.drawPath(
        path,
        _strokePaint(color.withValues(alpha: 0.62 * opacity), width),
      );
      // Segunda pasada algo desplazada: el borde irregular del grafito.
      canvas.drawPath(
        path.shift(Offset(width * 0.3, width * 0.2)),
        _strokePaint(color.withValues(alpha: 0.22 * opacity), width * 0.8),
      );
    }
    final rnd = math.Random(stroke.id.hashCode);
    final grain = <Offset>[];
    final gaps = <Offset>[];
    _walk(pts, closed: stroke.closed, step: math.max(0.5, width * 0.3), (
      p,
      normal,
      i,
    ) {
      final pressure =
          stroke.points[math.min(i, stroke.points.length - 1)].pressure;
      final spread = width * (1.0 + pressure * 0.8);
      for (var k = 0; k < 3; k++) {
        grain.add(p + normal * ((rnd.nextDouble() - 0.5) * spread));
      }
      // Huecos blancos del papel dentro de la línea.
      if (rnd.nextDouble() < 0.35) {
        gaps.add(p + normal * ((rnd.nextDouble() - 0.5) * width * 0.6));
      }
    });
    final dot = math.max(0.8, width * 0.4);
    _points(canvas, grain, color.withValues(alpha: 0.4 * opacity), dot);
    _points(canvas, gaps, Colors.white.withValues(alpha: 0.35), dot * 0.8);
  }

  /// Carboncillo: mancha granulada ancha, más densa con más presión.
  static void _charcoal(
    Canvas canvas,
    AnnotationStroke stroke,
    List<Offset> pts,
    Color color,
    double w,
    double opacity,
  ) {
    final width = w * 1.8;
    if (pts.length > 1) {
      canvas.drawPath(
        _smoothPath(pts),
        _strokePaint(color.withValues(alpha: 0.32 * opacity), width * 0.75)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, width * 0.08),
      );
    }
    final rnd = math.Random(stroke.id.hashCode);
    final fine = <Offset>[];
    final coarse = <Offset>[];
    _walk(pts, closed: stroke.closed, step: math.max(0.8, width * 0.12), (
      p,
      normal,
      i,
    ) {
      final pressure =
          stroke.points[math.min(i, stroke.points.length - 1)].pressure;
      final count = 3 + (pressure * 6).round();
      for (var k = 0; k < count; k++) {
        final along =
            Offset(normal.dy, -normal.dx) *
            ((rnd.nextDouble() - 0.5) * width * 0.25);
        final q = p + normal * ((rnd.nextDouble() - 0.5) * width) + along;
        (rnd.nextDouble() < 0.7 ? fine : coarse).add(q);
      }
    });
    final grainSize = math.max(1.0, width * 0.08);
    _points(canvas, fine, color.withValues(alpha: 0.5 * opacity), grainSize);
    _points(
      canvas,
      coarse,
      color.withValues(alpha: 0.8 * opacity),
      grainSize * 1.8,
    );
  }

  static void _hatch(
    Canvas canvas,
    List<Offset> pts,
    Color color,
    double w,
    double s,
  ) {
    if (pts.length < 3) return;
    final area = _polygon(pts);
    final b = area.getBounds();
    final gap = math.max(4.0, w * 1.3);
    canvas.save();
    canvas.clipPath(area);
    final paint = _strokePaint(color, math.max(0.8, w * 0.28));
    // Diagonal a 45°: x - y = c.
    for (var c = b.left - b.height; c < b.right; c += gap) {
      canvas.drawLine(Offset(c, b.top), Offset(c + b.height, b.bottom), paint);
    }
    canvas.restore();
  }

  static void _pathArrow(
    Canvas canvas,
    List<Offset> pts,
    Color color,
    double w,
  ) {
    if (pts.length < 2) return;
    final path = _smoothPath(pts);
    final paint = _strokePaint(color, w);
    final dash = math.max(6.0, w * 3);
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash * 2) {
        canvas.drawPath(
          metric.extractPath(d, math.min(metric.length, d + dash)),
          paint,
        );
      }
      final tip = metric.getTangentForOffset(metric.length);
      final back = metric.getTangentForOffset(
        math.max(0, metric.length - dash * 1.5),
      );
      if (tip != null && back != null) {
        _arrow(canvas, [back.position, tip.position], color, w);
      }
    }
  }

  static void _arrow(Canvas canvas, List<Offset> pts, Color color, double w) {
    if (pts.length < 2) {
      canvas.drawCircle(pts.single, w / 2, Paint()..color = color);
      return;
    }
    final paint = _strokePaint(color, w);
    canvas.drawLine(pts.first, pts.last, paint);
    final start = pts[pts.length - 2] == pts.last
        ? pts.first
        : pts[pts.length - 2];
    final angle = math.atan2(pts.last.dy - start.dy, pts.last.dx - start.dx);
    final head = math.max(10.0, w * 4);
    final end = pts.last;
    canvas.drawPath(
      Path()
        ..moveTo(
          end.dx - head * math.cos(angle - 0.45),
          end.dy - head * math.sin(angle - 0.45),
        )
        ..lineTo(end.dx, end.dy)
        ..lineTo(
          end.dx - head * math.cos(angle + 0.45),
          end.dy - head * math.sin(angle + 0.45),
        ),
      paint,
    );
  }

  // ─── Utilidades de trazo ───────────────────────────────────────────────────

  static void _points(
    Canvas canvas,
    List<Offset> pts,
    Color color,
    double size,
  ) {
    if (pts.isEmpty) return;
    final raw = Float32List(pts.length * 2);
    for (var i = 0; i < pts.length; i++) {
      raw[i * 2] = pts[i].dx;
      raw[i * 2 + 1] = pts[i].dy;
    }
    canvas.drawRawPoints(
      ui.PointMode.points,
      raw,
      Paint()
        ..color = color
        ..strokeWidth = size
        ..strokeCap = StrokeCap.round,
    );
  }

  /// Recorre el trazo a paso fijo, dando posición, normal e índice del punto.
  static void _walk(
    List<Offset> pts,
    void Function(Offset p, Offset normal, int index) visit, {
    required double step,
    bool closed = false,
  }) {
    if (pts.length == 1) {
      visit(pts.single, const Offset(0, 1), 0);
      return;
    }
    final path = closed ? [...pts, pts.first] : pts;
    var carry = 0.0;
    for (var i = 1; i < path.length; i++) {
      final a = path[i - 1];
      final b = path[i];
      final seg = b - a;
      final len = seg.distance;
      if (len == 0) continue;
      final normal = Offset(-seg.dy, seg.dx) / len;
      var t = carry;
      while (t < len) {
        visit(a + seg * (t / len), normal, i - 1);
        t += step;
      }
      carry = t - len;
    }
  }

  static Path _smoothPath(List<Offset> pts) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length == 1) return path..lineTo(pts.first.dx, pts.first.dy);
    if (pts.length == 2) return path..lineTo(pts.last.dx, pts.last.dy);
    _quadThrough(path, pts);
    return path;
  }

  /// Curvas cuadráticas por los puntos medios: quita el dentado del ratón.
  static void _quadThrough(Path path, List<Offset> pts) {
    for (var i = 1; i < pts.length - 1; i++) {
      final mid = (pts[i] + pts[i + 1]) / 2;
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
  }

  static Path _polygon(List<Offset> pts) => Path()..addPolygon(pts, true);

  // ─── Sellos ────────────────────────────────────────────────────────────────

  static double stampRadius(AnnotationStamp stamp, Size size) =>
      stamp.size * math.min(size.width, size.height) / 2;

  static Offset stampCenter(AnnotationStamp stamp, Size size) =>
      Offset(stamp.x * size.width, stamp.y * size.height);

  /// Posición del tirador de giro de un sello seleccionado.
  static Offset stampHandle(AnnotationStamp stamp, Size size) =>
      stampCenter(stamp, size) +
      Offset.fromDirection(stamp.rotation, stampRadius(stamp, size) * 1.7);

  /// Sellos con haz o ángulo de visión que se puede abrir y alargar.
  static bool hasBeam(AnnotationStampKind kind) => switch (kind) {
    AnnotationStampKind.camera ||
    AnnotationStampKind.light ||
    AnnotationStampKind.fresnel ||
    AnnotationStampKind.hmi ||
    AnnotationStampKind.ledPanel ||
    AnnotationStampKind.softbox ||
    AnnotationStampKind.crane ||
    AnnotationStampKind.dolly => true,
    _ => false,
  };

  /// Apertura (radianes) y alcance (radios) por defecto de cada sello.
  static (double, double) beamDefaults(AnnotationStampKind kind) =>
      switch (kind) {
        AnnotationStampKind.camera ||
        AnnotationStampKind.dolly ||
        AnnotationStampKind.crane => (0.82, 2.6),
        AnnotationStampKind.fresnel => (0.6, 2.6),
        AnnotationStampKind.hmi => (0.5, 3.0),
        AnnotationStampKind.ledPanel => (1.5, 1.8),
        AnnotationStampKind.softbox => (1.6, 1.8),
        _ => (0.7, 2.2),
      };

  static double beamSpread(AnnotationStamp stamp) =>
      stamp.spread ?? beamDefaults(stamp.kind).$1;

  static double beamReach(AnnotationStamp stamp) =>
      stamp.reach ?? beamDefaults(stamp.kind).$2;

  /// Tirador del borde del haz: arrastrarlo abre o cierra y alarga.
  static Offset beamHandle(AnnotationStamp stamp, Size size) =>
      stampCenter(stamp, size) +
      Offset.fromDirection(
        stamp.rotation + beamSpread(stamp) / 2,
        beamReach(stamp) * stampRadius(stamp, size),
      );

  /// Ángulo de visión horizontal de una óptica, en radianes.
  static double fieldOfView(double lensMm, {double sensorWidthMm = 24.9}) =>
      2 * math.atan(sensorWidthMm / (2 * lensMm));

  static void paintStamp(
    Canvas canvas,
    Size size,
    AnnotationStamp stamp, {
    bool selected = false,
  }) {
    final c = stampCenter(stamp, size);
    final r = stampRadius(stamp, size);
    final color = Color(stamp.colorArgb);
    final line = _strokePaint(color, math.max(1.2, r * 0.08));
    final fill = Paint()..color = color;
    final paper = Paint()..color = Colors.white;

    if (stamp.kind == AnnotationStampKind.text) {
      _text(canvas, stamp.label ?? '', c, color, r * 0.9, center: true);
    } else {
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(stamp.rotation);
      final spread = beamSpread(stamp);
      final reach = beamReach(stamp);
      switch (stamp.kind) {
        case AnnotationStampKind.camera:
          _fov(canvas, r, spread, reach, color);
          _camera(canvas, r, line, fill, paper, color);
        case AnnotationStampKind.dolly:
          _dolly(canvas, r, line, paper);
          _fov(canvas, r, spread, reach, color);
          _camera(canvas, r * 0.8, line, fill, paper, color);
        case AnnotationStampKind.crane:
          _crane(canvas, r, line, fill, paper, color, spread, reach);
        case AnnotationStampKind.actor:
          _actor(canvas, r, line, fill, paper);
        case AnnotationStampKind.light:
          _beam(canvas, r, spread, reach, color);
          _light(canvas, r, line, fill, color);
        case AnnotationStampKind.fresnel:
          _beam(canvas, r, spread, reach, color);
          _fresnel(canvas, r, line, fill, paper);
        case AnnotationStampKind.hmi:
          _beam(canvas, r, spread, reach, color);
          _hmi(canvas, r, line, fill, paper);
        case AnnotationStampKind.ledPanel:
          _spill(canvas, r, spread, reach, color);
          _ledPanel(canvas, r, line, paper);
        case AnnotationStampKind.tube:
          _tube(canvas, r, line, paper, color);
        case AnnotationStampKind.softbox:
          _spill(canvas, r, spread, reach, color);
          _softbox(canvas, r, line, paper, color);
        case AnnotationStampKind.sun:
          _sun(canvas, r, line, paper);
        case AnnotationStampKind.frame:
          _frame(canvas, r, line);
        case AnnotationStampKind.bounce:
          _bounce(canvas, r, line, paper);
        case AnnotationStampKind.diffusion:
          _diffusion(canvas, r, line, color);
        case AnnotationStampKind.window:
          _window(canvas, r, line, paper);
        case AnnotationStampKind.door:
          _door(canvas, r, line);
        case AnnotationStampKind.table:
          _table(canvas, r, line, paper);
        case AnnotationStampKind.chair:
          _chair(canvas, r, line, paper);
        case AnnotationStampKind.sofa:
          _sofa(canvas, r, line, paper);
        case AnnotationStampKind.car:
          _car(canvas, r, line, paper);
        case AnnotationStampKind.text:
          break;
      }
      canvas.restore();
      final lens = stamp.lensMm;
      if (lens != null && stamp.kind == AnnotationStampKind.camera) {
        _text(
          canvas,
          '${lens.round()} mm',
          c + Offset.fromDirection(stamp.rotation, r * (reach + 0.35)),
          color,
          math.max(8, r * 0.34),
          center: true,
        );
      }
      final label = stamp.label;
      if (label != null && label.isNotEmpty) {
        _text(
          canvas,
          label,
          c + Offset(0, r * 1.15),
          color,
          math.max(9, r * 0.42),
          center: true,
        );
      }
    }

    if (selected) {
      final ring = Paint()
        ..color = const Color(0xFF2997FF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(c, r * 1.25, ring);
      if (stamp.kind != AnnotationStampKind.text) {
        final h = stampHandle(stamp, size);
        canvas.drawLine(
          c + Offset.fromDirection(stamp.rotation, r * 1.25),
          h,
          ring,
        );
        canvas.drawCircle(h, 7, Paint()..color = const Color(0xFF2997FF));
        canvas.drawCircle(h, 7, ring..color = Colors.white);
      }
      if (hasBeam(stamp.kind)) {
        final b = beamHandle(stamp, size);
        canvas.drawCircle(b, 7, Paint()..color = const Color(0xFFFFB300));
        canvas.drawCircle(
          b,
          7,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  /// Cámara cenital: cuerpo, objetivo y ángulo de visión punteado.
  static void _camera(
    Canvas canvas,
    double r,
    Paint line,
    Paint fill,
    Paint paper,
    Color color,
  ) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(-r * 0.7, -r * 0.42, r * 0.22, r * 0.42),
      Radius.circular(r * 0.08),
    );
    canvas.drawRRect(body, paper);
    canvas.drawRRect(body, line);
    final lens = Path()
      ..moveTo(r * 0.22, -r * 0.2)
      ..lineTo(r * 0.62, -r * 0.3)
      ..lineTo(r * 0.62, r * 0.3)
      ..lineTo(r * 0.22, r * 0.2)
      ..close();
    canvas.drawPath(lens, fill);
    // Visor/asa: marca dónde está la parte de atrás.
    canvas.drawCircle(Offset(-r * 0.42, 0), r * 0.12, fill);
  }

  /// Personaje cenital: hombros, cabeza y nariz que marca hacia dónde mira.
  static void _actor(
    Canvas canvas,
    double r,
    Paint line,
    Paint fill,
    Paint paper,
  ) {
    final shoulders = Rect.fromCenter(
      center: Offset.zero,
      width: r * 0.75,
      height: r * 1.7,
    );
    canvas.drawOval(shoulders, paper);
    canvas.drawOval(shoulders, line);
    canvas.drawCircle(Offset.zero, r * 0.42, fill);
    final nose = Path()
      ..moveTo(r * 0.38, -r * 0.14)
      ..lineTo(r * 0.62, 0)
      ..lineTo(r * 0.38, r * 0.14)
      ..close();
    canvas.drawPath(nose, fill);
  }

  /// Foco: cuerpo, viseras y el haz abierto (la «Λ» de los bocetos).
  static void _light(
    Canvas canvas,
    double r,
    Paint line,
    Paint fill,
    Color color,
  ) {
    final body = Rect.fromLTRB(-r * 0.55, -r * 0.32, r * 0.2, r * 0.32);
    canvas.drawRect(body, fill);
    // Viseras.
    canvas.drawLine(
      Offset(r * 0.2, -r * 0.32),
      Offset(r * 0.48, -r * 0.55),
      line,
    );
    canvas.drawLine(
      Offset(r * 0.2, r * 0.32),
      Offset(r * 0.48, r * 0.55),
      line,
    );
  }

  static void _softbox(
    Canvas canvas,
    double r,
    Paint line,
    Paint paper,
    Color color,
  ) {
    final box = Path()
      ..moveTo(-r * 0.5, -r * 0.25)
      ..lineTo(r * 0.1, -r * 0.8)
      ..lineTo(r * 0.1, r * 0.8)
      ..lineTo(-r * 0.5, r * 0.25)
      ..close();
    canvas.drawPath(box, paper);
    canvas.drawPath(box, line);
    canvas.drawLine(
      Offset(r * 0.1, -r * 0.8),
      Offset(r * 0.1, r * 0.8),
      Paint()
        ..color = line.color
        ..strokeWidth = line.strokeWidth * 2.2,
    );
  }

  /// Sol: disco con rayos y flecha hacia donde entra la luz.
  static void _sun(Canvas canvas, double r, Paint line, Paint paper) {
    final disc = Offset(-r * 0.4, 0);
    canvas.drawCircle(disc, r * 0.38, paper);
    canvas.drawCircle(disc, r * 0.38, line);
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        disc + Offset.fromDirection(a, r * 0.5),
        disc + Offset.fromDirection(a, r * 0.72),
        line,
      );
    }
    final shaft = Paint()
      ..color = line.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = line.strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(r * 0.4, 0), Offset(r * 1.8, 0), shaft);
    canvas.drawPath(
      Path()
        ..moveTo(r * 1.5, -r * 0.22)
        ..lineTo(r * 1.8, 0)
        ..lineTo(r * 1.5, r * 0.22),
      shaft,
    );
  }

  /// Marco / bandera (12×12, rebote…): barra con topes, como en los bocetos.
  static void _frame(Canvas canvas, double r, Paint line) {
    final bar = Paint()
      ..color = line.color
      ..strokeWidth = line.strokeWidth * 1.6
      ..strokeCap = StrokeCap.butt;
    canvas.drawLine(Offset(0, -r), Offset(0, r), bar);
    canvas.drawLine(Offset(-r * 0.18, -r), Offset(r * 0.18, -r), line);
    canvas.drawLine(Offset(-r * 0.18, r), Offset(r * 0.18, r), line);
  }

  /// Ángulo de visión punteado desde el objetivo.
  static void _fov(
    Canvas canvas,
    double r,
    double spread,
    double reach,
    Color color,
  ) {
    final fov = Paint()
      ..color = color.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * 0.04);
    final origin = Offset(r * 0.62, 0);
    for (final side in [-1.0, 1.0]) {
      _dashed(
        canvas,
        origin,
        Offset.fromDirection(side * spread / 2, r * reach),
        fov,
        r * 0.12,
      );
    }
    canvas.drawPath(
      Path()
        ..moveTo(origin.dx, origin.dy)
        ..lineTo(
          Offset.fromDirection(-spread / 2, r * reach).dx,
          Offset.fromDirection(-spread / 2, r * reach).dy,
        )
        ..arcTo(
          Rect.fromCircle(center: Offset.zero, radius: r * reach),
          -spread / 2,
          spread,
          false,
        )
        ..close(),
      Paint()..color = color.withValues(alpha: 0.05),
    );
  }

  /// Haz de un foco: la «Λ» de los bocetos, abierta según [spread].
  static void _beam(
    Canvas canvas,
    double r,
    double spread,
    double reach,
    Color color,
  ) {
    final a = Offset(r * 0.2, -r * 0.3);
    final b = Offset(r * 0.2, r * 0.3);
    final far1 = Offset.fromDirection(-spread / 2, r * reach) + a;
    final far2 = Offset.fromDirection(spread / 2, r * reach) + b;
    canvas.drawPath(
      Path()
        ..moveTo(a.dx, a.dy)
        ..lineTo(far1.dx, far1.dy)
        ..lineTo(far2.dx, far2.dy)
        ..lineTo(b.dx, b.dy)
        ..close(),
      Paint()..color = color.withValues(alpha: 0.10),
    );
    final edge = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, r * 0.045);
    canvas.drawLine(a, far1, edge);
    canvas.drawLine(b, far2, edge);
  }

  /// Luz difusa: mancha blanda que se abre (panel, softbox).
  static void _spill(
    Canvas canvas,
    double r,
    double spread,
    double reach,
    Color color,
  ) {
    final far1 = Offset.fromDirection(-spread / 2, r * reach);
    final far2 = Offset.fromDirection(spread / 2, r * reach);
    canvas.drawPath(
      Path()
        ..moveTo(r * 0.1, -r * 0.8)
        ..lineTo(far1.dx, math.min(far1.dy, -r * 0.8))
        ..lineTo(far2.dx, math.max(far2.dy, r * 0.8))
        ..lineTo(r * 0.1, r * 0.8)
        ..close(),
      Paint()
        ..color = color.withValues(alpha: 0.09)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.15),
    );
  }

  /// Dolly: plataforma con ruedas sobre la vía.
  static void _dolly(Canvas canvas, double r, Paint line, Paint paper) {
    final rail = Paint()
      ..color = line.color.withValues(alpha: 0.6)
      ..strokeWidth = line.strokeWidth * 0.8;
    for (final side in [-1.0, 1.0]) {
      canvas.drawLine(
        Offset(-r * 2.2, side * r * 0.62),
        Offset(r * 2.2, side * r * 0.62),
        rail,
      );
    }
    for (var x = -r * 2.0; x <= r * 2.0; x += r * 0.5) {
      canvas.drawLine(Offset(x, -r * 0.75), Offset(x, r * 0.75), rail);
    }
    final deck = Rect.fromCenter(
      center: Offset.zero,
      width: r * 1.6,
      height: r * 1.1,
    );
    canvas.drawRect(deck, paper);
    canvas.drawRect(deck, line);
  }

  /// Grúa: base, brazo y cabeza con su ángulo de visión.
  static void _crane(
    Canvas canvas,
    double r,
    Paint line,
    Paint fill,
    Paint paper,
    Color color,
    double spread,
    double reach,
  ) {
    canvas.drawCircle(Offset(-r * 0.6, 0), r * 0.45, paper);
    canvas.drawCircle(Offset(-r * 0.6, 0), r * 0.45, line);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(-r * 1.2, 0),
        width: r * 0.4,
        height: r * 0.5,
      ),
      fill,
    );
    canvas.drawLine(
      Offset(-r * 0.6, 0),
      Offset(r * 1.2, 0),
      Paint()
        ..color = line.color
        ..strokeWidth = line.strokeWidth * 2.2,
    );
    canvas.save();
    canvas.translate(r * 1.2, 0);
    _fov(canvas, r * 0.6, spread, reach, color);
    _camera(canvas, r * 0.6, line, fill, paper, color);
    canvas.restore();
  }

  static void _fresnel(
    Canvas canvas,
    double r,
    Paint line,
    Paint fill,
    Paint paper,
  ) {
    final body = Rect.fromLTRB(-r * 0.6, -r * 0.38, r * 0.15, r * 0.38);
    canvas.drawRect(body, fill);
    // Lente escalonada.
    canvas.drawArc(
      Rect.fromCircle(center: Offset(r * 0.05, 0), radius: r * 0.42),
      -math.pi / 3,
      2 * math.pi / 3,
      false,
      line,
    );
    canvas.drawLine(
      Offset(r * 0.15, -r * 0.38),
      Offset(r * 0.45, -r * 0.6),
      line,
    );
    canvas.drawLine(
      Offset(r * 0.15, r * 0.38),
      Offset(r * 0.45, r * 0.6),
      line,
    );
  }

  static void _hmi(
    Canvas canvas,
    double r,
    Paint line,
    Paint fill,
    Paint paper,
  ) {
    final body = Rect.fromLTRB(-r * 0.7, -r * 0.45, r * 0.2, r * 0.45);
    canvas.drawRect(body, fill);
    canvas.drawLine(
      Offset(r * 0.28, -r * 0.45),
      Offset(r * 0.28, r * 0.45),
      line,
    );
    // Balasto con su cable.
    final ballast = Rect.fromCenter(
      center: Offset(-r * 1.4, r * 0.5),
      width: r * 0.5,
      height: r * 0.35,
    );
    canvas.drawRect(ballast, paper);
    canvas.drawRect(ballast, line);
    canvas.drawLine(Offset(-r * 0.7, 0), ballast.topRight, line);
  }

  static void _ledPanel(Canvas canvas, double r, Paint line, Paint paper) {
    final panel = Rect.fromLTRB(-r * 0.12, -r * 0.85, r * 0.12, r * 0.85);
    canvas.drawRect(panel, paper);
    canvas.drawRect(panel, line);
    for (var y = -r * 0.6; y <= r * 0.6; y += r * 0.3) {
      canvas.drawCircle(Offset(0, y), r * 0.05, Paint()..color = line.color);
    }
    canvas.drawLine(Offset(-r * 0.12, 0), Offset(-r * 0.45, 0), line);
  }

  static void _tube(
    Canvas canvas,
    double r,
    Paint line,
    Paint paper,
    Color color,
  ) {
    final glow = RRect.fromRectAndRadius(
      Rect.fromLTRB(-r * 0.55, -r * 1.1, r * 0.55, r * 1.1),
      Radius.circular(r * 0.5),
    );
    canvas.drawRRect(
      glow,
      Paint()
        ..color = color.withValues(alpha: 0.10)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.2),
    );
    final tube = RRect.fromRectAndRadius(
      Rect.fromLTRB(-r * 0.1, -r, r * 0.1, r),
      Radius.circular(r * 0.1),
    );
    canvas.drawRRect(tube, paper);
    canvas.drawRRect(tube, line);
  }

  /// Rebotador: panel blanco con su cara reflectante punteada.
  static void _bounce(Canvas canvas, double r, Paint line, Paint paper) {
    final board = Rect.fromLTRB(-r * 0.14, -r, r * 0.14, r);
    canvas.drawRect(board, paper);
    canvas.drawRect(board, line);
    _dashed(
      canvas,
      Offset(r * 0.28, -r * 0.9),
      Offset(r * 0.28, r * 0.9),
      line,
      r * 0.1,
    );
  }

  /// Difusor (6×6, 12×12): marco con la tela en trazo fino.
  static void _diffusion(Canvas canvas, double r, Paint line, Color color) {
    _frame(canvas, r, line);
    final cloth = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = r * 0.22;
    canvas.drawLine(Offset(0, -r * 0.92), Offset(0, r * 0.92), cloth);
  }

  /// Ventana en planta: muro con doble línea de vidrio.
  static void _window(Canvas canvas, double r, Paint line, Paint paper) {
    final wall = Rect.fromLTRB(-r * 0.16, -r * 1.2, r * 0.16, r * 1.2);
    canvas.drawRect(wall, paper);
    canvas.drawRect(wall, line);
    canvas.drawLine(Offset(0, -r * 1.2), Offset(0, r * 1.2), line);
  }

  /// Puerta: hoja y arco de apertura.
  static void _door(Canvas canvas, double r, Paint line) {
    canvas.drawLine(Offset(0, -r), Offset(r * 1.6, -r), line);
    final arc = Paint()
      ..color = line.color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = line.strokeWidth * 0.7;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(0, -r), radius: r * 1.6),
      0,
      math.pi / 2,
      false,
      arc,
    );
    canvas.drawLine(Offset(0, -r), Offset(0, r * 0.6), line);
  }

  static void _table(Canvas canvas, double r, Paint line, Paint paper) {
    final top = Rect.fromCenter(
      center: Offset.zero,
      width: r * 1.2,
      height: r * 1.8,
    );
    canvas.drawRect(top, paper);
    canvas.drawRect(top, line);
  }

  static void _chair(Canvas canvas, double r, Paint line, Paint paper) {
    final seat = Rect.fromCenter(
      center: Offset.zero,
      width: r * 0.9,
      height: r * 0.9,
    );
    canvas.drawRect(seat, paper);
    canvas.drawRect(seat, line);
    // Respaldo detrás: mira hacia la derecha.
    canvas.drawLine(
      Offset(-r * 0.55, -r * 0.45),
      Offset(-r * 0.55, r * 0.45),
      Paint()
        ..color = line.color
        ..strokeWidth = line.strokeWidth * 2.5,
    );
  }

  static void _sofa(Canvas canvas, double r, Paint line, Paint paper) {
    final body = Rect.fromCenter(
      center: Offset.zero,
      width: r * 1.0,
      height: r * 2.2,
    );
    canvas.drawRect(body, paper);
    canvas.drawRect(body, line);
    canvas.drawRect(Rect.fromLTRB(-r * 0.5, -r * 1.1, -r * 0.2, r * 1.1), line);
    for (final side in [-1.0, 1.0]) {
      canvas.drawRect(
        Rect.fromLTRB(-r * 0.5, side * r * 0.85, r * 0.5, side * r * 1.1),
        line,
      );
    }
  }

  /// Coche en planta, con el morro hacia donde mira.
  static void _car(Canvas canvas, double r, Paint line, Paint paper) {
    final body = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset.zero, width: r * 2.4, height: r * 1.1),
      Radius.circular(r * 0.3),
    );
    canvas.drawRRect(body, paper);
    canvas.drawRRect(body, line);
    // Parabrisas y luna trasera.
    canvas.drawLine(
      Offset(r * 0.45, -r * 0.42),
      Offset(r * 0.6, r * 0.42),
      line,
    );
    canvas.drawLine(
      Offset(-r * 0.6, -r * 0.4),
      Offset(-r * 0.7, r * 0.4),
      line,
    );
    canvas.drawRect(
      Rect.fromLTRB(-r * 0.6, -r * 0.42, r * 0.45, r * 0.42),
      line,
    );
  }

  static void _dashed(
    Canvas canvas,
    Offset a,
    Offset b,
    Paint paint,
    double dash,
  ) {
    final d = b - a;
    final len = d.distance;
    if (len == 0) return;
    final u = d / len;
    for (var t = 0.0; t < len; t += dash * 2) {
      canvas.drawLine(a + u * t, a + u * math.min(len, t + dash), paint);
    }
  }

  static void _text(
    Canvas canvas,
    String text,
    Offset anchor,
    Color color,
    double fontSize, {
    bool center = false,
  }) {
    if (text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
          height: 1.1,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 4,
    )..layout(maxWidth: fontSize * 18);
    final topLeft = center
        ? anchor - Offset(painter.width / 2, painter.height / 2)
        : anchor;
    painter.paint(canvas, topLeft);
  }
}
