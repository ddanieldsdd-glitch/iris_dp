import 'dart:math' as math;
import 'dart:ui';

import 'scan_capture.dart';
import 'scan_structure.dart';

/// Lo que se saca de una captura sin malla: la estructura para revisar y las
/// paredes vistas, de fondo.
typedef DirectPlan = ({ScanStructure structure, List<(Offset, Offset)> cut});

/// Altura y extremos horizontales de un plano vertical. ARKit deja el ancho
/// en la x del ancla, pero se comprueba: un plano tumbado saldría sin ancho.
({Offset a, Offset b, double bottom, double top}) _verticalSpan(
  CapturePlane plane,
) {
  final cx = plane.center[0], cy = plane.center[1], cz = plane.center[2];
  final hx = plane.extent[0] / 2, hz = plane.extent[1] / 2;
  final x0 = plane.toWorld(cx - hx, cy, cz),
      x1 = plane.toWorld(cx + hx, cy, cz);
  final z0 = plane.toWorld(cx, cy, cz - hz),
      z1 = plane.toWorld(cx, cy, cz + hz);
  final xIsWide = (x1[1] - x0[1]).abs() <= (z1[1] - z0[1]).abs();
  final wide = xIsWide ? (x0, x1) : (z0, z1);
  final tall = xIsWide ? (z0, z1) : (x0, x1);
  return (
    a: Offset(wide.$1[0], wide.$1[2]),
    b: Offset(wide.$2[0], wide.$2[2]),
    bottom: math.min(tall.$1[1], tall.$2[1]),
    top: math.max(tall.$1[1], tall.$2[1]),
  );
}

double _planeY(CapturePlane plane) =>
    plane.toWorld(plane.center[0], plane.center[1], plane.center[2])[1];

double? _floorOf(CapturePackage c, CaptureHints hints) {
  if (hints.floorY != null) return hints.floorY;
  final floors = c.planes.where(
    (p) => !p.vertical && p.classification == 'floor',
  );
  if (floors.isNotEmpty) {
    return floors.map(_planeY).reduce(math.min);
  }
  // Sin nada clasificado: el plano horizontal grande más bajo.
  final big = c.planes.where(
    (p) => !p.vertical && p.extent[0] * p.extent[1] >= 1,
  );
  if (big.isNotEmpty) return big.map(_planeY).reduce(math.min);
  if (c.points.length >= 90) {
    final ys = [for (var i = 1; i < c.points.length; i += 3) c.points[i]]
      ..sort();
    return ys[(ys.length * 0.03).floor()];
  }
  final bottoms = [
    for (final p in c.planes.where((p) => p.isWall)) _verticalSpan(p).bottom,
  ];
  return bottoms.isEmpty ? null : bottoms.reduce(math.min);
}

double? _ceilingOf(CapturePackage c, CaptureHints hints) {
  if (c.exterior) return null;
  if (hints.ceilingY != null) return hints.ceilingY;
  final ceilings = c.planes.where(
    (p) => !p.vertical && p.classification == 'ceiling',
  );
  return ceilings.isEmpty ? null : ceilings.map(_planeY).reduce(math.max);
}

bool _crosses((Offset, Offset) s, (Offset, Offset) t) {
  double side(Offset a, Offset b, Offset p) =>
      (b.dx - a.dx) * (p.dy - a.dy) - (b.dy - a.dy) * (p.dx - a.dx);
  return side(s.$1, s.$2, t.$1) * side(s.$1, s.$2, t.$2) < 0 &&
      side(t.$1, t.$2, s.$1) * side(t.$1, t.$2, s.$2) < 0;
}

/// El contorno que dibujan las esquinas tocadas, en el orden en que se
/// tocaron; si ese orden se cruza consigo mismo, alrededor de su centro.
List<(Offset, Offset)> _cornerChords(List<Offset> corners) {
  if (corners.length < 3) return const [];
  List<(Offset, Offset)> ring(List<Offset> pts) => [
    for (var i = 0; i < pts.length; i++) (pts[i], pts[(i + 1) % pts.length]),
  ];
  var edges = ring(corners);
  var tangled = false;
  for (var i = 0; i < edges.length && !tangled; i++) {
    for (var j = i + 2; j < edges.length; j++) {
      if (i == 0 && j == edges.length - 1) continue;
      if (_crosses(edges[i], edges[j])) {
        tangled = true;
        break;
      }
    }
  }
  if (tangled) {
    var c = Offset.zero;
    for (final p in corners) {
      c += p;
    }
    c = c / corners.length.toDouble();
    final sorted = [...corners]
      ..sort((a, b) => (a - c).direction.compareTo((b - c).direction));
    edges = ring(sorted);
  }
  return edges;
}

