import 'dart:math' as math;
import 'dart:ui';

import 'scan_walls.dart';

/// De dónde sale un elemento de la estructura.
enum ScanSource { mesh, arkit, mark }

/// Lo que el visor mide de un escaneo (`iris.scanProfile` e `iris.scanGrid`),
/// en metros de la planta: x y la «y» del lienzo, con [heights] en la
/// vertical del 3D.
class ScanProfile {
  /// Alto de cada casilla de [up] y [down].
  final double bin;

  /// Altura de la casilla 0.
  final double y0;

  /// Área de los triángulos horizontales que miran arriba / abajo, por
  /// alturas.
  final List<double> up, down;

  /// Altura de cada corte, de abajo arriba, y sus tramos.
  final List<double> heights;
  final List<List<(Offset, Offset)>> slices;

  final ScanGrid? grid;

  const ScanProfile({
    required this.bin,
    required this.y0,
    required this.up,
    required this.down,
    required this.heights,
    required this.slices,
    this.grid,
  });

  static ScanProfile? fromJson(Map json, {Map? grid}) {
    List<double> nums(Object? v) => [
      for (final x in (v as List? ?? const [])) (x as num).toDouble(),
    ];
    final heights = nums(json['heights']);
    final raw = json['slices'];
    if (raw is! List || raw.length != heights.length) return null;
    return ScanProfile(
      bin: (json['bin'] as num?)?.toDouble() ?? 0.05,
      y0: (json['y0'] as num?)?.toDouble() ?? 0,
      up: nums(json['up']),
      down: nums(json['down']),
      heights: heights,
      slices: [for (final s in raw) sliceSegments((s as List).cast<num>())],
      grid: grid == null ? null : ScanGrid.fromJson(grid),
    );
  }

  ScanProfile withGrid(ScanGrid? grid) => ScanProfile(
    bin: bin,
    y0: y0,
    up: up,
    down: down,
    heights: heights,
    slices: slices,
    grid: grid,
  );
}

/// Rejilla cenital: en cada celda, la altura más alta del escaneo (null si
/// no hay nada).
class ScanGrid {
  final double x0, y0, cell;
  final int cols, rows;
  final List<double?> top;

  const ScanGrid({
    required this.x0,
    required this.y0,
    required this.cell,
    required this.cols,
    required this.rows,
    required this.top,
  });

  static ScanGrid? fromJson(Map json) {
    final top = json['top'];
    final cols = json['cols'], rows = json['rows'];
    if (top is! List || cols is! num || rows is! num) return null;
    if (top.length != cols * rows) return null;
    return ScanGrid(
      x0: (json['x0'] as num).toDouble(),
      y0: (json['y0'] as num).toDouble(),
      cell: (json['cell'] as num).toDouble(),
      cols: cols.toInt(),
      rows: rows.toInt(),
      top: [for (final v in top) (v as num?)?.toDouble()],
    );
  }

  double? at(int i, int j) =>
      i < 0 || j < 0 || i >= cols || j >= rows ? null : top[j * cols + i];

  double? atPoint(Offset p) =>
      at(((p.dx - x0) / cell).floor(), ((p.dy - y0) / cell).floor());

  Offset center(int i, int j) =>
      Offset(x0 + (i + 0.5) * cell, y0 + (j + 0.5) * cell);
}

/// La captura del iPhone (ES.1) ya llevada a metros de la planta.
class CaptureHints {
  /// Planos de pared de ARKit vistos desde arriba: la cara de la pared.
  final List<(Offset, Offset)> wallPlanes;

  /// Esquinas tocadas.
  final List<Offset> corners;

  /// Alturas tocadas en el suelo y el techo, en la vertical del 3D.
  final double? floorY, ceilingY;

  const CaptureHints({
    this.wallPlanes = const [],
    this.corners = const [],
    this.floorY,
    this.ceilingY,
  });
}

class ScanWall {
  Offset start, end;

