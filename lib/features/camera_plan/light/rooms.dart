import 'dart:math' as math;
import 'dart:ui';

/// Un recinto: el suelo que encierran unas paredes que se cierran sobre sí
/// mismas.
class PlanRoom {
  /// Contorno, en unidades del lienzo.
  final List<Offset> polygon;

  const PlanRoom(this.polygon);

  /// Superficie en unidades del lienzo al cuadrado.
  double get area {
    var sum = 0.0;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      sum += a.dx * b.dy - b.dx * a.dy;
    }
    return sum.abs() / 2;
  }

  Offset get centroid {
    var x = 0.0;
    var y = 0.0;
    for (final p in polygon) {
      x += p.dx;
      y += p.dy;
    }
    return Offset(x / polygon.length, y / polygon.length);
  }

  /// Un punto que seguro cae dentro, aunque el recinto tenga forma de L.
  Offset get interiorPoint {
    final c = centroid;
    if (contains(c)) return c;
    for (var i = 0; i < polygon.length; i++) {
      final a = polygon[i];
      final b = polygon[(i + 1) % polygon.length];
      final mid = (a + b) / 2;
      final span = b - a;
      if (span.distance < 1e-6) continue;
      final normal = Offset(-span.dy, span.dx) / span.distance;
      for (final side in const [6.0, -6.0]) {
        final p = mid + normal * side;
        if (contains(p)) return p;
      }
    }
    return c;
  }

  bool contains(Offset p) {
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  Path get path => Path()..addPolygon(polygon, true);
}

/// Encuentra los recintos que cierran las paredes de una planta.
class PlanRooms {
  /// Dos extremos a menos de esto se dan por unidos (20 cm a la escala de
  /// partida).
  static const double joinTolerance = 10;

  /// Recintos que forman los tramos [walls]. Los extremos casi juntos se
  /// unen, los tramos que se cruzan se parten, y lo que queda suelto no
  /// cierra nada. No cuenta lo menor que [minArea].
  static List<PlanRoom> detect(
    List<(Offset, Offset)> walls, {
    double tolerance = joinTolerance,
    double minArea = 2500,
  }) {
    final segments = [
      for (final (a, b) in walls)
        if ((b - a).distance > 1e-6) (a, b),
    ];
    if (segments.length < 3) return const [];

    // Dónde hay que partir cada tramo: en sus cruces con otros y donde el
    // extremo de otro lo toca.
    final cuts = [
      for (final _ in segments) <double>[0, 1],
    ];
    for (var i = 0; i < segments.length; i++) {
      final (a, b) = segments[i];
      final ab = b - a;
      final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
      for (var j = 0; j < segments.length; j++) {
        if (i == j) continue;
        final (c, d) = segments[j];
        for (final end in [c, d]) {
          final t = ((end.dx - a.dx) * ab.dx + (end.dy - a.dy) * ab.dy) / len2;
          if (t <= 0 || t >= 1) continue;
          if ((a + ab * t - end).distance <= tolerance) cuts[i].add(t);
        }
        if (j < i) continue;
        final cd = d - c;
        final denom = ab.dx * cd.dy - ab.dy * cd.dx;
        if (denom.abs() < 1e-9) continue;
        final ac = c - a;
        final t = (ac.dx * cd.dy - ac.dy * cd.dx) / denom;
        final u = (ac.dx * ab.dy - ac.dy * ab.dx) / denom;
        if (t > 0 && t < 1 && u > 0 && u < 1) {
          cuts[i].add(t);
          cuts[j].add(u);
        }
      }
    }

    // Nudos: los puntos casi juntos son el mismo.
    final nodes = <Offset>[];
    int nodeFor(Offset p) {
      for (var i = 0; i < nodes.length; i++) {
        if ((nodes[i] - p).distance <= tolerance) return i;
      }
      nodes.add(p);
      return nodes.length - 1;
    }

    final links = <int, Set<int>>{};
    for (var i = 0; i < segments.length; i++) {
      final (a, b) = segments[i];
      final ts = cuts[i]..sort();
      var from = nodeFor(a);
      for (final t in ts.skip(1)) {
        final to = nodeFor(a + (b - a) * t);
        if (to != from) {
          links.putIfAbsent(from, () => {}).add(to);
          links.putIfAbsent(to, () => {}).add(from);
        }
        from = to;
      }
    }

    // Lo que acaba en punta no encierra nada.
    var pruned = true;
    while (pruned) {
      pruned = false;
      for (final node in links.keys.toList()) {
        final around = links[node]!;
        if (around.length != 1) continue;
        links[around.first]!.remove(node);
        links.remove(node);
        pruned = true;
      }
      links.removeWhere((_, around) => around.isEmpty);
    }
    if (links.isEmpty) return const [];

    // Vecinos de cada nudo, ordenados por ángulo.
    final ordered = <int, List<int>>{};
    double angle(int from, int to) {
      final d = nodes[to] - nodes[from];
      return math.atan2(d.dy, d.dx);
    }

    for (final entry in links.entries) {
      ordered[entry.key] = entry.value.toList()
        ..sort((x, y) => angle(entry.key, x).compareTo(angle(entry.key, y)));
    }

    // Se recorre cada cara girando siempre hacia el mismo lado. Las caras
    // cerradas salen con un signo de área y la de fuera con el contrario.
    final seen = <(int, int)>{};
    final rooms = <PlanRoom>[];
    for (final start in ordered.keys) {
      for (final next in ordered[start]!) {
        if (seen.contains((start, next))) continue;
        final loop = <int>[];
        var u = start;
        var v = next;
        var guard = 0;
        while (seen.add((u, v)) && guard++ < 10000) {
          loop.add(u);
          final around = ordered[v]!;
          final w = around[(around.indexOf(u) + 1) % around.length];
          u = v;
          v = w;
        }
        if (loop.length < 3) continue;
        var signed = 0.0;
        for (var i = 0; i < loop.length; i++) {
          final a = nodes[loop[i]];
          final b = nodes[loop[(i + 1) % loop.length]];
          signed += a.dx * b.dy - b.dx * a.dy;
        }
        if (signed / 2 < -minArea) {
          rooms.add(PlanRoom([for (final n in loop) nodes[n]]));
        }
      }
    }
    return rooms;
  }
}