/// Si ya hay una pared vista a lo largo de ese tramo.
bool _alreadySeen((Offset, Offset) chord, List<(Offset, Offset)> seen) {
  final len = (chord.$2 - chord.$1).distance;
  if (len < 1e-3) return true;
  final d = (chord.$2 - chord.$1) / len;
  final n = Offset(-d.dy, d.dx);
  double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
  var covered = 0.0;
  for (final (a, b) in seen) {
    final l = (b - a).distance;
    if (l < 1e-3 || dot((b - a) / l, d).abs() < 0.97) continue;
    if (dot((a + b) / 2 - chord.$1, n).abs() > 0.25) continue;
    final ta = dot(a - chord.$1, d), tb = dot(b - chord.$1, d);
    covered += math.max(
      0,
      math.min(len, math.max(ta, tb)) - math.max(0, math.min(ta, tb)),
    );
  }
  return covered >= len * 0.5;
}

/// La pared más cercana a [p], y el punto de ella que le corresponde.
(int, Offset)? _nearestWall(List<ScanWall> walls, Offset p, double within) {
  (int, Offset)? best;
  var bestD = within;
  for (var i = 0; i < walls.length; i++) {
    final w = walls[i];
    final d = w.dir;
    final t = (((p - w.start).dx * d.dx + (p - w.start).dy * d.dy))
        .clamp(0.0, w.length)
        .toDouble();
    final q = w.start + d * t;
    final gap = (q - p).distance;
    if (gap < bestD) {
      bestD = gap;
      best = (i, q);
    }
  }
  return best;
}

List<ScanOpening> _openingsFromCapture(
  CapturePackage c,
  List<ScanWall> walls,
  double floorY,
  double heightM,
) {
  final out = <ScanOpening>[];
  double headOfDoor() => math.min(2.05, heightM);

  void place(
    ScanOpeningKind kind,
    Offset at,
    double width,
    double sill,
    double head,
    double confidence,
  ) {
    final hit = _nearestWall(walls, at, 0.5);
    if (hit == null) return;
    out.add(
      ScanOpening(
        kind: kind,
        wall: hit.$1,
        center: hit.$2,
        width: width,
        sill: sill,
        head: head,
        confidence: confidence,
      ),
    );
  }

  // Los dos bordes de cada hueco se tocan seguidos. Un toque suelto se queda
  // con la medida de serie y sale como dudoso.
  void fromMarks(String kind, double minW, double maxW) {
    final marks = c.marks.where((m) => m.kind == kind).toList();
    final isDoor = kind == 'door';
    var i = 0;
    while (i < marks.length) {
      final a = marks[i].position;
      final pa = Offset(a[0], a[2]);
      final b = i + 1 < marks.length ? marks[i + 1].position : null;
      final pb = b == null ? null : Offset(b[0], b[2]);
      final width = pb == null ? 0.0 : (pb - pa).distance;
      final paired = pb != null && width >= minW && width <= maxW;
      var sill = isDoor ? 0.0 : 0.9;
      var head = isDoor ? headOfDoor() : math.min(2.1, heightM);
      if (paired && !isDoor && (b![1] - a[1]).abs() > 0.4) {
        sill = math.max(0, math.min(a[1], b[1]) - floorY);
        head = math.min(heightM, math.max(a[1], b[1]) - floorY);
      }
      place(
        isDoor ? ScanOpeningKind.door : ScanOpeningKind.window,
        paired ? (pa + pb) / 2 : pa,
        paired ? width : (isDoor ? 0.8 : 1.0),
        sill,
        head,
        paired ? 0.85 : 0.5,
      );
      i += paired ? 2 : 1;
    }
  }

  fromMarks('door', 0.5, 2.5);
  fromMarks('window', 0.3, 4);

  // Lo que ARKit clasificó como puerta o ventana, si no se ha tocado ya.
  for (final plane in c.planes.where(
    (p) =>
        p.vertical &&
        (p.classification == 'door' || p.classification == 'window'),
  )) {
    final span = _verticalSpan(plane);
    final center = (span.a + span.b) / 2;
    if (out.any((o) => (o.center - center).distance < 0.5)) continue;
    final isDoor = plane.classification == 'door';
    place(
      isDoor ? ScanOpeningKind.door : ScanOpeningKind.window,
      center,
      (span.b - span.a).distance,
      isDoor ? 0 : math.max(0, span.bottom - floorY),
      isDoor ? headOfDoor() : math.min(heightM, span.top - floorY),
      0.6,
    );
  }
  return out;
}

List<ScanObject> _objectsFromCapture(CapturePackage c, double floorY) => [
  for (final plane in c.planes.where(
    (p) =>
        !p.vertical &&
        (p.classification == 'table' || p.classification == 'seat') &&
        math.min(p.extent[0], p.extent[1]) >= 0.3,
  ))
    ScanObject(
      center: () {
        final w = plane.toWorld(
          plane.center[0],
          plane.center[1],
          plane.center[2],
        );
        return Offset(w[0], w[2]);
      }(),
      width: plane.extent[0],
      depth: plane.extent[1],
      rotationDeg:
          math.atan2(plane.transform[2], plane.transform[0]) * 180 / math.pi,
      heightM: _planeY(plane) - floorY,
      confidence: 0.5,
    ),
];

