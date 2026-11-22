import 'dart:math' as math;
import 'dart:ui';

/// Forma de una cubierta (plan AM.3).
enum ArchRoofKind {
  flat('Plana'),
  shed('Un agua'),
  gable('Dos aguas'),
  hip('Cuatro aguas'),
  vault('Bóveda');

  const ArchRoofKind(this.label);
  final String label;
}

/// Una cubierta sobre cualquier contorno: la nave, un volumen o, más
/// adelante, un recinto. Da la altura sobre el alero en cada punto, que
/// es lo que usan la luz, el alzado y el 3D.
///
/// El contorno va en metros, con los ejes del lienzo (y hacia abajo).
class ArchRoof {
  final ArchRoofKind kind;

  /// Lo que sube la cumbrera (o el lado alto) sobre el alero, en metros.
  final double riseM;

  /// Dirección de la cumbrera en el lienzo, en grados (0 = horizontal). En
  /// una cubierta a un agua, el lado alto es el de la normal (−sen, cos).
  final double ridgeDeg;

  /// Lo que sale el alero por fuera de las paredes, en metros. Solo se ve.
  final double overhangM;

  /// Material de la biblioteca (`ArchMaterials`).
  final String? mat;

  const ArchRoof({
    this.kind = ArchRoofKind.gable,
    this.riseM = 1.5,
    this.ridgeDeg = 0,
    this.overhangM = 0,
    this.mat,
  });

  ArchRoof copyWith({
    ArchRoofKind? kind,
    double? riseM,
    double? ridgeDeg,
    double? overhangM,
    String? mat,
  }) => ArchRoof(
    kind: kind ?? this.kind,
    riseM: riseM ?? this.riseM,
    ridgeDeg: ridgeDeg ?? this.ridgeDeg,
    overhangM: overhangM ?? this.overhangM,
    mat: mat ?? this.mat,
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'riseM': riseM,
    'ridgeDeg': ridgeDeg,
    if (overhangM > 0) 'overhangM': overhangM,
    'mat': ?mat,
  };

  static ArchRoof? fromJson(Object? raw) {
    if (raw is! Map) return null;
    double n(String k, double d) => (raw[k] as num?)?.toDouble() ?? d;
    return ArchRoof(
      kind: ArchRoofKind.values.asNameMap()[raw['kind']] ?? ArchRoofKind.flat,
      riseM: n('riseM', 1.5),
      ridgeDeg: n('ridgeDeg', 0),
      overhangM: n('overhangM', 0),
      mat: raw['mat'] as String?,
    );
  }

  /// Lo más alto sobre el alero.
  double get peakM => kind == ArchRoofKind.flat ? 0 : riseM;

  /// Dirección de la cumbrera y su normal, en el lienzo.
  Offset get ridgeDir {
    final r = ridgeDeg * math.pi / 180;
    return Offset(math.cos(r), math.sin(r));
  }

  /// Altura sobre el alero en [p], para el contorno [poly].
  double riseAt(List<Offset> poly, Offset p) {
    if (kind == ArchRoofKind.flat || riseM == 0 || poly.length < 3) return 0;
    final g = RoofFrame.of(poly, ridgeDir);
    final s = g.across(p);
    final half = g.halfSpan;
    if (half <= 0) return 0;
    final t = (s / half).clamp(-1.0, 1.0);
    switch (kind) {
      case ArchRoofKind.flat:
        return 0;
      case ArchRoofKind.shed:
        return riseM * (t + 1) / 2;
      case ArchRoofKind.gable:
        return riseM * (1 - t.abs());
      case ArchRoofKind.vault:
        return riseM * math.sqrt(math.max(0, 1 - t * t));
      case ArchRoofKind.hip:
        // Todos los faldones con la misma pendiente: la altura crece con
        // la distancia al borde más cercano hasta la cumbrera. En un
        // contorno convexo es exactamente la cubierta a cuatro aguas.
        final slope = riseM / half;
        return math.min(riseM, slope * _distanceToEdge(poly, p));
    }
  }

  /// La cumbrera en el contorno: sus dos extremos, o `null` si no tiene
  /// (plana, un agua). En cuatro aguas, se acorta media luz por cada lado.
  (Offset, Offset)? ridge(List<Offset> poly) {
    if (kind == ArchRoofKind.flat || kind == ArchRoofKind.shed) return null;
    if (poly.length < 3) return null;
    final g = RoofFrame.of(poly, ridgeDir);
    var lo = g.alongMin, hi = g.alongMax;
    if (kind == ArchRoofKind.hip) {
      lo += g.halfSpan;
      hi -= g.halfSpan;
      if (hi < lo) lo = hi = (lo + hi) / 2;
    }
    final d = ridgeDir;
    final base = g.centre;
    return (base + d * lo, base + d * hi);
  }

