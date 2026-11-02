import 'dart:math' as math;
import 'dart:ui';

/// Una pared propuesta a partir del corte de un escaneo, en metros de la
/// planta.
class WallProposal {
  final Offset start;
  final Offset end;

  /// Grosor si se han visto las dos caras de la pared; 0 si solo una.
  final double thickness;

  const WallProposal(this.start, this.end, {this.thickness = 0});

  double get length => (end - start).distance;
}

/// Tramos de un corte: `[x1, y1, x2, y2, …]` en metros.
List<(Offset, Offset)> sliceSegments(List<num> flat) => [
  for (var i = 0; i + 3 < flat.length; i += 4)
    (
      Offset(flat[i].toDouble(), flat[i + 1].toDouble()),
      Offset(flat[i + 2].toDouble(), flat[i + 3].toDouble()),
    ),
];

/// Paredes a partir del corte horizontal de un escaneo (F6.20 E4).
///
/// 1. Las direcciones dominantes: histograma de ángulos pesado por longitud;
///    en una casa suelen ser dos, a 90°.
/// 2. Para cada dirección, los tramos alineados se agrupan por su distancia
///    a una recta (a menos de [offsetTol]) y se unen a lo largo si los
///    separa menos de [gap]: un hueco mayor, como una puerta, parte la
///    pared.
/// 3. Dos líneas paralelas a menos de [pairMax] que se solapan son las dos
///    caras de una pared: queda la del medio, con su grosor.
/// 4. Fuera lo que mide menos de [minLength] (muebles, marcos).
List<WallProposal> proposeWalls(
  List<(Offset, Offset)> segments, {
  double minLength = 0.6,
  double offsetTol = 0.06,
  double gap = 0.25,
  double angleTolDeg = 8,
  double pairMax = 0.35,
}) {
  final segs = [
    for (final s in segments)
      if ((s.$2 - s.$1).distance > 1e-3) s,
  ];
  if (segs.isEmpty) return const [];

  double angleOf((Offset, Offset) s) {
    final d = s.$2 - s.$1;
    final a = math.atan2(d.dy, d.dx) * 180 / math.pi;
    return (a % 180 + 180) % 180;
  }

  double circDiff(double a, double b) {
    final d = (a - b).abs() % 180;
    return math.min(d, 180 - d);
  }

  // 1 · Direcciones dominantes.
  final hist = List<double>.filled(180, 0);
  for (final s in segs) {
    hist[angleOf(s).round() % 180] += (s.$2 - s.$1).distance;
  }
  final smooth = List<double>.generate(180, (i) {
    var sum = 0.0;
    for (var k = -2; k <= 2; k++) {
      sum += hist[(i + k + 180) % 180];
    }
    return sum;
  });
  final peaks = <double>[];
  final work = [...smooth];
  double? first;
  while (peaks.length < 6) {
    var best = 0;
    for (var i = 1; i < 180; i++) {
      if (work[i] > work[best]) best = i;
    }
    if (work[best] <= 0) break;
    first ??= work[best];
    if (work[best] < first * 0.1) break;
    peaks.add(best.toDouble());
    for (var k = -15; k <= 15; k++) {
      work[(best + k + 180) % 180] = 0;
    }
  }

  // Un trozo corto con ruido se tuerce mucho: más margen para él.
  double tolOf((Offset, Offset) s) =>
      (s.$2 - s.$1).distance < 0.2 ? math.max(angleTolDeg, 20) : angleTolDeg;

  // El histograma va de grado en grado: cada pico se afina con la media de
  // sus tramos (en ángulo doble, para que 179° y 1° sean vecinos).
  for (var k = 0; k < peaks.length; k++) {
    var cx = 0.0, cy = 0.0;
    for (final s in segs) {
      final a = angleOf(s);
      if (circDiff(a, peaks[k]) > tolOf(s)) continue;
      final len = (s.$2 - s.$1).distance;
      cx += math.cos(2 * a * math.pi / 180) * len;
      cy += math.sin(2 * a * math.pi / 180) * len;
    }
    if (cx != 0 || cy != 0) {
      peaks[k] = (math.atan2(cy, cx) * 90 / math.pi % 180 + 180) % 180;
    }
  }

  // 2 · Líneas por dirección.
  final lines = <_Line>[];
  for (final peak in peaks) {
    final rad = peak * math.pi / 180;
    final d = Offset(math.cos(rad), math.sin(rad));
    final n = Offset(-d.dy, d.dx);
    double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
    final items = <(double, (Offset, Offset))>[];
    for (final s in segs) {
      if (circDiff(angleOf(s), peak) > tolOf(s)) continue;
      items.add((dot((s.$1 + s.$2) / 2, n), s));
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));
    var i = 0;
    while (i < items.length) {
      var j = i + 1;
      while (j < items.length && items[j].$1 - items[j - 1].$1 <= offsetTol) {
        j++;
      }
      final group = [for (final it in items.sublist(i, j)) it.$2];
      i = j;
      // Recta de mínimos cuadrados con los extremos de sus tramos, pesados
      // por longitud: más fina que el ángulo del histograma.
      var w = 0.0;
      var c = Offset.zero;
      for (final s in group) {
        final len = (s.$2 - s.$1).distance;
        w += len;
        c += (s.$1 + s.$2) * (len / 2);
      }
      c = c / w;
      var sxx = 0.0, sxy = 0.0, syy = 0.0;
      for (final s in group) {
        final len = (s.$2 - s.$1).distance / 2;
        for (final q in [s.$1 - c, s.$2 - c]) {
          sxx += q.dx * q.dx * len;
          sxy += q.dx * q.dy * len;
          syy += q.dy * q.dy * len;
        }
      }
      final theta = 0.5 * math.atan2(2 * sxy, sxx - syy);
      var gd = Offset(math.cos(theta), math.sin(theta));
      if (dot(gd, d) < 0) gd = -gd;
      // Si la recta se aparta mucho del pico (un grupo corto y redondo), se
      // queda la dirección del pico.
      if (dot(gd, d).abs() < math.cos(angleTolDeg * math.pi / 180)) gd = d;
      final gn = Offset(-gd.dy, gd.dx);
      final offset = dot(c, gn);
      final spans = [
        for (final s in group)
          (
            math.min(dot(s.$1, gd), dot(s.$2, gd)),
            math.max(dot(s.$1, gd), dot(s.$2, gd)),
          ),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      var (s0, s1) = spans.first;
      void flush() {
        if (s1 - s0 >= minLength * 0.5) {
          lines.add(_Line(gd, gn, offset, s0, s1));
        }
      }

      for (final sp in spans.skip(1)) {
        if (sp.$1 - s1 <= gap) {
          s1 = math.max(s1, sp.$2);
        } else {
          flush();
          (s0, s1) = sp;
        }
      }
      flush();
    }
  }

  // 3 · Dos caras de la misma pared.
  double dot(Offset a, Offset b) => a.dx * b.dx + a.dy * b.dy;
  final parallel = math.cos(3 * math.pi / 180);
  lines.sort((a, b) => (b.t1 - b.t0).compareTo(a.t1 - a.t0));
  final used = List<bool>.filled(lines.length, false);
  final out = <WallProposal>[];
  for (var i = 0; i < lines.length; i++) {
    if (used[i]) continue;
    var line = lines[i];
    var thickness = 0.0;
    for (var j = i + 1; j < lines.length; j++) {
      final other = lines[j];
      if (used[j] || dot(other.d, line.d).abs() < parallel) continue;
      final a = other.point(other.t0), b = other.point(other.t1);
      final dist = dot((a + b) / 2, line.n) - line.offset;
      if (dist.abs() <= offsetTol || dist.abs() > pairMax) continue;
      final ta = dot(a, line.d), tb = dot(b, line.d);
      final o0 = math.min(ta, tb), o1 = math.max(ta, tb);
      final overlap = math.min(line.t1, o1) - math.max(line.t0, o0);
      final shorter = math.min(line.t1 - line.t0, o1 - o0);
      if (overlap < shorter * 0.5) continue;
      used[j] = true;
      thickness = dist.abs();
      line = _Line(
        line.d,
        line.n,
        line.offset + dist / 2,
        math.min(line.t0, o0),
        math.max(line.t1, o1),
      );
      break;
    }
    if (line.t1 - line.t0 < minLength) continue;
    out.add(
      WallProposal(
        line.point(line.t0),
        line.point(line.t1),
        thickness: thickness,
      ),
    );
  }
  out.sort((a, b) => b.length.compareTo(a.length));
  return out;
}

class _Line {
  final Offset d, n;
  final double offset, t0, t1;
  const _Line(this.d, this.n, this.offset, this.t0, this.t1);

  Offset point(double t) => n * offset + d * t;
}
