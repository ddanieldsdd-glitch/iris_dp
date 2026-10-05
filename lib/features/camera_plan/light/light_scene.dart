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

  /// Desde qué altura tapa: la hoja de una ventana empieza en el alféizar
  /// y el sol pasa por debajo.
  final double baseM;

  /// Es un tramo de pared.
  final bool isWall;

  /// Si deshace la luz que lo cruza (una tela, una cortina): la luz
  /// directa no pasa y sale por el otro lado como fuente blanda con este
  /// ángulo de haz y [diffuseKeep] de lo que le llega.
  final double? diffuseDeg;
  final double diffuseKeep;

  /// Una loma: radio de su base. Su altura baja de [heightM] en el centro
  /// a cero en el borde; [radius] es lo que mide a la altura de la cara.
  final double? domeRadius;

  /// Nombre con el que sale en el fotómetro cuando emite.
  final String? label;

  /// Elemento de la planta del que sale, si lo hay.
  final PlanElement? element;

  const LightBlocker(
    this.a,
    this.b, {
    this.transmission = 0,
    this.miredShift = 0,
    this.heightM = 2.5,
    this.baseM = 0,
    this.isWall = false,
    this.diffuseDeg,
    this.diffuseKeep = 0,
    this.label,
    this.element,
  }) : radius = 0,
       domeRadius = null;

  const LightBlocker.circle(
    Offset centre,
    this.radius, {
    this.element,
    this.transmission = 0,
    this.heightM = 1.75,
    this.domeRadius,
  }) : a = centre,
       b = centre,
       miredShift = 0,
       baseM = 0,
       isWall = false,
       diffuseDeg = null,
       diffuseKeep = 0,
       label = null;

  LightBlocker withHeight(double height) => isCircle
      ? LightBlocker.circle(
          a,
          radius,
          element: element,
          transmission: transmission,
          heightM: height,
          domeRadius: domeRadius,
        )
      : LightBlocker(
          a,
          b,
          transmission: transmission,
          miredShift: miredShift,
          heightM: height,
          baseM: baseM,
          isWall: isWall,
          diffuseDeg: diffuseDeg,
          diffuseKeep: diffuseKeep,
          label: label,
          element: element,
        );

  /// Demasiado bajo para tapar la luz que viaja a la altura de la cara.
  bool get isLow => heightM < 1.2;

  bool get isOpaque => transmission <= 0;
  bool get isCircle => radius > 0;

  /// Altura de una loma a [distance] de su centro.
  double domeHeightAt(double distance) {
    final r = domeRadius;
    if (r == null || r <= 0) return heightM;
    return heightM * (1 - distance / r).clamp(0.0, 1.0);
  }
}

/// Un hueco en una pared (ventana, puerta, abertura): el sol y el cielo
/// entran por él entre su alféizar y su dintel.
class LightAperture {
  final Offset a;
  final Offset b;
  final double sillM;
  final double headM;
  final PlanElement? element;

