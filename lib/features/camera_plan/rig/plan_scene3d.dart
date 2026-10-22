import 'dart:math' as math;
import 'dart:ui';

import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import '../light/plan_light.dart';
import '../light_beam.dart';
import '../light_overrides.dart';
import '../plan_opening.dart';
import '../plan_segment.dart';
import 'plan_drape.dart';
import 'plan_hall.dart';
import 'plan_rig.dart';

/// La planta resuelta en 3D: metros, z hacia arriba, todo ya calculado
/// (alturas, catenarias, huecos, hacia dónde apunta cada luz). La leen el
/// visor 3D y, más adelante, la hoja PDF y las exportaciones a glTF y MVR.
/// No se guarda: sale siempre de la planta.
///
/// Ejes: x igual que el lienzo, y al revés que el lienzo (hacia arriba en
/// la pantalla), z hacia arriba. Formato `iris.scene3d` versión 1.
class PlanScene3d {
  PlanScene3d._();

  static const format = 'iris.scene3d';
  static const version = 1;

  /// Altura de una pared suelta sin nave.
  static const double defaultWallM = 2.5;

  /// Distancia del lienzo a la que un hueco se considera puesto en una
  /// pared.
  static const double _openingTolerance = 24;

  static Map<String, dynamic> build(
    List<PlanElement> elements, {
    required double metersPerUnit,
    String? name,
  }) {
    final mpu = metersPerUnit;
    List<double> xy(Offset p) => [_r(p.dx * mpu), _r(-p.dy * mpu)];
    final halls = <String, (PlanElement, HallRecipe)>{};
    for (final el in elements) {
      if (!PlanHall.isHall(el)) continue;
      final recipe = PlanHall.recipeOf(el);
      final uid = LightOverrides.uidOf(el);
      if (recipe != null && uid != null) halls[uid] = (el, recipe);
    }
    // Altura de la cubierta de una nave en un punto del lienzo.
    double? roofAt(String? hallUid, Offset canvas) {
      final h = halls[hallUid];
      if (h == null) return null;
      return h.$2.roofAt((canvas - h.$1.position) * mpu);
    }

    final out = <String, dynamic>{
      'format': format,
      'version': version,
      'units': 'm',
      'name': ?name,
      'halls': [
        for (final MapEntry(key: uid, value: (el, r)) in halls.entries)
          _hall(uid, el, r, mpu),
      ],
    };

    final openings = elements.where(PlanOpening.isOpening).toList();
    final walls = <Map<String, dynamic>>[];
    final drapes = <Map<String, dynamic>>[];
    final pillars = <Map<String, dynamic>>[];
    final trusses = <Map<String, dynamic>>[];
    final rigging = <Map<String, dynamic>>[];
    final fixtures = <Map<String, dynamic>>[];
    final people = <Map<String, dynamic>>[];
    final cameras = <Map<String, dynamic>>[];

    for (final el in elements) {
      final level = PlanLevel.of(el);
      final uid = LightOverrides.uidOf(el);
      if (PlanDrape.isDrape(el)) {
        drapes.add(_drape(el, mpu, level, xy));
        continue;
      }
      if (PlanSegment.isSegment(el)) {
        if (PlanSegment.kind(el) != PlanSegment.kindWall) continue;
        walls.add(_wall(el, openings, mpu, level, xy, roofAt));
        continue;
      }
      switch (RigTypeCodec.of(el)) {
        case RigType.pillar:
          pillars.add({
            'id': ?uid,
            'at': xy(el.position),
            'z0': level,
            'shape': PlanPillar.isRound(el) ? 'round' : 'square',
            'sizeM': PlanPillar.sizeM(el),
            'heightM': _r(
              roofAt(PlanHall.hallUidOf(el), el.position) ??
                  PlanPillar.heightM(el),
            ),
          });
        case RigType.truss:
          trusses.add({
            'id': ?uid,
            'from': xy(PlanTruss.start(el)),
            'to': xy(PlanTruss.end(el)),
            'z': _r(level + PlanTruss.lowM(el)),
            'profile': PlanTruss.profile(el).name,
            'sizeCm': PlanTruss.sizeCm(el),
            if (el.props[PlanTruss.apexDownKey] == true) 'apexDown': true,
            'pieces': PlanTruss.pieces(el, mpu).pieces,
          });
        case RigType.motor || RigType.groundSupport:
          rigging.add({
            'id': ?uid,
            'type': RigTypeCodec.of(el)!.name,
            'at': xy(el.position),
            'z0': level,
            'truss': el.props[PlanRigPoint.trussKey],
            'wllKg': PlanRigPoint.wllKg(el),
          });
        case RigType.hall || RigType.scan || null:
          break;
      }
      switch (el.type) {
        case ElementType.light:
          final f = _fixture(el, mpu, level, xy);
          if (f != null) fixtures.add(f);
        case ElementType.actor:
          people.add({
            'id': ?uid,
            'name': el.label ?? 'Actor',
            'at': xy(el.position),
            'z0': level,
          });
        case ElementType.camera:
          final rad = el.rotation * math.pi / 180;
          cameras.add({
            'id': ?uid,
            'name': el.cameraLabel,
            'at': xy(el.position),
            'z0': level,
            'dir': [_r(math.sin(rad)), _r(math.cos(rad))],
          });
        default:
          break;
      }
    }
    out
      ..['walls'] = walls
      ..['drapes'] = drapes
      ..['pillars'] = pillars
      ..['trusses'] = trusses
      ..['rigging'] = rigging
      ..['fixtures'] = fixtures
      ..['people'] = people
      ..['cameras'] = cameras;
    return out;
  }

