import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'annotation_brush_catalog.dart';
import 'annotation_document.dart';
import 'annotation_textures.dart';

/// Motor de pinceles por estampado: recorre el trazo suavizado y deja una
/// huella de la punta cada pocos píxeles, con presión, inclinación y azar
/// deterministas; después recorta el resultado con el grano del papel.
abstract final class BrushEngine {
  /// Máximo de huellas por trazo; si se pasa, se abre el espaciado.
  static const _maxDabs = 24000;

  static double unit(Size size) => math.min(size.width, size.height) / 1000;

  /// Semilla estable (FNV-1a) para que el azar de un trazo no cambie entre
  /// dispositivos ni versiones de Dart.
  static int seedFor(AnnotationStroke stroke) {
    final explicit = stroke.seed;
    if (explicit != null) return explicit;
    var h = 0x811C9DC5;
    for (final unit in stroke.id.codeUnits) {
      h ^= unit;
      h = (h * 0x01000193) & 0xFFFFFFFF;
    }
    return h;
  }

  /// Pinta [stroke] si su pincel está en el catálogo. Devuelve `false` si
  /// no lo está (lo pinta el renderizador antiguo).
  static bool paint(Canvas canvas, Size size, AnnotationStroke stroke) {
    final spec = BrushCatalog.byId(stroke.brushId);
    if (spec == null) return false;
    if (stroke.points.isEmpty) return true;
    // El difumino necesita leer la capa: lo resuelve el lienzo.
    if (spec.mode == BrushMode.smudge) return true;
    final u = unit(size);
    final pts = [
      for (final p in stroke.points)
        Offset(p.x * size.width, p.y * size.height),
    ];
    final diameter = math.max(0.6, stroke.width * u * spec.sizeScale);
    final color = Color(stroke.colorArgb);
    final rnd = math.Random(seedFor(stroke));
    final bounds = _bounds(pts, diameter * 2.5 + 2);

    final layerAlpha = spec.wet ? stroke.opacity.clamp(0.0, 1.0) : 1.0;
    canvas.saveLayer(
      bounds,
      Paint()
        ..color = Color.fromRGBO(0, 0, 0, layerAlpha)
        ..blendMode = spec.mode == BrushMode.erase
            ? BlendMode.dstOut
            : spec.blend,
    );
    if (spec.isArea) {
      _paintArea(canvas, spec, stroke, pts, color, diameter, rnd);
    } else {
      final dabs = _dabs(spec, stroke, pts, diameter, rnd);
      final opacity = spec.wet ? 1.0 : stroke.opacity.clamp(0.0, 1.0);
      _drawDabs(canvas, spec, dabs, color, opacity);
    }
    final avgPressure =
        stroke.points.fold<double>(0, (sum, p) => sum + p.pressure) /
        stroke.points.length;
    _applyGrain(canvas, spec, bounds, u, avgPressure);
    canvas.restore();
    return true;
  }

  // ─── Huellas ───────────────────────────────────────────────────────────────

  static List<_Dab> _dabs(
    BrushSpec spec,
    AnnotationStroke stroke,
    List<Offset> pts,
    double diameter,
    math.Random rnd,
  ) {
    final points = stroke.points;
    if (pts.length == 1) {
      final p = points.single;
      return [
        _Dab(
          pts.single,
          _size(spec, diameter, p.pressure, p.tilt, 1, rnd),
          _angle(spec, 0, rnd),
          _alpha(spec, p.pressure, rnd),
        ),
      ];
    }

    // Longitud acumulada de la polilínea, para leer la presión por fracción.
    final cumulative = Float64List(pts.length);
    for (var i = 1; i < pts.length; i++) {
      cumulative[i] = cumulative[i - 1] + (pts[i] - pts[i - 1]).distance;
    }
    final polyLength = cumulative.last;
    final path = stroke.closed
        ? (Path()..addPolygon(pts, true))
        : _smoothPath(pts);
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
    if (total <= 0) {
      final p = points.first;
      return [
        _Dab(
          pts.first,
          _size(spec, diameter, p.pressure, p.tilt, 1, rnd),
          _angle(spec, 0, rnd),
          _alpha(spec, p.pressure, rnd),
        ),
      ];
    }

    var step = math.max(0.35, spec.spacing * diameter);
    if (total / step > _maxDabs) step = total / _maxDabs;
    final out = <_Dab>[];
    var walked = 0.0;
    var segIndex = 0;
    for (final metric in metrics) {
      var d = 0.0;
      while (d <= metric.length) {
        final tangent = metric.getTangentForOffset(d);
        if (tangent == null) break;
        final along = walked + d;
        final fraction = along / total;
        final sample = _sampleAt(points, cumulative, fraction * polyLength, (
          i,
        ) {
          segIndex = i;
        }, segIndex);
        final taper = _taper(spec, along, total, diameter);
        final size = _size(
          spec,
          diameter,
          sample.pressure,
          sample.tilt,
          taper,
          rnd,
        );
        final direction = -tangent.angle;
        var pos = tangent.position;
        if (spec.scatter > 0) {
          final normal = Offset(-math.sin(direction), math.cos(direction));
          pos +=
              normal * ((rnd.nextDouble() - 0.5) * 2 * spec.scatter * diameter);
        }
        out.add(
          _Dab(
            pos,
            size,
            _angle(spec, direction, rnd),
            _alpha(spec, sample.pressure, rnd) * math.min(1, taper * 1.5),
          ),
        );
        // El paso sigue al tamaño: huellas pequeñas, más juntas.
        d += math.max(step * 0.35, spec.spacing * size).clamp(0.35, step * 3);
      }
      walked += metric.length;
    }
    return out;
  }