  /// Grosor en metros; si no se vieron las dos caras, el de serie.
  double thickness;
  bool thicknessEstimated;
  double confidence;
  ScanSource source;

  ScanWall(
    this.start,
    this.end, {
    required this.thickness,
    this.thicknessEstimated = false,
    this.confidence = 1,
    this.source = ScanSource.mesh,
  });

  double get length => (end - start).distance;
  Offset get dir => (end - start) / length;
  Offset get normal => Offset(-dir.dy, dir.dx);
  double get offset => _dot(start, normal);
  double tOf(Offset p) => _dot(p, dir);
}

enum ScanOpeningKind { door, window, passage }

class ScanOpening {
  final ScanOpeningKind kind;

  /// Índice de su pared en [ScanStructure.walls].
  final int wall;
  final Offset center;
  final double width;

  /// Alféizar y dintel sobre el suelo, en metros.
  final double sill, head;
  final double confidence;

  const ScanOpening({
    required this.kind,
    required this.wall,
    required this.center,
    required this.width,
    required this.sill,
    required this.head,
    required this.confidence,
  });
}

/// Un mueble: una caja alineada con los ejes de la casa.
class ScanObject {
  final Offset center;

  /// Lado a lo largo de [rotationDeg] y lado perpendicular.
  final double width, depth;
  final double rotationDeg;
  final double heightM;
  final double confidence;

  const ScanObject({
    required this.center,
    required this.width,
    required this.depth,
    required this.rotationDeg,
    required this.heightM,
    required this.confidence,
  });
}

class ScanStructure {
  final double floorY;

  /// Del suelo al techo. [heightEstimated] si el techo no se vio.
  final double heightM;
  final bool heightEstimated;

  /// Dirección principal de la casa, en grados (0–90).
  final double axisDeg;
  final List<ScanWall> walls;
  final List<ScanOpening> openings;
  final List<ScanObject> objects;

  const ScanStructure({
    required this.floorY,
    required this.heightM,
    required this.heightEstimated,
    required this.axisDeg,
    required this.walls,
    required this.openings,
    required this.objects,
  });
}

double _dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
double _cross(Offset a, Offset b) => a.dx * b.dy - a.dy * b.dx;

/// Grosor que se da a una pared de la que solo se vio una cara.
const double kScanDefaultThickness = 0.10;

