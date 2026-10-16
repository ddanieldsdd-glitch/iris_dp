import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// Puntas de pincel: la huella que se estampa a lo largo del trazo.
enum BrushTip {
  /// Disco de borde nítido (fineliner, relleno).
  hardRound,

  /// Disco de borde gaussiano (aerógrafo, niebla).
  softRound,

  /// Mina de grafito: disco con huecos de grano.
  graphite,

  /// Carbón: mancha irregular con motas.
  charcoal,

  /// Barra de carbón o tiza de lado: rectángulo rasposo.
  chalk,

  /// Punta biselada de rotulador.
  chisel,

  /// Rotulador gastado: bisel con rayas secas.
  dryChisel,

  /// Aguada: mancha con el borde algo más oscuro, como el pigmento al secar.
  wash,

  /// Plumilla: elipse estrecha que cambia de grosor con la dirección.
  nib,
}

/// Grano del papel: textura que se repite fija sobre el folio.
enum BrushGrain { fine, rough, kraft, streak }

/// Texturas generadas con ruido determinista (sin assets de terceros): el
/// mismo dibujo sale igual en el Mac, el iPad y el PNG exportado.
class AnnotationTextures {
  AnnotationTextures._();

  static final AnnotationTextures instance = AnnotationTextures._();

  static const tipSize = 128;
  static const grainSize = 256;

  final Map<BrushTip, ui.Image> _tips = {};
  final Map<BrushGrain, ui.Image> _grains = {};

  ui.Image tip(BrushTip tip) =>
      _tips.putIfAbsent(tip, () => _toImage(tipSize, _tipAlpha(tip)));

  ui.Image grain(BrushGrain grain) =>
      _grains.putIfAbsent(grain, () => _toImage(grainSize, _grainAlpha(grain)));

  /// Rectángulo de la textura de punta, para `drawAtlas`.
  static const tipRect = Rect.fromLTWH(0, 0, tipSize * 1.0, tipSize * 1.0);

  // ─── Generación ────────────────────────────────────────────────────────────