  static ({double pressure, double tilt}) _sampleAt(
    List<AnnotationPoint> points,
    Float64List cumulative,
    double at,
    void Function(int) remember,
    int from,
  ) {
    var i = from.clamp(1, points.length - 1);
    while (i < points.length - 1 && cumulative[i] < at) {
      i++;
    }
    while (i > 1 && cumulative[i - 1] > at) {
      i--;
    }
    remember(i);
    final a = points[i - 1];
    final b = points[i];
    final span = cumulative[i] - cumulative[i - 1];
    final t = span <= 0
        ? 0.0
        : ((at - cumulative[i - 1]) / span).clamp(0.0, 1.0);
    return (
      pressure: a.pressure + (b.pressure - a.pressure) * t,
      tilt: a.tilt + (b.tilt - a.tilt) * t,
    );
  }

  static double _taper(BrushSpec spec, double at, double total, double d) {
    var t = 1.0;
    if (spec.taperStart > 0) {
      t = math.min(t, (at / (spec.taperStart * d)).clamp(0.0, 1.0));
    }
    if (spec.taperEnd > 0) {
      t = math.min(t, ((total - at) / (spec.taperEnd * d)).clamp(0.0, 1.0));
    }
    // Nunca desaparece del todo: la punta sigue tocando el papel.
    return 0.15 + 0.85 * math.sqrt(t);
  }

  static double _size(
    BrushSpec spec,
    double diameter,
    double pressure,
    double tilt,
    double taper,
    math.Random rnd,
  ) {
    var s = diameter * (1 - spec.pressureSize + spec.pressureSize * pressure);
    s *= taper;
    if (spec.sizeJitter > 0) {
      s *= 1 + (rnd.nextDouble() - 0.5) * 2 * spec.sizeJitter;
    }
    if (spec.tiltWidens && tilt > 0.25) {
      s *= 1 + 1.6 * (tilt / (math.pi / 2)).clamp(0.0, 1.0);
    }
    return math.max(0.4, s);
  }

  static double _angle(BrushSpec spec, double direction, math.Random rnd) {
    var a = spec.followDirection ? direction + spec.angle : spec.angle;
    if (spec.rotationJitter > 0) {
      a += (rnd.nextDouble() - 0.5) * 2 * math.pi * spec.rotationJitter;
    }
    return a;
  }

  static double _alpha(BrushSpec spec, double pressure, math.Random rnd) {
    if (spec.wet) return 1;
    var a =
        spec.flow *
        (1 - spec.pressureOpacity + spec.pressureOpacity * pressure);
    if (spec.opacityJitter > 0) a *= 1 - rnd.nextDouble() * spec.opacityJitter;
    return a.clamp(0.0, 1.0);
  }

