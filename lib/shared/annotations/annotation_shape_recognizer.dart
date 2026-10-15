import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

/// Qué ha reconocido el enderezado.
enum RecognizedShapeKind { line, polyline, polygon, rectangle, ellipse, curve }

class RecognizedShape {
  final RecognizedShapeKind kind;
  final List<Offset> points;
  final bool closed;

  const RecognizedShape(this.kind, this.points, {this.closed = false});
}

/// Convierte un trazo a mano en una forma limpia, como hacen las apps de
/// dibujo al «mantener» el lápiz al final del trazo:
///
/// * casi recto → línea recta;
/// * con esquinas → polilínea de tramos rectos (paredes, recorridos);
/// * cerrado → rectángulo, polígono o elipse.
///
/// Trabaja en píxeles del documento (no normalizados) para que los ángulos
/// sean reales aunque el lienzo no sea cuadrado. Los tramos casi
/// horizontales, verticales o a 45° se ajustan a ese ángulo.
abstract final class AnnotationShapeRecognizer {
  /// Tolerancia del ajuste de ángulo, en radianes (≈ 6°).
  static const double angleSnap = 6 * math.pi / 180;

  static RecognizedShape? recognize(List<Offset> raw) {
    final pts = _dedupe(raw);
    if (pts.length < 2) return null;
    final length = _pathLength(pts);
    if (length < 10) return null;
    final bounds = _bounds(pts);
    final diag = math.max(1.0, _diag(bounds));

    final gap = (pts.first - pts.last).distance;
    final closed =
        pts.length > 6 && gap < math.max(14, diag * 0.2) && length > diag * 1.8;

    if (closed) return _recognizeClosed(pts, diag);

    // Línea: el trazo no se separa mucho de la cuerda.
    final chord = gap;
    if (chord > 0) {
      var maxDev = 0.0;
      for (final p in pts) {
        maxDev = math.max(maxDev, _distToSegment(p, pts.first, pts.last));
      }
      if (maxDev < math.max(6, chord * 0.08)) {
        return RecognizedShape(
          RecognizedShapeKind.line,
          snapLine(pts.first, pts.last),
        );
      }
    }

    final simplified = _rdp(pts, math.max(5, diag * 0.05));
    if (simplified.length <= 2) {
      return RecognizedShape(
        RecognizedShapeKind.line,
        snapLine(pts.first, pts.last),
      );
    }
    if (simplified.length <= 7 && _hasCorners(simplified)) {
      return RecognizedShape(
        RecognizedShapeKind.polyline,
        _snapPolyline(simplified),
      );
    }
    // Curva libre: se suaviza el temblor sin cambiar su forma.
    return RecognizedShape(
      RecognizedShapeKind.curve,
      _chaikin(_rdp(pts, math.max(2, diag * 0.012)), 2),
    );
  }

  /// Línea con el extremo ajustado a 0°/45°/90° si está cerca.
  static List<Offset> snapLine(Offset a, Offset b) {
    final d = b - a;
    final len = d.distance;
    if (len == 0) return [a, b];
    final angle = _snapAngle(d.direction);
    return [a, a + Offset.fromDirection(angle, len)];
  }

  static RecognizedShape _recognizeClosed(List<Offset> pts, double diag) {
    final loop = [...pts];
    final simplified = _rdp([...loop, loop.first], math.max(5, diag * 0.06));
    // Quita el vértice repetido de cierre.
    final vertices = simplified.sublist(0, simplified.length - 1);
    final ellipse = _fitEllipse(loop);
    final ellipseError = _meanDistance(loop, ellipse, closed: true) / diag;
    final polygonError =
        _meanDistance(loop, [...vertices, vertices.first], closed: true) / diag;

    final cornersAreSharp = _hasCorners([...vertices, vertices.first]);
    final preferPolygon =
        vertices.length >= 3 &&
        (vertices.length <= 4 ||
            (vertices.length <= 6 &&
                cornersAreSharp &&
                polygonError < ellipseError));

    if (preferPolygon && vertices.length == 4) {
      return RecognizedShape(
        RecognizedShapeKind.rectangle,
        _rectangleFrom(vertices),
        closed: true,
      );
    }
    if (preferPolygon) {
      return RecognizedShape(
        RecognizedShapeKind.polygon,
        _snapPolyline(vertices),
        closed: true,
      );
    }
    return RecognizedShape(RecognizedShapeKind.ellipse, ellipse, closed: true);
  }

  static bool _hasCorners(List<Offset> pts) {
    // Al menos un giro claro (> 25°) entre tramos consecutivos.
    for (var i = 1; i < pts.length - 1; i++) {
      final a = (pts[i] - pts[i - 1]).direction;
      final b = (pts[i + 1] - pts[i]).direction;
      if (_angleDiff(a, b).abs() > 25 * math.pi / 180) return true;
    }
    return false;
  }

  static List<Offset> _snapPolyline(List<Offset> pts) {
    final out = <Offset>[pts.first];
    for (var i = 1; i < pts.length; i++) {
      final d = pts[i] - pts[i - 1];
      out.add(
        out.last + Offset.fromDirection(_snapAngle(d.direction), d.distance),
      );
    }
    return out;
  }