  static double _r(double v) => (v * 1000).roundToDouble() / 1000;

  static Map<String, dynamic> _hall(
    String uid,
    PlanElement el,
    HallRecipe r,
    double mpu,
  ) {
    // La cubierta se manda muestreada: una rejilla de alturas recortada al
    // perímetro. Así el visor no repite la geometría de la receta.
    final poly = r.polygon(stepM: 0.5);
    var minX = double.infinity, maxX = -double.infinity;
    var minY = double.infinity, maxY = -double.infinity;
    for (final p in poly) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    const cell = 0.5;
    final nx = math.max(2, ((maxX - minX) / cell).ceil());
    final ny = math.max(2, ((maxY - minY) / cell).ceil());
    final z = <double>[];
    for (var j = 0; j <= ny; j++) {
      for (var i = 0; i <= nx; i++) {
        final p = Offset(
          minX + (maxX - minX) * i / nx,
          minY + (maxY - minY) * j / ny,
        );
        z.add(_r(r.roofAt(p)));
      }
    }
    final origin = el.position * mpu;
    List<double> m(Offset p) => [_r(origin.dx + p.dx), _r(-(origin.dy + p.dy))];
    return {
      'id': uid,
      'z0': r.levelM,
      'eaveM': r.eaveM,
      'roof': r.roof.name,
      'outline': [for (final p in poly) m(p)],
      // Fila j recorre la y del lienzo hacia abajo: en el visor, hacia -y.
      'roofGrid': {
        'origin': m(Offset(minX, minY)),
        'stepX': _r((maxX - minX) / nx),
        'stepY': _r(-(maxY - minY) / ny),
        'nx': nx,
        'ny': ny,
        'z': z,
      },
    };
  }