  static void _drawDabs(
    Canvas canvas,
    BrushSpec spec,
    List<_Dab> dabs,
    Color color,
    double opacity,
  ) {
    if (dabs.isEmpty) return;
    final image = AnnotationTextures.instance.tip(spec.tip);
    const half = AnnotationTextures.tipSize / 2;
    final transforms = <RSTransform>[];
    final rects = <Rect>[];
    final colors = <Color>[];
    for (final dab in dabs) {
      transforms.add(
        RSTransform.fromComponents(
          rotation: dab.angle,
          scale: dab.size / AnnotationTextures.tipSize,
          anchorX: half,
          anchorY: half,
          translateX: dab.position.dx,
          translateY: dab.position.dy,
        ),
      );
      rects.add(AnnotationTextures.tipRect);
      colors.add(
        color.withValues(alpha: (dab.alpha * opacity).clamp(0.0, 1.0)),
      );
    }
    canvas.drawAtlas(
      image,
      transforms,
      rects,
      colors,
      BlendMode.modulate,
      null,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  // ─── Áreas: relleno y trama ────────────────────────────────────────────────

  static void _paintArea(
    Canvas canvas,
    BrushSpec spec,
    AnnotationStroke stroke,
    List<Offset> pts,
    Color color,
    double diameter,
    math.Random rnd,
  ) {
    if (pts.length < 3) return;
    final region = _smoothPath(pts, closed: true);
    final paintColor = color.withValues(
      alpha: spec.wet ? 1.0 : stroke.opacity.clamp(0.0, 1.0),
    );
    if (spec.area == BrushArea.fill) {
      canvas.drawPath(
        region,
        Paint()
          ..color = paintColor
          ..isAntiAlias = true,
      );
      return;
    }
    canvas.save();
    canvas.clipPath(region);
    final angles = spec.area == BrushArea.crossHatch
        ? [spec.hatchAngle, spec.hatchAngle - math.pi / 2]
        : [spec.hatchAngle];
    for (final angle in angles) {
      _hatchLines(
        canvas,
        region.getBounds(),
        angle,
        diameter,
        spec.hatchGap,
        paintColor,
        rnd,
      );
    }
    canvas.restore();
  }

  /// Rayas paralelas hechas a mano: algo onduladas, con el largo y la
  /// separación un poco irregulares.
  static void _hatchLines(
    Canvas canvas,
    Rect bounds,
    double angle,
    double width,
    double gapFactor,
    Color color,
    math.Random rnd,
  ) {
    final dir = Offset(math.cos(angle), math.sin(angle));
    final normal = Offset(-dir.dy, dir.dx);
    final center = bounds.center;
    final reach = bounds.longestSide;
    final gap = math.max(1.5, width * gapFactor);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    for (
      var off = -reach;
      off <= reach;
      off += gap * (0.8 + rnd.nextDouble() * 0.4)
    ) {
      final base = center + normal * off;
      final a = base - dir * reach;
      final b = base + dir * reach;
      final mid =
          Offset.lerp(a, b, 0.5)! +
          normal * ((rnd.nextDouble() - 0.5) * gap * 0.35);
      paint.strokeWidth = width * (0.8 + rnd.nextDouble() * 0.4);
      canvas.drawPath(
        Path()
          ..moveTo(a.dx, a.dy)
          ..quadraticBezierTo(mid.dx, mid.dy, b.dx, b.dy),
        paint,
      );
    }
  }

  // ─── Grano ─────────────────────────────────────────────────────────────────

  /// Recorta lo pintado con el grano del papel: las crestas cogen pigmento y
  /// los valles se quedan claros, menos cuanto más se aprieta.
  static void _applyGrain(
    Canvas canvas,
    BrushSpec spec,
    Rect bounds,
    double u,
    double pressure,
  ) {
    final grain = spec.grain;
    if (grain == null || spec.grainDepth <= 0) return;
    final depth = (spec.grainDepth * (1 - spec.grainPressure * pressure)).clamp(
      0.0,
      1.0,
    );
    canvas.saveLayer(bounds, Paint()..blendMode = BlendMode.dstIn);
    canvas.drawRect(
      bounds,
      Paint()..color = Color.fromRGBO(255, 255, 255, 1 - depth),
    );
    canvas.drawRect(
      bounds,
      Paint()..shader = grainShader(grain, u * spec.grainScale),
    );
    canvas.restore();
  }

  /// Textura de grano repetida, fija al papel (no al trazo).
  static ui.ImageShader grainShader(BrushGrain grain, double scale) {
    final s = math.max(0.2, scale);
    return ui.ImageShader(
      AnnotationTextures.instance.grain(grain),
      TileMode.repeated,
      TileMode.repeated,
      Float64List.fromList([s, 0, 0, 0, 0, s, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1]),
      filterQuality: FilterQuality.medium,
    );
  }

  /// Pinta el papel: su color y un velo de su grano.
  static void paintPaper(Canvas canvas, Size size, AnnotationPaper paper) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = BrushCatalog.paperColor(paper));
    final strength = switch (paper) {
      AnnotationPaper.kraft => 0.09,
      AnnotationPaper.grey => 0.06,
      _ => 0.025,
    };
    canvas.drawRect(
      rect,
      Paint()
        ..shader = grainShader(BrushCatalog.paperGrain(paper), unit(size) * 2.2)
        ..colorFilter = ColorFilter.mode(
          Color.fromRGBO(70, 50, 20, strength),
          BlendMode.srcIn,
        ),
    );
  }

  // ─── Utilidades ────────────────────────────────────────────────────────────

  static Rect _bounds(List<Offset> pts, double pad) {
    var minX = pts.first.dx, maxX = pts.first.dx;
    var minY = pts.first.dy, maxY = pts.first.dy;
    for (final p in pts) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    return Rect.fromLTRB(minX - pad, minY - pad, maxX + pad, maxY + pad);
  }

  /// Curvas por los puntos medios: el trazo del lápiz sin dientes. Con
  /// pocos puntos es una forma enderezada y se respetan sus esquinas.
  static Path _smoothPath(List<Offset> pts, {bool closed = false}) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    if (pts.length <= 8) {
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      if (closed) path.close();
      return path;
    }
    for (var i = 1; i < pts.length - 1; i++) {
      final mid = (pts[i] + pts[i + 1]) / 2;
      path.quadraticBezierTo(pts[i].dx, pts[i].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    if (closed) path.close();
    return path;
  }
}

class _Dab {
  final Offset position;
  final double size;
  final double angle;
  final double alpha;

  const _Dab(this.position, this.size, this.angle, this.alpha);
}