  /// Rectángulo orientado según el lado más largo (ajustado a 0°/45°/90°).
  static List<Offset> _rectangleFrom(List<Offset> v) {
    var longest = 0;
    var longestLen = 0.0;
    for (var i = 0; i < 4; i++) {
      final len = (v[(i + 1) % 4] - v[i]).distance;
      if (len > longestLen) {
        longestLen = len;
        longest = i;
      }
    }
    final angle = _snapAngle((v[(longest + 1) % 4] - v[longest]).direction);
    final u = Offset(math.cos(angle), math.sin(angle));
    final n = Offset(-u.dy, u.dx);
    final center = v.reduce((a, b) => a + b) / 4;
    var minU = double.infinity, maxU = -double.infinity;
    var minN = double.infinity, maxN = -double.infinity;
    for (final p in v) {
      final r = p - center;
      final pu = r.dx * u.dx + r.dy * u.dy;
      final pn = r.dx * n.dx + r.dy * n.dy;
      minU = math.min(minU, pu);
      maxU = math.max(maxU, pu);
      minN = math.min(minN, pn);
      maxN = math.max(maxN, pn);
    }
    Offset at(double a, double b) => center + u * a + n * b;
    return [at(minU, minN), at(maxU, minN), at(maxU, maxN), at(minU, maxN)];
  }

  /// Elipse por momentos: centro, eje principal y radios.
  static List<Offset> _fitEllipse(List<Offset> pts) {
    final c = pts.reduce((a, b) => a + b) / pts.length.toDouble();
    var sxx = 0.0, syy = 0.0, sxy = 0.0;
    for (final p in pts) {
      final d = p - c;
      sxx += d.dx * d.dx;
      syy += d.dy * d.dy;
      sxy += d.dx * d.dy;
    }
    var angle = 0.5 * math.atan2(2 * sxy, sxx - syy);
    // Casi a eje: se endereza.
    final snapped = _snapAngle(angle);
    if ((snapped - angle).abs() < angleSnap) angle = snapped;
    final u = Offset(math.cos(angle), math.sin(angle));
    final n = Offset(-u.dy, u.dx);
    // Radio = media de las distancias proyectadas × √2 (curva de muestra
    // uniforme en ángulo da un valor estable aunque el trazo sea irregular).
    var su = 0.0, sn = 0.0;
    for (final p in pts) {
      final d = p - c;
      final pu = d.dx * u.dx + d.dy * u.dy;
      final pn = d.dx * n.dx + d.dy * n.dy;
      su += pu * pu;
      sn += pn * pn;
    }
    var ru = math.sqrt(2 * su / pts.length);
    var rn = math.sqrt(2 * sn / pts.length);
    // Casi círculo → círculo.
    if ((ru - rn).abs() < math.max(ru, rn) * 0.12) {
      ru = rn = (ru + rn) / 2;
    }
    const steps = 48;
    return [
      for (var i = 0; i < steps; i++)
        c +
            u * (ru * math.cos(i / steps * 2 * math.pi)) +
            n * (rn * math.sin(i / steps * 2 * math.pi)),
    ];
  }

  static double _meanDistance(
    List<Offset> pts,
    List<Offset> shape, {
    bool closed = false,
  }) {
    final poly = closed && shape.first != shape.last
        ? [...shape, shape.first]
        : shape;
    var total = 0.0;
    for (final p in pts) {
      var best = double.infinity;
      for (var i = 1; i < poly.length; i++) {
        best = math.min(best, _distToSegment(p, poly[i - 1], poly[i]));
      }
      total += best;
    }
    return total / pts.length;
  }

  static double _snapAngle(double angle) {
    const step = math.pi / 4;
    final nearest = (angle / step).round() * step;
    return (angle - nearest).abs() <= angleSnap ? nearest : angle;
  }

  static double _angleDiff(double a, double b) {
    var d = b - a;
    while (d > math.pi) {
      d -= 2 * math.pi;
    }
    while (d < -math.pi) {
      d += 2 * math.pi;
    }
    return d;
  }

  static List<Offset> _rdp(List<Offset> pts, double epsilon) {
    if (pts.length < 3) return [...pts];
    var index = 0;
    var maxDist = 0.0;
    for (var i = 1; i < pts.length - 1; i++) {
      final d = _distToSegment(pts[i], pts.first, pts.last);
      if (d > maxDist) {
        maxDist = d;
        index = i;
      }
    }
    if (maxDist <= epsilon) return [pts.first, pts.last];
    final left = _rdp(pts.sublist(0, index + 1), epsilon);
    final right = _rdp(pts.sublist(index), epsilon);
    return [...left.sublist(0, left.length - 1), ...right];
  }

  static List<Offset> _chaikin(List<Offset> pts, int iterations) {
    var out = pts;
    for (var it = 0; it < iterations; it++) {
      if (out.length < 3) return out;
      final next = <Offset>[out.first];
      for (var i = 0; i < out.length - 1; i++) {
        final a = out[i];
        final b = out[i + 1];
        next
          ..add(a * 0.75 + b * 0.25)
          ..add(a * 0.25 + b * 0.75);
      }
      next.add(out.last);
      out = next;
    }
    return out;
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

  static List<Offset> _dedupe(List<Offset> pts) {
    final out = <Offset>[];
    for (final p in pts) {
      if (out.isEmpty || (out.last - p).distance > 0.5) out.add(p);
    }
    return out;
  }

  static double _pathLength(List<Offset> pts) {
    var total = 0.0;
    for (var i = 1; i < pts.length; i++) {
      total += (pts[i] - pts[i - 1]).distance;
    }
    return total;
  }

  static Rect _bounds(List<Offset> pts) {
    var l = pts.first.dx, r = l, t = pts.first.dy, b = t;
    for (final p in pts) {
      l = math.min(l, p.dx);
      r = math.max(r, p.dx);
      t = math.min(t, p.dy);
      b = math.max(b, p.dy);
    }
    return Rect.fromLTRB(l, t, r, b);
  }

  static double _diag(Rect r) =>
      math.sqrt(r.width * r.width + r.height * r.height);
}
