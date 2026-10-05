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
import 'rooms.dart';
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

  /// Hasta qué altura tapa, en metros. El sol pasa por encima de lo que
  /// es más bajo que su rayo; la luz de un aparato en trípode, por encima
  /// de lo que no llega a la altura de la cara.
  final double heightM;

  /// Es el cristal o la tela de un hueco de pared (ver [LightAperture]).
  final bool isAperture;

  /// Elemento de la planta del que sale, si lo hay.
  final PlanElement? element;

  const LightBlocker(
    this.a,
    this.b, {
    this.transmission = 0,
    this.miredShift = 0,
    this.heightM = 2.5,
    this.isAperture = false,
    this.element,
  }) : radius = 0;

  const LightBlocker.circle(
    Offset centre,
    this.radius, {
    this.element,
    this.transmission = 0,
    this.heightM = 1.75,
  }) : a = centre,
       b = centre,
       miredShift = 0,
       isAperture = false;

  LightBlocker withHeight(double height) => isCircle
      ? LightBlocker.circle(
          a,
          radius,
          element: element,
          transmission: transmission,
          heightM: height,
        )
      : LightBlocker(
          a,
          b,
          transmission: transmission,
          miredShift: miredShift,
          heightM: height,
          isAperture: isAperture,
          element: element,
        );

  /// Demasiado bajo para tapar la luz que viaja a la altura de la cara.
  bool get isLow => heightM < 1.2;

  bool get isOpaque => transmission <= 0;
  bool get isCircle => radius > 0;
}

/// Un hueco en una pared (ventana, puerta, abertura): el sol y el cielo
/// entran por él entre su alféizar y su dintel.
class LightAperture {
  final Offset a;
  final Offset b;
  final double transmission;
  final double miredShift;
  final double sillM;
  final double headM;

  /// Si lo que lleva (difusión, visillo) deshace el sol directo: el hueco
  /// pasa a ser una fuente blanda con este ángulo de haz. `null` = el sol
  /// pasa en línea recta.
  final double? diffuseDeg;

  /// Su cristal o su tela, para que la fuente que sale de él no se tape a
  /// sí misma.
  final LightBlocker? pane;
  final PlanElement? element;

  const LightAperture(
    this.a,
    this.b, {
    required this.transmission,
    required this.sillM,
    required this.headM,
    this.miredShift = 0,
    this.diffuseDeg,
    this.pane,
    this.element,
  });

  Offset get centre => (a + b) / 2;
  double get width => (b - a).distance;
}

/// Un recinto con lo que se sabe de él.
class SceneRoom {
  final PlanRoom room;

  /// Con techo: el sol y el cielo solo entran por sus huecos.
  final bool roofed;
  final double ceilingM;
  final SurfaceMaterial floor;

  const SceneRoom(
    this.room, {
    required this.roofed,
    required this.ceilingM,
    required this.floor,
  });
}

class _Gap {
  final Offset a;
  final Offset b;
  final double transmission;
  final double mired;
  final double? diffuseDeg;
  final PlanElement element;

  const _Gap(
    this.a,
    this.b,
    this.transmission,
    this.element, {
    this.mired = 0,
    this.diffuseDeg,
  });
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

  /// Si cuelga del techo y alumbra hacia abajo: metros que hay de la fuente
  /// al plano donde se mide. `null` = a la altura del sujeto, en trípode.
  final double? overheadM;

  /// Colgada del techo: grados que se inclina desde la vertical hacia
  /// [aim]. 0 = recta hacia abajo.
  final double tiltDeg;

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
    this.overheadM,
    this.tiltDeg = 0,
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

  /// Huecos de pared por los que entran el sol y el cielo.
  final List<LightAperture> apertures;

  /// Recintos cerrados por paredes.
  final List<SceneRoom> rooms;

  const LightScene({
    required this.lights,
    required this.blockers,
    required this.metersPerUnit,
    this.ambient,
    this.apertures = const [],
    this.rooms = const [],
  });

