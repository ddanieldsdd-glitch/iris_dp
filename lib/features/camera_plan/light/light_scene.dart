import 'dart:math' as math;
import 'dart:ui';

import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import '../plan_opening.dart';
import '../plan_segment.dart';
import 'ambient.dart';
import 'modifiers.dart';
import 'photometry.dart';
import 'plan_light.dart';
import 'surfaces.dart';

/// Algo que se interpone entre una luz y un punto: una pared, una ventana,
/// una bandera, una persona. [transmission] es la parte de la luz que deja
/// pasar; [miredShift], el tinte que le da (una gelatina).
class LightBlocker {
  final Offset a;
  final Offset b;

  /// Si es mayor que cero, el tope es un círculo de este radio centrado en
  /// [a] (una persona, una cámara) y [b] no cuenta.
  final double radius;
  final double transmission;
  final double miredShift;

  /// Elemento de la planta del que sale, si lo hay.
  final PlanElement? element;

  const LightBlocker(
    this.a,
    this.b, {
    this.transmission = 0,
    this.miredShift = 0,
    this.element,
  }) : radius = 0;

  const LightBlocker.circle(Offset centre, this.radius, {this.element})
    : a = centre,
      b = centre,
      transmission = 0,
      miredShift = 0;

  bool get isOpaque => transmission <= 0;
  bool get isCircle => radius > 0;
}

/// Una fuente dentro de la planta: un aparato, o una superficie que
/// devuelve o deja pasar la luz de un aparato (un rebote, un marco de
/// difusión, una pared).
class SceneLight {
  final LightSource source;
  final Offset position;

  /// Hacia dónde emite: el eje del haz.
  final Offset aim;

  /// Solo emite hacia delante: una superficie no ilumina a su espalda.
  final bool frontOnly;

  /// Lo que es por dentro: la luz de un aparato, o `null` si es una
  /// superficie.
  final PlanLight? fixture;

  /// El tope del que sale (el rebote, la tela, la pared), para que no se
  /// tape a sí mismo.
  final LightBlocker? surface;
  final String label;

  const SceneLight({
    required this.source,
    required this.position,
    required this.aim,
    required this.label,
    this.frontOnly = false,
    this.fixture,
    this.surface,
  });

  bool get isSecondary => fixture == null;
}

/// Lo que aporta una fuente a un punto.
class LightContribution {
  final SceneLight light;
  final double lux;

  /// Temperatura de color con la que llega, tras lo que atraviesa.
  final double cct;

  const LightContribution(this.light, this.lux, this.cct);
}

/// La planta vista por la luz: las fuentes, lo que las tapa y la escala.
/// Con ella se calcula cuánta luz llega a cualquier punto.
class LightScene {
  final List<SceneLight> lights;
  final List<LightBlocker> blockers;

  /// Metros por unidad del lienzo.
  final double metersPerUnit;

  /// Sol, cielo y rebote de paredes. `null` = sala a oscuras, sin ventanas
  /// al exterior: solo la luz que ponemos.
  final PlanAmbient? ambient;

  const LightScene({
    required this.lights,
    required this.blockers,
    required this.metersPerUnit,
    this.ambient,
  });

  /// Largo de partida de una pieza de grip o de una pared suelta, en
  /// unidades del lienzo.
  static const double pieceWidth = 60;

  /// Luz que deja pasar el cristal de una ventana.
  static const double glassTransmission = 0.9;

  /// Radio del cuerpo de una persona y de una cámara, en metros.
  static const double bodyRadiusM = 0.25;

  /// Altura de pared que cuenta para el rebote de sala, en metros.
  static const double wallHeightM = 2.5;

  /// A qué distancia de una pared se considera que una ventana o una puerta
  /// está puesta en ella.
  static const double _mountTolerance = 24;

  static const lenKey = 'len';
  static const materialKey = 'material';
  static const noShadowKey = 'noShadow';