  /// La cubierta en triángulos sobre [poly] (metros, sin girar): `roof`
  /// es la cubierta y `gables` lo que cierra cada pared desde el alero
  /// hasta ella (los hastiales). Cada punto es `x, y, z`, con z sobre el
  /// alero. La rejilla va alineada con la cumbrera, así la arista de
  /// arriba sale limpia.
  ({List<double> roof, List<double> gables}) mesh(
    List<Offset> poly, {
    double stepM = 0.25,
  }) {
    final roof = <double>[], gables = <double>[];
    if (poly.length < 3) return (roof: roof, gables: gables);
    final g = RoofFrame.of(poly, ridgeDir);
    final dir = g.dir, n = g.normal;
    Offset at(double a, double s) => g.centre + dir * a + n * s;
    // Media luz en un número par de pasos: la cumbrera cae en una línea.
    final halfSteps = math.max(1, (g.halfSpan / stepM).ceil());
    final ds = g.halfSpan / halfSteps;
    final along = math.max(1, ((g.alongMax - g.alongMin) / stepM).ceil());
    final da = (g.alongMax - g.alongMin) / along;
    bool inside(Offset p) {
      var c = false;
      for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
        final a = poly[i], b = poly[j];
        if ((a.dy > p.dy) != (b.dy > p.dy) &&
            p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
          c = !c;
        }
      }
      return c;
    }

    void put(List<double> out, Offset p, double z) =>
        out.addAll([_r(p.dx), _r(p.dy), _r(z)]);
    for (var i = 0; i < along; i++) {
      for (var j = 0; j < halfSteps * 2; j++) {
        final a0 = g.alongMin + da * i, a1 = a0 + da;
        final s0 = -g.halfSpan + ds * j, s1 = s0 + ds;
        final c = at((a0 + a1) / 2, (s0 + s1) / 2);
        if (!inside(c)) continue;
        final q = [at(a0, s0), at(a1, s0), at(a1, s1), at(a0, s1)];
        final z = [for (final p in q) riseAt(poly, p)];
        for (final k in const [0, 1, 2, 0, 2, 3]) {
          put(roof, q[k], z[k]);
        }
      }
    }
    // Hastiales: cada lado sube del alero a la cubierta.
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      final len = (b - a).distance;
      final k = math.max(1, (len / stepM).ceil());
      for (var m = 0; m < k; m++) {
        final p = Offset.lerp(a, b, m / k)!, q = Offset.lerp(a, b, (m + 1) / k)!;
        final zp = riseAt(poly, p), zq = riseAt(poly, q);
        if (zp < 0.005 && zq < 0.005) continue;
        put(gables, p, 0);
        put(gables, q, 0);
        put(gables, q, zq);
        put(gables, p, 0);
        put(gables, q, zq);
        put(gables, p, zp);
      }
    }
    return (roof: roof, gables: gables);
  }

  static double _r(double v) => (v * 1000).round() / 1000;

  static double _distanceToEdge(List<Offset> poly, Offset p) {
    var best = double.infinity;
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      final ab = b - a;
      final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
      final t = len2 == 0
          ? 0.0
          : (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2).clamp(0.0, 1.0);
      best = math.min(best, (p - (a + ab * t)).distance);
    }
    return best;
  }
}

/// El contorno visto desde la cumbrera: su centro, cuánto mide a lo largo
/// y media luz a lo ancho.
class RoofFrame {
  final Offset centre;
  final Offset dir;
  final double halfSpan;
  final double alongMin;
  final double alongMax;

  const RoofFrame._(
    this.centre,
    this.dir,
    this.halfSpan,
    this.alongMin,
    this.alongMax,
  );

  Offset get normal => Offset(-dir.dy, dir.dx);

  /// Distancia (con signo) a la línea de la cumbrera.
  double across(Offset p) {
    final v = p - centre, n = normal;
    return v.dx * n.dx + v.dy * n.dy;
  }

  static final _cache = <(int, Offset), RoofFrame>{};

  static RoofFrame of(List<Offset> poly, Offset dir) {
    final key = (Object.hashAll(poly), dir);
    final hit = _cache[key];
    if (hit != null) return hit;
    final n = Offset(-dir.dy, dir.dx);
    // Centro de la caja vista desde la cumbrera: la cumbrera queda en
    // medio aunque el contorno no sea simétrico.
    var aMin = double.infinity, aMax = -double.infinity;
    var sMin = double.infinity, sMax = -double.infinity;
    for (final p in poly) {
      final a = p.dx * dir.dx + p.dy * dir.dy;
      final s = p.dx * n.dx + p.dy * n.dy;
      aMin = math.min(aMin, a);
      aMax = math.max(aMax, a);
      sMin = math.min(sMin, s);
      sMax = math.max(sMax, s);
    }
    final centre = dir * ((aMin + aMax) / 2) + n * ((sMin + sMax) / 2);
    final half = (aMax - aMin) / 2;
    final frame = RoofFrame._(
      centre,
      dir,
      (sMax - sMin) / 2,
      -half,
      half,
    );
    if (_cache.length > 256) _cache.clear();
    return _cache[key] = frame;
  }
}