  static Map<String, dynamic> _wall(
    PlanElement el,
    List<PlanElement> openings,
    double mpu,
    double level,
    List<double> Function(Offset) xy,
    double? Function(String?, Offset) roofAt,
  ) {
    final steps = PlanSegment.curve(el) == 0 ? 1 : 16;
    final pts = [
      for (var k = 0; k <= steps; k++) PlanSegment.pointAt(el, k / steps),
    ];
    final cum = <double>[0];
    for (var k = 1; k < pts.length; k++) {
      cum.add(cum.last + (pts[k] - pts[k - 1]).distance);
    }
    final hallUid = PlanHall.hallUidOf(el);
    final fixed = (el.props[PlanPillar.heightKey] as num?)?.toDouble();
    final tops = [
      for (final p in pts) _r(roofAt(hallUid, p) ?? fixed ?? defaultWallM),
    ];
    final holes = <Map<String, dynamic>>[];
    for (final o in openings) {
      // Dónde cae el centro del hueco sobre la pared.
      var best = double.infinity, along = 0.0;
      for (var k = 1; k < pts.length; k++) {
        final a = pts[k - 1], ab = pts[k] - a;
        final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
        if (len2 == 0) continue;
        final t =
            (((o.position.dx - a.dx) * ab.dx + (o.position.dy - a.dy) * ab.dy) /
                    len2)
                .clamp(0.0, 1.0);
        final d = (o.position - (a + ab * t)).distance;
        if (d < best) {
          best = d;
          along = cum[k - 1] + (cum[k] - cum[k - 1]) * t;
        }
      }
      if (best > _openingTolerance) continue;
      final half = PlanOpening.width(o) / 2;
      holes.add({
        'from': _r(math.max(0, along - half) * mpu),
        'to': _r(math.min(cum.last, along + half) * mpu),
        'sill': PlanOpening.sill(o),
        'head': PlanOpening.head(o),
        'kind': PlanOpening.isWindow(o)
            ? 'window'
            : PlanOpening.isDoor(o)
            ? 'door'
            : 'gap',
        if (PlanOpening.isWindow(o) && !PlanOpening.solidLeaves(o))
          'glass': true,
      });
    }
    holes.sort((a, b) => (a['from'] as double).compareTo(b['from'] as double));
    return {
      'id': ?LightOverrides.uidOf(el),
      'points': [for (final p in pts) xy(p)],
      'z0': level,
      'tops': tops,
      'openings': holes,
    };
  }

  static Map<String, dynamic> _drape(
    PlanElement el,
    double mpu,
    double level,
    List<double> Function(Offset) xy,
  ) {
    final c = PlanDrape.catenary(el, mpu);
    final n = math.max(8, (c.span * 6).ceil());
    final mat = PlanDrape.material(el);
    final color = PlanDrape.color(el);
    return {
      'id': ?LightOverrides.uidOf(el),
      'z0': level,
      'material': mat.id,
      'color':
          '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
      'transmission': mat.transmission,
      'fullness': PlanDrape.fullness(el),
      'sagM': _r(c.sag),
      'ropeM': _r(c.rope),
      'samples': [
        for (var k = 0; k <= n; k++)
          {
            'p': xy(PlanSegment.pointAt(el, k / n)),
            'top': _r(PlanDrape.topAt(el, k / n, c)),
            'bottom': _r(PlanDrape.bottomAt(el, k / n, c)),
          },
      ],
    };
  }

  static Map<String, dynamic>? _fixture(
    PlanElement el,
    double mpu,
    double level,
    List<double> Function(Offset) xy,
  ) {
    final type = el.lightType;
    if (type == null || type == LightType.sun) return null;
    final beam = LightBeam.of(el);
    final rad = el.rotation * math.pi / 180;
    // Hacia dónde mira en planta, con los ejes del visor.
    final hx = math.sin(rad), hy = math.cos(rad);
    final z = level + PlanLight.heightOf(el);
    final double dx, dy, dz;
    if (PlanLight.isOverhead(el)) {
      final tilt = PlanLight.tiltOf(el) * math.pi / 180;
      dx = math.sin(tilt) * hx;
      dy = math.sin(tilt) * hy;
      dz = -math.cos(tilt);
    } else {
      final len = math.sqrt(1 + 0.15 * 0.15);
      dx = hx / len;
      dy = hy / len;
      dz = -0.15 / len;
    }
    // Apunta al suelo si llega; si no, a lo que alcanza el haz.
    final reach = (beam?.reach ?? 300) * mpu;
    final t = dz < -0.02 ? math.min((z - level) / -dz, reach) : reach;
    final p = xy(el.position);
    final light = PlanLight.of(el);
    return {
      'id': ?LightOverrides.uidOf(el),
      'name': el.label?.isNotEmpty == true ? el.label : type.label,
      'type': type.dbValue,
      'pos': [p[0], p[1], _r(z)],
      'aim': [_r(p[0] + dx * t), _r(p[1] + dy * t), _r(z + dz * t)],
      'beamDeg': beam?.spread ?? 360,
      'cct': beam?.cct ?? 3200,
      'watts': ?light?.watts,
      'on': beam != null && !beam.off,
      if (TrussMagnet.trussUidOf(el) != null)
        'truss': TrussMagnet.trussUidOf(el),
    };
  }
}