  /// Largo de una pieza de grip, en unidades del lienzo.
  static double lengthOf(PlanElement el) =>
      (el.props[lenKey] as num?)?.toDouble() ?? pieceWidth;

  factory LightScene.from(
    Iterable<PlanElement> elements, {
    required double metersPerUnit,
    bool wallBounce = true,
    PlanAmbient? ambient,
  }) {
    final all = elements.toList();
    final bounce = wallBounce && (ambient?.wallBounce ?? true);
    final blockers = blockersOf(all, metersPerUnit: metersPerUnit);
    final fixtures = <SceneLight>[
      for (final el in all)
        if (PlanLight.of(el) case final light?)
          SceneLight(
            source: light.source,
            position: el.position,
            aim: aimOf(el),
            fixture: light,
            label: (el.props['name'] as String?) ?? el.displayLabel,
          ),
    ];
    final direct = LightScene(
      lights: fixtures,
      blockers: blockers,
      metersPerUnit: metersPerUnit,
    );
    return LightScene(
      lights: [
        ...fixtures,
        ...direct._secondarySources(all, wallBounce: bounce),
      ],
      blockers: blockers,
      metersPerUnit: metersPerUnit,
      ambient: ambient,
    );
  }

  // ── Qué tapa la luz ───────────────────────────────────────────────────────

  static (Offset, Offset) _span(PlanElement el, double width) {
    final rad = el.rotation * math.pi / 180;
    final half = Offset(math.cos(rad), math.sin(rad)) * (width / 2);
    return (el.position - half, el.position + half);
  }

  static double _filterTransmission(PlanElement el, ModifierKind kind) {
    var transmission = 1.0;
    for (final id in (el.props[PlanLight.modifiersKey] as List? ?? const [])) {
      final m = LightModifier.byId(id?.toString());
      if (m != null && m.kind == kind) transmission *= m.transmission;
    }
    return transmission;
  }

  static List<LightModifier> _filters(PlanElement el) => [
    for (final id in (el.props[PlanLight.modifiersKey] as List? ?? const []))
      ?LightModifier.byId(id?.toString()),
  ];

  /// Tela de un marco de difusión (½ grid cloth si no se ha elegido).
  static LightModifier diffusionOf(PlanElement el) =>
      _filters(el).where((m) => m.kind == ModifierKind.diffusion).firstOrNull ??
      LightModifier.byId('grid-half')!;

