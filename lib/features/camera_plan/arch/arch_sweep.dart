import 'dart:math' as math;
import 'dart:ui';

import '../camera_plan_element_model.dart';
import '../light_overrides.dart';
import '../rig/plan_rig.dart';
import 'arch_material.dart';

/// Qué perfil recorre el camino (AM.5).
enum SweepKind {
  railing('Barandilla'),
  kerb('Bordillo'),
  skirting('Zócalo'),
  cornice('Cornisa'),
  track('Vía de tren'),
  catenary('Catenaria'),
  deck('Tablero de puente'),
  hull('Casco de vagón'),
  columns('Columnas en fila'),
  seats('Asientos en fila'),
  custom('Perfil propio');

  const SweepKind(this.label);
  final String label;

  static SweepKind byName(String? name) => SweepKind.values.firstWhere(
    (k) => k.name == name,
    orElse: () => SweepKind.custom,
  );
}

/// Un perfil que recorre el camino: un polígono en metros, `across` a la
/// izquierda del camino y `up` desde el suelo, en sentido antihorario.
class SweepPart {
  final List<Offset> profile;
  final String mat;

  /// Lo que cambia al elegir otro material en el panel.
  final bool main;

  const SweepPart(this.profile, this.mat, {this.main = false});

  double get minAcross => profile.map((p) => p.dx).reduce(math.min);
  double get maxAcross => profile.map((p) => p.dx).reduce(math.max);
  double get bottom => profile.map((p) => p.dy).reduce(math.min);
  double get top => profile.map((p) => p.dy).reduce(math.max);
}

/// Una pieza que se repite a lo largo del camino: una caja de [alongM] ×
/// [acrossM] × de [baseM] a [topM], con su centro a [offsetM] a la
/// izquierda del camino.
class SweepRepeat {
  final double alongM;
  final double acrossM;
  final double baseM;
  final double topM;
  final double offsetM;
  final double everyM;

  /// Una en cada punta (postes) o repartidas por dentro (traviesas).
  final bool ends;
  final String mat;
  final bool main;

  /// Tapa la luz.
  final bool blocks;

  const SweepRepeat({
    required this.alongM,
    required this.acrossM,
    required this.baseM,
    required this.topM,
    required this.everyM,
    required this.mat,
    this.offsetM = 0,
    this.ends = false,
    this.main = false,
    this.blocks = false,
  });

  /// La caja como perfil, para barrerla a lo largo de su tramo.
  List<Offset> get profile => [
    Offset(offsetM - acrossM / 2, baseM),
    Offset(offsetM + acrossM / 2, baseM),
    Offset(offsetM + acrossM / 2, topM),
    Offset(offsetM - acrossM / 2, topM),
  ];
}

/// Lo que tapa la luz: una pantalla a [acrossM] del camino, de [baseM] a
/// [topM], que deja pasar [transmission].
typedef SweepScreen = ({
  double acrossM,
  double baseM,
  double topM,
  double transmission,
});

/// Un punto del camino: dónde, hacia dónde va y su izquierda (las dos de
/// largo 1, en el lienzo), y a qué distancia del arranque en metros.
typedef SweepFrame = ({Offset at, Offset along, Offset left, double s});

/// Un barrido (AM.5): un perfil que recorre una línea, recta o curva, como
/// en Vectorworks o SketchUp («sígueme»). Con él salen barandillas,
/// bordillos, zócalos y cornisas; la vía del tren con sus traviesas; la
/// catenaria; el tablero de un puente con sus pilas; el casco de un
/// vagón; y filas de columnas o de asientos.
///
/// Se guarda como pieza: el camino son puntos relativos a `position`
/// (`pts`), así que moverlo lo mueve entero; con dos puntos, `curve` es
/// lo que se aparta el centro de la recta, como en una pared.
abstract final class ArchSweep {
  static const kindKey = 'sweepKind';
  static const pointsKey = 'pts';
  static const curveKey = 'curve';
  static const heightKey = 'sweepH';
  static const widthKey = 'sweepW';
  static const baseKey = 'sweepZ';
  static const everyKey = 'sweepEvery';