/// El solucionador de estructura (ES.2): del escaneo medido a paredes con
/// grosor, alturas, huecos y muebles. Ver `docs/PLAN_ESCANEO.md`.
ScanStructure solveStructure(
  ScanProfile p, {
  CaptureHints? capture,
  double snapDeg = 3,
  double cornerTol = 0.35,
}) {
  // 1 · Suelo y techo.
  var floorY = _peakHeight(p, p.up, lowest: true) ?? _firstSliceY(p);
  var ceilingY = _peakHeight(p, p.down, lowest: false);
  if (capture?.floorY != null) floorY = capture!.floorY!;
  if (capture?.ceilingY != null) ceilingY = capture!.ceilingY!;
  if (ceilingY != null && ceilingY - floorY < 1.6) ceilingY = null;

  final rel = [for (final h in p.heights) h - floorY];
  final step = p.heights.length > 1 ? p.heights[1] - p.heights[0] : 0.15;
  final topRel = ceilingY == null ? double.infinity : ceilingY - floorY;

  // 2 · Paredes candidatas: los cortes por encima de los muebles bajos.
  final upper = <(Offset, Offset)>[];
  for (var k = 0; k < rel.length; k++) {
    if (rel[k] >= 0.9 && rel[k] < topRel - 0.04) upper.addAll(p.slices[k]);
  }
  final proposals = proposeWalls(upper, minLength: 0.5);

  // Los cortes que deciden si una línea es pared: los de 1,2 m para arriba
  // (un mueble alto llega, una cama no).
  final supportSlices = [
    for (var k = 0; k < rel.length; k++)
      if (rel[k] >= 1.2 && rel[k] < topRel - 0.04) k,
  ];
  final judge = supportSlices.length >= 2
      ? supportSlices
      : [
          for (var k = 0; k < rel.length; k++)
            if (rel[k] >= 0.9 && rel[k] < topRel - 0.04) k,
        ];

  var walls = <ScanWall>[];
  for (final w in proposals) {
    final wall = ScanWall(
      w.start,
      w.end,
      thickness: w.thickness > 0.02 ? w.thickness : kScanDefaultThickness,
      thicknessEstimated: w.thickness <= 0.02,
    );
    final seen = [
      for (final k in judge)
        _coverage(wall, p.slices[k]).where((b) => b).length * _binM >=
            math.max(0.25 * wall.length, 0.3),
    ];
    final support = judge.isEmpty
        ? 0.0
        : seen.where((s) => s).length / judge.length;
    if (support < 0.5) continue;
    // Con el techo a la vista, una pared llega hasta él; un mueble alto no.
    if (ceilingY != null &&
        seen.length >= 2 &&
        !seen.reversed.take(2).any((s) => s)) {
      continue;
    }
    wall.confidence =
        ((0.4 + 0.6 * support) * (wall.thicknessEstimated ? 0.85 : 1))
            .clamp(0, 1)
            .toDouble();
    walls.add(wall);
  }

  // 3 · Fusión con la captura: los planos de ARKit mandan sobre la posición.
  if (capture != null) _fuseCapture(walls, capture);

  // Una pared vista por una sola cara: su eje se aparta medio grosor de la
  // habitación (hacia fuera del centro de la planta).
  if (walls.isNotEmpty) {
    var c = Offset.zero;
    for (final w in walls) {
      c += (w.start + w.end) / 2;
    }
    c = c / walls.length.toDouble();
    for (final w in walls) {
      if (!w.thicknessEstimated || w.source != ScanSource.mesh) continue;
      final n = w.normal;
      final side = _dot(c - w.start, n) > 0 ? -1.0 : 1.0;
      final shift = n * (side * w.thickness / 2);
      w.start += shift;
      w.end += shift;
    }
  }

  // 4 · Regularización: ejes de la casa y esquinas cerradas.
  final axis = _dominantAxis(walls);
  for (final w in walls) {
    _snapToAxis(w, axis, snapDeg);
  }
  _joinCorners(walls, cornerTol);
  if (capture != null) {
    for (final c in capture.corners) {
      for (final w in walls) {
        if ((w.start - c).distance <= 0.2) w.start = c;
        if ((w.end - c).distance <= 0.2) w.end = c;
      }
    }
  }

  final heightM = ceilingY != null
      ? ceilingY - floorY
      : _estimatedHeight(walls, p, rel);

  // 5 · Pasos: dos tramos en la misma línea separados por un hueco.
  final openings = <ScanOpening>[];
  walls = _mergePassages(walls, openings, heightM);

  // 6 · Puertas y ventanas por el perfil vertical de cada pared.
  for (var i = 0; i < walls.length; i++) {
    openings.addAll(_openingsOf(i, walls[i], p, rel, step, heightM));
  }

  // 7 · Muebles.
  final objects = p.grid == null
      ? const <ScanObject>[]
      : _objects(p.grid!, walls, floorY, heightM, axis);

  return ScanStructure(
    floorY: floorY,
    heightM: heightM,
    heightEstimated: ceilingY == null,
    axisDeg: axis * 180 / math.pi,
    walls: walls,
    openings: _dropOccluded(openings, walls, p.grid, floorY),
    objects: objects,
  );
}

double _firstSliceY(ScanProfile p) =>
    p.heights.isEmpty ? p.y0 : p.heights.first - 0.05;

