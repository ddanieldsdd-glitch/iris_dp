import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart' show ValueNotifier;

import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import '../light/light_scene.dart';
import '../light_overrides.dart';
import '../plan_segment.dart';
import '../rig/plan_rig.dart';
import 'arch_material.dart';

/// Qué hace el pincel del terreno (AM.7).
enum TerrainBrushMode {
  raise('Subir'),
  lower('Bajar'),
  smooth('Alisar'),
  flatten('Aplanar'),
  paint('Pintar');

  const TerrainBrushMode(this.label);
  final String label;
}

/// El pincel con el que se trabaja el terreno: qué hace, su radio y
/// cuánto sube o baja de una pasada (metros), y el material con el que
/// pinta.
class TerrainBrush {
  final TerrainBrushMode mode;
  final double radiusM;
  final double strengthM;
  final String materialId;

  /// Al aplanar: la cota donde empezó la pasada.
  final double? flattenTo;

  const TerrainBrush({
    this.mode = TerrainBrushMode.raise,
    this.radiusM = 3,
    this.strengthM = 0.5,
    this.materialId = 'sand',
    this.flattenTo,
  });

  TerrainBrush copyWith({
    TerrainBrushMode? mode,
    double? radiusM,
    double? strengthM,
    String? materialId,
    double? flattenTo,
  }) => TerrainBrush(
    mode: mode ?? this.mode,
    radiusM: radiusM ?? this.radiusM,
    strengthM: strengthM ?? this.strengthM,
    materialId: materialId ?? this.materialId,
    flattenTo: flattenTo ?? this.flattenTo,
  );
}

/// Terreno por alturas (AM.7), como el de Unreal o World Machine: una
/// rejilla de cotas en metros que se trabaja con pinceles, con un material
/// por casilla (arena, hierba, roca, tierra…) y, si se quiere, agua hasta
/// una cota (mar, orilla, lago).
///
/// Se guarda como una pieza más, con el centro en `position` y sin giro.
/// Las cotas van en los vértices, fila a fila: `(cols + 1) × (rows + 1)`.
abstract final class ArchTerrain {
  static const colsKey = 'tCols';
  static const rowsKey = 'tRows';
  static const cellKey = 'tCell';
  static const heightsKey = 'tH';

  /// Los materiales del terreno; el primero es el de fondo.
  static const matsKey = 'tMats';

  /// Qué material lleva cada casilla: su índice en [matsKey].
  static const paintKey = 'tPaint';

  /// Cota del agua, en metros, si hay agua.
  static const waterKey = 'waterM';

  static const defaultMat = 'grass';
  static const waterMat = 'water';

  /// Lo que se ofrece para pintar.
  static const paintable = [
    'grass',
    'sand',
    'earth',
    'stone-rock',
    'stone-paving',
    'asphalt',
    'concrete-floor',
  ];

  /// El pincel de la planta: si hay uno y está seleccionado un terreno,
  /// arrastrar sobre él lo trabaja en vez de moverlo.
  static final brush = ValueNotifier<TerrainBrush?>(null);

  static bool isTerrain(PlanElement el) =>
      RigTypeCodec.of(el) == RigType.terrain;