  static bool isSweep(PlanElement el) => RigTypeCodec.of(el) == RigType.sweep;

  static PlanElement create(
    Offset from,
    Offset to, {
    SweepKind kind = SweepKind.railing,
  }) {
    final el = RigTypeCodec.create(
      RigType.sweep,
      from,
      props: {
        kindKey: kind.name,
        pointsKey: [
          [0.0, 0.0],
          [to.dx - from.dx, to.dy - from.dy],
        ],
      },
    );
    LightOverrides.ensureUids([el]);
    return el;
  }

  static SweepKind kind(PlanElement el) =>
      SweepKind.byName(el.props[kindKey] as String?);

  /// Los puntos del camino, en el lienzo.
  static List<Offset> points(PlanElement el) {
    final raw = el.props[pointsKey];
    final out = <Offset>[];
    if (raw is List) {
      for (final p in raw) {
        if (p is List && p.length >= 2 && p[0] is num && p[1] is num) {
          out.add(
            el.position +
                Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
          );
        }
      }
    }
    if (out.length < 2) return [el.position, el.position + const Offset(100, 0)];
    return out;
  }

  static void setPoints(PlanElement el, List<Offset> pts) {
    el.props[pointsKey] = [
      for (final p in pts) [p.dx - el.position.dx, p.dy - el.position.dy],
    ];
  }

  static double curve(PlanElement el) =>
      (el.props[curveKey] as num?)?.toDouble() ?? 0;

  /// El camino ya con su curva, punto a punto.
  static List<Offset> path(PlanElement el) {
    final pts = points(el);
    final c = curve(el);
    if (pts.length != 2 || c.abs() < 0.5) return pts;
    final a = pts[0], b = pts[1];
    final d = b - a;
    if (d.distance < 1e-6) return pts;
    final n = Offset(-d.dy, d.dx) / d.distance;
    final mid = Offset.lerp(a, b, 0.5)! + n * c;
    const k = 24;
    return [
      for (var i = 0; i <= k; i++) _quad(a, mid, b, i / k),
    ];
  }

  /// La curva que pasa por [mid] en su mitad: una parábola de dos puntas,
  /// como la de las paredes curvas.
  static Offset _quad(Offset a, Offset mid, Offset b, double t) {
    final ctrl = mid * 2 - (a + b) / 2;
    final u = 1 - t;
    return a * (u * u) + ctrl * (2 * u * t) + b * (t * t);
  }

  static double lengthM(PlanElement el, double mpu) {
    final p = path(el);
    var len = 0.0;
    for (var i = 1; i < p.length; i++) {
      len += (p[i] - p[i - 1]).distance;
    }
    return len * mpu;
  }

  // ── Medidas por tipo ────────────────────────────────────────────────────

  static double _num(PlanElement el, String key, double fallback) =>
      (el.props[key] as num?)?.toDouble() ?? fallback;

  /// Alto: de la barandilla, del bordillo, del hilo de contacto, del casco
  /// o de las columnas.
  static double heightM(PlanElement el) => _num(el, heightKey, switch (kind(el)) {
    SweepKind.railing => 1.0,
    SweepKind.kerb => 0.15,
    SweepKind.skirting => 0.1,
    SweepKind.cornice => 0.18,
    SweepKind.track => 0.52,
    SweepKind.catenary => 5.5,
    SweepKind.deck => 1.0,
    SweepKind.hull => 2.9,
    SweepKind.columns => 3.0,
    SweepKind.seats => 0.9,
    SweepKind.custom => 0.5,
  });

  /// Ancho: del tablero, del casco, de la columna o del perfil propio.
  static double widthM(PlanElement el) => _num(el, widthKey, switch (kind(el)) {
    SweepKind.deck => 6.0,
    SweepKind.hull => 2.9,
    SweepKind.columns => 0.35,
    SweepKind.cornice => 0.2,
    SweepKind.seats => 0.5,
    _ => 0.3,
  });