/// El pico más bajo (suelo) o más alto (techo) del histograma con al menos
/// un cuarto del área del mayor.
double? _peakHeight(ScanProfile p, List<double> h, {required bool lowest}) {
  if (h.isEmpty) return null;
  final s = List<double>.generate(h.length, (i) {
    var sum = 0.0;
    for (var k = i - 1; k <= i + 1; k++) {
      if (k >= 0 && k < h.length) sum += h[k];
    }
    return sum;
  });
  final max = s.reduce(math.max);
  if (max <= 0) return null;
  final order = lowest
      ? List<int>.generate(s.length, (i) => i)
      : List<int>.generate(s.length, (i) => s.length - 1 - i);
  for (final i in order) {
    final left = i > 0 ? s[i - 1] : -1;
    final right = i < s.length - 1 ? s[i + 1] : -1;
    if (s[i] >= 0.25 * max && s[i] >= left && s[i] >= right) {
      // Centro de masas de la casilla y sus vecinas, más fino que la casilla.
      var w = 0.0, m = 0.0;
      for (var k = i - 1; k <= i + 1; k++) {
        if (k < 0 || k >= h.length) continue;
        w += h[k];
        m += h[k] * (p.y0 + (k + 0.5) * p.bin);
      }
      return w > 0 ? m / w : p.y0 + (i + 0.5) * p.bin;
    }
  }
  return null;
}

const double _binM = 0.05;

int _bins(ScanWall w) => math.max(1, (w.length / _binM).ceil());

/// Qué trozos de 5 cm de la pared tocan los tramos de un corte.
List<bool> _coverage(ScanWall w, List<(Offset, Offset)> segs) {
  final n = _bins(w);
  final out = List<bool>.filled(n, false);
  final d = w.dir, nrm = w.normal, off = w.offset;
  final band = w.thickness / 2 + 0.08;
  final t0 = w.tOf(w.start);
  final parallel = math.cos(25 * math.pi / 180);
  for (final s in segs) {
    final a = _dot(s.$1, nrm) - off, b = _dot(s.$2, nrm) - off;
    if (a.abs() > band || b.abs() > band) continue;
    final v = s.$2 - s.$1;
    final len = v.distance;
    if (len > 0.02 && (_dot(v, d) / len).abs() < parallel) continue;
    var ta = _dot(s.$1, d) - t0, tb = _dot(s.$2, d) - t0;
    if (ta > tb) (ta, tb) = (tb, ta);
    // Los trozos cuyo centro cae en el tramo; uno corto marca el suyo.
    final i0 = math.max(0, (ta / _binM - 0.5).ceil());
    final i1 = math.min(n - 1, (tb / _binM - 0.5).floor());
    if (i0 > i1) {
      final i = ((ta + tb) / 2 / _binM).floor();
      if (i >= 0 && i < n) out[i] = true;
    }
    for (var i = i0; i <= i1; i++) {
      out[i] = true;
    }
  }
  return out;
}

/// Dirección principal (radianes, 0–π/2): la media en ángulo cuádruple,
/// pesada por longitud, para que 0° y 90° cuenten igual.
double _dominantAxis(List<ScanWall> walls) {
  var cx = 0.0, cy = 0.0;
  for (final w in walls) {
    final a = math.atan2(w.end.dy - w.start.dy, w.end.dx - w.start.dx);
    cx += math.cos(4 * a) * w.length;
    cy += math.sin(4 * a) * w.length;
  }
  if (cx == 0 && cy == 0) return 0;
  final axis = math.atan2(cy, cx) / 4;
  return (axis % (math.pi / 2) + math.pi / 2) % (math.pi / 2);
}

void _snapToAxis(ScanWall w, double axis, double snapDeg) {
  final a = math.atan2(w.end.dy - w.start.dy, w.end.dx - w.start.dx);
  const quarter = math.pi / 2;
  final k = ((a - axis) / quarter).round();
  final target = axis + k * quarter;
  if ((a - target).abs() > snapDeg * math.pi / 180) return;
  final mid = (w.start + w.end) / 2;
  final half = w.length / 2;
  final d = Offset(math.cos(target), math.sin(target));
  w.start = mid - d * half;
  w.end = mid + d * half;
}