  /// Paredes, ventanas, puertas, grip, personas y cámaras convertidos en
  /// topes que tapan o filtran. Una ventana o una puerta abre un hueco en
  /// la pared sobre la que está.
  static List<LightBlocker> blockersOf(
    List<PlanElement> elements, {
    double metersPerUnit = defaultMetersPerUnit,
  }) {
    // Huecos: tramo que ocupan y luz que dejan pasar.
    final openings = <(Offset, Offset, double)>[];
    final walls = <(Offset, Offset, PlanElement)>[];
    final blockers = <LightBlocker>[];
    final body = bodyRadiusM / metersPerUnit;

    for (final el in elements) {
      switch (el.type) {
        case ElementType.actor || ElementType.camera:
          // Una persona o una cámara hacen sombra.
          if (el.props[noShadowKey] != true) {
            blockers.add(LightBlocker.circle(el.position, body, element: el));
          }
          continue;
        case ElementType.light:
          final (a, b) = _span(el, lengthOf(el));
          switch (el.lightType) {
            case LightType.flag || LightType.cutter || LightType.bounce:
              // Negro, cortador y rebote no dejan pasar nada.
              blockers.add(LightBlocker(a, b, element: el));
            case LightType.diffusionFrame:
              // La tela corta el haz directo: lo que sale de ella es una
              // fuente nueva, más ancha (ver `_secondarySources`).
              blockers.add(LightBlocker(a, b, element: el));
            case LightType.net:
              final scrim = _filterTransmission(el, ModifierKind.scrim);
              blockers.add(
                LightBlocker(
                  a,
                  b,
                  transmission: scrim < 1 ? scrim : 0.71,
                  element: el,
                ),
              );
            case LightType.gel:
              final gels = _filters(
                el,
              ).where((m) => m.kind == ModifierKind.correction).toList();
              final gel = gels.isEmpty
                  ? LightModifier.byId('cto-half')!
                  : gels.first;
              blockers.add(
                LightBlocker(
                  a,
                  b,
                  transmission: gel.transmission,
                  miredShift: gel.miredShift,
                  element: el,
                ),
              );
            default:
              break;
          }
          continue;
        case ElementType.prop:
          continue;
        case ElementType.wall:
          break;
      }

      if (PlanSegment.isSegment(el)) {
        if (PlanSegment.kind(el) != PlanSegment.kindWall) continue;
        // Una pared curva se trocea en tramos rectos.
        final pieces = PlanSegment.curve(el) == 0 ? 1 : 12;
        var from = PlanSegment.pointAt(el, 0);
        for (var i = 1; i <= pieces; i++) {
          final to = PlanSegment.pointAt(el, i / pieces);
          walls.add((from, to, el));
          from = to;
        }
        continue;
      }

      if (PlanOpening.isOpening(el)) {
        final (a, b) = PlanOpening.span(el);
        if (PlanOpening.isWindow(el)) {
          // Una ventana puede llevar cortina: su difusión o su gelatina.
          var transmission = glassTransmission;
          for (final m in _filters(el)) {
            transmission *= m.transmission;
          }
          openings.add((a, b, transmission));
        } else if (PlanOpening.isDoor(el)) {
          // Abierta, el hueco deja pasar y la hoja tapa donde esté.
          openings.add((a, b, PlanOpening.passesLight(el) ? 1 : 0));
          if (PlanOpening.passesLight(el)) {
            for (final (hinge, tip) in PlanOpening.leaves(el)) {
              blockers.add(LightBlocker(hinge, tip, element: el));
            }
          }
        } else {
          openings.add((
            a,
            b,
            el.architectureType == ArchitectureType.prisonBars ? 0.7 : 1,
          ));
        }
        continue;
      }

      // Pared suelta de tamaño fijo.
      final (a, b) = _span(el, pieceWidth);
      walls.add((a, b, el));
    }

    bool mountedOn(Offset centre, (Offset, Offset, PlanElement) wall) {
      final length = (wall.$2 - wall.$1).distance;
      if (length < 1) return false;
      final dir = (wall.$2 - wall.$1) / length;
      final along =
          (centre.dx - wall.$1.dx) * dir.dx + (centre.dy - wall.$1.dy) * dir.dy;
      final foot = wall.$1 + dir * along.clamp(0, length);
      return (centre - foot).distance <= _mountTolerance;
    }

    for (final wall in walls) {
      final (a, b, element) = wall;
      final length = (b - a).distance;
      if (length < 1) continue;
      final dir = (b - a) / length;

      // Tramos de esta pared ocupados por huecos, en distancia desde `a`.
      final cuts = <(double, double, double)>[];
      for (final (oa, ob, transmission) in openings) {
        final centre = (oa + ob) / 2;
        if (!mountedOn(centre, wall)) continue;
        final along = (centre.dx - a.dx) * dir.dx + (centre.dy - a.dy) * dir.dy;
        final half = (ob - oa).distance / 2;
        final from = (along - half).clamp(0.0, length);
        final to = (along + half).clamp(0.0, length);
        if (to - from > 1) cuts.add((from, to, transmission));
      }
      cuts.sort((x, y) => x.$1.compareTo(y.$1));

      var cursor = 0.0;
      for (final (from, to, transmission) in cuts) {
        if (from > cursor + 0.5) {
          blockers.add(
            LightBlocker(a + dir * cursor, a + dir * from, element: element),
          );
        }
        if (transmission < 1) {
          blockers.add(
            LightBlocker(
              a + dir * math.max(from, cursor),
              a + dir * to,
              transmission: transmission,
            ),
          );
        }
        cursor = math.max(cursor, to);
      }
      if (length > cursor + 0.5) {
        blockers.add(LightBlocker(a + dir * cursor, b, element: element));
      }
    }

    // Ventanas y puertas cerradas sueltas, sin pared: filtran o tapan igual.
    for (final (oa, ob, transmission) in openings) {
      if (transmission >= 1) continue;
      final centre = (oa + ob) / 2;
      if (!walls.any((w) => mountedOn(centre, w))) {
        blockers.add(LightBlocker(oa, ob, transmission: transmission));
      }
    }
    return blockers;
  }