  /// Desde dónde empieza: la cornisa bajo el techo, el tablero sobre el
  /// suelo, el piso del vagón sobre el carril.
  static double baseM(PlanElement el) => _num(el, baseKey, switch (kind(el)) {
    SweepKind.cornice => 2.4,
    SweepKind.deck => 5.0,
    SweepKind.hull => 1.1,
    _ => 0.0,
  });

  /// Cada cuánto se repite: postes, traviesas, postes de catenaria, pilas,
  /// columnas o asientos.
  static double everyM(PlanElement el) =>
      math.max(0.2, _num(el, everyKey, defaultEveryM(kind(el)) ?? 1));

  static double? defaultEveryM(SweepKind k) => switch (k) {
    SweepKind.railing => 1.2,
    SweepKind.track => 0.6,
    SweepKind.catenary => 50,
    SweepKind.deck => 20,
    SweepKind.columns => 3,
    SweepKind.seats => 0.5,
    _ => null,
  };

  /// Qué medidas tiene sentido tocar en cada tipo.
  static ({bool height, bool width, bool base, bool every}) knobs(
    SweepKind k,
  ) => (
    height: k != SweepKind.track,
    width: switch (k) {
      SweepKind.deck ||
      SweepKind.hull ||
      SweepKind.columns ||
      SweepKind.cornice ||
      SweepKind.seats ||
      SweepKind.custom => true,
      _ => false,
    },
    base: switch (k) {
      SweepKind.cornice || SweepKind.deck || SweepKind.hull => true,
      SweepKind.custom => true,
      _ => false,
    },
    every: defaultEveryM(k) != null,
  );

  /// El material elegido para lo principal, o `null` si el del tipo.
  static ArchMaterial? material(PlanElement el) =>
      ArchMaterials.byId(el.props[ArchMaterials.key] as String?);

  /// El material de lo principal: el elegido o el del tipo.
  static ArchMaterial mainMaterial(PlanElement el) {
    for (final p in parts(el)) {
      if (p.main) return ArchMaterials.byId(p.mat)!;
    }
    for (final r in repeats(el)) {
      if (r.main) return ArchMaterials.byId(r.mat)!;
    }
    return ArchMaterials.byId('concrete-smooth')!;
  }

  /// Otro tipo: vuelve a sus medidas y su material.
  static void setKind(PlanElement el, SweepKind k) {
    el.props[kindKey] = k.name;
    for (final key in [heightKey, widthKey, baseKey, everyKey]) {
      el.props.remove(key);
    }
    el.props.remove(ArchMaterials.key);
  }

  // ── Piezas ──────────────────────────────────────────────────────────────

  static List<Offset> _rect(double a0, double a1, double z0, double z1) => [
    Offset(a0, z0),
    Offset(a1, z0),
    Offset(a1, z1),
    Offset(a0, z1),
  ];