/// Cierra esquinas y uniones en T: un extremo cerca de otra pared (no
/// paralela) se lleva al cruce de los dos ejes, y la otra pared se alarga
/// hasta él si se quedaba corta.
void _joinCorners(List<ScanWall> walls, double tol) {
  final minSin = math.sin(20 * math.pi / 180);
  for (var i = 0; i < walls.length; i++) {
    for (final atStart in [true, false]) {
      final w = walls[i];
      final e = atStart ? w.start : w.end;
      Offset? best;
      int? bestJ;
      var bestDist = tol;
      for (var j = 0; j < walls.length; j++) {
        if (j == i) continue;
        final o = walls[j];
        final denom = _cross(w.dir, o.dir);
        if (denom.abs() < minSin) continue;
        // Cruce de las dos rectas.
        final t = _cross(o.start - w.start, o.dir) / denom;
        final x = w.start + w.dir * t;
        final dist = (x - e).distance;
        if (dist > bestDist) continue;
        final tj = o.tOf(x);
        if (tj < o.tOf(o.start) - tol || tj > o.tOf(o.end) + tol) continue;
        best = x;
        bestJ = j;
        bestDist = dist;
      }
      if (best == null) continue;
      if (atStart) {
        w.start = best;
      } else {
        w.end = best;
      }
      final o = walls[bestJ!];
      final tj = o.tOf(best);
      if (tj < o.tOf(o.start)) o.start = best;
      if (tj > o.tOf(o.end)) o.end = best;
    }
  }
  walls.removeWhere((w) => w.length < 0.3);
}

void _fuseCapture(List<ScanWall> walls, CaptureHints c) {
  final parallel = math.cos(5 * math.pi / 180);
  for (final (a, b) in c.wallPlanes) {
    final len = (b - a).distance;
    if (len < 0.3) continue;
    final d = (b - a) / len;
    ScanWall? match;
    var bestDist = 0.0;
    for (final w in walls) {
      if (_dot(d, w.dir).abs() < parallel) continue;
      final face = _dot((a + b) / 2, w.normal) - w.offset;
      // La cara de ARKit cae en una de las dos caras de la pared.
      final miss = (face.abs() - w.thickness / 2).abs();
      if (miss > 0.15) continue;
      final ta = w.tOf(a), tb = w.tOf(b);
      final overlap =
          math.min(w.tOf(w.end), math.max(ta, tb)) -
          math.max(w.tOf(w.start), math.min(ta, tb));
      if (overlap < 0.3 * math.min(len, w.length)) continue;
      if (match == null || miss < bestDist) {
        match = w;
        bestDist = miss;
      }
    }
    if (match != null) {
      final face = _dot((a + b) / 2, match.normal) - match.offset;
      final side = face >= 0 ? 1.0 : -1.0;
      final shift = match.normal * (face - side * match.thickness / 2);
      match.start += shift;
      match.end += shift;
      match.source = ScanSource.arkit;
      match.confidence = math.max(match.confidence, 0.9);
    } else if (len >= 0.8) {
      // Una pared que la malla no trae: se pone desde ARKit.
      walls.add(
        ScanWall(
          a,
          b,
          thickness: kScanDefaultThickness,
          thicknessEstimated: true,
          confidence: 0.5,
          source: ScanSource.arkit,
        ),
      );
    }
  }
}

/// Si no se vio el techo: la altura del corte más alto que aún ve paredes.
double _estimatedHeight(List<ScanWall> walls, ScanProfile p, List<double> rel) {
  var best = 2.5;
  var found = false;
  for (var k = rel.length - 1; k >= 0 && walls.isNotEmpty; k--) {
    if (rel[k] < 1.8) break;
    var covered = 0;
    for (final w in walls) {
      final cov = _coverage(w, p.slices[k]);
      if (cov.where((b) => b).length >= 0.3 * cov.length) covered++;
    }
    if (covered >= math.max(1, walls.length ~/ 2)) {
      best = rel[k] + 0.1;
      found = true;
      break;
    }
  }
  return found ? best : 2.5;
}

