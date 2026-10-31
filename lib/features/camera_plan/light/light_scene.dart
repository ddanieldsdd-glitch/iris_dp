import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import '../plan_marks.dart';
import '../plan_opening.dart';
import '../plan_segment.dart';
import '../rig/plan_drape.dart';
import '../rig/plan_rig.dart';
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

  /// Alto de la parte que recibe luz y la suelta, si no es todo el tope:
  /// una cortina cuelga más allá del hueco, pero solo le da luz el hueco.
  final double? diffuseHeightM;

  /// Una loma: radio de su base. Su altura baja de [heightM] en el centro
  /// a cero en el borde; [radius] es lo que mide a la altura de la cara.
  final double? domeRadius;

  /// Una loma alargada: cuánto se estira a lo largo de su eje ([turn], en
  /// radianes). 1 = redonda.
  final double stretch;
  final double turn;

  /// Nombre con el que sale en el fotómetro cuando emite.
  final String? label;

  /// Cota del suelo donde está, en metros: lo que hay sobre una colina o
  /// una plataforma tapa desde ahí arriba.
  final double groundM;

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
    this.diffuseHeightM,
    this.label,
    this.groundM = 0,
    this.element,
  }) : radius = 0,
       domeRadius = null,
       stretch = 1,
       turn = 0;

  const LightBlocker.circle(
    Offset centre,
    this.radius, {
    this.element,
    this.transmission = 0,
    this.heightM = 1.75,
    this.domeRadius,
    this.stretch = 1,
    this.turn = 0,
    this.groundM = 0,
  }) : a = centre,
       b = centre,
       miredShift = 0,
       baseM = 0,
       isWall = false,
       diffuseDeg = null,
       diffuseKeep = 0,
       diffuseHeightM = null,
       label = null;

  /// El mismo tope con otra altura o sobre otra cota.
  LightBlocker copyWith({double? heightM, double? groundM}) => isCircle
      ? LightBlocker.circle(
          a,
          radius,
          element: element,
          transmission: transmission,
          heightM: heightM ?? this.heightM,
          domeRadius: domeRadius,
          stretch: stretch,
          turn: turn,
          groundM: groundM ?? this.groundM,
        )
      : LightBlocker(
          a,
          b,
          transmission: transmission,
          miredShift: miredShift,
          heightM: heightM ?? this.heightM,
          baseM: baseM,
          isWall: isWall,
          diffuseDeg: diffuseDeg,
          diffuseKeep: diffuseKeep,
          diffuseHeightM: diffuseHeightM,
          label: label,
          groundM: groundM ?? this.groundM,
          element: element,
        );

  /// Entre qué alturas tapa, contando la cota del suelo.
  double get bottom => groundM + baseM;
  double get top => groundM + heightM;

  bool get isOpaque => transmission <= 0;
  bool get isCircle => radius > 0;

  /// Un vector del plano visto desde el círculo: una loma alargada es un
  /// círculo en un espacio encogido a lo largo de su eje.
  Offset localVector(Offset v) {
    if (stretch == 1) return v;
    final c = math.cos(-turn);
    final s = math.sin(-turn);
    return Offset((v.dx * c - v.dy * s) / stretch, v.dx * s + v.dy * c);
  }

  /// Distancia de un punto al centro, en ese mismo espacio.
  double localDistance(Offset point) => localVector(point - a).distance;

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

  /// Cota del suelo de su pared.
  final double groundM;
  final PlanElement? element;

  const LightAperture(
    this.a,
    this.b, {
    required this.sillM,
    required this.headM,
    this.groundM = 0,
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

  /// Cota del suelo del recinto.
  final double groundM;

  const SceneRoom(
    this.room, {
    required this.roofed,
    required this.ceilingM,
    required this.floor,
    this.groundM = 0,
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

  /// Altura a la que está la fuente, en metros y contando la cota del
  /// suelo: de ahí sale su rayo.
  final double z;

  /// Si es la suma de varias: lo que devuelve una cara de un paño mate por
  /// cada fuente que le da. Comparten sitio, eje y forma, y solo cambian la
  /// intensidad y el color; el fotómetro las enseña por separado.
  final List<SceneLight> parts;

  const SceneLight({
    required this.source,
    required this.position,
    required this.aim,
    required this.label,
    this.z = PlanLight.subjectHeightM,
    this.frontOnly = false,
    this.overheadM,
    this.tiltDeg = 0,
    this.fixture,
    this.surface,
    this.parts = const [],
  });

  bool get isSecondary => fixture == null;

  /// Una sola fuente con la luz de todas [parts], que tienen que salir del
  /// mismo sitio con el mismo eje y la misma forma (ver [parts]).
  ///
  /// Como los lux de una fuente son proporcionales a sus candelas, las
  /// candelas se suman y el color se pondera en mireds por candela: lo que
  /// llega a cualquier punto es lo mismo que sumando las partes.
  factory SceneLight.fused(List<SceneLight> parts) {
    final first = parts.first;
    if (parts.length == 1) return first;
    var candela = 0.0;
    var mired = 0.0;
    var status = first.source.status;
    for (final part in parts) {
      candela += part.source.candela;
      mired += part.source.candela * 1e6 / part.source.cct;
      // La suma es tan fiable como la menos fiable de sus partes.
      if (part.source.status.index > status.index) status = part.source.status;
    }
    final label = first.label.split(' ← ').first;
    return SceneLight(
      source: first.source.copyWith(
        candela: candela,
        cct: 1e6 / (mired / candela),
        status: status,
      ),
      position: first.position,
      aim: first.aim,
      label: '$label ← ${parts.length} fuentes',
      z: first.z,
      frontOnly: first.frontOnly,
      overheadM: first.overheadM,
      tiltDeg: first.tiltDeg,
      surface: first.surface,
      parts: parts,
    );
  }
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

  LightScene({
    required this.lights,
    required this.blockers,
    required this.metersPerUnit,
    this.ambient,
    this.apertures = const [],
    this.rooms = const [],
  });

  /// Lomas: lo que da cota al suelo.
  late final List<LightBlocker> hills = [
    for (final b in blockers)
      if (b.domeRadius != null) b,
  ];

  /// Los topes (salvo las lomas) y los huecos, repartidos en casillas: un
  /// rayo solo mira lo que hay en las casillas que cruza. Los topes van con
  /// su índice en [blockers]; los huecos, a continuación.
  late final _ObstacleGrid _grid = _ObstacleGrid([
    for (final b in blockers)
      if (b.domeRadius != null)
        null
      else if (b.isCircle)
        Rect.fromCircle(
          center: b.a,
          radius: b.radius * math.max(1.0, b.stretch),
        )
      else
        Rect.fromPoints(b.a, b.b),
    for (final gap in apertures) Rect.fromPoints(gap.a, gap.b),
  ]);

  /// Huella de lo que tapa la luz: los topes y los huecos, con su forma y
  /// sus alturas. Dos plantas con la misma huella ven igual desde cualquier
  /// punto (ver [visibleArea]), aunque sus luces sean otras.
  late final int obstacleKey = Object.hash(
    Object.hashAll([
      for (final b in blockers)
        Object.hash(
          b.a,
          b.b,
          b.radius,
          b.transmission,
          b.heightM,
          b.baseM,
          b.groundM,
          b.domeRadius,
          b.stretch,
          b.turn,
        ),
    ]),
    Object.hashAll([
      for (final gap in apertures)
        Object.hash(gap.a, gap.b, gap.sillM, gap.headM, gap.groundM),
    ]),
  );

  /// Cota del suelo en un punto, en metros: la de la loma más alta que
  /// tenga debajo.
  double groundAt(Offset point) => _groundOf(hills, point);

  static double _groundOf(List<LightBlocker> hills, Offset point) {
    var ground = 0.0;
    for (final hill in hills) {
      final distance = hill.localDistance(point);
      if (distance < hill.domeRadius!) {
        ground = math.max(ground, hill.domeHeightAt(distance));
      }
    }
    return ground;
  }

  /// Altura de la cara de alguien de pie en un punto.
  double _faceAt(Offset point) => groundAt(point) + PlanLight.subjectHeightM;

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

  /// La planta vista por la luz.
  ///
  /// Con [fuseBounces], lo que devuelve cada cara de un paño mate (paredes y
  /// rebotes mate) va en una sola fuente: con muchas luces y muchas paredes
  /// son cientos de fuentes menos y la misma luz. Sin él, una por cada
  /// fuente que le da (sirve para comprobarlo).
  factory LightScene.from(
    Iterable<PlanElement> elements, {
    required double metersPerUnit,
    bool wallBounce = true,
    PlanAmbient? ambient,
    bool fuseBounces = true,
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
    // La cota del suelo la dan las lomas; todo lo demás se apoya en ella.
    final hills = [
      for (final b in built.blockers)
        if (b.domeRadius != null) b,
    ];
    double ground(Offset p) => hills.isEmpty ? 0 : _groundOf(hills, p);
    for (var i = 0; i < rooms.length; i++) {
      final room = rooms[i];
      rooms[i] = SceneRoom(
        room.room,
        roofed: room.roofed,
        ceilingM: room.ceilingM,
        floor: room.floor,
        groundM: ground(room.room.interiorPoint),
      );
    }
    // La pared de un recinto con techo llega hasta él.
    final blockers = <LightBlocker>[
      for (final blocker in built.blockers)
        if (blocker.domeRadius != null)
          blocker
        else if (blocker.isWall)
          blocker.copyWith(
            heightM: _wallHeight(blocker, rooms),
            groundM: ground((blocker.a + blocker.b) / 2),
          )
        else
          blocker.copyWith(groundM: ground((blocker.a + blocker.b) / 2)),
    ];
    final apertures = [
      for (final gap in built.apertures)
        LightAperture(
          gap.a,
          gap.b,
          sillM: gap.sillM,
          headM: gap.headM,
          groundM: ground(gap.centre),
          element: gap.element,
        ),
    ];
    // Altura de cada aparato: en trípode, a la de la cara; colgado, a la
    // de su techo (o la que se le haya puesto), sin atravesarlo.
    double fixtureZ(PlanElement el) {
      final base = ground(el.position);
      if (!PlanLight.isOverhead(el)) {
        // En trípode, a su altura si la tiene (F6.21.5); si no, a la cara.
        return base +
            (PlanLight.hasOwnAim(el)
                ? PlanLight.heightOf(el)
                : PlanLight.subjectHeightM);
      }
      final ceiling = _ceilingAt(rooms, el.position);
      final mount = el.props[PlanLight.heightKey] != null
          ? PlanLight.heightOf(el)
          : ceiling ?? PlanLight.defaultCeilingHeight;
      return base + (ceiling == null ? mount : math.min(mount, ceiling));
    }

    final fixtures = <SceneLight>[
      for (final el in all)
        if (PlanLight.of(el) case final light?)
          SceneLight(
            source: light.source,
            position: el.position,
            aim: aimOf(el),
            // Sin altura propia, cuelga del techo del recinto donde está.
            overheadM: !PlanLight.isOverhead(el)
                ? _standDrop(el)
                : el.props[PlanLight.heightKey] != null
                ? PlanLight.overheadDrop(el)
                : ((_ceilingAt(rooms, el.position) ??
                              PlanLight.defaultCeilingHeight) -
                          PlanLight.subjectHeightM)
                      .clamp(0.3, 50.0),
            tiltDeg: PlanLight.isOverhead(el)
                ? PlanLight.tiltOf(el)
                : _standDrop(el) == null
                ? 0
                : (90 + PlanLight.elevationOf(el)).clamp(0.0, 89.0),
            z: fixtureZ(el),
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
      ...direct._secondarySources(
        all,
        wallBounce: bounce,
        diffusers: false,
        fuse: fuseBounces,
      ),
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

  /// Un pilar: tapa hasta su altura, redondo o cuadrado (girado con él).
  static void _addPillar(
    List<LightBlocker> blockers,
    PlanElement el,
    double metersPerUnit,
  ) {
    final size = PlanPillar.sizeM(el) / metersPerUnit;
    final height = PlanPillar.heightM(el);
    if (PlanPillar.isRound(el)) {
      blockers.add(
        LightBlocker.circle(el.position, size / 2, heightM: height, element: el),
      );
      return;
    }
    final rad = el.rotation * math.pi / 180;
    final u = Offset(math.cos(rad), math.sin(rad)) * (size / 2);
    final v = Offset(-math.sin(rad), math.cos(rad)) * (size / 2);
    final corners = [
      el.position - u - v,
      el.position + u - v,
      el.position + u + v,
      el.position - u + v,
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
  }

  /// Una tela: tapa de su bajo a su borde de arriba, que sigue la
  /// catenaria, y deja pasar lo que deja su tejido.
  static void _addDrape(
    List<LightBlocker> blockers,
    PlanElement el,
    double metersPerUnit,
  ) {
    final c = PlanDrape.catenary(el, metersPerUnit);
    final transmission = PlanDrape.material(el).transmission;
    const pieces = 8;
    var from = PlanSegment.pointAt(el, 0);
    for (var i = 1; i <= pieces; i++) {
      final to = PlanSegment.pointAt(el, i / pieces);
      final mid = (i - 0.5) / pieces;
      blockers.add(
        LightBlocker(
          from,
          to,
          heightM: PlanDrape.topAt(el, mid, c),
          baseM: PlanDrape.bottomAt(el, mid, c),
          transmission: transmission,
          element: el,
        ),
      );
      from = to;
    }
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

  static const stretchKey = 'stretch';
  static const roughKey = 'rough';
  static const seedKey = 'seed';

  /// Cuánto se alarga una colina a lo largo de su eje. 1 = redonda.
  static double hillStretch(PlanElement el) =>
      ((el.props[stretchKey] as num?)?.toDouble() ?? 1).clamp(0.25, 6.0);

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
            blockers.add(
              LightBlocker.circle(
                el.position,
                body,
                element: el,
                heightM: el.type == ElementType.actor
                    ? PlanMarks.heightM(el)
                    : 1.6,
              ),
            );
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
          if (PlanPillar.isPillar(el)) {
            _addPillar(blockers, el, metersPerUnit);
            continue;
          }
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
                  stretch: hillStretch(el),
                  turn: el.rotation * math.pi / 180,
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
        if (PlanDrape.isDrape(el)) {
          _addDrape(blockers, el, metersPerUnit);
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
        // Una cortina o un marco cuelgan algo más allá del hueco por
        // arriba y por abajo ([over]): si no, el sol se colaría por debajo.
        LightBlocker panel(
          Offset p,
          Offset q,
          double keep,
          double mired,
          double? diffuse,
          String label, {
          double over = 0,
        }) => diffuse != null
            ? LightBlocker(
                p,
                q,
                miredShift: mired,
                baseM: math.max(0, sill - over),
                heightM: head + over,
                diffuseDeg: diffuse,
                diffuseKeep: keep,
                diffuseHeightM: head - sill,
                label: label,
                element: el,
              )
            : LightBlocker(
                p,
                q,
                transmission: keep,
                miredShift: mired,
                baseM: math.max(0, sill - over),
                heightM: head + over,
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
        if (isWindow && PlanOpening.solidLeaves(el)) {
          // Contraventanas: macizas, como una puerta.
          for (final (hinge, tip) in leaves) {
            blockers.add(
              LightBlocker(hinge, tip, baseM: sill, heightM: head, element: el),
            );
          }
        } else if (isWindow) {
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
              over: 0.15,
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
              over: 0.4,
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
    LightBlocker? own, {
    double? z,
  }) {
    final span = centre - light.position;
    final units = span.distance;
    if (units < 1e-6 || light.source.candela <= 0) return null;
    final toSurface = span / units;
    // Ley del coseno al incidir: la luz que llega de lado a una superficie
    // se reparte en más área.
    final cos = -(toSurface.dx * normal.dx + toSurface.dy * normal.dy);
    if (cos <= 0.02) return null;
    final height = z ?? _faceAt(centre);
    final passed = _throughput(
      light.position,
      centre,
      ignore: own,
      zFrom: light.z,
      zTo: height,
    );
    if (passed.transmission <= 0) return null;
    final lux =
        luxFrom(light, units, _offAxis(light, toSurface), receiverZ: height) *
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
  ///
  /// Con [fuse], lo que devuelve cada cara de una superficie mate va en una
  /// sola fuente ([SceneLight.fused]). Solo se hace con los rebotes, que es
  /// lo último: las telas alimentan después a las paredes, y ahí sumar antes
  /// de los umbrales de cada fuente cambiaría algún resto de luz.
  List<SceneLight> _secondarySources(
    List<PlanElement> elements, {
    required bool wallBounce,
    required bool diffusers,
    bool fuse = false,
  }) {
    final result = <SceneLight>[];

    void emit({
      required Offset centre,
      required Offset tangent,
      required double lengthUnits,
      required double heightM,
      double baseM = 0,
      required double keep,
      required double mired,
      required double beamDeg,
      required bool through,
      required LightBlocker? own,
      required String label,
    }) {
      final areaM2 = lengthUnits * metersPerUnit * heightM;
      final normalA = Offset(-tangent.dy, tangent.dx);
      // A qué altura está el centro de la superficie.
      final z = groundAt(centre) + baseM + heightM / 2;
      // Una superficie mate reparte la luz según el coseno de Lambert, y
      // el flujo Φ que recibe da Φ/π en su eje. Una brillante (plata,
      // espejo) conserva el haz: Φ entre su ángulo sólido, y lo manda en
      // la dirección del reflejo.
      final matte = beamDeg >= 90;
      final spread = matte ? math.pi : LightSource.solidAngle(beamDeg);
      // Lo que sale por cada cara, si se funde: por la de [normalA] y por
      // la contraria.
      final faces = fuse && matte ? (<SceneLight>[], <SceneLight>[]) : null;
      void add(SceneLight light, Offset facing) {
        if (faces == null) {
          result.add(light);
        } else if (facing == normalA) {
          faces.$1.add(light);
        } else {
          faces.$2.add(light);
        }
      }

      void flush() {
        if (faces == null) return;
        for (final face in [faces.$1, faces.$2]) {
          if (face.isNotEmpty) result.add(SceneLight.fused(face));
        }
      }

      Offset reflected(Offset incoming, Offset normal) {
        final dot = incoming.dx * normal.dx + incoming.dy * normal.dy;
        final out = incoming - normal * (2 * dot);
        return out.distance < 1e-6 ? normal : out / out.distance;
      }

      for (final light in lights) {
        final toLight = light.position - centre;
        // La cara que mira a la fuente.
        final facing = (toLight.dx * normalA.dx + toLight.dy * normalA.dy) >= 0
            ? normalA
            : normalA * -1;
        final incident = _incident(light, centre, facing, own, z: z);
        if (incident == null) continue;
        final flux = incident.lux * areaM2 * keep;
        final candela = flux / spread;
        if (candela < 1) continue;
        final incoming = toLight.distance < 1e-6
            ? facing * -1
            : toLight / -toLight.distance;
        add(
          SceneLight(
            source: LightSource(
              candela: candela,
              beamDeg: beamDeg,
              sizeM: lengthUnits * metersPerUnit,
              cct: _shift(incident.cct, mired),
              status: light.source.status,
              lambertian: matte,
            ),
            position: centre,
            // Una tela emite por la cara contraria a la fuente; un rebote
            // mate, por la misma; uno brillante, hacia el reflejo.
            aim: through
                ? facing * -1
                : matte
                ? facing
                : reflected(incoming, facing),
            frontOnly: true,
            z: z,
            surface: own,
            label: '$label ← ${light.label}',
          ),
          facing,
        );
      }

      // El sol también le da.
      final env = ambient;
      if (env == null || !env.hasSun) return flush();
      final toward = env.towardSun;
      final dot = toward.dx * normalA.dx + toward.dy * normalA.dy;
      if (dot.abs() < 0.05) return flush();
      final facing = dot >= 0 ? normalA : normalA * -1;
      // El sol puede darle solo en parte (la mancha de una ventana cae
      // baja): se mira a varias alturas y a lo largo de la superficie.
      var lit = 0.0;
      var sunMired = 0.0;
      const across = [-1 / 3, 0.0, 1 / 3];
      const up = [1 / 6, 1 / 2, 5 / 6];
      for (final k in across) {
        for (final v in up) {
          final part = sunThroughput(
            centre + tangent * (lengthUnits * k) + facing * 3,
            heightM: baseM + heightM * v,
          );
          lit += part.transmission;
          if (part.transmission > 0) sunMired = part.miredShift;
        }
      }
      final sun = (
        transmission: lit / (across.length * up.length),
        miredShift: sunMired,
      );
      if (sun.transmission <= 0) return flush();
      final cosElevation = 1 / math.sqrt(1 + _sunTan * _sunTan);
      final lux =
          env.condition.sunLux * sun.transmission * cosElevation * dot.abs();
      final candela = lux * areaM2 * keep / spread;
      if (candela < 1) return flush();
      add(
        SceneLight(
          source: LightSource(
            candela: candela,
            beamDeg: beamDeg,
            sizeM: lengthUnits * metersPerUnit,
            cct: _shift(env.condition.sunCct, sun.miredShift + mired),
            status: PhotometryStatus.estimated,
            lambertian: matte,
          ),
          position: centre,
          aim: through
              ? facing * -1
              : matte
              ? facing
              : reflected(toward * -1, facing),
          frontOnly: true,
          z: z,
          surface: own,
          label: '$label ← Sol',
        ),
        facing,
      );
      flush();
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
          heightM: cloth.diffuseHeightM ?? cloth.heightM - cloth.baseM,
          baseM:
              cloth.baseM +
              (cloth.heightM - cloth.baseM - (cloth.diffuseHeightM ?? 0)) *
                  (cloth.diffuseHeightM == null ? 0 : 0.5),
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
      final oc = blocker.localVector(origin - blocker.a);
      final d = blocker.localVector(dir);
      final a = d.dx * d.dx + d.dy * d.dy;
      if (a < 1e-12) return null;
      final b = oc.dx * d.dx + oc.dy * d.dy;
      final c = oc.dx * oc.dx + oc.dy * oc.dy - blocker.radius * blocker.radius;
      // El origen está dentro del círculo: no se tapa a sí mismo.
      if (c <= 0) return null;
      final disc = b * b - a * c;
      if (disc < 0) return null;
      final t = (-b - math.sqrt(disc)) / a;
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
  /// Distancia a la que un rayo cruza el tramo [a]–[b], o `null`.
  static double? _segmentHit(Offset origin, Offset dir, Offset a, Offset b) {
    final s = b - a;
    final denom = dir.dx * s.dy - dir.dy * s.dx;
    if (denom.abs() < 1e-9) return null;
    final diff = a - origin;
    final t = (diff.dx * s.dy - diff.dy * s.dx) / denom;
    final u = (diff.dx * dir.dy - diff.dy * dir.dx) / denom;
    if (t <= 1e-6 || u < 0 || u > 1) return null;
    return t;
  }

  /// Lo que queda de un rayo de luz que va en línea recta.
  ///
  /// Sale de [from] a la altura [zFrom], avanza [length] unidades hacia
  /// [dir] y cambia de altura [slope] metros por unidad. A cada cosa que
  /// cruza llega a la altura que le toca: la tapa si cae entre su base y
  /// su tope. Vale para un aparato (de su altura a la del punto medido),
  /// para el sol (un rayo que sube sin fin) y para el terreno.
  ({double transmission, double miredShift}) _ray(
    Offset from,
    Offset dir,
    double length,
    double zFrom,
    double slope, {
    LightBlocker? ignore,
    Offset? receiver,
  }) {
    const none = (transmission: 0.0, miredShift: 0.0);
    double zAt(double t) => zFrom + t * slope;

    // Los techos: si el rayo cruza la altura de un techo dentro de su
    // recinto, lo atraviesa.
    if (slope.abs() > 1e-9) {
      for (final room in rooms) {
        if (!room.roofed) continue;
        final t = (room.groundM + room.ceilingM - zFrom) / slope;
        if (t > 1e-3 && t < length && room.room.contains(from + dir * t)) {
          return none;
        }
      }
    }

    // Los huecos: por debajo del alféizar y por encima del dintel hay
    // pared. Lo que lleve el hueco (cristal, tela, hojas) va como tope.
    // Las lomas, aparte: no van en la rejilla.
    var transmission = 1.0;
    var mired = 0.0;
    var blocked = false;
    final count = blockers.length;
    _grid.walk(from, dir, length, (_) => !blocked, (i) {
      if (i >= count) {
        final gap = apertures[i - count];
        final hit = _segmentHit(from, dir, gap.a, gap.b);
        if (hit == null || hit < 0.5 || hit >= length - 0.5) return;
        final z = zAt(hit) - gap.groundM;
        if (z < gap.sillM || (z > gap.headM && z < _wallTopAt(gap.centre))) {
          blocked = true;
        }
        return;
      }
      final blocker = blockers[i];
      if (identical(blocker, ignore)) return;
      // Quien está dentro del cuerpo de una persona no queda a su sombra.
      if (receiver != null &&
          blocker.isCircle &&
          blocker.heightM <= 2 &&
          (receiver - blocker.a).distance <= blocker.radius) {
        return;
      }
      final hit = _rayHit(from, dir, blocker);
      // Un tope a ras del punto medido no cuenta: el punto está «en» la
      // pared, no detrás.
      if (hit == null || hit < 0.5 || hit >= length - 0.5) return;
      final z = zAt(hit);
      if (z >= blocker.top || z < blocker.bottom) return;
      transmission *= blocker.transmission;
      mired += blocker.miredShift;
      if (transmission <= 0) blocked = true;
    });
    if (blocked) return none;
    for (final hill in hills) {
      if (identical(hill, ignore)) continue;
      if (_domeBlocks(from, dir, hill, zAt, length)) return none;
    }
    return (transmission: transmission, miredShift: mired);
  }

  /// Lo que queda de la luz entre dos puntos y el tinte que coge. Sin
  /// alturas, va de cara a cara.
  ({double transmission, double miredShift}) _throughput(
    Offset from,
    Offset to, {
    LightBlocker? ignore,
    double? zFrom,
    double? zTo,
  }) {
    final span = to - from;
    final distance = span.distance;
    if (distance < 1e-6) return (transmission: 1, miredShift: 0);
    final start = zFrom ?? _faceAt(from);
    final end = zTo ?? _faceAt(to);
    return _ray(
      from,
      span / distance,
      distance,
      start,
      (end - start) / distance,
      ignore: ignore,
      receiver: to,
    );
  }

  /// Parte de la luz que llega de [from] a [to], según lo que hay en medio.
  /// 1 = nada en medio; 0 = tapado.
  double transmissionBetween(Offset from, Offset to) =>
      _throughput(from, to).transmission;

  /// Hasta dónde ve una fuente a la altura [z] la ladera de una loma: la
  /// ilumina por el lado que le da la cara y deja a oscuras lo que queda
  /// tras su perfil.
  double _domeReach(
    Offset origin,
    Offset dir,
    double max,
    double z,
    LightBlocker hill,
  ) {
    final radius = hill.domeRadius!;
    final oc = hill.localVector(origin - hill.a);
    final d = hill.localVector(dir);
    final a = d.dx * d.dx + d.dy * d.dy;
    if (a < 1e-12) return max;
    final b = oc.dx * d.dx + oc.dy * d.dy;
    final c = oc.dx * oc.dx + oc.dy * oc.dy - radius * radius;
    final disc = b * b - a * c;
    if (disc <= 0) return max;
    final root = math.sqrt(disc);
    final enter = math.max(1.0, (-b - root) / a);
    final exit = math.min(max, (-b + root) / a);
    if (exit <= enter) return max;
    // Pendiente de la línea de visión más alta que ha hecho falta hasta
    // aquí para salvar el terreno.
    var horizon = double.negativeInfinity;
    const steps = 32;
    for (var i = 0; i <= steps; i++) {
      final t = enter + (exit - enter) * i / steps;
      final ground = hill.domeHeightAt(hill.localDistance(origin + dir * t));
      final toFace = (ground + PlanLight.subjectHeightM - z) / t;
      if (toFace < horizon - 1e-6) return t;
      horizon = math.max(horizon, (ground - z) / t);
    }
    // Detrás de la loma, el suelo vuelve a su cota: ¿se ve por encima?
    final beyond = exit + 1;
    final toFace =
        (groundAt(origin + dir * beyond) + PlanLight.subjectHeightM - z) /
        beyond;
    return toFace < horizon ? exit : max;
  }

  /// Distancia hasta el primer tope opaco en una dirección, con [max] de
  /// límite, para una fuente a la altura [z] (la de la cara, si no se da).
  double reachAlong(
    Offset origin,
    Offset dir,
    double max, {
    LightBlocker? ignore,
    bool fromAbove = false,
    double? z,
  }) => _reach(
    origin,
    dir,
    max,
    height: z ?? _faceAt(origin),
    ignore: ignore,
    fromAbove: fromAbove,
  ).t;

  /// [reachAlong], y además con qué choca: su índice en la rejilla (ver
  /// [_grid]), [_hitDome] si es una loma o [_noHit] si con nada.
  ({double t, int item}) _reach(
    Offset origin,
    Offset dir,
    double max, {
    required double height,
    LightBlocker? ignore,
    bool fromAbove = false,
  }) {
    var best = max;
    var item = _noHit;
    final count = blockers.length;
    _grid.walk(origin, dir, max, (enter) => enter <= best, (i) {
      double? hit;
      if (i < count) {
        final blocker = blockers[i];
        if (!blocker.isOpaque || identical(blocker, ignore)) return;
        if (fromAbove && blocker.isCircle && blocker.heightM <= 2) return;
        if (!fromAbove && (height >= blocker.top || height < blocker.bottom)) {
          return;
        }
        hit = _rayHit(origin, dir, blocker);
      } else {
        // Un hueco más alto o más bajo que la fuente es pared para ella.
        if (fromAbove) return;
        final gap = apertures[i - count];
        final rel = height - gap.groundM;
        if (rel >= gap.sillM && rel <= gap.headM) return;
        hit = _segmentHit(origin, dir, gap.a, gap.b);
      }
      if (hit != null && hit < best) {
        best = hit;
        item = i;
      }
    });
    for (final hill in hills) {
      if (!hill.isOpaque || identical(hill, ignore)) continue;
      final t = _domeReach(origin, dir, best, height, hill);
      if (t < best) {
        best = t;
        item = _hitDome;
      }
    }
    return (t: best, item: item);
  }

  static const _noHit = -1;
  static const _hitDome = -2;

  /// Zona que alcanza una luz desde [origin] hasta [reach], recortada por
  /// lo que la tapa: lo que queda a su sombra no entra. [rays] es cuántos
  /// rayos se tiran alrededor, además de los de las esquinas (menos, en
  /// borrador).
  ///
  /// Se barre por ángulos: solo se tiran rayos hacia los extremos de lo que
  /// tapa (tres por esquina, para que el corte de la sombra salga limpio),
  /// las tangentes de los cuerpos y los cruces con el borde del alcance.
  /// Entre dos rayos que dan en la misma pared, el contorno es esa pared;
  /// entre dos que no dan en nada, el arco del alcance. Solo donde cambia
  /// lo que se ve (un cuerpo, dos paredes que se cruzan) se tiran más.
  Path visibleArea(
    Offset origin,
    double reach, {
    LightBlocker? ignore,
    bool fromAbove = false,
    double? z,
    int rays = 240,
  }) {
    for (final hill in hills) {
      if (identical(hill, ignore)) continue;
      final wide = hill.domeRadius! * math.max(1.0, hill.stretch);
      if ((hill.a - origin).distance < reach + wide) {
        return visibleAreaByRays(
          origin,
          reach,
          ignore: ignore,
          fromAbove: fromAbove,
          z: z,
          rays: rays,
        );
      }
    }
    final height = z ?? _faceAt(origin);
    const twoPi = 2 * math.pi;
    final step = twoPi / rays;
    final events = <double>[];
    void corner(Offset p) {
      final d = p - origin;
      if (d.distance > reach + 1 || d.distance < 1e-6) return;
      final angle = math.atan2(d.dy, d.dx);
      for (final delta in const [-0.0007, 0.0, 0.0007]) {
        events.add((angle + delta) % twoPi);
      }
    }

    // Donde un tramo cruza el borde del alcance, el contorno pasa de arco
    // a pared.
    void crossings(Offset a, Offset b) {
      final s = b - a;
      final f = a - origin;
      final qa = s.dx * s.dx + s.dy * s.dy;
      if (qa < 1e-12) return;
      final qb = 2 * (f.dx * s.dx + f.dy * s.dy);
      final qc = f.dx * f.dx + f.dy * f.dy - reach * reach;
      final disc = qb * qb - 4 * qa * qc;
      if (disc <= 0) return;
      final root = math.sqrt(disc);
      for (final u in [(-qb - root) / (2 * qa), (-qb + root) / (2 * qa)]) {
        if (u <= 0 || u >= 1) continue;
        final d = f + s * u;
        final angle = math.atan2(d.dy, d.dx);
        for (final delta in const [-0.0007, 0.0007]) {
          events.add((angle + delta) % twoPi);
        }
      }
    }

    void segment(Offset a, Offset b) {
      corner(a);
      corner(b);
      crossings(a, b);
    }

    for (final blocker in blockers) {
      if (!blocker.isOpaque || identical(blocker, ignore)) continue;
      if (blocker.domeRadius != null) continue;
      if (fromAbove && blocker.isCircle && blocker.heightM <= 2) continue;
      if (!fromAbove && (height >= blocker.top || height < blocker.bottom)) {
        continue;
      }
      if (!blocker.isCircle) {
        segment(blocker.a, blocker.b);
        continue;
      }
      // Las dos tangentes al círculo, y unos cuantos por dentro para que la
      // sombra siga el contorno.
      final d = blocker.a - origin;
      final distance = d.distance;
      final wide = blocker.radius * math.max(1.0, blocker.stretch);
      if (distance <= wide || distance > reach + wide) continue;
      final centre = math.atan2(d.dy, d.dx);
      final half = math.asin(wide / distance);
      for (final edge in [centre - half, centre + half]) {
        for (final delta in const [-0.001, 0.001]) {
          events.add((edge + delta) % twoPi);
        }
      }
      for (var i = 1; i < 6; i++) {
        events.add((centre - half + 2 * half * i / 6) % twoPi);
      }
    }
    if (!fromAbove) {
      // Un hueco más alto o más bajo que la fuente es pared para ella.
      for (final gap in apertures) {
        final rel = height - gap.groundM;
        if (rel >= gap.sillM && rel <= gap.headM) continue;
        segment(gap.a, gap.b);
      }
    }
    if (events.isEmpty) events.add(0);
    events.sort();

    final count = blockers.length;
    ({double t, int item}) cast(double angle) => _reach(
      origin,
      Offset(math.cos(angle), math.sin(angle)),
      reach,
      height: height,
      ignore: ignore,
      fromAbove: fromAbove,
    );
    final hits = [for (final angle in events) cast(angle)];

    final path = Path();
    var first = true;
    void to(double angle, double t) {
      final x = origin.dx + math.cos(angle) * t;
      final y = origin.dy + math.sin(angle) * t;
      if (first) {
        path.moveTo(x, y);
        first = false;
      } else {
        path.lineTo(x, y);
      }
    }

    for (var i = 0; i < events.length; i++) {
      final from = events[i];
      final hit = hits[i];
      to(from, hit.t);
      final last = i == events.length - 1;
      final until = last ? events.first + twoPi : events[i + 1];
      final next = last ? hits.first : hits[i + 1];
      final open = hit.item == _noHit && next.item == _noHit;
      // La misma pared (o el mismo hueco) a los dos lados: es el contorno.
      final wall =
          hit.item >= 0 &&
          hit.item == next.item &&
          (hit.item >= count || !blockers[hit.item].isCircle);
      if (wall) continue;
      // Los rayos de la rejilla que caen dentro, como los de siempre.
      for (var k = (from / step).floor() + 1; k * step < until; k++) {
        final angle = k * step;
        to(angle, open ? reach : cast(angle).t);
      }
    }
    return path..close();
  }

  /// [visibleArea] a la antigua: un rayo cada pocos grados y tres en cada
  /// esquina. Se usa cuando hay lomas, cuya sombra no es una recta, y sirve
  /// de referencia para comprobar el barrido.
  Path visibleAreaByRays(
    Offset origin,
    double reach, {
    LightBlocker? ignore,
    bool fromAbove = false,
    double? z,
    int rays = 240,
  }) {
    // Un rayo cada grado y medio, más uno a cada lado de cada esquina para
    // que el corte de la sombra salga limpio. Todos los ángulos van de 0 a
    // 2π: mezclados con negativos, el contorno se cruza y deja de recortar.
    const twoPi = 2 * math.pi;
    final angles = <double>[for (var i = 0; i < rays; i++) i * twoPi / rays];
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
      if (fromAbove && blocker.isCircle && blocker.heightM <= 2) continue;
      if (blocker.isCircle) {
        // Las dos tangentes al círculo.
        final d = blocker.a - origin;
        final distance = d.distance;
        final wide =
            (blocker.domeRadius ?? blocker.radius) *
            math.max(1.0, blocker.stretch);
        if (distance <= wide || distance > reach + wide) {
          continue;
        }
        final centre = math.atan2(d.dy, d.dx);
        final half = math.asin(wide / distance);
        for (final edge in [centre - half, centre + half]) {
          for (final delta in const [-0.001, 0.001]) {
            angles.add((edge + delta) % twoPi);
          }
        }
        // Y unos cuantos por dentro, para que la sombra siga el contorno.
        final inner = blocker.domeRadius == null ? 6 : 36;
        for (var i = 1; i < inner; i++) {
          angles.add((centre - half + 2 * half * i / inner) % twoPi);
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
                z: z,
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
  /// Un foco de trípode con altura o inclinación propias, por encima de la
  /// cara (F6.21.5), alumbra como uno colgado: desde su altura y con el
  /// ángulo de su haz, así que lo que queda por debajo del eje recibe menos.
  /// Sin altura ni inclinación propias, o a la altura de la cara, sigue como
  /// siempre: `null`.
  static double? _standDrop(PlanElement el) {
    if (PlanLight.isOverhead(el) || !PlanLight.hasOwnAim(el)) return null;
    final drop = PlanLight.heightOf(el) - PlanLight.subjectHeightM;
    return drop < 0.3 ? null : drop;
  }

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
  double luxFrom(
    SceneLight light,
    double units,
    double offAxisDeg, {
    double? receiverZ,
  }) {
    final flat = units * metersPerUnit;
    if (light.overheadM == null) {
      // Ley del cuadrado de la distancia, con la distancia real: si la
      // fuente y el punto están a distinta altura, en diagonal.
      final rise = receiverZ == null ? 0.0 : receiverZ - light.z;
      return light.source.illuminance(
        math.max(math.sqrt(flat * flat + rise * rise), 0.05),
        offAxisDeg: offAxisDeg,
      );
    }
    final drop = receiverZ == null
        ? light.overheadM!
        : math.max(0.3, (light.z - receiverZ).abs());
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

  /// Toda la luz que llega a un punto, ya sumada: para pintar la planta.
  ///
  /// Las fuentes anchas se miran desde tres puntos de su frente, así sus
  /// sombras salen con penumbra. El sol se mide a [sunHeightM] del suelo
  /// (en el suelo, por defecto: es donde se ve su mancha). Lo que aporta
  /// menos de [cutoff] lux ni se comprueba si está tapado.
  ({double lux, double cct}) sampleAt(
    Offset point, {
    double cutoff = 0,
    double sunHeightM = 0,
  }) {
    var total = 0.0;
    var mired = 0.0;
    void add(double lux, double kelvin) {
      if (lux <= 0) return;
      total += lux;
      mired += lux * 1e6 / (kelvin <= 0 ? 5600 : kelvin);
    }

    final face = _faceAt(point);

    for (final light in lights) {
      final source = light.source;
      if (source.candela <= 0) continue;
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
      final raw = luxFrom(light, units, offAxis, receiverZ: face);
      if (raw <= cutoff) continue;

      final above = light.overheadM != null;
      // De borde a borde de la fuente: así la penumbra mide lo que debe,
      // tamaño × (objeto→suelo) / (fuente→objeto).
      final half = source.sizeM / metersPerUnit / 2;
      double keep;
      double shift;
      if (half < 5 || above) {
        final passed = _throughput(
          light.position,
          point,
          ignore: light.surface,
          zFrom: light.z,
          zTo: face,
        );
        keep = passed.transmission;
        shift = passed.miredShift;
      } else {
        // Penumbra: la fuente vista desde tres puntos de su ancho.
        final across = Offset(-light.aim.dy, light.aim.dx) * half;
        keep = 0;
        shift = 0;
        for (final k in const [-1.0, 0.0, 1.0]) {
          final passed = _throughput(
            light.position + across * k,
            point,
            ignore: light.surface,
            zFrom: light.z,
            zTo: face,
          );
          keep += passed.transmission / 3;
          if (passed.transmission > 0) shift = passed.miredShift;
        }
      }
      if (keep <= 0) continue;
      add(raw * keep, _shift(source.cct, shift));
    }

    final env = ambient;
    if (env != null) {
      if (env.hasSun) {
        final passed = sunThroughput(point, heightM: sunHeightM);
        add(
          env.condition.sunLux * passed.transmission,
          _shift(env.condition.sunCct, passed.miredShift),
        );
      }
      if (env.hasSky && env.skyLux > cutoff && !isRoofed(point)) {
        add(env.skyLux * _openSky(point), env.skyCct);
      }
    }
    return (lux: total, cct: total <= 0 ? 0 : 1e6 / (mired / total));
  }

  /// Lux por debajo de los que una fuente no cuenta en el fotómetro.
  static const double minContribution = 0.01;

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
      final face = _faceAt(point);
      // Lo que ni sin nada delante llega al mínimo que se enseña no se
      // comprueba: lo que tape solo puede quitar.
      final raw = luxFrom(light, units, offAxis, receiverZ: face);
      if (raw <= minContribution) continue;
      final passed = _throughput(
        light.position,
        point,
        ignore: light.surface,
        zFrom: light.z,
        zTo: face,
      );
      if (passed.transmission <= 0) continue;
      final lux = raw * passed.transmission;
      // Una fuente fundida se enseña por partes: cada una aporta en
      // proporción a sus candelas, con su color.
      for (final part in light.parts.isEmpty ? [light] : light.parts) {
        final share = identical(part, light)
            ? lux
            : lux * part.source.candela / light.source.candela;
        if (share > minContribution) {
          result.add(
            LightContribution(
              part,
              share,
              _shift(part.source.cct, passed.miredShift),
            ),
          );
        }
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
    // Rayos paralelos: el sol no cae con la distancia; solo importa qué
    // cruza su rayo mientras sube.
    return _ray(
      point,
      env.towardSun,
      double.infinity,
      groundAt(point) + heightM,
      _sunTan * metersPerUnit,
      receiver: point,
    );
  }

  /// Si un rayo que sube choca con la ladera de una loma.
  static bool _domeBlocks(
    Offset origin,
    Offset dir,
    LightBlocker hill,
    double Function(double units) heightAt, [
    double length = double.infinity,
  ]) {
    final radius = hill.domeRadius!;
    final oc = hill.localVector(origin - hill.a);
    final d = hill.localVector(dir);
    final a = d.dx * d.dx + d.dy * d.dy;
    if (a < 1e-12) return false;
    final b = oc.dx * d.dx + oc.dy * d.dy;
    final c = oc.dx * oc.dx + oc.dy * oc.dy - radius * radius;
    final disc = b * b - a * c;
    if (disc <= 0) return false;
    final root = math.sqrt(disc);
    final enter = math.max(0.0, (-b - root) / a);
    final exit = math.min(length, (-b + root) / a);
    if (exit <= enter) return false;
    const steps = 24;
    // Los extremos se dejan fuera: ahí están la fuente o el punto medido,
    // apoyados en la ladera.
    for (var i = 1; i < steps; i++) {
      final t = enter + (exit - enter) * i / steps;
      final distance = hill.localDistance(origin + dir * t);
      if (heightAt(t) < hill.domeHeightAt(distance) - 0.02) return true;
    }
    return false;
  }

  /// Hasta dónde sube la pared en un punto de ella: el techo más alto de
  /// los recintos que toca o, si no, la altura de pared de siempre.
  double wallTopAt(Offset onWall) => _wallTopAt(onWall);

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
          z: gap.groundM + (gap.sillM + gap.headM) / 2,
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
          z: room.groundM + 0.02,
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

/// Rejilla de casillas cuadradas sobre los obstáculos de la planta. Cada
/// casilla sabe qué obstáculos la tocan; un rayo recorre solo las casillas
/// que cruza, en orden (Amanatides y Woo, «A Fast Voxel Traversal
/// Algorithm», 1987).
class _ObstacleGrid {
  late final Rect _bounds;
  late final double _cell;
  late final int _cols;
  late final int _rows;
  late final List<List<int>> _cells;

  /// Marca de la última pasada en la que se miró cada obstáculo: así uno
  /// que ocupa varias casillas se mira una sola vez.
  final Int32List _seen;
  int _pass = 0;

  /// [boxes] son las cajas de los obstáculos, por índice; `null` = no va en
  /// la rejilla.
  _ObstacleGrid(List<Rect?> boxes) : _seen = Int32List(boxes.length) {
    Rect? all;
    var count = 0;
    for (final box in boxes) {
      if (box == null) continue;
      all = all?.expandToInclude(box) ?? box;
      count++;
    }
    _bounds = (all ?? Rect.zero).inflate(2);
    // Casillas de modo que haya unas dos por obstáculo, y no más de 64 por
    // lado.
    final side = math.max(_bounds.width, _bounds.height);
    _cell = math.max(
      math.max(side / 64, 8.0),
      math.sqrt(_bounds.width * _bounds.height / math.max(1, count * 2)),
    );
    _cols = math.max(1, (_bounds.width / _cell).ceil());
    _rows = math.max(1, (_bounds.height / _cell).ceil());
    _cells = List.generate(_cols * _rows, (_) => <int>[]);
    for (var i = 0; i < boxes.length; i++) {
      // Un poco más grande: un rayo que roza el borde no se lo salta.
      final box = boxes[i]?.inflate(1);
      if (box == null) continue;
      final c0 = _col(box.left), c1 = _col(box.right);
      final r0 = _row(box.top), r1 = _row(box.bottom);
      for (var r = r0; r <= r1; r++) {
        for (var c = c0; c <= c1; c++) {
          _cells[r * _cols + c].add(i);
        }
      }
    }
  }

  int _col(double x) =>
      ((x - _bounds.left) / _cell).floor().clamp(0, _cols - 1);
  int _row(double y) => ((y - _bounds.top) / _cell).floor().clamp(0, _rows - 1);

  /// Recorre las casillas que cruza el rayo de [origin] hacia [dir] (de
  /// largo uno) hasta [length], y llama a [visit] con cada obstáculo que
  /// encuentra, una vez. Antes de cada casilla pregunta a [goOn], con la
  /// distancia a la que entra en ella, si sigue.
  void walk(
    Offset origin,
    Offset dir,
    double length,
    bool Function(double enter) goOn,
    void Function(int item) visit,
  ) {
    // Dónde entra y sale el rayo de la rejilla.
    var t0 = 0.0;
    var t1 = length;
    for (final (o, d, lo, hi) in [
      (origin.dx, dir.dx, _bounds.left, _bounds.right),
      (origin.dy, dir.dy, _bounds.top, _bounds.bottom),
    ]) {
      if (d.abs() < 1e-12) {
        if (o < lo || o > hi) return;
        continue;
      }
      var a = (lo - o) / d;
      var b = (hi - o) / d;
      if (a > b) (a, b) = (b, a);
      t0 = math.max(t0, a);
      t1 = math.min(t1, b);
    }
    if (t0 > t1) return;
    final start = origin + dir * t0;
    var col = _col(start.dx);
    var row = _row(start.dy);
    final stepX = dir.dx > 0 ? 1 : -1;
    final stepY = dir.dy > 0 ? 1 : -1;
    double next(double o, double d, double lo, int index, int step) {
      if (d.abs() < 1e-12) return double.infinity;
      final edge = lo + (step > 0 ? index + 1 : index) * _cell;
      return (edge - o) / d;
    }

    var nextX = next(origin.dx, dir.dx, _bounds.left, col, stepX);
    var nextY = next(origin.dy, dir.dy, _bounds.top, row, stepY);
    final deltaX = dir.dx.abs() < 1e-12
        ? double.infinity
        : _cell / dir.dx.abs();
    final deltaY = dir.dy.abs() < 1e-12
        ? double.infinity
        : _cell / dir.dy.abs();
    if (_pass == 0x7fffffff) {
      _seen.fillRange(0, _seen.length, 0);
      _pass = 0;
    }
    final pass = ++_pass;
    var enter = t0;
    while (true) {
      if (!goOn(enter)) return;
      for (final item in _cells[row * _cols + col]) {
        if (_seen[item] == pass) continue;
        _seen[item] = pass;
        visit(item);
      }
      if (nextX < nextY) {
        col += stepX;
        enter = nextX;
        nextX += deltaX;
      } else {
        row += stepY;
        enter = nextY;
        nextY += deltaY;
      }
      if (enter > t1 || col < 0 || col >= _cols || row < 0 || row >= _rows) {
        return;
      }
    }
  }
}