  /// Los perfiles que recorren el camino.
  static List<SweepPart> parts(PlanElement el) {
    final h = heightM(el), w = widthM(el), z = baseM(el);
    final own = material(el)?.id;
    SweepPart main(List<Offset> p, String mat) =>
        SweepPart(p, own ?? mat, main: true);
    switch (kind(el)) {
      case SweepKind.railing:
        return [
          main(_rect(-0.025, 0.025, h - 0.05, h), 'metal-brushed'),
          main(_rect(-0.015, 0.015, 0.08, 0.11), 'metal-brushed'),
        ];
      case SweepKind.kerb:
        return [
          main([
            const Offset(-0.075, 0),
            const Offset(0.075, 0),
            Offset(0.075, h * 0.8),
            Offset(0.05, h),
            Offset(-0.075, h),
          ], 'concrete-smooth'),
        ];
      case SweepKind.skirting:
        return [main(_rect(0, 0.015, 0, h), 'wood-painted')];
      case SweepKind.cornice:
        return [
          main([
            Offset(0, z),
            Offset(w * 0.3, z),
            Offset(w * 0.3, z + h * 0.28),
            Offset(w, z + h * 0.66),
            Offset(w, z + h),
            Offset(0, z + h),
          ], 'plaster-raw'),
        ];
      case SweepKind.track:
        // Ancho ibérico no: el internacional, 1,435 m entre carriles.
        const g = 1.435 / 2 + 0.036;
        List<Offset> rail(double c) => [
          for (final p in const [
            Offset(-0.035, 0.35),
            Offset(0.035, 0.35),
            Offset(0.035, 0.37),
            Offset(0.01, 0.37),
            Offset(0.01, 0.48),
            Offset(0.036, 0.48),
            Offset(0.036, 0.52),
            Offset(-0.036, 0.52),
            Offset(-0.036, 0.48),
            Offset(-0.01, 0.48),
            Offset(-0.01, 0.37),
            Offset(-0.035, 0.37),
          ])
            p + Offset(c, 0),
        ];
        return [
          const SweepPart([
            Offset(-1.8, 0),
            Offset(1.8, 0),
            Offset(1.4, 0.25),
            Offset(-1.4, 0.25),
          ], 'stone-rock'),
          main(rail(-g), 'metal-brushed'),
          main(rail(g), 'metal-brushed'),
        ];
      case SweepKind.catenary:
        return [
          main(_rect(-0.01, 0.01, h, h + 0.02), 'paint-black'),
          main(_rect(-0.01, 0.01, h + 1.2, h + 1.22), 'paint-black'),
        ];
      case SweepKind.deck:
        final top = z + 0.6;
        return [
          main(_rect(-w / 2, w / 2, z, top), 'concrete-smooth'),
          main(_rect(-w / 2, -w / 2 + 0.25, top, top + h), 'concrete-smooth'),
          main(_rect(w / 2 - 0.25, w / 2, top, top + h), 'concrete-smooth'),
        ];
      case SweepKind.hull:
        const t = 0.06;
        final eave = z + h * 0.78;
        final roof = <Offset>[
          for (var k = 0; k <= 12; k++)
            Offset(
              w / 2 * math.cos(math.pi * k / 12),
              eave + (h * 0.22) * math.sin(math.pi * k / 12),
            ),
          for (var k = 12; k >= 0; k--)
            Offset(
              (w / 2 - t) * math.cos(math.pi * k / 12),
              eave - t + (h * 0.22 - t) * math.sin(math.pi * k / 12),
            ),
        ];
        return [
          const SweepPart([
            Offset(-1.2, 0),
            Offset(1.2, 0),
            Offset(1.2, 0.1),
            Offset(-1.2, 0.1),
          ], 'paint-black'),
          SweepPart(_rect(-w / 2, w / 2, z - 0.12, z), 'wood-planks'),
          main(_rect(w / 2 - t, w / 2, z, eave), 'paint-grey'),
          main(_rect(-w / 2, -w / 2 + t, z, eave), 'paint-grey'),
          main(roof, 'paint-grey'),
        ];
      case SweepKind.columns || SweepKind.seats:
        return const [];
      case SweepKind.custom:
        return [main(_rect(-w / 2, w / 2, z, z + h), 'concrete-smooth')];
    }
  }