  // ── Superficies que devuelven la luz ──────────────────────────────────────

  /// Lux con los que una fuente ilumina una superficie en [centre] con
  /// normal [normal] (orientada hacia la fuente), sin contar la propia
  /// superficie como tope.
  ({double lux, double cct})? _incident(
    SceneLight light,
    Offset centre,
    Offset normal,
    LightBlocker? own,
  ) {
    final span = centre - light.position;
    final units = span.distance;
    if (units < 1e-6 || light.source.candela <= 0) return null;
    final toSurface = span / units;
    // Coseno con el que la luz incide sobre la superficie.
    final cos = -(toSurface.dx * normal.dx + toSurface.dy * normal.dy);
    if (cos <= 0.02) return null;
    final passed = _throughput(light.position, centre, ignore: own);
    if (passed.transmission <= 0) return null;
    final meters = math.max(units * metersPerUnit, 0.05);
    final lux =
        light.source.illuminance(
          meters,
          offAxisDeg: _offAxis(light, toSurface),
        ) *
        passed.transmission *
        cos;
    if (lux < 0.5) return null;
    return (lux: lux, cct: _shift(light.source.cct, passed.miredShift));
  }

  static double _shift(double kelvin, double mired) {
    if (mired == 0 || kelvin <= 0) return kelvin;
    final m = 1e6 / kelvin + mired;
    return m <= 0 ? kelvin : 1e6 / m;
  }