/// Une los tramos de una misma línea con un hueco de 0,6 a 2,6 m: es un
/// paso de suelo a techo.
List<ScanWall> _mergePassages(
  List<ScanWall> walls,
  List<ScanOpening> openings,
  double heightM,
) {
  final parallel = math.cos(1.5 * math.pi / 180);
  final out = [...walls];
  final passages = <(int, Offset, double)>[];
  var merged = true;
  while (merged) {
    merged = false;
    outer:
    for (var i = 0; i < out.length; i++) {
      for (var j = i + 1; j < out.length; j++) {
        final a = out[i], b = out[j];
        if (_dot(a.dir, b.dir).abs() < parallel) continue;
        if ((_dot(b.start, a.normal) - a.offset).abs() > 0.08) continue;
        final a0 = a.tOf(a.start), a1 = a.tOf(a.end);
        final b0 = math.min(a.tOf(b.start), a.tOf(b.end));
        final b1 = math.max(a.tOf(b.start), a.tOf(b.end));
        final gapStart = b0 > a1 ? a1 : b1;
        final gapEnd = b0 > a1 ? b0 : a0;
        final gap = gapEnd - gapStart;
        if (gap < 0.6 || gap > 2.6) continue;
        final t0 = math.min(a0, b0), t1 = math.max(a1, b1);
        final n = a.normal * a.offset;
        final wall = ScanWall(
          n + a.dir * t0,
          n + a.dir * t1,
          thickness: math.max(a.thickness, b.thickness),
          thicknessEstimated: a.thicknessEstimated && b.thicknessEstimated,
          confidence: math.min(a.confidence, b.confidence),
          source: a.source,
        );
        out
          ..removeAt(j)
          ..removeAt(i)
          ..add(wall);
        passages.add((-1, n + a.dir * ((gapStart + gapEnd) / 2), gap));
        merged = true;
        break outer;
      }
    }
  }
  // Cada paso, a la pared que lo contiene.
  for (final (_, center, width) in passages) {
    var best = -1;
    var bestDist = 0.1;
    for (var i = 0; i < out.length; i++) {
      final w = out[i];
      final t = w.tOf(center);
      if (t < w.tOf(w.start) || t > w.tOf(w.end)) continue;
      final dist = (_dot(center, w.normal) - w.offset).abs();
      if (dist < bestDist) {
        best = i;
        bestDist = dist;
      }
    }
    if (best < 0) continue;
    openings.add(
      ScanOpening(
        kind: ScanOpeningKind.passage,
        wall: best,
        center: center,
        width: width,
        sill: 0,
        head: heightM,
        confidence: 0.5,
      ),
    );
  }
  return out;
}

enum _Cell { solid, door, window }