  /// Un terreno plano que llena el rectángulo de [from] a [to] (lienzo),
  /// con casillas de medio metro o más (no más de 80 por lado).
  static PlanElement create(
    Offset from,
    Offset to,
    double metersPerUnit, {
    String material = defaultMat,
  }) {
    final w = math.max(2.0, (to.dx - from.dx).abs() * metersPerUnit);
    final d = math.max(2.0, (to.dy - from.dy).abs() * metersPerUnit);
    final cell = math.max(0.5, (math.max(w, d) / 80 * 4).ceil() / 4);
    final cols = math.max(2, (w / cell).round());
    final rows = math.max(2, (d / cell).round());
    final el = RigTypeCodec.create(
      RigType.terrain,
      Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2),
      props: {
        colsKey: cols,
        rowsKey: rows,
        cellKey: cell,
        heightsKey: List<double>.filled((cols + 1) * (rows + 1), 0),
        matsKey: [material],
      },
    );
    LightOverrides.ensureUids([el]);
    return el;
  }

  static int cols(PlanElement el) =>
      math.max(1, (el.props[colsKey] as num?)?.toInt() ?? 1);
  static int rows(PlanElement el) =>
      math.max(1, (el.props[rowsKey] as num?)?.toInt() ?? 1);
  static double cellM(PlanElement el) =>
      math.max(0.1, (el.props[cellKey] as num?)?.toDouble() ?? 1);
  static double widthM(PlanElement el) => cols(el) * cellM(el);
  static double depthM(PlanElement el) => rows(el) * cellM(el);

  /// Las cotas de los vértices, en metros.
  static List<double> heights(PlanElement el) {
    final n = (cols(el) + 1) * (rows(el) + 1);
    final raw = el.props[heightsKey];
    final out = List<double>.filled(n, 0);
    if (raw is List) {
      for (var k = 0; k < n && k < raw.length; k++) {
        out[k] = (raw[k] as num?)?.toDouble() ?? 0;
      }
    }
    return out;
  }

  static void setHeights(PlanElement el, List<double> h) =>
      el.props[heightsKey] = [for (final v in h) (v * 100).round() / 100];

  /// Esquina de arriba a la izquierda, en el lienzo.
  static Offset origin(PlanElement el, double mpu) =>
      el.position - Offset(widthM(el), depthM(el)) / (2 * mpu);

  static Rect rect(PlanElement el, double mpu) =>
      origin(el, mpu) & Size(widthM(el) / mpu, depthM(el) / mpu);

  /// El vértice (i, j), en el lienzo.
  static Offset vertex(PlanElement el, int i, int j, double mpu) =>
      origin(el, mpu) + Offset(i.toDouble(), j.toDouble()) * (cellM(el) / mpu);

  static bool contains(PlanElement el, Offset p, double mpu) =>
      rect(el, mpu).contains(p);

  /// La cota del terreno en [p] (lienzo), entre sus cuatro vértices;
  /// `null` fuera del terreno. [h] evita leer las cotas cada vez.
  static double? heightAt(
    PlanElement el,
    Offset p,
    double mpu, [
    List<double>? h,
  ]) {
    final c = cols(el), r = rows(el);
    final q = (p - origin(el, mpu)) * mpu / cellM(el);
    if (q.dx < 0 || q.dy < 0 || q.dx > c || q.dy > r) return null;
    final hs = h ?? heights(el);
    final i = math.min(c - 1, q.dx.floor()), j = math.min(r - 1, q.dy.floor());
    final u = q.dx - i, v = q.dy - j;
    double at(int a, int b) => hs[b * (c + 1) + a];
    return at(i, j) * (1 - u) * (1 - v) +
        at(i + 1, j) * u * (1 - v) +
        at(i, j + 1) * (1 - u) * v +
        at(i + 1, j + 1) * u * v;
  }

  static (double, double) range(PlanElement el) {
    final h = heights(el);
    return (h.reduce(math.min), h.reduce(math.max));
  }

  // ── Materiales y agua ────────────────────────────────────────────────

  static List<String> materials(PlanElement el) {
    final raw = el.props[matsKey];
    final out = [
      if (raw is List)
        for (final m in raw)
          if (m is String && ArchMaterials.byId(m) != null) m,
    ];
    return out.isEmpty ? [defaultMat] : out;
  }

  static String baseMaterial(PlanElement el) => materials(el).first;

  static void setBaseMaterial(PlanElement el, String id) {
    final m = materials(el);
    m[0] = id;
    el.props[matsKey] = m;
  }

  /// El índice de material de cada casilla, fila a fila.
  static List<int> paint(PlanElement el) {
    final n = cols(el) * rows(el);
    final raw = el.props[paintKey];
    final top = materials(el).length - 1;
    return [
      for (var k = 0; k < n; k++)
        raw is List && k < raw.length
            ? ((raw[k] as num?)?.toInt() ?? 0).clamp(0, top)
            : 0,
    ];
  }

  static double? water(PlanElement el) =>
      (el.props[waterKey] as num?)?.toDouble();

  static void setWater(PlanElement el, double? m) => m == null
      ? el.props.remove(waterKey)
      : el.props[waterKey] = (m * 100).round() / 100;

  // ── Pinceles ─────────────────────────────────────────────────────────

  /// Una pincelada en [at] (lienzo). [amount] es la parte de la fuerza del
  /// pincel que se aplica (lo que se ha movido el dedo, por ejemplo).
  static void stroke(
    PlanElement el,
    Offset at,
    TerrainBrush b,
    double mpu, {
    double amount = 1,
  }) {
    final c = cols(el), r = rows(el), cell = cellM(el);
    final o = origin(el, mpu);
    final centre = (at - o) * mpu;
    final radius = math.max(cell, b.radiusM);
    double weight(Offset p) {
      final t = (1 - (p - centre).distance / radius).clamp(0.0, 1.0);
      return t * t * (3 - 2 * t);
    }

    if (b.mode == TerrainBrushMode.paint) {
      final mats = materials(el);
      var index = mats.indexOf(b.materialId);
      if (index < 0) {
        mats.add(b.materialId);
        index = mats.length - 1;
        el.props[matsKey] = mats;
      }
      final p = paint(el);
      for (var j = 0; j < r; j++) {
        for (var i = 0; i < c; i++) {
          final mid = Offset(i + 0.5, j + 0.5) * cell;
          if ((mid - centre).distance <= radius) p[j * c + i] = index;
        }
      }
      el.props[paintKey] = p;
      return;
    }
    final h = heights(el);
    final before = List<double>.of(h);
    final i0 = math.max(0, ((centre.dx - radius) / cell).floor());
    final i1 = math.min(c, ((centre.dx + radius) / cell).ceil());
    final j0 = math.max(0, ((centre.dy - radius) / cell).floor());
    final j1 = math.min(r, ((centre.dy + radius) / cell).ceil());
    final k = amount.clamp(0.0, 1.0);
    for (var j = j0; j <= j1; j++) {
      for (var i = i0; i <= i1; i++) {
        final w = weight(Offset(i.toDouble(), j.toDouble()) * cell);
        if (w <= 0) continue;
        final at = j * (c + 1) + i;
        double near(int a, int b) =>
            before[b.clamp(0, r) * (c + 1) + a.clamp(0, c)];
        final next = switch (b.mode) {
          TerrainBrushMode.raise => h[at] + b.strengthM * w * k,
          TerrainBrushMode.lower => h[at] - b.strengthM * w * k,
          TerrainBrushMode.smooth =>
            h[at] +
                ((near(i - 1, j) +
                                near(i + 1, j) +
                                near(i, j - 1) +
                                near(i, j + 1)) /
                            4 -
                        h[at]) *
                    math.min(1.0, w * k * 1.5),
          TerrainBrushMode.flatten =>
            h[at] +
                ((b.flattenTo ?? before[at]) - h[at]) *
                    math.min(1.0, w * k * 1.5),
          TerrainBrushMode.paint => h[at],
        };
        h[at] = next.clamp(-50.0, 300.0);
      }
    }
    setHeights(el, h);
  }

  // ── Colinas y taludes de antes ───────────────────────────────────────

  /// Las colinas y los taludes que caen en el terreno, ya metidos en sus
  /// cotas (la más alta en cada punto). Devuelve los que ha absorbido,
  /// para quitarlos de la planta.
  static List<PlanElement> absorb(
    PlanElement el,
    Iterable<PlanElement> elements,
    double mpu,
  ) {
    final area = rect(el, mpu);
    final c = cols(el), r = rows(el);
    final h = heights(el);
    final taken = <PlanElement>[];
    for (final e in elements) {
      double Function(Offset p)? shape;
      if (e.type == ElementType.prop &&
          e.propType == PropType.hill &&
          RigTypeCodec.of(e) == null &&
          area.contains(e.position)) {
        shape = _hill(e, mpu);
      } else if (PlanSegment.isSegment(e) &&
          PlanSegment.kind(e) == PlanSegment.kindRelief &&
          area.contains(PlanSegment.pointAt(e, 0.5))) {
        shape = _relief(e, mpu);
      }
      if (shape == null) continue;
      taken.add(e);
      for (var j = 0; j <= r; j++) {
        for (var i = 0; i <= c; i++) {
          final k = j * (c + 1) + i;
          h[k] = math.max(h[k], shape(vertex(el, i, j, mpu)));
        }
      }
    }
    if (taken.isNotEmpty) setHeights(el, h);
    return taken;
  }

  /// Una colina: una campana de su altura en el centro a cero en su
  /// radio, alargada y girada como en la planta.
  static double Function(Offset) _hill(PlanElement e, double mpu) {
    final radius = LightScene.propSizeM(e) / mpu;
    final height = LightScene.propHeightM(e);
    final stretch = LightScene.hillStretch(e);
    final turn = e.rotation * math.pi / 180;
    return (p) {
      final v = p - e.position;
      final cs = math.cos(-turn), sn = math.sin(-turn);
      final local = Offset(
        (v.dx * cs - v.dy * sn) / stretch,
        v.dx * sn + v.dy * cs,
      );
      final t = local.distance / radius;
      return t >= 1 ? 0 : height * 0.5 * (1 + math.cos(math.pi * t));
    };
  }

  /// Un talud: arriba, de su lado alto, a su altura; hacia el lado que
  /// baja (el de las rayitas), cae hasta el suelo en una vez y media su
  /// altura.
  static double Function(Offset) _relief(PlanElement e, double mpu) {
    final height = LightScene.propHeightM(e);
    final down = e.props['flip'] == true ? -1.0 : 1.0;
    final run = math.max(1.0, height * 1.5) / mpu;
    final pts = [for (var k = 0; k <= 16; k++) PlanSegment.pointAt(e, k / 16)];
    return (p) {
      var best = double.infinity, side = 0.0;
      var end = false;
      for (var k = 0; k + 1 < pts.length; k++) {
        final a = pts[k], b = pts[k + 1];
        final ab = b - a;
        final len2 = ab.distanceSquared;
        if (len2 < 1e-9) continue;
        final raw = ((p - a).dx * ab.dx + (p - a).dy * ab.dy) / len2;
        final t = raw.clamp(0.0, 1.0);
        final q = a + ab * t;
        final d = (p - q).distance;
        if (d < best) {
          best = d;
          final n = Offset(-ab.dy, ab.dx) / math.sqrt(len2) * down;
          side = (p - q).dx * n.dx + (p - q).dy * n.dy;
          end = (k == 0 && raw < 0) || (k == pts.length - 2 && raw > 1);
        }
      }
      if (end) return height * (1 - best / run).clamp(0.0, 1.0);
      if (side <= 0) return best < run * 8 ? height : 0;
      return height * (1 - side / run).clamp(0.0, 1.0);
    };
  }

  // ── Curvas de nivel ──────────────────────────────────────────────────

  /// Cada cuánto va una curva de nivel: unas doce en todo el desnivel.
  static double contourStep(PlanElement el) {
    final (lo, hi) = range(el);
    final span = hi - lo;
    for (final s in const [0.1, 0.25, 0.5, 1.0, 2.0, 5.0, 10.0]) {
      if (span / s <= 12) return s;
    }
    return 20;
  }

  /// Las curvas de nivel, en tramos del lienzo con su cota.
  static List<(Offset, Offset, double)> contours(
    PlanElement el,
    double mpu, {
    double? stepM,
  }) {
    final (lo, hi) = range(el);
    if (hi - lo < 0.05) return const [];
    final step = stepM ?? contourStep(el);
    final out = <(Offset, Offset, double)>[];
    for (var z = (lo / step).floor() * step + step; z < hi; z += step) {
      if (z.abs() < 1e-9) z = 0;
      for (final (a, b) in isoline(el, z, mpu)) {
        out.add((a, b, z));
      }
    }
    return out;
  }

  /// Dónde el terreno pasa por la cota [z]: cuadrados en marcha.
  static List<(Offset, Offset)> isoline(PlanElement el, double z, double mpu) {
    final c = cols(el), r = rows(el);
    final h = heights(el);
    final out = <(Offset, Offset)>[];
    Offset cut(int i0, int j0, int i1, int j1) {
      final a = h[j0 * (c + 1) + i0], b = h[j1 * (c + 1) + i1];
      final t = (b - a).abs() < 1e-9 ? 0.5 : ((z - a) / (b - a)).clamp(0, 1);
      return Offset.lerp(
        vertex(el, i0, j0, mpu),
        vertex(el, i1, j1, mpu),
        t.toDouble(),
      )!;
    }

    for (var j = 0; j < r; j++) {
      for (var i = 0; i < c; i++) {
        bool up(int a, int b) => h[b * (c + 1) + a] >= z;
        final code =
            (up(i, j) ? 1 : 0) |
            (up(i + 1, j) ? 2 : 0) |
            (up(i + 1, j + 1) ? 4 : 0) |
            (up(i, j + 1) ? 8 : 0);
        if (code == 0 || code == 15) continue;
        final top = cut(i, j, i + 1, j);
        final right = cut(i + 1, j, i + 1, j + 1);
        final bottom = cut(i, j + 1, i + 1, j + 1);
        final left = cut(i, j, i, j + 1);
        switch (code) {
          case 1 || 14:
            out.add((left, top));
          case 2 || 13:
            out.add((top, right));
          case 3 || 12:
            out.add((left, right));
          case 4 || 11:
            out.add((right, bottom));
          case 6 || 9:
            out.add((top, bottom));
          case 7 || 8:
            out.add((left, bottom));
          case 5:
            out
              ..add((left, top))
              ..add((right, bottom));
          case 10:
            out
              ..add((top, right))
              ..add((left, bottom));
        }
      }
    }
    return out;
  }

  /// Las casillas bajo el agua (su media, por debajo de la cota del agua),
  /// en el lienzo.
  static List<Rect> flooded(PlanElement el, double mpu) {
    final w = water(el);
    if (w == null) return const [];
    final c = cols(el), r = rows(el);
    final h = heights(el);
    final size = cellM(el) / mpu;
    final o = origin(el, mpu);
    return [
      for (var j = 0; j < r; j++)
        for (var i = 0; i < c; i++)
          if ((h[j * (c + 1) + i] +
                      h[j * (c + 1) + i + 1] +
                      h[(j + 1) * (c + 1) + i] +
                      h[(j + 1) * (c + 1) + i + 1]) /
                  4 <
              w)
            Rect.fromLTWH(o.dx + i * size, o.dy + j * size, size, size),
    ];
  }

  // ── 3D ───────────────────────────────────────────────────────────────

  /// La malla por material: triángulos con cada vértice en el lienzo (x,
  /// y) y su cota en metros (z), de cara arriba, y la normal de cada
  /// vértice (x, y del lienzo, z arriba) para que el terreno se vea liso.
  /// El agua va como `water`.
  static Map<String, ({List<double> tris, List<double> normals})> mesh(
    PlanElement el,
    double mpu,
  ) {
    final c = cols(el), r = rows(el), cell = cellM(el);
    final h = heights(el);
    final mats = materials(el);
    final p = paint(el);
    double at(int i, int j) => h[j.clamp(0, r) * (c + 1) + i.clamp(0, c)];
    final out = <String, ({List<double> tris, List<double> normals})>{};
    void v(({List<double> tris, List<double> normals}) to, int i, int j) {
      final q = vertex(el, i, j, mpu);
      to.tris.addAll([q.dx, q.dy, at(i, j)]);
      final gx = (at(i + 1, j) - at(i - 1, j)) / (2 * cell);
      final gy = (at(i, j + 1) - at(i, j - 1)) / (2 * cell);
      final n = math.sqrt(gx * gx + gy * gy + 1);
      to.normals.addAll([-gx / n, -gy / n, 1 / n]);
    }

    for (var j = 0; j < r; j++) {
      for (var i = 0; i < c; i++) {
        final to = out.putIfAbsent(
          mats[p[j * c + i]],
          () => (tris: <double>[], normals: <double>[]),
        );
        // De cara arriba en el visor, con la y de la planta hacia el norte.
        v(to, i, j);
        v(to, i, j + 1);
        v(to, i + 1, j + 1);
        v(to, i, j);
        v(to, i + 1, j + 1);
        v(to, i + 1, j);
      }
    }
    final w = water(el);
    if (w != null && h.any((x) => x < w)) {
      final o = rect(el, mpu);
      out[waterMat] = (
        tris: [
          o.left, o.top, w, o.left, o.bottom, w, o.right, o.bottom, w, //
          o.left, o.top, w, o.right, o.bottom, w, o.right, o.top, w,
        ],
        normals: [
          for (var k = 0; k < 6; k++) ...[0.0, 0.0, 1.0],
        ],
      );
    }
    return out;
  }

  /// Un resumen para el panel.
  static String summary(PlanElement el) {
    final (lo, hi) = range(el);
    String m(double v) => v.toStringAsFixed(v == v.roundToDouble() ? 0 : 1);
    final w = water(el);
    return '${m(widthM(el))} × ${m(depthM(el))} m en casillas de '
        '${cellM(el).toStringAsFixed(2)} m · de ${lo.toStringAsFixed(2)} a '
        '${hi.toStringAsFixed(2)} m'
        '${w == null ? '' : ' · agua a ${w.toStringAsFixed(2)} m'}.';
  }
}