  /// Rebotes, marcos de difusión y paredes: cada uno recibe la luz de los
  /// aparatos y la devuelve como una fuente nueva, ancha y blanda.
  ///
  /// Una superficie mate que recibe un flujo Φ lo reparte por todo su
  /// frente, con intensidad Φ/π en su eje. Φ es la luz que le llega por su
  /// área y por lo que devuelve o deja pasar.
  List<SceneLight> _secondarySources(
    List<PlanElement> elements, {
    required bool wallBounce,
  }) {
    final result = <SceneLight>[];

    void emit({
      required Offset centre,
      required Offset tangent,
      required double lengthUnits,
      required double heightM,
      required double keep,
      required double mired,
      required double beamDeg,
      required bool through,
      required LightBlocker? own,
      required String label,
    }) {
      final areaM2 = lengthUnits * metersPerUnit * heightM;
      final normalA = Offset(-tangent.dy, tangent.dx);
      for (final light in lights) {
        final toLight = light.position - centre;
        // La cara que mira a la fuente.
        final facing = (toLight.dx * normalA.dx + toLight.dy * normalA.dy) >= 0
            ? normalA
            : normalA * -1;
        final incident = _incident(light, centre, facing, own);
        if (incident == null) continue;
        final flux = incident.lux * areaM2 * keep;
        final candela = flux / math.pi;
        if (candela < 1) continue;
        result.add(
          SceneLight(
            source: LightSource(
              candela: candela,
              beamDeg: beamDeg,
              sizeM: lengthUnits * metersPerUnit,
              cct: _shift(incident.cct, mired),
              status: light.source.status,
            ),
            position: centre,
            // Una tela emite por la cara contraria a la fuente; un rebote,
            // por la misma.
            aim: through ? facing * -1 : facing,
            frontOnly: true,
            surface: own,
            label: '$label ← ${light.label}',
          ),
        );
      }
    }

    LightBlocker? blockerOf(PlanElement el) {
      for (final b in blockers) {
        if (identical(b.element, el)) return b;
      }
      return null;
    }

    for (final el in elements) {
      if (el.type != ElementType.light) continue;
      final rad = el.rotation * math.pi / 180;
      final tangent = Offset(math.cos(rad), math.sin(rad));
      final length = lengthOf(el);
      if (el.lightType == LightType.bounce) {
        final material = SurfaceMaterial.byId(
          el.props[materialKey] as String?,
          kBounceMaterials,
        );
        emit(
          centre: el.position,
          tangent: tangent,
          lengthUnits: length,
          heightM: length * metersPerUnit,
          keep: material.reflectance,
          mired: material.miredShift,
          beamDeg: material.beamDeg,
          through: false,
          own: blockerOf(el),
          label: '${el.displayLabel} (${material.name})',
        );
      } else if (el.lightType == LightType.diffusionFrame) {
        final cloth = diffusionOf(el);
        emit(
          centre: el.position,
          tangent: tangent,
          lengthUnits: length,
          heightM: length * metersPerUnit,
          keep: cloth.transmission,
          mired: cloth.miredShift,
          beamDeg: cloth.spreadDeg ?? 120,
          through: true,
          own: blockerOf(el),
          label: cloth.name,
        );
      }
    }

    if (wallBounce) {
      for (final blocker in blockers) {
        final wall = blocker.element;
        if (wall == null ||
            blocker.isCircle ||
            wall.type != ElementType.wall ||
            !blocker.isOpaque ||
            PlanOpening.isOpening(wall)) {
          continue;
        }
        final span = blocker.b - blocker.a;
        final length = span.distance;
        if (length < 20) continue;
        final material = SurfaceMaterial.byId(
          wall.props[materialKey] as String?,
          kWallMaterials,
        );
        // La pared se reparte en tres paños; cada uno devuelve lo suyo.
        for (final t in const [1 / 6, 0.5, 5 / 6]) {
          emit(
            centre: blocker.a + span * t,
            tangent: span / length,
            lengthUnits: length / 3,
            heightM: wallHeightM,
            keep: material.reflectance,
            mired: material.miredShift,
            beamDeg: material.beamDeg,
            through: false,
            own: blocker,
            label: 'Pared ${material.name.toLowerCase()}',
          );
        }
      }
    }
    return result;
  }

  // ── Geometría ─────────────────────────────────────────────────────────────

  /// Distancia desde [origin], en la dirección [dir], a la que el rayo
  /// encuentra el tope; `null` si no lo encuentra.
  static double? _rayHit(Offset origin, Offset dir, LightBlocker blocker) {
    if (blocker.isCircle) {
      final oc = origin - blocker.a;
      final b = oc.dx * dir.dx + oc.dy * dir.dy;
      final c = oc.dx * oc.dx + oc.dy * oc.dy - blocker.radius * blocker.radius;
      // El origen está dentro del círculo: no se tapa a sí mismo.
      if (c <= 0) return null;
      final disc = b * b - c;
      if (disc < 0) return null;
      final t = -b - math.sqrt(disc);
      return t > 1e-6 ? t : null;
    }
    final s = blocker.b - blocker.a;
    final denom = dir.dx * s.dy - dir.dy * s.dx;
    if (denom.abs() < 1e-9) return null;
    final diff = blocker.a - origin;
    final t = (diff.dx * s.dy - diff.dy * s.dx) / denom;
    final u = (diff.dx * dir.dy - diff.dy * dir.dx) / denom;
    if (t <= 1e-6 || u < 0 || u > 1) return null;
    return t;
  }