  /// Pasa un mapa de alfa (0–1) a una imagen blanca con ese alfa. Se pinta
  /// con puntos agrupados por nivel para poder hacerlo de forma síncrona.
  static ui.Image _toImage(int size, Float32List alpha) {
    const levels = 48;
    final buckets = List.generate(levels, (_) => <double>[]);
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        final a = alpha[y * size + x];
        if (a <= 0.004) continue;
        final level = (a.clamp(0.0, 1.0) * (levels - 1)).round();
        if (level == 0) continue;
        buckets[level]
          ..add(x + 0.5)
          ..add(y + 0.5);
      }
    }
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.square
      ..isAntiAlias = false;
    for (var level = 1; level < levels; level++) {
      final pts = buckets[level];
      if (pts.isEmpty) continue;
      paint.color = Color.fromRGBO(255, 255, 255, level / (levels - 1));
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.fromList(pts),
        paint,
      );
    }
    final picture = recorder.endRecording();
    final image = picture.toImageSync(size, size);
    picture.dispose();
    return image;
  }

  static Float32List _tipAlpha(BrushTip tip) {
    const n = tipSize;
    final out = Float32List(n * n);
    final noise = _Noise(tip.index * 7919 + 13);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        // u, v en -1…1.
        final u = (x + 0.5) / n * 2 - 1;
        final v = (y + 0.5) / n * 2 - 1;
        final r = math.sqrt(u * u + v * v);
        double a;
        switch (tip) {
          case BrushTip.hardRound:
            a = _edge(r, 0.94, 0.06);
          case BrushTip.softRound:
            a = math.exp(-r * r * 4.2) * _edge(r, 1, 0.08);
          case BrushTip.graphite:
            final grit = noise.fbm(x / 6, y / 6, 3);
            a = _edge(r, 0.9, 0.2) * _smooth(0.28, 0.72, grit);
          case BrushTip.charcoal:
            final wobble = noise.fbm(x / 22, y / 22, 2) * 0.45;
            final speck = noise.fbm(x / 3, y / 3, 2);
            a =
                _edge(r, 0.62 + wobble, 0.25) *
                (0.25 + 0.75 * _smooth(0.35, 0.7, speck));
          case BrushTip.chalk:
            final scratch = noise.fbm(x / 1.6, y / 5, 3);
            final box = _edge(u.abs(), 0.92, 0.1) * _edge(v.abs(), 0.42, 0.14);
            a = box * _smooth(0.3, 0.75, scratch);
          case BrushTip.chisel:
            a = _edge(u.abs(), 0.9, 0.08) * _edge(v.abs(), 0.3, 0.08);
          case BrushTip.dryChisel:
            // Rayas a lo ancho de la punta: al avanzar quedan surcos secos.
            final streak = noise.fbm(x / 1.7, 0, 3);
            final ink = noise.fbm(x / 11, 0, 2);
            a =
                _edge(u.abs(), 0.92, 0.08) *
                _edge(v.abs(), 0.34, 0.08) *
                (0.35 + 0.65 * _smooth(0.3, 0.6, streak * 0.6 + ink * 0.4));
          case BrushTip.wash:
            final wobble = noise.fbm(x / 26, y / 26, 3) * 0.3;
            final rr = r / (0.72 + wobble);
            final body = _edge(rr, 1, 0.22);
            final rim = math.exp(-math.pow((rr - 0.92) / 0.08, 2).toDouble());
            a = body * 0.55 + rim * 0.45 * body;
          case BrushTip.nib:
            a = _edge(math.sqrt(u * u + (v * 3.2) * (v * 3.2)), 0.92, 0.1);
        }
        out[y * n + x] = a.clamp(0.0, 1.0);
      }
    }
    return out;
  }

  static Float32List _grainAlpha(BrushGrain grain) {
    const n = grainSize;
    final out = Float32List(n * n);
    final noise = _Noise(grain.index * 104729 + 7);
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < n; x++) {
        double a;
        switch (grain) {
          case BrushGrain.fine:
            // Diente fino de papel de dibujo: muchas crestas pequeñas.
            final f = noise.fbm(x / 2, y / 2, 3, px: n ~/ 2, py: n ~/ 2);
            final g = noise.fbm(x / 8, y / 8, 2, px: n ~/ 8, py: n ~/ 8);
            a = _smooth(0.3, 0.7, f * 0.7 + g * 0.3);
          case BrushGrain.rough:
            // Grano grueso (prensado en frío): bultos grandes.
            final f = noise.fbm(x / 8, y / 8, 4, px: n ~/ 8, py: n ~/ 8);
            a = _smooth(0.32, 0.68, f);
          case BrushGrain.kraft:
            // Fibras largas en varias direcciones.
            final fibres = noise.fbm(x / 2, y / 16, 3, px: n ~/ 2, py: n ~/ 16);
            final cross = noise.fbm(x / 16, y / 2, 2, px: n ~/ 16, py: n ~/ 2);
            final base = noise.fbm(x / 4, y / 4, 2, px: n ~/ 4, py: n ~/ 4);
            a = _smooth(0.28, 0.72, base * 0.5 + fibres * 0.3 + cross * 0.2);
          case BrushGrain.streak:
            final s = noise.fbm(x / 1, y / 32, 3, px: n, py: n ~/ 32);
            a = _smooth(0.25, 0.7, s);
        }
        out[y * n + x] = a;
      }
    }
    return out;
  }

  static double _edge(double r, double radius, double soft) =>
      1 - _smooth(radius - soft, radius, r);

  static double _smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }
}

/// Ruido de valor periódico (para que el grano se repita sin costuras).
class _Noise {
  _Noise(int seed) {
    final rnd = math.Random(seed);
    for (var i = 0; i < _table.length; i++) {
      _table[i] = rnd.nextDouble();
    }
  }

  final Float64List _table = Float64List(1024);

  double _lattice(int x, int y) {
    final h = (x * 73856093) ^ (y * 19349663);
    return _table[h & 1023];
  }

  double value(double x, double y, int px, int py) {
    final x0 = x.floor();
    final y0 = y.floor();
    final fx = x - x0;
    final fy = y - y0;
    final sx = fx * fx * (3 - 2 * fx);
    final sy = fy * fy * (3 - 2 * fy);
    int wx(int v) => px > 0 ? v % px : v;
    int wy(int v) => py > 0 ? v % py : v;
    final a = _lattice(wx(x0), wy(y0));
    final b = _lattice(wx(x0 + 1), wy(y0));
    final c = _lattice(wx(x0), wy(y0 + 1));
    final d = _lattice(wx(x0 + 1), wy(y0 + 1));
    return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy;
  }

  /// Suma de octavas en 0–1. [px] y [py] (celdas de la primera octava)
  /// hacen que el ruido se repita en cada eje.
  double fbm(double x, double y, int octaves, {int px = 0, int py = 0}) {
    var sum = 0.0;
    var amp = 0.5;
    var norm = 0.0;
    var freq = 1;
    for (var o = 0; o < octaves; o++) {
      sum += value(x * freq, y * freq, px * freq, py * freq) * amp;
      norm += amp;
      amp *= 0.5;
      freq *= 2;
    }
    return sum / norm;
  }
}
