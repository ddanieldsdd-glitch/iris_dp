import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:image/image.dart' as img;

import '../arch/arch_material.dart';
import 'scan_structure.dart';

/// Una escalera o una rampa que se ve en el escaneo (AM.U3): de dónde
/// arranca a dónde llega (metros de la planta), su ancho y lo que sube.
class ScanStair {
  final Offset from, to;
  final double widthM;
  final double riseM;
  final bool ramp;
  final double confidence;

  const ScanStair({
    required this.from,
    required this.to,
    required this.widthM,
    required this.riseM,
    this.ramp = false,
    this.confidence = 0.6,
  });

  ScanStair moved(Offset d) => ScanStair(
    from: from + d,
    to: to + d,
    widthM: widthM,
    riseM: riseM,
    ramp: ramp,
    confidence: confidence,
  );

  double get runM => (to - from).distance;
}

/// Del escaneo a las piezas del motor arquitectónico (AM.U3): el contorno
/// del recinto para su suelo y su techo, los niveles, las escaleras y las
/// rampas, y el material de cada cara por su color.
abstract final class ScanEngine {
  /// El contorno del recinto, en metros de la planta: las paredes
  /// encadenadas por sus puntas; si no cierran, la envolvente de sus
  /// puntas. `null` con menos de tres puntos.
  static List<Offset>? outline(List<ScanWall> walls, {double joinM = 0.35}) {
    if (walls.length >= 3) {
      final loop = _chain(walls, joinM);
      if (loop != null) return loop;
    }
    final pts = [for (final w in walls) ...[w.start, w.end]];
    if (pts.length < 3) return null;
    final hull = _hull(pts);
    return hull.length >= 3 ? hull : null;
  }

  static List<Offset>? _chain(List<ScanWall> walls, double joinM) {
    final used = List<bool>.filled(walls.length, false);
    final loop = <Offset>[walls.first.start];
    var tip = walls.first.end;
    used[0] = true;
    for (var n = 1; n < walls.length; n++) {
      var best = -1;
      var bestD = joinM;
      var flip = false;
      for (var i = 0; i < walls.length; i++) {
        if (used[i]) continue;
        final ds = (walls[i].start - tip).distance;
        final de = (walls[i].end - tip).distance;
        if (ds < bestD) {
          best = i;
          bestD = ds;
          flip = false;
        }
        if (de < bestD) {
          best = i;
          bestD = de;
          flip = true;
        }
      }
      if (best < 0) return null;
      used[best] = true;
      final w = walls[best];
      // La esquina: donde se cortan las dos rectas, o el punto medio.
      loop.add(Offset.lerp(tip, flip ? w.end : w.start, 0.5)!);
      tip = flip ? w.start : w.end;
    }
    if ((tip - loop.first).distance > joinM) return null;
    loop[0] = Offset.lerp(tip, loop.first, 0.5)!;
    return loop;
  }

  static List<Offset> _hull(List<Offset> pts) {
    final p = [...pts]
      ..sort(
        (a, b) =>
            a.dx != b.dx ? a.dx.compareTo(b.dx) : a.dy.compareTo(b.dy),
      );
    double cross(Offset o, Offset a, Offset b) =>
        (a.dx - o.dx) * (b.dy - o.dy) - (a.dy - o.dy) * (b.dx - o.dx);
    final lower = <Offset>[], upper = <Offset>[];
    for (final q in p) {
      while (lower.length >= 2 &&
          cross(lower[lower.length - 2], lower.last, q) <= 0) {
        lower.removeLast();
      }
      lower.add(q);
    }
    for (final q in p.reversed) {
      while (upper.length >= 2 &&
          cross(upper[upper.length - 2], upper.last, q) <= 0) {
        upper.removeLast();
      }
      upper.add(q);
    }
    return [...lower..removeLast(), ...upper..removeLast()];
  }