  /// Lo que se repite a lo largo del camino.
  static List<SweepRepeat> repeats(PlanElement el) {
    final h = heightM(el), w = widthM(el), z = baseM(el), e = everyM(el);
    final own = material(el)?.id;
    switch (kind(el)) {
      case SweepKind.railing:
        return [
          SweepRepeat(
            alongM: 0.04,
            acrossM: 0.04,
            baseM: 0,
            topM: h - 0.05,
            everyM: e,
            ends: true,
            mat: own ?? 'metal-brushed',
            main: true,
          ),
        ];
      case SweepKind.track:
        return [
          SweepRepeat(
            alongM: 0.25,
            acrossM: 2.6,
            baseM: 0.2,
            topM: 0.35,
            everyM: e,
            mat: 'concrete-smooth',
          ),
        ];
      case SweepKind.catenary:
        return [
          SweepRepeat(
            alongM: 0.25,
            acrossM: 0.25,
            baseM: 0,
            topM: h + 1.6,
            offsetM: -2.4,
            everyM: e,
            ends: true,
            mat: 'metal-corrugated',
            blocks: true,
          ),
          SweepRepeat(
            alongM: 0.1,
            acrossM: 2.5,
            baseM: h + 1.15,
            topM: h + 1.28,
            offsetM: -1.2,
            everyM: e,
            ends: true,
            mat: 'metal-corrugated',
          ),
        ];
      case SweepKind.deck:
        return [
          SweepRepeat(
            alongM: 1.5,
            acrossM: w * 0.6,
            baseM: 0,
            topM: z,
            everyM: e,
            mat: 'concrete-smooth',
            blocks: true,
          ),
        ];
      case SweepKind.columns:
        return [
          SweepRepeat(
            alongM: w,
            acrossM: w,
            baseM: 0,
            topM: h,
            everyM: e,
            mat: own ?? 'stone-marble',
            main: true,
            blocks: true,
          ),
        ];
      case SweepKind.seats:
        return [
          SweepRepeat(
            alongM: math.min(e - 0.04, 0.46),
            acrossM: w,
            baseM: 0,
            topM: 0.45,
            everyM: e,
            mat: own ?? 'leather',
            main: true,
          ),
          SweepRepeat(
            alongM: math.min(e - 0.04, 0.46),
            acrossM: 0.08,
            baseM: 0.45,
            topM: h,
            offsetM: -w / 2 + 0.04,
            everyM: e,
            mat: own ?? 'leather',
            main: true,
          ),
        ];
      case SweepKind.kerb ||
          SweepKind.skirting ||
          SweepKind.cornice ||
          SweepKind.hull ||
          SweepKind.custom:
        return const [];
    }
  }

  /// Lo que tapa la luz, a lo largo del camino.
  static List<SweepScreen> screens(PlanElement el) {
    final h = heightM(el), w = widthM(el), z = baseM(el);
    return switch (kind(el)) {
      SweepKind.railing => [
        (acrossM: 0, baseM: 0, topM: h, transmission: 0.75),
      ],
      SweepKind.kerb => [(acrossM: 0, baseM: 0, topM: h, transmission: 0)],
      SweepKind.deck => [
        for (final a in [-w / 2, w / 2])
          (acrossM: a, baseM: z, topM: z + 0.6 + h, transmission: 0),
      ],
      SweepKind.hull => [
        for (final a in [-w / 2, w / 2])
          (acrossM: a, baseM: z, topM: z + h * 0.78, transmission: 0),
      ],
      SweepKind.custom => [
        (acrossM: 0, baseM: z, topM: z + h, transmission: 0),
      ],
      _ => const [],
    };
  }

  /// Si va por encima de la cabeza: la planta lo dibuja a trazos.
  static bool isOverhead(PlanElement el) => switch (kind(el)) {
    SweepKind.cornice || SweepKind.catenary => true,
    SweepKind.deck || SweepKind.custom => baseM(el) >= 2.0,
    _ => false,
  };

  // ── Geometría ───────────────────────────────────────────────────────────

  /// Los puntos del camino con su dirección y su izquierda. En las
  /// esquinas, la izquierda es la de inglete: lo que hay a un lado sigue
  /// paralelo al camino.
  static List<SweepFrame> frames(PlanElement el, double mpu) =>
      _frames(path(el), mpu);

  static List<SweepFrame> _frames(List<Offset> p, double mpu) {
    final out = <SweepFrame>[];
    var s = 0.0;
    for (var i = 0; i < p.length; i++) {
      if (i > 0) s += (p[i] - p[i - 1]).distance * mpu;
      Offset unit(Offset d) =>
          d.distance < 1e-9 ? const Offset(1, 0) : d / d.distance;
      final before = i > 0 ? unit(p[i] - p[i - 1]) : null;
      final after = i + 1 < p.length ? unit(p[i + 1] - p[i]) : null;
      final along = before != null && after != null
          ? unit(before + after)
          : (after ?? before!);
      Offset leftOf(Offset t) => Offset(t.dy, -t.dx);
      var left = leftOf(along);
      if (before != null && after != null) {
        final cos = left.dx * leftOf(before).dx + left.dy * leftOf(before).dy;
        left = left / math.max(0.34, cos);
      }
      out.add((at: p[i], along: along, left: left, s: s));
    }
    return out;
  }

