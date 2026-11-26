import 'dart:math' as math;
import 'dart:ui';

import '../camera_plan_element_model.dart';
import '../light/rooms.dart';
import '../light_overrides.dart';
import '../rig/plan_rig.dart';
import 'arch_material.dart';
import 'arch_roof.dart';

/// Forjados y volúmenes (plan AM.2): un contorno en planta estirado en
/// altura, como el empujar/tirar de SketchUp.
///
/// - **Forjado:** una losa con su grosor y la cota de arriba: una tarima,
///   una acera, un andén, un escenario o la entreplanta de encima.
/// - **Volumen:** del suelo a una altura: una barra, una caseta, un
///   plinto, un banco o un bloque de edificio.
///
/// Se guardan como `prop` con `label` `slab` o `volume` ([RigType]); el
/// contorno va en metros respecto a `position` y gira con `rotation`.
abstract final class ArchSolid {
  /// Contorno en metros: `[[x, y], …]`, y hacia abajo como el lienzo.
  static const outlineKey = 'outlineM';

  /// Volumen: alto desde su suelo.
  static const heightKey = 'heightM';

  /// Forjado: cota de su cara de arriba sobre el suelo, y su grosor.
  static const topKey = 'topM';
  static const thickKey = 'thickM';

  static const double defaultVolumeM = 1.1;
  static const double defaultSlabTopM = 0.4;
  static const double defaultSlabThickM = 0.2;

  /// Volumen: su cubierta (AM.3), `ArchRoof` en JSON. Sin ella, plano.
  static const roofKey = 'roof';

  static const defaultSlabMat = 'wood-floor-oak';
  static const defaultVolumeMat = 'paint-white';

  static bool isSlab(PlanElement el) => RigTypeCodec.of(el) == RigType.slab;
  static bool isVolume(PlanElement el) =>
      RigTypeCodec.of(el) == RigType.volume;
  static bool isSolid(PlanElement el) => isSlab(el) || isVolume(el);

  /// Un rectángulo de esquina a esquina (en el lienzo), con el centro en
  /// su sitio.
  static PlanElement rectangle(
    RigType kind,
    Offset a,
    Offset b,
    double metersPerUnit,
  ) {
    assert(kind == RigType.slab || kind == RigType.volume);
    final centre = (a + b) / 2;
    final hw = (b.dx - a.dx).abs() / 2 * metersPerUnit;
    final hd = (b.dy - a.dy).abs() / 2 * metersPerUnit;
    return create(kind, centre, [
      Offset(-hw, -hd),
      Offset(hw, -hd),
      Offset(hw, hd),
      Offset(-hw, hd),
    ]);
  }

  /// Con un contorno cualquiera, en metros respecto a [origin].
  static PlanElement create(
    RigType kind,
    Offset origin,
    List<Offset> outlineM,
  ) {
    final el = RigTypeCodec.create(
      kind,
      origin,
      props: {
        outlineKey: [
          for (final p in outlineM) [_r(p.dx), _r(p.dy)],
        ],
        if (kind == RigType.volume) heightKey: defaultVolumeM,
        if (kind == RigType.slab) ...{
          topKey: defaultSlabTopM,
          thickKey: defaultSlabThickM,
        },
        ArchMaterials.key: kind == RigType.slab
            ? defaultSlabMat
            : defaultVolumeMat,
      },
    );
    LightOverrides.ensureUids([el]);
    return el;
  }

  /// Con la forma del recinto cerrado de paredes en que cae [p], o
  /// `null` si no cae en ninguno.
  static PlanElement? fromRoom(
    RigType kind,
    List<PlanRoom> rooms,
    Offset p,
    double metersPerUnit,
  ) {
    PlanRoom? best;
    for (final r in rooms) {
      if (!r.contains(p)) continue;
      // El más pequeño que lo contiene (una habitación dentro de la casa).
      if (best == null || r.area.abs() < best.area.abs()) best = r;
    }
    if (best == null || best.polygon.length < 3) return null;
    final poly = best.polygon;
    final centre =
        poly.reduce((a, b) => a + b) / poly.length.toDouble();
    return create(kind, centre, [
      for (final q in poly) (q - centre) * metersPerUnit,
    ]);
  }

  /// Huecos (el de una escalera, un patio): contornos en metros respecto
  /// al centro, como el contorno.
  static const holesKey = 'holes';

  static List<List<Offset>> holesM(PlanElement el) {
    final raw = el.props[holesKey];
    if (raw is! List) return const [];
    return [
      for (final h in raw)
        if (h is List)
          [
            for (final p in h)
              if (p is List && p.length >= 2)
                Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
          ],
    ].where((h) => h.length >= 3).toList();
  }

  static void setHoles(PlanElement el, List<List<Offset>> holes) {
    if (holes.isEmpty) {
      el.props.remove(holesKey);
      return;
    }
    el.props[holesKey] = [
      for (final h in holes)
        [
          for (final p in h) [_r(p.dx), _r(p.dy)],
        ],
    ];
  }

  /// Los huecos en el lienzo, girados con el elemento.
  static List<List<Offset>> holes(PlanElement el, double metersPerUnit) => [
    for (final h in holesM(el))
      [for (final p in h) toCanvas(el, p, metersPerUnit)],
  ];