  /// Otros suelos del escaneo sobre el de abajo (entreplanta, planta de
  /// arriba), en metros sobre él: alturas con mucha superficie que mira
  /// arriba, a más de [minStoreyM] del suelo y entre sí, y bajo el techo.
  static List<double> floors(
    ScanProfile p,
    double floorY, {
    double? ceilingM,
    double minAreaM2 = 3,
    double minStoreyM = 1.8,
  }) {
    // Los picos, sumando la casilla y sus vecinas (un suelo no es plano
    // al centímetro).
    final peaks = <(double, double)>[];
    for (var k = 0; k < p.up.length; k++) {
      final a = p.up[k];
      final prev = k > 0 ? p.up[k - 1] : 0.0;
      final next = k + 1 < p.up.length ? p.up[k + 1] : 0.0;
      if (a < prev || a < next) continue;
      final area = a + prev + next;
      if (area < minAreaM2) continue;
      final h = p.y0 + (k + 0.5) * p.bin - floorY;
      if (h < minStoreyM) continue;
      if (ceilingM != null && h > ceilingM - 0.3) continue;
      peaks.add((h, area));
    }
    peaks.sort((a, b) => a.$1.compareTo(b.$1));
    final out = <double>[];
    for (final (h, _) in peaks) {
      if (out.isNotEmpty && h - out.last < minStoreyM) continue;
      out.add((h * 100).round() / 100);
    }
    return out;
  }

  /// Escaleras y rampas: en la rejilla cenital, zonas cuyo suelo (lo más
  /// bajo de cada celda) sube con una pendiente seguida. Una escalera
  /// sube entre 35 y 100 %; una rampa, entre el 2 y el 14 %. Un mueble
  /// es plano: no sale.
  ///
  /// [levels] son los otros suelos (metros sobre el de abajo): sus celdas
  /// no cuentan, para no mezclar la planta de arriba con la escalera, y
  /// una escalera que llega cerca de uno sube hasta él.
  static List<ScanStair> stairs(
    ScanGrid grid,
    double floorY, {
    List<double> levels = const [],
  }) {
    final src = grid.bottom;
    if (src == null) return const [];
    final n = grid.cols * grid.rows;
    final h = List<double?>.filled(n, null);
    for (var i = 0; i < n; i++) {
      final v = src[i];
      if (v == null) continue;
      final rel = v - floorY;
      if (rel <= 0.06 || rel >= 4.5) continue;
      if (levels.any((l) => (rel - l).abs() < 0.1)) continue;
      h[i] = rel;
    }
    final seen = List<bool>.filled(n, false);
    final out = <ScanStair>[];
    final cell = grid.cell;
    for (var start = 0; start < n; start++) {
      if (h[start] == null || seen[start]) continue;
      // Una zona: celdas vecinas que suben poco de una a otra.
      final zone = <int>[];
      final stack = [start];
      seen[start] = true;
      while (stack.isNotEmpty) {
        final c = stack.removeLast();
        zone.add(c);
        final ci = c % grid.cols, cj = c ~/ grid.cols;
        for (final (di, dj) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final i = ci + di, j = cj + dj;
          if (i < 0 || j < 0 || i >= grid.cols || j >= grid.rows) continue;
          final k = j * grid.cols + i;
          if (seen[k] || h[k] == null) continue;
          if ((h[k]! - h[c]!).abs() > 0.3) continue;
          seen[k] = true;
          stack.add(k);
        }
      }
      if (zone.length * cell * cell < 0.8) continue;
      // El plano que mejor pasa: h = a·x + b·y + c.
      var sx = 0.0, sy = 0.0, sz = 0.0;
      var sxx = 0.0, syy = 0.0, sxy = 0.0, sxz = 0.0, syz = 0.0;
      final pts = <(double, double, double)>[];
      for (final k in zone) {
        final x = grid.x0 + (k % grid.cols + 0.5) * cell;
        final y = grid.y0 + (k ~/ grid.cols + 0.5) * cell;
        final z = h[k]!;
        pts.add((x, y, z));
        sx += x;
        sy += y;
        sz += z;
      }
      final m = pts.length.toDouble();
      final mx = sx / m, my = sy / m, mz = sz / m;
      for (final (x, y, z) in pts) {
        final dx = x - mx, dy = y - my, dz = z - mz;
        sxx += dx * dx;
        syy += dy * dy;
        sxy += dx * dy;
        sxz += dx * dz;
        syz += dy * dz;
      }
      final det = sxx * syy - sxy * sxy;
      if (det.abs() < 1e-9) continue;
      final a = (sxz * syy - syz * sxy) / det;
      final b = (syz * sxx - sxz * sxy) / det;
      final slope = math.sqrt(a * a + b * b);
      final stair = slope >= 0.35 && slope <= 1.0;
      final ramp = slope >= 0.02 && slope <= 0.14;
      if (!stair && !ramp) continue;
      // Que el plano explique la zona (r²).
      var ssRes = 0.0, ssTot = 0.0;
      for (final (x, y, z) in pts) {
        final fit = mz + a * (x - mx) + b * (y - my);
        ssRes += (z - fit) * (z - fit);
        ssTot += (z - mz) * (z - mz);
      }
      final r2 = ssTot < 1e-9 ? 0.0 : 1 - ssRes / ssTot;
      if (r2 < 0.75) continue;
      final up = Offset(a, b) / slope;
      final across = Offset(-up.dy, up.dx);
      var lo = double.infinity, hi = -double.infinity;
      var left = double.infinity, right = -double.infinity;
      var top = 0.0;
      for (final (x, y, z) in pts) {
        final q = Offset(x - mx, y - my);
        final along = q.dx * up.dx + q.dy * up.dy;
        final side = q.dx * across.dx + q.dy * across.dy;
        lo = math.min(lo, along - cell / 2);
        hi = math.max(hi, along + cell / 2);
        left = math.min(left, side - cell / 2);
        right = math.max(right, side + cell / 2);
        top = math.max(top, z);
      }
      // Lo primero de una rampa queda a ras de suelo y no se ve: llega
      // abajo por su pendiente.
      if (ramp) lo = math.max(lo - 2, math.min(lo, -mz / slope));
      final run = hi - lo;
      if (run < (ramp ? 1.0 : 0.6)) continue;
      final mid = (left + right) / 2;
      final c = Offset(mx, my) + across * mid;
      // Una escalera llega al suelo de arriba con un peldaño más de lo que
      // se ve de su última huella; si hay un nivel a mano, hasta él.
      var rise = top;
      if (stair) {
        final n = math.max(1, (top / 0.175).round());
        rise = top * (n + 1) / n;
        for (final l in levels) {
          if (l > top - 0.05 && l - top < 0.5) rise = l;
        }
      }
      out.add(
        ScanStair(
          from: c + up * lo,
          to: c + up * hi,
          widthM: (right - left).clamp(0.6, 4.0),
          riseM: (rise * 100).round() / 100,
          ramp: ramp,
          confidence: r2.clamp(0.0, 1.0) * (stair ? 0.8 : 0.7),
        ),
      );
    }
    return out;
  }