/// La planta sin PC y sin LiDAR (ES.A): paredes, huecos y mesas a partir de
/// los planos y los toques de la captura, en el mismo iPhone o iPad.
///
/// Reutiliza el solucionador con un perfil hecho de los planos de ARKit. Sin
/// malla no hay perfil vertical real: los huecos que mandan son los tocados
/// o los que ARKit clasificó, nunca un trozo de pared que no se llegó a ver.
///
/// El mundo de ARKit ya es la planta: x igual, y arriba, z hacia el «abajo»
/// del lienzo. `null` si la captura no da ninguna pared.
DirectPlan? solveCaptureDirect(CapturePackage c) {
  final raw = c.hintsFrom(c.hintPoints());
  final floorY = _floorOf(c, raw);
  if (floorY == null) return null;
  final ceilingY = _ceilingOf(c, raw);

  // Solo lo que cruza la franja de 1 a 1,7 m es pared; lo más bajo es el
  // costado de un mueble. ARKit rara vez ve una pared entera de alto: la que
  // pasa se da por entera.
  final seen = <(Offset, Offset)>[];
  var highest = floorY + 2.5;
  for (final plane in c.planes.where((p) => p.isWall)) {
    final span = _verticalSpan(plane);
    if ((span.b - span.a).distance < 0.4) continue;
    if (span.top < floorY + 1.3 || span.bottom > floorY + 1.4) continue;
    seen.add((span.a, span.b));
    highest = math.max(highest, span.top);
  }
  // Las esquinas tocadas mandan: dan la pared entera, y ARKit casi nunca ve
  // una de punta a punta. Los planos solo añaden lo que no se tocó.
  final chords = [
    for (final chord in _cornerChords(raw.corners))
      if ((chord.$2 - chord.$1).distance >= 0.5) chord,
  ];
  final segments = [
    ...chords,
    ...seen.where((plane) => !_alreadySeen(plane, chords)),
  ];
  if (segments.isEmpty) return null;

  final top = ceilingY ?? highest;
  final heights = <double>[for (var h = floorY + 0.075; h < top; h += 0.15) h];
  final solved = solveStructure(
    ScanProfile(
      bin: 0.05,
      y0: floorY,
      up: const [],
      down: const [],
      heights: heights,
      slices: [for (final _ in heights) segments],
    ),
    capture: CaptureHints(
      // Solo las que han pasado el filtro: el resto crearía paredes.
      wallPlanes: seen,
      corners: raw.corners,
      floorY: floorY,
      ceilingY: ceilingY,
      storefronts: raw.storefronts,
      lights: raw.lights,
      exterior: raw.exterior,
    ),
  );
  if (solved.walls.isEmpty) return null;
  return (
    structure: ScanStructure(
      floorY: solved.floorY,
      heightM: solved.heightM,
      heightEstimated: solved.heightEstimated,
      axisDeg: solved.axisDeg,
      walls: solved.walls,
      openings: [
        // Los escaparates salen de sus toques.
        ...solved.openings.where((o) => o.kind == ScanOpeningKind.storefront),
        ..._openingsFromCapture(c, solved.walls, solved.floorY, solved.heightM),
      ],
      objects: _objectsFromCapture(c, solved.floorY),
      lights: solved.lights,
      exterior: solved.exterior,
    ),
    cut: segments,
  );
}

/// [s] desplazada [delta] metros en la planta.
ScanStructure movedStructure(ScanStructure s, Offset delta) => ScanStructure(
  floorY: s.floorY,
  heightM: s.heightM,
  heightEstimated: s.heightEstimated,
  axisDeg: s.axisDeg,
  walls: [
    for (final w in s.walls)
      ScanWall(
        w.start + delta,
        w.end + delta,
        thickness: w.thickness,
        thicknessEstimated: w.thicknessEstimated,
        confidence: w.confidence,
        source: w.source,
      ),
  ],
  openings: [
    for (final o in s.openings)
      ScanOpening(
        kind: o.kind,
        wall: o.wall,
        center: o.center + delta,
        width: o.width,
        sill: o.sill,
        head: o.head,
        confidence: o.confidence,
      ),
  ],
  objects: [
    for (final o in s.objects)
      ScanObject(
        center: o.center + delta,
        width: o.width,
        depth: o.depth,
        rotationDeg: o.rotationDeg,
        heightM: o.heightM,
        confidence: o.confidence,
      ),
  ],
  lights: [
    for (final l in s.lights) ScanLight(l.position + delta, l.y, l.label),
  ],
  exterior: s.exterior,
);