  /// Recinto en el que cae un punto, si está dentro de alguno.
  SceneRoom? roomAt(Offset point) {
    for (final room in rooms) {
      if (room.room.contains(point)) return room;
    }
    return null;
  }

  /// El punto está bajo techo.
  bool isRoofed(Offset point) => roomAt(point)?.roofed ?? false;

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
    final built = _build(all, metersPerUnit: metersPerUnit);
    final rooms = <SceneRoom>[
      for (final room in PlanRooms.detect(
        built.walls,
        minArea: 1 / (metersPerUnit * metersPerUnit),
      ))
        _roomWith(room, ambient?.rooms ?? const []),
    ];
    final bounce = wallBounce && (ambient?.wallBounce ?? true);
    // La pared de un recinto con techo llega hasta él.
    final blockers = <LightBlocker>[
      for (final blocker in built.blockers)
        if (!blocker.isCircle &&
            blocker.element?.type == ElementType.wall &&
            !blocker.isAperture)
          blocker.withHeight(_wallHeight(blocker, rooms))
        else
          blocker,
    ];
    final apertures = built.apertures;
    final fixtures = <SceneLight>[
      for (final el in all)
        if (PlanLight.of(el) case final light?)
          SceneLight(
            source: light.source,
            position: el.position,
            aim: aimOf(el),
            // Sin altura propia, cuelga del techo del recinto donde está.
            overheadM: !PlanLight.isOverhead(el)
                ? null
                : el.props[PlanLight.heightKey] != null
                ? PlanLight.overheadDrop(el)
                : ((_ceilingAt(rooms, el.position) ??
                              PlanLight.defaultCeilingHeight) -
                          PlanLight.subjectHeightM)
                      .clamp(0.3, 50.0),
            tiltDeg: PlanLight.tiltOf(el),
            fixture: light,
            label: (el.props['name'] as String?) ?? el.displayLabel,
          ),
    ];
    final bare = LightScene(
      lights: fixtures,
      blockers: blockers,
      metersPerUnit: metersPerUnit,
      ambient: ambient,
      apertures: apertures,
      rooms: rooms,
    );
    // Los huecos por los que entra el cielo (o un sol difuso) son fuentes:
    // un rebote o un negro actúan sobre ellos como sobre un aparato.
    final direct = LightScene(
      lights: [...fixtures, ...bare._apertureSources()],
      blockers: blockers,
      metersPerUnit: metersPerUnit,
      ambient: ambient,
      apertures: apertures,
      rooms: rooms,
    );
    return LightScene(
      lights: [
        ...direct.lights,
        ...direct._secondarySources(all, wallBounce: bounce),
        ...direct._floorSunSources(),
      ],
      blockers: blockers,
      metersPerUnit: metersPerUnit,
      ambient: ambient,
      apertures: apertures,
      rooms: rooms,
    );
  }

  static double? _ceilingAt(List<SceneRoom> rooms, Offset point) {
    for (final room in rooms) {
      if (room.roofed && room.room.contains(point)) return room.ceilingM;
    }
    return null;
  }

  static SceneRoom _roomWith(PlanRoom room, List<RoomSetting> settings) {
    RoomSetting? own;
    for (final s in settings) {
      if (room.contains(s.point)) own = s;
    }
    return SceneRoom(
      room,
      roofed: !(own?.openSky ?? false),
      ceilingM: own?.ceilingM ?? wallHeightM,
      floor: SurfaceMaterial.byId(own?.floor, kFloorMaterials),
    );
  }

  static double _wallHeight(LightBlocker wall, List<SceneRoom> rooms) {
    final span = wall.b - wall.a;
    final length = span.distance;
    if (length < 1e-6) return wall.heightM;
    final normal = Offset(-span.dy, span.dx) / length;
    final mid = (wall.a + wall.b) / 2;
    var height = wall.heightM;
    for (final side in const [8.0, -8.0]) {
      for (final room in rooms) {
        if (room.roofed && room.room.contains(mid + normal * side)) {
          height = math.max(height, room.ceilingM);
        }
      }
    }
    return height;
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
  }) => _build(elements, metersPerUnit: metersPerUnit).blockers;

  static const sizeKey = 'size';
  static const heightKey = 'height';

  /// Radio (o medio largo) de un árbol, una roca o una colina, en metros.
  static double propSizeM(PlanElement el) =>
      (el.props[sizeKey] as num?)?.toDouble() ??
      switch (el.propType) {
        PropType.tree => 1.2,
        PropType.rock => 0.4,
        PropType.hill => 4,
        _ => 0.5,
      };

  /// Altura de un árbol, una roca, un vehículo, una colina o un relieve.
  static double propHeightM(PlanElement el) =>
      (el.props[heightKey] as num?)?.toDouble() ??
      (PlanSegment.isSegment(el)
          ? 2
          : switch (el.propType) {
              PropType.tree => 5,
              PropType.rock => 0.6,
              PropType.vehicle => 1.5,
              PropType.hill => 6,
              _ => 0.8,
            });

  /// Luz que se cuela entre las hojas de un árbol.
  static const double treeTransmission = 0.25;

  static ({
    List<LightBlocker> blockers,
    List<LightAperture> apertures,
    List<(Offset, Offset)> walls,
  })
  _build(List<PlanElement> elements, {required double metersPerUnit}) {
    // Huecos: tramo que ocupan y luz que dejan pasar.
    final openings = <_Gap>[];
    final walls = <(Offset, Offset, PlanElement)>[];
    final blockers = <LightBlocker>[];
    final apertures = <LightAperture>[];
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
          final radius = propSizeM(el) / metersPerUnit;
          final height = propHeightM(el);
          switch (el.propType) {
            case PropType.tree:
              // La copa deja pasar una parte: luz moteada.
              blockers.add(
                LightBlocker.circle(
                  el.position,
                  radius,
                  element: el,
                  transmission: treeTransmission,
                  heightM: height,
                ),
              );
            case PropType.rock || PropType.hill:
              blockers.add(
                LightBlocker.circle(
                  el.position,
                  radius,
                  element: el,
                  heightM: height,
                ),
              );
            case PropType.vehicle:
              // Su caja, girada con él.
              final rad = el.rotation * math.pi / 180;
              final along = Offset(-math.sin(rad), math.cos(rad)) * 38;
              final across = Offset(math.cos(rad), math.sin(rad)) * 18;
              final corners = [
                el.position - along - across,
                el.position - along + across,
                el.position + along + across,
                el.position + along - across,
              ];
              for (var i = 0; i < 4; i++) {
                blockers.add(
                  LightBlocker(
                    corners[i],
                    corners[(i + 1) % 4],
                    heightM: height,
                    element: el,
                  ),
                );
              }
            default:
              break;
          }
          continue;
        case ElementType.wall:
          break;
      }

      if (PlanSegment.isSegment(el)) {
        if (PlanSegment.kind(el) == PlanSegment.kindRelief) {
          // Un talud: tapa hasta su altura.
          final pieces = PlanSegment.curve(el) == 0 ? 1 : 12;
          var from = PlanSegment.pointAt(el, 0);
          for (var i = 1; i <= pieces; i++) {
            final to = PlanSegment.pointAt(el, i / pieces);
            blockers.add(
              LightBlocker(from, to, heightM: propHeightM(el), element: el),
            );
            from = to;
          }
          continue;
        }
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
          // Abierta, no hay cristal en medio (ni lo que lleve pegado); sus
          // hojas hacen sombra como las de una puerta.
          final isOpen = PlanOpening.openDeg(el) > 3;
          var glass = isOpen ? 1.0 : glassTransmission;
          var mired = 0.0;
          double? diffuse;
          if (!isOpen) {
            for (final m in _filters(el)) {
              glass *= m.transmission;
              mired += m.miredShift;
              final spread = m.spreadDeg;
              if (spread != null) diffuse = math.max(diffuse ?? 0, spread);
            }
          }
          if (isOpen) {
            for (final (hinge, tip) in PlanOpening.leaves(el)) {
              blockers.add(LightBlocker(hinge, tip, element: el));
            }
          }
          // La cortina tapa una parte del ancho, desde un lado.
          final covered = PlanOpening.curtain(el);
          if (covered <= 0.01) {
            openings.add(
              _Gap(a, b, glass, el, mired: mired, diffuseDeg: diffuse),
            );
          } else {
            final split = a + (b - a) * covered;
            final cloth = PlanOpening.curtainMaterial(el).transmission;
            // Una cortina deshace el sol: lo que pasa sale blando.
            openings.add(
              _Gap(a, split, glass * cloth, el, mired: mired, diffuseDeg: 120),
            );
            if (covered < 0.99) {
              openings.add(
                _Gap(split, b, glass, el, mired: mired, diffuseDeg: diffuse),
              );
            }
          }
        } else if (PlanOpening.isDoor(el)) {
          // Abierta, el hueco deja pasar y la hoja tapa donde esté.
          openings.add(_Gap(a, b, PlanOpening.passesLight(el) ? 1 : 0, el));
          if (PlanOpening.passesLight(el)) {
            for (final (hinge, tip) in PlanOpening.leaves(el)) {
              blockers.add(LightBlocker(hinge, tip, element: el));
            }
          }
        } else {
          openings.add(
            _Gap(
              a,
              b,
              el.architectureType == ArchitectureType.prisonBars ? 0.7 : 1,
              el,
            ),
          );
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
      final cuts = <(double, double, _Gap)>[];
      for (final gap in openings) {
        final oa = gap.a;
        final ob = gap.b;
        // El hueco cuenta en este tramo si está sobre su línea y lo pisa.
        // Así una ventana en una pared curva abre hueco en todos los
        // tramos que ocupa, no solo en el de su centro.
        final centre = (oa + ob) / 2;
        final rel = centre - a;
        final off = (rel.dx * dir.dy - rel.dy * dir.dx).abs();
        if (off > _mountTolerance) continue;
        double along(Offset p) =>
            (p.dx - a.dx) * dir.dx + (p.dy - a.dy) * dir.dy;
        final la = along(oa);
        final lb = along(ob);
        final from = math.min(la, lb).clamp(0.0, length);
        final to = math.max(la, lb).clamp(0.0, length);
        if (to - from > 1) cuts.add((from, to, gap));
      }
      cuts.sort((x, y) => x.$1.compareTo(y.$1));

      var cursor = 0.0;
      for (final (from, to, gap) in cuts) {
        if (from > cursor + 0.5) {
          blockers.add(
            LightBlocker(a + dir * cursor, a + dir * from, element: element),
          );
        }
        final start = a + dir * math.max(from, cursor);
        final end = a + dir * to;
        LightBlocker? pane;
        if (gap.transmission < 1) {
          pane = LightBlocker(
            start,
            end,
            transmission: gap.transmission,
            miredShift: gap.mired,
            isAperture: true,
            element: gap.element,
          );
          blockers.add(pane);
        }
        if ((end - start).distance > 1) {
          apertures.add(
            LightAperture(
              start,
              end,
              transmission: gap.transmission,
              miredShift: gap.mired,
              sillM: PlanOpening.sill(gap.element),
              headM: PlanOpening.head(gap.element),
              diffuseDeg: gap.diffuseDeg,
              pane: pane,
              element: gap.element,
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
    for (final gap in openings) {
      if (gap.transmission >= 1) continue;
      final centre = (gap.a + gap.b) / 2;
      if (!walls.any((w) => mountedOn(centre, w))) {
        blockers.add(
          LightBlocker(
            gap.a,
            gap.b,
            transmission: gap.transmission,
            miredShift: gap.mired,
            element: gap.element,
          ),
        );
      }
    }
    return (
      blockers: blockers,
      apertures: apertures,
      walls: [for (final (a, b, _) in walls) (a, b)],
    );
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
    final lux =
        luxFrom(light, units, _offAxis(light, toSurface)) *
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

      // El sol también le da.
      final env = ambient;
      if (env == null || !env.hasSun) return;
      final toward = env.towardSun;
      final dot = toward.dx * normalA.dx + toward.dy * normalA.dy;
      if (dot.abs() < 0.05) return;
      final facing = dot >= 0 ? normalA : normalA * -1;
      final sun = sunThroughput(centre + facing * 3);
      if (sun.transmission <= 0) return;
      final cosElevation = 1 / math.sqrt(1 + _sunTan * _sunTan);
      final lux =
          env.condition.sunLux * sun.transmission * cosElevation * dot.abs();
      final candela = lux * areaM2 * keep / math.pi;
      if (candela < 1) return;
      result.add(
        SceneLight(
          source: LightSource(
            candela: candela,
            beamDeg: beamDeg,
            sizeM: lengthUnits * metersPerUnit,
            cct: _shift(env.condition.sunCct, sun.miredShift + mired),
            status: PhotometryStatus.estimated,
          ),
          position: centre,
          aim: through ? facing * -1 : facing,
          frontOnly: true,
          surface: own,
          label: '$label ← Sol',
        ),
      );
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
        // La pared se reparte en paños de alrededor de dos metros (hasta
        // tres); cada uno devuelve lo suyo. Un tramo corto, como los de una
        // pared curva, es un solo paño.
        final panes = (length * metersPerUnit / 2).round().clamp(1, 3);
        for (final t in [for (var i = 0; i < panes; i++) (i + 0.5) / panes]) {
          emit(
            centre: blocker.a + span * t,
            tangent: span / length,
            lengthUnits: length / panes,
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
    bool fromAbove = false,
  }) {
    final span = to - from;
    final distance = span.distance;
    if (distance < 1e-6) return (transmission: 1, miredShift: 0);
    final dir = span / distance;
    var transmission = 1.0;
    var mired = 0.0;
    for (final blocker in blockers) {
      if (identical(blocker, ignore)) continue;
      // Lo que no llega a la altura de la cara no tapa.
      if (blocker.isLow) continue;
      // La luz que cae del techo pasa por encima de personas y cámaras.
      if (fromAbove && blocker.isCircle && blocker.heightM <= 2) continue;
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
    bool fromAbove = false,
  }) {
    var best = max;
    for (final blocker in blockers) {
      if (!blocker.isOpaque || identical(blocker, ignore)) continue;
      if (blocker.isLow) continue;
      if (fromAbove && blocker.isCircle && blocker.heightM <= 2) continue;
      final hit = _rayHit(origin, dir, blocker);
      if (hit != null && hit < best) best = hit;
    }
    return best;
  }

  /// Zona que alcanza una luz desde [origin] hasta [reach], recortada por
  /// lo que la tapa: lo que queda a su sombra no entra.
  Path visibleArea(
    Offset origin,
    double reach, {
    LightBlocker? ignore,
    bool fromAbove = false,
  }) {
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
      if (blocker.isLow) continue;
      if (fromAbove && blocker.isCircle && blocker.heightM <= 2) continue;
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
          origin +
          dir *
              reachAlong(
                origin,
                dir,
                reach,
                ignore: ignore,
                fromAbove: fromAbove,
              );
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

  /// Lux que da una fuente a [units] de distancia sobre el plano, sin nada
  /// en medio.
  ///
  /// En trípode, la luz viaja a la altura del sujeto. Colgada del techo,
  /// alumbra hacia abajo: lo que cuenta es la distancia real (en diagonal)
  /// y cuánto se aparta el punto de la vertical del aparato.
  double luxFrom(SceneLight light, double units, double offAxisDeg) {
    final flat = units * metersPerUnit;
    final drop = light.overheadM;
    if (drop == null) {
      return light.source.illuminance(
        math.max(flat, 0.05),
        offAxisDeg: offAxisDeg,
      );
    }
    final distance = math.sqrt(flat * flat + drop * drop);
    // Inclinada, su eje ya no cae a plomo: se aparta de la vertical hacia
    // donde apunta en planta.
    final tilt = light.tiltDeg.clamp(0.0, 89.0) * math.pi / 180;
    final along = math.cos(offAxisDeg * math.pi / 180);
    final cos =
        (along * math.sin(tilt) * flat + math.cos(tilt) * drop) / distance;
    return light.source.illuminance(
      distance,
      offAxisDeg: math.acos(cos.clamp(-1.0, 1.0)) * 180 / math.pi,
    );
  }

  /// Lux que da una fuente a un punto, sin contar lo que haya en medio.
  double luxOf(SceneLight light, Offset point) {
    final span = point - light.position;
    final units = span.distance;
    final dir = units > 1e-6 ? span / units : light.aim;
    final cos = (dir.dx * light.aim.dx + dir.dy * light.aim.dy).clamp(
      -1.0,
      1.0,
    );
    return luxFrom(light, units, math.acos(cos) * 180 / math.pi);
  }

  /// Lo que aporta cada fuente a un punto de la planta, de más a menos.
  List<LightContribution> contributionsAt(Offset point) {
    final result = <LightContribution>[];
    for (final light in lights) {
      if (light.source.candela <= 0) continue;
      final span = point - light.position;
      final units = span.distance;
      final dir = units > 1e-6 ? span / units : light.aim;
      final offAxis = light.overheadM != null && light.tiltDeg > 0
          ? math.acos(
                  (dir.dx * light.aim.dx + dir.dy * light.aim.dy).clamp(
                    -1.0,
                    1.0,
                  ),
                ) *
                180 /
                math.pi
          : _offAxis(light, dir);
      if (light.frontOnly && offAxis >= 89) continue;
      final passed = _throughput(
        light.position,
        point,
        ignore: light.surface,
        fromAbove: light.overheadM != null,
      );
      if (passed.transmission <= 0) continue;
      final lux = luxFrom(light, units, offAxis) * passed.transmission;
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

  // ── Sol y cielo ───────────────────────────────────────────────────────────

  double get _sunTan {
    final elevation = (ambient?.sunElevation ?? 35).clamp(3.0, 89.0);
    return math.tan(elevation * math.pi / 180);
  }

  /// Lo que queda del sol directo al llegar a [point], medido a [heightM]
  /// del suelo.
  ///
  /// El rayo sube hacia el sol: a cada cosa que cruza llega más alto. Pasa
  /// por encima de lo que es más bajo que él, entra por un hueco si lo
  /// cruza entre el alféizar y el dintel, y no atraviesa un techo.
  ({double transmission, double miredShift}) sunThroughput(
    Offset point, {
    double heightM = PlanLight.subjectHeightM,
  }) {
    final env = ambient;
    if (env == null || !env.hasSun) return (transmission: 0, miredShift: 0);
    final toward = env.towardSun;
    final rise = _sunTan * metersPerUnit;
    double heightAt(double units) => heightM + units * rise;

    // El techo: si el rayo alcanza la altura del techo todavía dentro del
    // recinto, lo tiene encima.
    for (final room in rooms) {
      if (!room.roofed || room.ceilingM <= heightM) continue;
      final units = (room.ceilingM - heightM) / rise;
      if (room.room.contains(point + toward * units)) {
        return (transmission: 0, miredShift: 0);
      }
    }

    var transmission = 1.0;
    var mired = 0.0;
    for (final gap in apertures) {
      final hit = _rayHit(point, toward, LightBlocker(gap.a, gap.b));
      if (hit == null || hit < 0.5) continue;
      final h = heightAt(hit);
      if (h < gap.sillM) return (transmission: 0, miredShift: 0);
      if (h <= gap.headM) {
        // Con difusión o cortina, el sol directo no pasa: sale como luz
        // blanda del propio hueco (ver `_apertureSources`).
        if (gap.diffuseDeg != null) return (transmission: 0, miredShift: 0);
        transmission *= gap.transmission;
        mired += gap.miredShift;
        if (transmission <= 0) return (transmission: 0, miredShift: 0);
      } else if (h < _wallTopAt(gap.centre)) {
        return (transmission: 0, miredShift: 0);
      }
    }
    for (final blocker in blockers) {
      if (blocker.isAperture) continue;
      if (blocker.isCircle &&
          (point - blocker.a).distance <= blocker.radius &&
          blocker.heightM <= 2) {
        continue;
      }
      final hit = _rayHit(point, toward, blocker);
      if (hit == null || hit < 0.5) continue;
      if (heightAt(hit) >= blocker.heightM) continue;
      transmission *= blocker.transmission;
      mired += blocker.miredShift;
      if (transmission <= 0) return (transmission: 0, miredShift: 0);
    }
    return (transmission: transmission, miredShift: mired);
  }

  /// Hasta dónde sube la pared en un punto de ella.
  double _wallTopAt(Offset onWall) {
    var top = wallHeightM;
    for (final room in rooms) {
      if (!room.roofed) continue;
      for (final d in const [
        Offset(8, 0),
        Offset(-8, 0),
        Offset(0, 8),
        Offset(0, -8),
      ]) {
        if (room.room.contains(onWall + d)) top = math.max(top, room.ceilingM);
      }
    }
    return top;
  }

  /// Parte del cielo que se ve desde un punto al aire libre, mirando
  /// alrededor (o solo hacia [facing]).
  double _openSky(Offset point, {Offset? facing}) {
    final reach = 4 / metersPerUnit;
    const rays = 16;
    var open = 0.0;
    var counted = 0;
    for (var i = 0; i < rays; i++) {
      final angle = i * 2 * math.pi / rays;
      final dir = Offset(math.cos(angle), math.sin(angle));
      if (facing != null && dir.dx * facing.dx + dir.dy * facing.dy < 0.15) {
        continue;
      }
      counted++;
      open += _throughput(point + dir * reach, point).transmission;
    }
    return counted == 0 ? 0 : open / counted;
  }

  /// Hacia qué lado da un hueco a un recinto con techo: el lado de dentro.
  /// `null` si no separa dentro de fuera.
  Offset? _inwardOf(LightAperture gap) {
    final span = gap.b - gap.a;
    if (span.distance < 1e-6) return null;
    final normal = Offset(-span.dy, span.dx) / span.distance;
    final front = isRoofed(gap.centre + normal * 10);
    final back = isRoofed(gap.centre - normal * 10);
    if (front == back) return null;
    return front ? normal : normal * -1;
  }

  /// Los huecos de un recinto con techo, como fuentes: por ellos entra el
  /// cielo y, si llevan difusión o cortina, el sol hecho luz blanda.
  List<SceneLight> _apertureSources() {
    final env = ambient;
    if (env == null) return const [];
    final result = <SceneLight>[];
    for (final gap in apertures) {
      if (gap.transmission <= 0) continue;
      final inward = _inwardOf(gap);
      if (inward == null) continue;
      final outward = inward * -1;
      final outside = gap.centre + outward * 10;
      final areaM2 = gap.width * metersPerUnit * (gap.headM - gap.sillM);
      final what = PlanOpening.isDoor(gap.element!) ? 'puerta' : 'ventana';

      void emit(double lux, double cct, double beamDeg, String label) {
        final candela = lux * areaM2 * gap.transmission / math.pi;
        if (candela < 0.05) return;
        result.add(
          SceneLight(
            source: LightSource(
              candela: candela,
              beamDeg: beamDeg,
              sizeM: gap.width * metersPerUnit,
              cct: _shift(cct, gap.miredShift),
              status: PhotometryStatus.estimated,
            ),
            position: gap.centre + inward * 2,
            aim: inward,
            frontOnly: true,
            surface: gap.pane,
            label: label,
          ),
        );
      }

      if (env.hasSky) {
        // Una ventana ve medio cielo: la mitad de lo que recibe el suelo.
        final lux = env.skyLux * 0.5 * _openSky(outside, facing: outward);
        emit(lux, env.skyCct, 120, '${env.day ? 'Cielo' : 'Luna'} por $what');
      }
      final diffuse = gap.diffuseDeg;
      if (env.hasSun && diffuse != null) {
        final toward = env.towardSun;
        final facing = toward.dx * outward.dx + toward.dy * outward.dy;
        if (facing > 0.02) {
          final sun = sunThroughput(
            outside,
            heightM: (gap.sillM + gap.headM) / 2,
          );
          final cosElevation = 1 / math.sqrt(1 + _sunTan * _sunTan);
          final lux =
              env.condition.sunLux * sun.transmission * cosElevation * facing;
          emit(
            lux,
            _shift(env.condition.sunCct, sun.miredShift),
            diffuse,
            'Sol difuso por $what',
          );
        }
      }
    }
    return result;
  }

  /// La mancha de sol que entra por cada hueco y cae en el suelo devuelve
  /// luz hacia arriba: el relleno natural de una sala con sol.
  List<SceneLight> _floorSunSources() {
    final env = ambient;
    if (env == null || !env.hasSun) return const [];
    final toward = env.towardSun;
    final tan = _sunTan;
    final sinElevation = tan / math.sqrt(1 + tan * tan);
    final result = <SceneLight>[];
    for (final gap in apertures) {
      if (gap.transmission <= 0 || gap.diffuseDeg != null) continue;
      final inward = _inwardOf(gap);
      if (inward == null) continue;
      final facing = -(toward.dx * inward.dx + toward.dy * inward.dy);
      if (facing <= 0.05) continue;
      final midM = (gap.sillM + gap.headM) / 2 / tan;
      final centre = gap.centre - toward * (midM / metersPerUnit);
      final room = roomAt(centre);
      if (room == null || !room.roofed) continue;
      final sun = sunThroughput(centre, heightM: 0);
      if (sun.transmission <= 0) continue;
      final depthM = (gap.headM - gap.sillM) / tan;
      final areaM2 = gap.width * metersPerUnit * facing * depthM;
      final lux = env.condition.sunLux * sinElevation * sun.transmission;
      final candela = lux * areaM2 * room.floor.reflectance / math.pi;
      if (candela < 1) continue;
      result.add(
        SceneLight(
          source: LightSource(
            candela: candela,
            beamDeg: 120,
            sizeM: math.sqrt(areaM2),
            cct: _shift(
              env.condition.sunCct,
              sun.miredShift + room.floor.miredShift,
            ),
            status: PhotometryStatus.estimated,
          ),
          position: centre,
          aim: inward,
          // Emite hacia arriba: la cara queda metro y medio por encima.
          overheadM: PlanLight.subjectHeightM,
          label: 'Suelo (${room.floor.name.toLowerCase()}) ← Sol',
        ),
      );
    }
    return result;
  }

  /// Lo que aportan el sol y el cielo a un punto.
  ///
  /// El sol llega en línea recta desde su dirección y su altura (ver
  /// [sunThroughput]). Al aire libre, el cielo llega de todas partes:
  /// cuenta la parte de horizonte despejada. Bajo techo solo entra por los
  /// huecos, que ya son fuentes.
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
      final passed = sunThroughput(point);
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

    if (env.hasSky && !isRoofed(point)) {
      final lux = env.skyLux * _openSky(point);
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