  // ── Material por el color ────────────────────────────────────────────

  /// El color medio, en sRGB de 0 a 1, de lo que cae dentro de [polygon]
  /// (píxeles) en la foto [bytes]. `null` si no se puede leer o no cae
  /// nada dentro.
  static (double, double, double)? meanColor(
    Uint8List bytes,
    List<Offset> polygon, {
    int samples = 40,
  }) {
    final image = img.decodeImage(bytes);
    if (image == null) return null;
    return _meanColor(image, polygon, samples);
  }

  static (double, double, double)? _meanColor(
    img.Image image,
    List<Offset> polygon,
    int samples,
  ) {
    if (polygon.length < 3) return null;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final p in polygon) {
      minX = math.min(minX, p.dx);
      minY = math.min(minY, p.dy);
      maxX = math.max(maxX, p.dx);
      maxY = math.max(maxY, p.dy);
    }
    minX = math.max(0, minX);
    minY = math.max(0, minY);
    maxX = math.min(image.width - 1.0, maxX);
    maxY = math.min(image.height - 1.0, maxY);
    if (maxX <= minX || maxY <= minY) return null;
    var r = 0.0, g = 0.0, b = 0.0;
    var count = 0;
    // Sin los bordes: allí suele haber otra cosa (marco, rodapié, sombra).
    final shrunk = _shrink(polygon, 0.15);
    for (var j = 0; j < samples; j++) {
      for (var i = 0; i < samples; i++) {
        final p = Offset(
          minX + (maxX - minX) * (i + 0.5) / samples,
          minY + (maxY - minY) * (j + 0.5) / samples,
        );
        if (!_inside(shrunk, p)) continue;
        final px = image.getPixel(p.dx.floor(), p.dy.floor());
        r += px.rNormalized;
        g += px.gNormalized;
        b += px.bNormalized;
        count++;
      }
    }
    if (count == 0) return null;
    return (r / count, g / count, b / count);
  }

  /// El material de cada cara por su foto, fuera del hilo de la pantalla:
  /// de cada trabajo, la foto ([path]), dónde caen en ella los puntos de la
  /// cara ([pixels], en las medidas de [frameSize]; los que no se ven, a
  /// `null`) y entre qué familias se elige. Devuelve el `id` del material o
  /// `null` si no hay foto que valga.
  static Future<List<String?>> materialsFromPhotos(
    List<
      ({
        String path,
        Size frameSize,
        List<Offset?> pixels,
        Set<ArchFamily> families,
      })
    >
    jobs,
  ) => Isolate.run(() {
    final decoded = <String, img.Image?>{};
    return [
      for (final j in jobs)
        () {
          final image = decoded.putIfAbsent(j.path, () {
            final f = File(j.path);
            return f.existsSync() ? img.decodeImage(f.readAsBytesSync()) : null;
          });
          if (image == null || j.frameSize.isEmpty) return null;
          final sx = image.width / j.frameSize.width;
          final sy = image.height / j.frameSize.height;
          final pts = [
            for (final p in j.pixels)
              if (p != null) Offset(p.dx * sx, p.dy * sy),
          ];
          if (pts.length < 3) return null;
          final c = _meanColor(image, _hull(pts), 40);
          return c == null ? null : nearestMaterial(c, j.families).id;
        }(),
    ];
  });

  static List<Offset> _shrink(List<Offset> poly, double k) {
    var c = Offset.zero;
    for (final p in poly) {
      c += p;
    }
    c = c / poly.length.toDouble();
    return [for (final p in poly) Offset.lerp(p, c, k)!];
  }

  static bool _inside(List<Offset> poly, Offset p) {
    var inside = false;
    for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
      final a = poly[i], b = poly[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        inside = !inside;
      }
    }
    return inside;
  }

  /// Las familias que tiene sentido proponer para cada cara.
  static const wallFamilies = {
    ArchFamily.plaster,
    ArchFamily.concrete,
    ArchFamily.brick,
    ArchFamily.stone,
    ArchFamily.tile,
    ArchFamily.wood,
  };
  static const floorFamilies = {
    ArchFamily.wood,
    ArchFamily.tile,
    ArchFamily.concrete,
    ArchFamily.stone,
    ArchFamily.fabric,
  };
  static const ceilingFamilies = {
    ArchFamily.plaster,
    ArchFamily.concrete,
    ArchFamily.wood,
  };

  /// El material de la biblioteca más parecido a un color de foto (sRGB
  /// de 0 a 1). Cuenta más el tinte que el brillo, porque la exposición
  /// de la foto no es la del sitio.
  static ArchMaterial nearestMaterial(
    (double, double, double) srgb,
    Set<ArchFamily> families,
  ) {
    double lin(double v) => v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    final (r, g, b) = (lin(srgb.$1), lin(srgb.$2), lin(srgb.$3));
    (double, double, double) chroma(double r, double g, double b) {
      final s = math.max(1e-6, r + g + b);
      return (r / s, g / s, math.log(s / 3 + 1e-4));
    }

    final (cr, cg, cl) = chroma(r, g, b);
    ArchMaterial? best;
    var bestD = double.infinity;
    for (final m in ArchMaterials.all) {
      if (!families.contains(m.family)) continue;
      final rgb = m.albedoRgb;
      final (mr, mg, ml) = chroma(
        (rgb >> 16 & 255) / 255,
        (rgb >> 8 & 255) / 255,
        (rgb & 255) / 255,
      );
      final d =
          math.pow((cr - mr) * 10, 2) +
          math.pow((cg - mg) * 10, 2) +
          math.pow((cl - ml) * 0.6, 2);
      if (d < bestD) {
        bestD = d.toDouble();
        best = m;
      }
    }
    return best ?? ArchMaterials.byId('plaster-raw')!;
  }
}
