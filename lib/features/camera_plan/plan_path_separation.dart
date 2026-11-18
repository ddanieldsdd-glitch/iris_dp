import 'dart:math' as math;
import 'dart:ui' show Offset;

/// Un tramo de un recorrido: de [a] a [b].
typedef PathSpan = ({Offset a, Offset b});

/// Separa los tramos de recorridos distintos que van casi por el mismo
/// sitio (paralelos, cerca y solapados) en carriles a [lane] uno de otro,
/// para que en papel se vean todos. Lo demás queda igual.
///
/// [routes] son los puntos de cada recorrido en la hoja; devuelve sus
/// tramos en el mismo orden, ya separados.
List<List<PathSpan>> separatePaths(
  List<List<Offset>> routes, {
  double near = 7,
  double lane = 4.5,
  double maxAngleDegrees = 15,
}) {
  final spans = <(int route, int index, Offset a, Offset b)>[];
  for (final (r, points) in routes.indexed) {
    for (var i = 0; i < points.length - 1; i++) {
      spans.add((r, i, points[i], points[i + 1]));
    }
  }
  final parent = [for (var i = 0; i < spans.length; i++) i];
  int find(int i) {
    while (parent[i] != i) {
      parent[i] = parent[parent[i]];
      i = parent[i];
    }
    return i;
  }

  final minCos = math.cos(maxAngleDegrees * math.pi / 180);
  bool together(PathSpan s, PathSpan t) {
    final ds = s.b - s.a;
    final dt = t.b - t.a;
    if (ds.distance == 0 || dt.distance == 0) return false;
    final us = ds / ds.distance;
    final ut = dt / dt.distance;
    if ((us.dx * ut.dx + us.dy * ut.dy).abs() < minCos) return false;
    // Lo lejos que va un tramo de la línea del otro, en su parte común.
    final normal = Offset(-us.dy, us.dx);
    double across(Offset p) =>
        ((p - s.a).dx * normal.dx + (p - s.a).dy * normal.dy).abs();
    double along(Offset p) => (p - s.a).dx * us.dx + (p - s.a).dy * us.dy;
    final t0 = along(t.a);
    final t1 = along(t.b);
    final lo = math.max(0.0, math.min(t0, t1));
    final hi = math.min(ds.distance, math.max(t0, t1));
    final shared = hi - lo;
    if (shared < 0.3 * math.min(ds.distance, dt.distance)) return false;
    return across(t.a) < near * 1.6 &&
        across(t.b) < near * 1.6 &&
        across((t.a + t.b) / 2) < near;
  }

  for (var i = 0; i < spans.length; i++) {
    for (var j = i + 1; j < spans.length; j++) {
      if (spans[i].$1 == spans[j].$1) continue;
      if (together(
        (a: spans[i].$3, b: spans[i].$4),
        (a: spans[j].$3, b: spans[j].$4),
      )) {
        parent[find(j)] = find(i);
      }
    }
  }

  final groups = <int, List<int>>{};
  for (var i = 0; i < spans.length; i++) {
    groups.putIfAbsent(find(i), () => []).add(i);
  }
  final shift = List.filled(spans.length, Offset.zero);
  for (final members in groups.values) {
    if (members.length < 2) continue;
    // Una sola normal para todo el grupo, vayan en el sentido que vayan.
    final first = spans[members.first];
    final d = first.$4 - first.$3;
    final normal = Offset(-d.dy, d.dx) / d.distance;
    double side(int k) {
      final mid = (spans[k].$3 + spans[k].$4) / 2;
      return mid.dx * normal.dx + mid.dy * normal.dy;
    }

    // Cada recorrido, un carril; en el orden en que ya estaban.
    final byRoute = <int, double>{};
    for (final k in members) {
      byRoute.update(spans[k].$1, (v) => v + side(k), ifAbsent: () => side(k));
    }
    final order = byRoute.keys.toList()
      ..sort((x, y) => byRoute[x]!.compareTo(byRoute[y]!));
    final n = order.length;
    if (n < 2) continue;
    for (final k in members) {
      final laneIndex = order.indexOf(spans[k].$1);
      shift[k] = normal * ((laneIndex - (n - 1) / 2) * lane);
    }
  }

  final out = [for (final _ in routes) <PathSpan>[]];
  for (final (k, span) in spans.indexed) {
    out[span.$1].add((a: span.$3 + shift[k], b: span.$4 + shift[k]));
  }
  return out;
}