  /// Un punto a [sM] metros del arranque, con su dirección.
  static SweepFrame frameAt(List<SweepFrame> f, double sM) {
    for (var i = 1; i < f.length; i++) {
      if (sM <= f[i].s + 1e-9 || i == f.length - 1) {
        final a = f[i - 1], b = f[i];
        final t = b.s - a.s < 1e-9 ? 0.0 : ((sM - a.s) / (b.s - a.s)).clamp(0.0, 1.0);
        final d = b.at - a.at;
        final along = d.distance < 1e-9 ? a.along : d / d.distance;
        return (
          at: Offset.lerp(a.at, b.at, t)!,
          along: along,
          left: Offset(along.dy, -along.dx),
          s: sM,
        );
      }
    }
    return f.first;
  }

  /// Dónde va cada repetición, en metros desde el arranque: con puntas,
  /// de punta a punta sin pasar de [SweepRepeat.everyM]; sin ellas,
  /// repartidas por dentro.
  static List<double> stations(SweepRepeat r, double lengthM) {
    if (lengthM < 1e-6) return const [0];
    if (r.ends) {
      final n = math.max(1, (lengthM / r.everyM - 1e-9).ceil());
      return [for (var k = 0; k <= n; k++) lengthM * k / n];
    }
    final n = math.max(1, (lengthM / r.everyM + 1e-9).floor());
    return [for (var k = 0; k < n; k++) lengthM * (k + 0.5) / n];
  }

  /// Cada repetición como un tramo corto del camino, para barrer su caja.
  static List<(SweepRepeat, List<SweepFrame>)> instances(
    PlanElement el,
    double mpu,
  ) {
    final f = frames(el, mpu);
    final len = f.last.s;
    final out = <(SweepRepeat, List<SweepFrame>)>[];
    for (final r in repeats(el)) {
      for (final s in stations(r, len)) {
        final c = frameAt(f, s);
        final half = r.alongM / 2 / mpu;
        out.add((
          r,
          [
            (at: c.at - c.along * half, along: c.along, left: c.left, s: s),
            (at: c.at + c.along * half, along: c.along, left: c.left, s: s),
          ],
        ));
      }
    }
    return out;
  }

  /// Un punto de un perfil puesto en el lienzo.
  static Offset place(SweepFrame f, double acrossM, double mpu) =>
      f.at + f.left * (acrossM / mpu);

  /// La huella en planta de un perfil: de su borde izquierdo al derecho.
  static List<Offset> band(
    List<SweepFrame> f,
    double a0,
    double a1,
    double mpu,
  ) => [
    for (final x in f) place(x, a1, mpu),
    for (final x in f.reversed) place(x, a0, mpu),
  ];

  /// Las huellas de todo: perfiles y repeticiones.
  static List<List<Offset>> footprints(PlanElement el, double mpu) {
    final f = frames(el, mpu);
    return [
      for (final p in parts(el)) band(f, p.minAcross, p.maxAcross, mpu),
      for (final (r, g) in instances(el, mpu))
        band(g, r.offsetM - r.acrossM / 2, r.offsetM + r.acrossM / 2, mpu),
    ];
  }