  /// Lo que queda de la luz entre dos puntos y el tinte que coge.
  ({double transmission, double miredShift}) _throughput(
    Offset from,
    Offset to, {
    LightBlocker? ignore,
  }) {
    final span = to - from;
    final distance = span.distance;
    if (distance < 1e-6) return (transmission: 1, miredShift: 0);
    final dir = span / distance;
    var transmission = 1.0;
    var mired = 0.0;
    for (final blocker in blockers) {
      if (identical(blocker, ignore)) continue;
      // Quien está dentro del cuerpo de una persona no queda a su sombra.
      if (blocker.isCircle && (to - blocker.a).distance <= blocker.radius) {
        continue;
      }
      final hit = _rayHit(from, dir, blocker);
      // Un tope a ras del punto medido no cuenta: el punto está «en» la
      // pared, no detrás.
      if (hit == null || hit >= distance - 0.5) continue;
      transmission *= blocker.transmission;
      mired += blocker.miredShift;
      if (transmission <= 0) return (transmission: 0, miredShift: 0);
    }
    return (transmission: transmission, miredShift: mired);
  }

  /// Parte de la luz que llega de [from] a [to], según lo que hay en medio.
  /// 1 = nada en medio; 0 = tapado.
  double transmissionBetween(Offset from, Offset to) =>
      _throughput(from, to).transmission;

  /// Distancia hasta el primer tope opaco en una dirección, con [max] de
  /// límite.
  double reachAlong(
    Offset origin,
    Offset dir,
    double max, {
    LightBlocker? ignore,
  }) {
    var best = max;
    for (final blocker in blockers) {
      if (!blocker.isOpaque || identical(blocker, ignore)) continue;
      final hit = _rayHit(origin, dir, blocker);
      if (hit != null && hit < best) best = hit;
    }
    return best;
  }