/// Puertas y ventanas de una pared por su perfil vertical: en cada trozo de
/// 5 cm, a qué alturas hay pared.
List<ScanOpening> _openingsOf(
  int index,
  ScanWall w,
  ScanProfile p,
  List<double> rel,
  double step,
  double heightM,
) {
  final ks = [
    for (var k = 0; k < rel.length; k++)
      if (rel[k] > 0.1 && rel[k] < heightM - 0.04) k,
  ];
  if (ks.length < 4) return const [];
  final cov = {for (final k in ks) k: _coverage(w, p.slices[k])};
  final n = _bins(w);

  bool filled(int k, int b) => cov[k]![b];
  final cls = List<_Cell>.filled(n, _Cell.solid);
  final lowHigh = List<(double?, double?)>.filled(n, (null, null));
  for (var b = 0; b < n; b++) {
    final low = [
      for (final k in ks)
        if (rel[k] <= 1.0) k,
    ];
    final mid = [
      for (final k in ks)
        if (rel[k] >= 1.1 && rel[k] <= 1.6) k,
    ];
    final doorBand = [
      for (final k in ks)
        if (rel[k] <= 1.7) k,
    ];
    final above = [
      for (final k in ks)
        if (rel[k] >= 1.85) k,
    ];
    final emptyDoor =
        doorBand.where((k) => !filled(k, b)).length >= 0.85 * doorBand.length;
    final hasAbove = above.any((k) => filled(k, b));
    final anyLow = low.any((k) => filled(k, b));
    final midEmpty = mid.isNotEmpty && mid.every((k) => !filled(k, b));
    if (emptyDoor && hasAbove) {
      cls[b] = _Cell.door;
      double? head;
      for (final k in above) {
        if (filled(k, b)) {
          head = rel[k] - step / 2;
          break;
        }
      }
      lowHigh[b] = (0, head);
    } else if (anyLow && midEmpty) {
      cls[b] = _Cell.window;
      double? sill, head;
      for (final k in ks) {
        if (rel[k] <= 1.1 && filled(k, b)) sill = rel[k] + step / 2;
      }
      for (final k in ks) {
        if (rel[k] >= 1.6 && filled(k, b)) {
          head = rel[k] - step / 2;
          break;
        }
      }
      lowHigh[b] = (sill, head);
    }
  }
  // Un trozo suelto distinto entre dos iguales es ruido.
  for (var b = 1; b + 1 < n; b++) {
    if (cls[b - 1] == cls[b + 1] && cls[b] != cls[b - 1]) cls[b] = cls[b - 1];
  }

  double median(List<double> v, double fallback) {
    if (v.isEmpty) return fallback;
    v.sort();
    return v[v.length ~/ 2];
  }

  final out = <ScanOpening>[];
  var b = 0;
  while (b < n) {
    final c = cls[b];
    var e = b;
    while (e + 1 < n && cls[e + 1] == c) {
      e++;
    }
    final width = (e - b + 1) * _binM;
    if (c != _Cell.solid) {
      final isDoor = c == _Cell.door;
      final ok = isDoor
          ? width >= 0.55 && width <= 2.4
          : width >= 0.3 && width <= 4;
      // Un hueco que toca el extremo de la pared puede ser solo un trozo sin
      // escanear: menos confianza.
      final atEnd = b == 0 || e == n - 1;
      if (ok) {
        final sills = <double>[], heads = <double>[];
        for (var i = b; i <= e; i++) {
          final (s, h) = lowHigh[i];
          if (s != null) sills.add(s);
          if (h != null) heads.add(h);
        }
        final sill = isDoor ? 0.0 : median(sills, 0.9);
        final head = math.min(
          heightM,
          median(heads, isDoor ? math.min(2.1, heightM) : heightM),
        );
        if (head - sill >= 0.3) {
          final t = w.tOf(w.start) + (b + e + 1) / 2 * _binM;
          out.add(
            ScanOpening(
              kind: isDoor ? ScanOpeningKind.door : ScanOpeningKind.window,
              wall: index,
              center: w.normal * w.offset + w.dir * t,
              width: width,
              sill: sill,
              head: head,
              confidence: atEnd ? 0.45 : 0.75,
            ),
          );
        }
      }
    }
    b = e + 1;
  }
  return out;
}

/// Fuera los huecos tapados por un mueble alto delante: detrás de un
/// armario la pared no se ve, pero no hay puerta.
List<ScanOpening> _dropOccluded(
  List<ScanOpening> openings,
  List<ScanWall> walls,
  ScanGrid? grid,
  double floorY,
) {
  if (grid == null) return openings;
  return [
    for (final o in openings)
      if (o.kind == ScanOpeningKind.passage ||
          !_occluded(o, walls[o.wall], grid, floorY))
        o,
  ];
}

bool _occluded(ScanOpening o, ScanWall w, ScanGrid grid, double floorY) {
  final limit = o.kind == ScanOpeningKind.door ? 1.2 : o.sill + 0.4;
  for (final side in [1.0, -1.0]) {
    var hits = 0, total = 0;
    for (var a = -0.4; a <= 0.4001; a += 0.1) {
      for (var d = 0.2; d <= 0.8001; d += 0.15) {
        final q =
            o.center +
            w.dir * (a * o.width) +
            w.normal * (side * (w.thickness / 2 + d));
        total++;
        final top = grid.atPoint(q);
        if (top != null && top - floorY >= limit) hits++;
      }
    }
    if (hits >= total * 0.5) return true;
  }
  return false;
}