  const LightAperture(
    this.a,
    this.b, {
    required this.sillM,
    required this.headM,
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
  final PlanElement element;

  const _Gap(this.a, this.b, this.element);
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
    final rooms = <SceneRoom>[
      for (final room in PlanRooms.detect(
        _build(all, metersPerUnit: metersPerUnit).walls,
        minArea: 1 / (metersPerUnit * metersPerUnit),
      ))
        _roomWith(room, ambient?.rooms ?? const []),
    ];
    // Con los recintos ya se sabe qué lado de cada hueco es el de dentro.
    final built = _build(
      all,
      metersPerUnit: metersPerUnit,
      roofedAt: (p) => rooms.any((r) => r.roofed && r.room.contains(p)),
    );
    final bounce = wallBounce && (ambient?.wallBounce ?? true);
    // La pared de un recinto con techo llega hasta él.
    final blockers = <LightBlocker>[
      for (final blocker in built.blockers)
        if (blocker.isWall)
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
    LightScene stage(List<SceneLight> lights) => LightScene(
      lights: lights,
      blockers: blockers,
      metersPerUnit: metersPerUnit,
      ambient: ambient,
      apertures: apertures,
      rooms: rooms,
    );
    // Los huecos por los que entra el cielo son fuentes: un rebote o un
    // negro actúan sobre ellos como sobre un aparato.
    final entering = [...fixtures, ...bare._apertureSources()];
    // Primero lo que difunde (telas, cortinas, marcos): recibe la luz y la
    // suelta blanda por el otro lado. Después lo que rebota, que ya ve
    // también esa luz blanda.
    final soft = stage(
      entering,
    )._secondarySources(all, wallBounce: false, diffusers: true);
    final direct = stage([...entering, ...soft]);
    return stage([
      ...direct.lights,
      ...direct._secondarySources(all, wallBounce: bounce, diffusers: false),
      ...direct._floorSunSources(),
    ]);
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
  _build(
    List<PlanElement> elements, {
    required double metersPerUnit,
    bool Function(Offset point)? roofedAt,
  }) {
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
              // fuente nueva, más ancha (ver `_secondarySources`). El
              // marco es cuadrado y va centrado a la altura de la cara.
              final cloth = diffusionOf(el);
              final side = lengthOf(el) * metersPerUnit;
              final base = math.max(0.0, PlanLight.subjectHeightM - side / 2);
              blockers.add(
                LightBlocker(
                  a,
                  b,
                  miredShift: cloth.miredShift,
                  baseM: base,
                  heightM: base + side,
                  diffuseDeg: cloth.spreadDeg ?? 120,
                  diffuseKeep: cloth.transmission,
                  label: cloth.name,
                  element: el,
                ),
              );
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
              final gels = _filters(el)
                  .where(
                    (m) =>
                        m.kind == ModifierKind.correction ||
                        m.kind == ModifierKind.nd,
                  )
                  .toList();
              // Sin elegir nada, medio CTO. Varias hojas se suman.
              final stack = gels.isEmpty
                  ? [LightModifier.byId('cto-half')!]
                  : gels;
              blockers.add(
                LightBlocker(
                  a,
                  b,
                  transmission: stack.fold(1, (t, m) => t * m.transmission),
                  miredShift: stack.fold(0, (t, m) => t + m.miredShift),
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
            case PropType.hill:
              // Una loma: a la altura de la cara mide menos que en la
              // base, y el sol pasa por encima de su falda.
              blockers.add(
                LightBlocker.circle(
                  el.position,
                  math.max(
                    1,
                    radius *
                        (1 - PlanLight.subjectHeightM / math.max(height, 0.1)),
                  ),
                  element: el,
                  heightM: height,
                  domeRadius: radius,
                ),
              );
            case PropType.rock:
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
        final span = b - a;
        if (span.distance < 1) continue;
        openings.add(_Gap(a, b, el));
        final sill = PlanOpening.sill(el);
        final head = PlanOpening.head(el);
        final dir = span / span.distance;
        final normal = Offset(-dir.dy, dir.dx);
        // El lado de dentro: el que da a un recinto con techo.
        final front = roofedAt?.call(el.position + normal * 10) ?? false;
        final back = roofedAt?.call(el.position - normal * 10) ?? false;
        final inward = back && !front ? normal * -1 : normal;

        // Lo que hay en el hueco: cristal, filtros o tela. Lo que difunde
        // no deja pasar la luz directa: la suelta blanda por el otro lado.
        LightBlocker panel(
          Offset p,
          Offset q,
          double keep,
          double mired,
          double? diffuse,
          String label,
        ) => diffuse != null
            ? LightBlocker(
                p,
                q,
                miredShift: mired,
                baseM: sill,
                heightM: head,
                diffuseDeg: diffuse,
                diffuseKeep: keep,
                label: label,
                element: el,
              )
            : LightBlocker(
                p,
                q,
                transmission: keep,
                miredShift: mired,
                baseM: sill,
                heightM: head,
                label: label,
                element: el,
              );

        final filters = _filters(el);
        var keep = 1.0;
        var mired = 0.0;
        double? diffuse;
        for (final m in filters) {
          keep *= m.transmission;
          mired += m.miredShift;
          final spread = m.spreadDeg;
          if (spread != null) diffuse = math.max(diffuse ?? 0, spread);
        }
        final isWindow = PlanOpening.isWindow(el);
        final side = PlanOpening.filterSide(el);
        final onGlass =
            isWindow && filters.isNotEmpty && side == PlanOpening.sideGlass;

        // Cerrada, las hojas son un solo paño sobre el hueco.
        final leaves = PlanOpening.openDeg(el) <= 3
            ? [(a, b)]
            : PlanOpening.leaves(el);
        if (isWindow) {
          // Las hojas son de cristal y llevan lo que tengan pegado. Giran
          // con la apertura: abierta, la luz entra por el hueco sin
          // tocarlas.
          for (final (hinge, tip) in leaves) {
            blockers.add(
              panel(
                hinge,
                tip,
                glassTransmission * (onGlass ? keep : 1),
                onGlass ? mired : 0,
                onGlass ? diffuse : null,
                onGlass
                    ? 'Ventana (${filters.map((m) => m.name).join(' + ')})'
                    : 'Ventana',
              ),
            );
          }
        } else if (PlanOpening.isDoor(el)) {
          for (final (hinge, tip) in leaves) {
            blockers.add(
              LightBlocker(hinge, tip, baseM: sill, heightM: head, element: el),
            );
          }
        } else if (el.architectureType == ArchitectureType.prisonBars) {
          blockers.add(panel(a, b, 0.7, 0, null, 'Rejas'));
        }

        // Filtros en un marco, por dentro o por fuera: cubren todo el
        // hueco, esté la ventana abierta o cerrada.
        if (filters.isNotEmpty && !onGlass) {
          final off =
              (side == PlanOpening.sideOut ? inward * -1 : inward) *
              PlanOpening.frameOffset;
          // El marco solapa un poco el hueco por los lados.
          final lap = dir * PlanOpening.frameOffset;
          blockers.add(
            panel(
              a + off - lap,
              b + off + lap,
              keep,
              mired,
              diffuse,
              filters.map((m) => m.name).join(' + '),
            ),
          );
        }

        // La cortina tapa una parte del ancho, desde un lado.
        final covered = PlanOpening.curtain(el);
        if (covered > 0.01) {
          final cloth = PlanOpening.curtainMaterial(el);
          final off =
              (PlanOpening.curtainSide(el) == PlanOpening.sideOut
                  ? inward * -1
                  : inward) *
              PlanOpening.curtainOffset;
          // La cortina solapa la pared por el lado del que cuelga y, echada
          // del todo, también por el otro.
          final lap = dir * PlanOpening.curtainOffset;
          blockers.add(
            panel(
              a + off - lap,
              a + off + span * covered + (covered > 0.99 ? lap : Offset.zero),
              cloth.transmission,
              0,
              cloth.transmission > 0 ? 120 : null,
              'Cortina (${cloth.name.toLowerCase()})',
            ),
          );
        }
        continue;
      }

      // Pared suelta de tamaño fijo.
      final (a, b) = _span(el, pieceWidth);
      walls.add((a, b, el));
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
            LightBlocker(
              a + dir * cursor,
              a + dir * from,
              isWall: true,
              element: element,
            ),
          );
        }
        final start = a + dir * math.max(from, cursor);
        final end = a + dir * to;
        if ((end - start).distance > 1) {
          apertures.add(
            LightAperture(
              start,
              end,
              sillM: PlanOpening.sill(gap.element),
              headM: PlanOpening.head(gap.element),
              element: gap.element,
            ),
          );
        }
        cursor = math.max(cursor, to);
      }
      if (length > cursor + 0.5) {
        blockers.add(
          LightBlocker(a + dir * cursor, b, isWall: true, element: element),
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
    required bool diffusers,
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

    if (diffusers) {
      // Telas, cortinas y filtros de difusión: en marcos de grip o en los
      // huecos de las paredes.
      for (final cloth in blockers) {
        final beam = cloth.diffuseDeg;
        if (beam == null || cloth.isCircle || cloth.diffuseKeep <= 0) continue;
        final span = cloth.b - cloth.a;
        if (span.distance < 1) continue;
        emit(
          centre: (cloth.a + cloth.b) / 2,
          tangent: span / span.distance,
          lengthUnits: span.distance,
          heightM: cloth.heightM - cloth.baseM,
          keep: cloth.diffuseKeep,
          mired: cloth.miredShift,
          beamDeg: beam,
          through: true,
          own: cloth,
          label: cloth.label ?? 'Difusión',
        );
      }
      return result;
    }

    LightBlocker? blockerOf(PlanElement el) {
      for (final b in blockers) {
        if (identical(b.element, el)) return b;
      }
      return null;
    }

    for (final el in elements) {
      if (el.type != ElementType.light) continue;
      if (el.lightType != LightType.bounce) continue;
      final rad = el.rotation * math.pi / 180;
      final tangent = Offset(math.cos(rad), math.sin(rad));
      final length = lengthOf(el);
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
      // Por debajo del alféizar y por encima del dintel hay pared. Lo que
      // lleve el hueco (cristal, tela, hojas) va aparte, como topes.
      final h = heightAt(hit);
      if (h < gap.sillM || (h > gap.headM && h < _wallTopAt(gap.centre))) {
        return (transmission: 0, miredShift: 0);
      }
    }
    for (final blocker in blockers) {
      final dome = blocker.domeRadius;
      if (dome != null) {
        // Quien está sobre la loma no queda a su sombra.
        if ((point - blocker.a).distance <= dome) continue;
        if (_domeBlocks(point, toward, blocker, heightAt)) {
          return (transmission: 0, miredShift: 0);
        }
        continue;
      }
      if (blocker.isCircle &&
          (point - blocker.a).distance <= blocker.radius &&
          blocker.heightM <= 2) {
        continue;
      }
      final hit = _rayHit(point, toward, blocker);
      if (hit == null || hit < 0.5) continue;
      final h = heightAt(hit);
      if (h >= blocker.heightM || h < blocker.baseM) continue;
      transmission *= blocker.transmission;
      mired += blocker.miredShift;
      if (transmission <= 0) return (transmission: 0, miredShift: 0);
    }
    return (transmission: transmission, miredShift: mired);
  }

  /// Si un rayo que sube choca con la ladera de una loma.
  static bool _domeBlocks(
    Offset origin,
    Offset dir,
    LightBlocker hill,
    double Function(double units) heightAt,
  ) {
    final radius = hill.domeRadius!;
    final oc = origin - hill.a;
    final b = oc.dx * dir.dx + oc.dy * dir.dy;
    final c = oc.dx * oc.dx + oc.dy * oc.dy - radius * radius;
    final disc = b * b - c;
    if (disc <= 0) return false;
    final root = math.sqrt(disc);
    final enter = math.max(0.0, -b - root);
    final exit = -b + root;
    if (exit <= enter) return false;
    const steps = 16;
    for (var i = 0; i <= steps; i++) {
      final t = enter + (exit - enter) * i / steps;
      final distance = (origin + dir * t - hill.a).distance;
      if (heightAt(t) < hill.domeHeightAt(distance)) return true;
    }
    return false;
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
  /// cielo. La fuente nace justo fuera del hueco, así lo que este lleve
  /// (cristal, filtros, cortina, hojas) actúa sobre ella.
  List<SceneLight> _apertureSources() {
    final env = ambient;
    if (env == null || !env.hasSky) return const [];
    final result = <SceneLight>[];
    for (final gap in apertures) {
      final inward = _inwardOf(gap);
      if (inward == null) continue;
      final outward = inward * -1;
      final outside = gap.centre + outward * skyOffset;
      final areaM2 = gap.width * metersPerUnit * (gap.headM - gap.sillM);
      final what = PlanOpening.isDoor(gap.element!) ? 'puerta' : 'ventana';
      // Una ventana ve medio cielo: la mitad de lo que recibe el suelo.
      final lux = env.skyLux * 0.5 * _openSky(outside, facing: outward);
      final candela = lux * areaM2 / math.pi;
      if (candela < 0.05) continue;
      result.add(
        SceneLight(
          source: LightSource(
            candela: candela,
            beamDeg: 120,
            sizeM: gap.width * metersPerUnit,
            cct: env.skyCct,
            status: PhotometryStatus.estimated,
          ),
          position: outside,
          aim: inward,
          frontOnly: true,
          label: '${env.day ? 'Cielo' : 'Luna'} por $what',
        ),
      );
    }
    return result;
  }

  /// A qué distancia de la pared, por fuera, nace la luz de cielo de un
  /// hueco: más allá de un marco o una cortina puestos por fuera.
  static const double skyOffset = 12;

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