  static bool contains(PlanElement el, Offset p, double mpu) {
    for (final poly in footprints(el, mpu)) {
      if (_inside(poly, p)) return true;
    }
    final pts = path(el);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i], d = b - a;
      final len2 = d.dx * d.dx + d.dy * d.dy;
      final t = len2 < 1e-9
          ? 0.0
          : (((p - a).dx * d.dx + (p - a).dy * d.dy) / len2).clamp(0.0, 1.0);
      if ((p - (a + d * t)).distance < 10) return true;
    }
    return false;
  }

  /// La malla: por material, triángulos con cada vértice en el lienzo (x,
  /// y) y su altura en metros (z). Las caras miran hacia fuera.
  static Map<String, List<double>> mesh(PlanElement el, double mpu) {
    final out = <String, List<double>>{};
    final f = frames(el, mpu);
    for (final p in parts(el)) {
      _extrude(f, p.profile, mpu, out.putIfAbsent(p.mat, () => []));
    }
    for (final (r, g) in instances(el, mpu)) {
      _extrude(g, r.profile, mpu, out.putIfAbsent(r.mat, () => []));
    }
    return out;
  }

  static void _extrude(
    List<SweepFrame> f,
    List<Offset> profile,
    double mpu,
    List<double> out,
  ) {
    if (f.length < 2 || profile.length < 3) return;
    final prof = _ccw(profile);
    void v(SweepFrame x, Offset q) {
      final c = place(x, q.dx, mpu);
      out.addAll([c.dx, c.dy, q.dy]);
    }

    for (var i = 0; i + 1 < f.length; i++) {
      final s0 = f[i], s1 = f[i + 1];
      for (var j = 0; j < prof.length; j++) {
        final a = prof[j], b = prof[(j + 1) % prof.length];
        v(s0, a);
        v(s0, b);
        v(s1, b);
        v(s0, a);
        v(s1, b);
        v(s1, a);
      }
    }
    // Las tapas: al principio mira hacia atrás y al final hacia delante.
    for (final (i, j, k) in _triangulate(prof)) {
      v(f.first, prof[i]);
      v(f.first, prof[k]);
      v(f.first, prof[j]);
      v(f.last, prof[i]);
      v(f.last, prof[j]);
      v(f.last, prof[k]);
    }
  }

  static double _area(List<Offset> p) {
    var a = 0.0;
    for (var i = 0; i < p.length; i++) {
      final q = p[(i + 1) % p.length];
      a += p[i].dx * q.dy - q.dx * p[i].dy;
    }
    return a / 2;
  }

  static List<Offset> _ccw(List<Offset> p) =>
      _area(p) < 0 ? p.reversed.toList() : p;

  /// Triángulos de un polígono antihorario, cortando orejas.
  static List<(int, int, int)> _triangulate(List<Offset> p) {
    final idx = [for (var i = 0; i < p.length; i++) i];
    final out = <(int, int, int)>[];
    double cross(Offset a, Offset b, Offset c) =>
        (b.dx - a.dx) * (c.dy - a.dy) - (b.dy - a.dy) * (c.dx - a.dx);
    var guard = 0;
    while (idx.length > 3 && guard++ < 1000) {
      var cut = false;
      for (var k = 0; k < idx.length; k++) {
        final i = idx[(k + idx.length - 1) % idx.length];
        final j = idx[k];
        final l = idx[(k + 1) % idx.length];
        if (cross(p[i], p[j], p[l]) <= 1e-12) continue;
        var inside = false;
        for (final m in idx) {
          if (m == i || m == j || m == l) continue;
          if (cross(p[i], p[j], p[m]) >= 0 &&
              cross(p[j], p[l], p[m]) >= 0 &&
              cross(p[l], p[i], p[m]) >= 0) {
            inside = true;
            break;
          }
        }
        if (inside) continue;
        out.add((i, j, l));
        idx.removeAt(k);
        cut = true;
        break;
      }
      if (!cut) break;
    }
    if (idx.length == 3) out.add((idx[0], idx[1], idx[2]));
    return out;
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

  /// «Barandilla · 12,0 m · postes cada 1,20 m».
  static String summary(PlanElement el, double mpu) {
    String m(double v) => v.toStringAsFixed(v < 10 ? 2 : 1).replaceAll('.', ',');
    final k = kind(el);
    final len = lengthM(el, mpu);
    final every = defaultEveryM(k) == null
        ? ''
        : ' · ${switch (k) {
            SweepKind.railing => 'postes',
            SweepKind.track => 'traviesas',
            SweepKind.catenary => 'postes',
            SweepKind.deck => 'pilas',
            SweepKind.columns => 'columnas',
            SweepKind.seats => 'asientos',
            _ => 'piezas',
          }} cada ${m(everyM(el))} m';
    return '${k.label} · ${m(len)} m$every';
  }
}