/// Lo que asoma del suelo y no es pared, agrupado en cajas.
List<ScanObject> _objects(
  ScanGrid g,
  List<ScanWall> walls,
  double floorY,
  double heightM,
  double axis,
) {
  if (walls.isEmpty) return const [];
  var minX = double.infinity, minY = double.infinity;
  var maxX = -double.infinity, maxY = -double.infinity;
  for (final w in walls) {
    for (final q in [w.start, w.end]) {
      minX = math.min(minX, q.dx);
      minY = math.min(minY, q.dy);
      maxX = math.max(maxX, q.dx);
      maxY = math.max(maxY, q.dy);
    }
  }
  bool nearWall(Offset q) {
    for (final w in walls) {
      final t = w.tOf(q);
      if (t < w.tOf(w.start) - 0.1 || t > w.tOf(w.end) + 0.1) continue;
      if ((_dot(q, w.normal) - w.offset).abs() <= w.thickness / 2 + 0.12) {
        return true;
      }
    }
    return false;
  }

  final mask = List<bool>.filled(g.cols * g.rows, false);
  for (var j = 0; j < g.rows; j++) {
    for (var i = 0; i < g.cols; i++) {
      final top = g.at(i, j);
      if (top == null) continue;
      final h = top - floorY;
      if (h < 0.12 || h > heightM - 0.15) continue;
      final c = g.center(i, j);
      if (c.dx < minX || c.dx > maxX || c.dy < minY || c.dy > maxY) continue;
      if (nearWall(c)) continue;
      mask[j * g.cols + i] = true;
    }
  }

  final seen = List<bool>.filled(mask.length, false);
  final d = Offset(math.cos(axis), math.sin(axis));
  final nrm = Offset(-d.dy, d.dx);
  final out = <ScanObject>[];
  for (var start = 0; start < mask.length; start++) {
    if (!mask[start] || seen[start]) continue;
    final cells = <int>[];
    final stack = [start];
    seen[start] = true;
    while (stack.isNotEmpty) {
      final k = stack.removeLast();
      cells.add(k);
      final i = k % g.cols, j = k ~/ g.cols;
      for (var dj = -1; dj <= 1; dj++) {
        for (var di = -1; di <= 1; di++) {
          final ni = i + di, nj = j + dj;
          if (ni < 0 || nj < 0 || ni >= g.cols || nj >= g.rows) continue;
          final nk = nj * g.cols + ni;
          if (mask[nk] && !seen[nk]) {
            seen[nk] = true;
            stack.add(nk);
          }
        }
      }
    }
    final area = cells.length * g.cell * g.cell;
    if (area < 0.12) continue;
    var u0 = double.infinity, u1 = -double.infinity;
    var v0 = double.infinity, v1 = -double.infinity;
    final tops = <double>[];
    for (final k in cells) {
      final c = g.center(k % g.cols, k ~/ g.cols);
      final u = _dot(c, d), v = _dot(c, nrm);
      u0 = math.min(u0, u);
      u1 = math.max(u1, u);
      v0 = math.min(v0, v);
      v1 = math.max(v1, v);
      tops.add(g.top[k]! - floorY);
    }
    tops.sort();
    final width = u1 - u0 + g.cell, depth = v1 - v0 + g.cell;
    final fill = area / (width * depth);
    out.add(
      ScanObject(
        center: d * ((u0 + u1) / 2) + nrm * ((v0 + v1) / 2),
        width: width,
        depth: depth,
        rotationDeg: axis * 180 / math.pi,
        heightM: tops[(tops.length * 0.9).floor().clamp(0, tops.length - 1)],
        confidence: (0.3 + 0.6 * fill).clamp(0, 0.9).toDouble(),
      ),
    );
  }
  out.sort((a, b) => (b.width * b.depth).compareTo(a.width * a.depth));
  return out;
}