  /// Contorno en metros, sin girar.
  static List<Offset> outlineM(PlanElement el) {
    final raw = el.props[outlineKey];
    if (raw is! List) return const [];
    return [
      for (final p in raw)
        if (p is List && p.length >= 2)
          Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()),
    ];
  }

  /// Contorno en el lienzo, girado con el elemento.
  static List<Offset> outline(PlanElement el, double metersPerUnit) {
    final rad = el.rotation * math.pi / 180;
    final c = math.cos(rad), s = math.sin(rad);
    return [
      for (final p in outlineM(el))
        el.position +
            Offset(p.dx * c - p.dy * s, p.dx * s + p.dy * c) / metersPerUnit,
    ];
  }

  /// Ancho y fondo del contorno, en metros (su caja sin girar).
  static Size sizeM(PlanElement el) {
    final pts = outlineM(el);
    if (pts.isEmpty) return Size.zero;
    final xs = pts.map((p) => p.dx), ys = pts.map((p) => p.dy);
    return Size(xs.reduce(math.max) - xs.reduce(math.min),
        ys.reduce(math.max) - ys.reduce(math.min));
  }

  /// Escala el contorno hasta [size] (en metros) sin moverlo de su centro.
  static void resize(PlanElement el, Size size) {
    final now = sizeM(el);
    if (now.width <= 0 || now.height <= 0) return;
    final pts = outlineM(el);
    final cx = pts.map((p) => p.dx).reduce((a, b) => a + b) / pts.length;
    final cy = pts.map((p) => p.dy).reduce((a, b) => a + b) / pts.length;
    final kx = size.width / now.width, ky = size.height / now.height;
    el.props[outlineKey] = [
      for (final p in pts)
        [_r(cx + (p.dx - cx) * kx), _r(cy + (p.dy - cy) * ky)],
    ];
  }

  /// Área en planta, m² (sin sus huecos).
  static double areaM2(PlanElement el) {
    double of(List<Offset> p) {
      var a = 0.0;
      for (var i = 0; i < p.length; i++) {
        final q = p[(i + 1) % p.length];
        a += p[i].dx * q.dy - q.dx * p[i].dy;
      }
      return a.abs() / 2;
    }

    return math.max(
      0.0,
      of(outlineM(el)) - holesM(el).fold(0.0, (s, h) => s + of(h)),
    );
  }

  static double heightM(PlanElement el) =>
      (el.props[heightKey] as num?)?.toDouble() ?? defaultVolumeM;
  static double slabTopM(PlanElement el) =>
      (el.props[topKey] as num?)?.toDouble() ?? defaultSlabTopM;
  static double slabThickM(PlanElement el) =>
      (el.props[thickKey] as num?)?.toDouble() ?? defaultSlabThickM;

  /// La cubierta de un volumen, si no es plana.
  static ArchRoof? roof(PlanElement el) {
    if (!isVolume(el)) return null;
    final r = ArchRoof.fromJson(el.props[roofKey]);
    return r == null || r.kind == ArchRoofKind.flat || r.riseM <= 0 ? null : r;
  }

  static void setRoof(PlanElement el, ArchRoof? roof) {
    if (roof == null || roof.kind == ArchRoofKind.flat) {
      el.props.remove(roofKey);
    } else {
      el.props[roofKey] = roof.toJson();
    }
  }

  /// Cota de arriba sobre el suelo de su nivel, en metros: con cubierta,
  /// la de la cumbrera.
  static double topM(PlanElement el) => isSlab(el)
      ? slabTopM(el)
      : heightM(el) + (roof(el)?.peakM ?? 0);

  /// Un punto del lienzo en metros del contorno (sin girar).
  static Offset toLocalM(PlanElement el, Offset p, double metersPerUnit) {
    final rad = -el.rotation * math.pi / 180;
    final c = math.cos(rad), s = math.sin(rad);
    final v = (p - el.position) * metersPerUnit;
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  /// Un punto del contorno (metros, sin girar) en el lienzo.
  static Offset toCanvas(PlanElement el, Offset m, double metersPerUnit) {
    final rad = el.rotation * math.pi / 180;
    final c = math.cos(rad), s = math.sin(rad);
    return el.position +
        Offset(m.dx * c - m.dy * s, m.dx * s + m.dy * c) / metersPerUnit;
  }

  /// Altura de lo de arriba en un punto del lienzo: el alero más lo que
  /// sube la cubierta ahí.
  static double topAt(PlanElement el, Offset p, double metersPerUnit) {
    final r = roof(el);
    if (r == null) return topM(el);
    return heightM(el) +
        r.riseAt(outlineM(el), toLocalM(el, p, metersPerUnit));
  }

  /// Cota de abajo: un volumen arranca del suelo; un forjado, de su
  /// cara de arriba menos su grosor (nunca por debajo del suelo).
  static double bottomM(PlanElement el) => !isSlab(el)
      ? 0
      // Bajo tierra (un túnel, un sótano), su grosor entero hacia abajo.
      : slabTopM(el) <= 0
      ? slabTopM(el) - slabThickM(el)
      : math.max(0.0, slabTopM(el) - slabThickM(el));

  /// Un forjado por encima de la cabeza (entreplanta, techo): en la
  /// planta va a trazos, como lo que está por encima del corte.
  static bool isOverhead(PlanElement el) => isSlab(el) && bottomM(el) > 2;

  static ArchMaterial material(PlanElement el) =>
      ArchMaterials.byId(el.props[ArchMaterials.key] as String?) ??
      ArchMaterials.byId(isSlab(el) ? defaultSlabMat : defaultVolumeMat)!;

  /// El punto del lienzo cae dentro del contorno (y no en un hueco).
  static bool contains(PlanElement el, Offset p, double metersPerUnit) {
    bool inPoly(List<Offset> poly) {
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

    return inPoly(outline(el, metersPerUnit)) &&
        !holes(el, metersPerUnit).any(inPoly);
  }

  static double _r(double v) => (v * 1000).round() / 1000;
}