  /// Zona que alcanza una luz desde [origin] hasta [reach], recortada por
  /// lo que la tapa: lo que queda a su sombra no entra.
  Path visibleArea(Offset origin, double reach, {LightBlocker? ignore}) {
    // Un rayo cada grado y medio, más uno a cada lado de cada esquina para
    // que el corte de la sombra salga limpio. Todos los ángulos van de 0 a
    // 2π: mezclados con negativos, el contorno se cruza y deja de recortar.
    const twoPi = 2 * math.pi;
    final angles = <double>[for (var i = 0; i < 240; i++) i * twoPi / 240];
    void addCorner(Offset corner) {
      final d = corner - origin;
      if (d.distance > reach + 1 || d.distance < 1e-6) return;
      final angle = math.atan2(d.dy, d.dx);
      for (final delta in const [-0.0007, 0.0, 0.0007]) {
        angles.add((angle + delta) % twoPi);
      }
    }

    for (final blocker in blockers) {
      if (!blocker.isOpaque || identical(blocker, ignore)) continue;
      if (blocker.isCircle) {
        // Las dos tangentes al círculo.
        final d = blocker.a - origin;
        final distance = d.distance;
        if (distance <= blocker.radius || distance > reach + blocker.radius) {
          continue;
        }
        final centre = math.atan2(d.dy, d.dx);
        final half = math.asin(blocker.radius / distance);
        for (final edge in [centre - half, centre + half]) {
          for (final delta in const [-0.001, 0.001]) {
            angles.add((edge + delta) % twoPi);
          }
        }
        // Y unos cuantos por dentro, para que la sombra siga el contorno.
        for (var i = 1; i < 6; i++) {
          angles.add((centre - half + 2 * half * i / 6) % twoPi);
        }
      } else {
        addCorner(blocker.a);
        addCorner(blocker.b);
      }
    }
    angles.sort();

    final path = Path();
    var first = true;
    for (final angle in angles) {
      final dir = Offset(math.cos(angle), math.sin(angle));
      final point =
          origin + dir * reachAlong(origin, dir, reach, ignore: ignore);
      if (first) {
        path.moveTo(point.dx, point.dy);
        first = false;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  // ── Cuánta luz llega ──────────────────────────────────────────────────────

  /// Hacia dónde apunta una luz: el eje de su haz.
  static Offset aimOf(PlanElement el) {
    final rad = el.rotation * math.pi / 180;
    return Offset(math.sin(rad), -math.cos(rad));
  }

  /// Grados entre el eje de una fuente y una dirección.
  static double _offAxis(SceneLight light, Offset dir) {
    if (light.source.isOmni && !light.frontOnly) return 0;
    final cos = (dir.dx * light.aim.dx + dir.dy * light.aim.dy).clamp(
      -1.0,
      1.0,
    );
    return math.acos(cos) * 180 / math.pi;
  }

  /// Lo que aporta cada fuente a un punto de la planta, de más a menos.
  List<LightContribution> contributionsAt(Offset point) {
    final result = <LightContribution>[];
    for (final light in lights) {
      if (light.source.candela <= 0) continue;
      final span = point - light.position;
      final units = span.distance;
      final meters = math.max(units * metersPerUnit, 0.05);
      final dir = units > 1e-6 ? span / units : light.aim;
      final offAxis = _offAxis(light, dir);
      if (light.frontOnly && offAxis >= 89) continue;
      final passed = _throughput(light.position, point, ignore: light.surface);
      if (passed.transmission <= 0) continue;
      final lux =
          light.source.illuminance(meters, offAxisDeg: offAxis) *
          passed.transmission;
      if (lux > 0.01) {
        result.add(
          LightContribution(
            light,
            lux,
            _shift(light.source.cct, passed.miredShift),
          ),
        );
      }
    }
    result.addAll(_ambientAt(point));
    result.sort((a, b) => b.lux.compareTo(a.lux));
    return result;
  }

  /// Lo que aportan el sol y el cielo a un punto.
  ///
  /// El sol llega en línea recta desde su dirección: una pared lo tapa
  /// hasta donde alcanza su sombra (más larga cuanto más bajo está), y una
  /// ventana lo deja entrar. El cielo llega de todas partes: cuenta la
  /// parte de horizonte que el punto tiene despejada.
  List<LightContribution> _ambientAt(Offset point) {
    final env = ambient;
    if (env == null) return const [];
    final result = <LightContribution>[];
    SceneLight marker(String label, Offset toward, double cct) => SceneLight(
      source: LightSource(
        candela: 0,
        beamDeg: 360,
        cct: cct,
        status: PhotometryStatus.estimated,
      ),
      position: point + toward * 1e6,
      aim: toward * -1,
      label: label,
    );

    if (env.hasSun) {
      final toward = env.towardSun;
      final shadow = env.shadowLength(wallHeightM) / metersPerUnit;
      final passed = _throughput(point + toward * shadow, point);
      final lux = env.condition.sunLux * passed.transmission;
      if (lux > 0.01) {
        result.add(
          LightContribution(
            marker('Sol', toward, env.condition.sunCct),
            lux,
            _shift(env.condition.sunCct, passed.miredShift),
          ),
        );
      }
    }

    if (env.hasSky) {
      // Hasta dónde hay que tener despejado para ver cielo sobre una pared.
      final reach = 4 / metersPerUnit;
      const rays = 16;
      var open = 0.0;
      for (var i = 0; i < rays; i++) {
        final angle = i * 2 * math.pi / rays;
        final dir = Offset(math.cos(angle), math.sin(angle));
        open += _throughput(point + dir * reach, point).transmission;
      }
      final lux = env.skyLux * open / rays;
      if (lux > 0.01) {
        result.add(
          LightContribution(
            marker(env.day ? 'Cielo' : 'Luna', const Offset(0, -1), env.skyCct),
            lux,
            env.skyCct,
          ),
        );
      }
    }
    return result;
  }

  /// Lux totales en un punto.
  double luxAt(Offset point) =>
      contributionsAt(point).fold(0, (sum, c) => sum + c.lux);

  /// Temperatura de color de la mezcla en un punto (media en mired, pesada
  /// por la luz de cada fuente). `null` si no llega luz.
  double? cctAt(Offset point) {
    final parts = contributionsAt(point);
    var lux = 0.0;
    var mired = 0.0;
    for (final part in parts) {
      lux += part.lux;
      mired += part.lux * 1e6 / part.cct;
    }
    return lux <= 0 ? null : 1e6 / (mired / lux);
  }
}
