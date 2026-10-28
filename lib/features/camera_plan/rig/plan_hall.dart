import 'dart:math' as math;
import 'dart:ui';

import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import '../light_overrides.dart';
import '../plan_opening.dart';
import '../plan_segment.dart';
import 'plan_drape.dart';
import 'plan_rig.dart';

/// Cubierta de una nave.
enum HallRoof {
  flat,
  gable,

  /// Lona: no carga, y cae entre cerchas.
  tensile,
}

extension HallRoofLabel on HallRoof {
  String get label => switch (this) {
    HallRoof.flat => 'Plana',
    HallRoof.gable => 'Dos aguas',
    HallRoof.tensile => 'Lona',
  };
}

/// Qué hay en un lado del perímetro.
enum HallEdgeKind {
  /// Pared ciega.
  wall,

  /// Ventanal o muro cortina: vidrio de alféizar a dintel a lo largo de
  /// todo el lado, en módulos.
  glass,

  /// Abierto, solo los pilares.
  open,

  /// Abierto con bambalinas de tela entre pilares.
  drape,
}

extension HallEdgeKindLabel on HallEdgeKind {
  String get label => switch (this) {
    HallEdgeKind.wall => 'Pared',
    HallEdgeKind.glass => 'Ventanal',
    HallEdgeKind.open => 'Abierto',
    HallEdgeKind.drape => 'Bambalinas',
  };
}

/// Un lado del perímetro: del vértice `i` al siguiente.
class HallEdge {
  final HallEdgeKind kind;

  /// Lo que se aparta el centro del lado de la recta, en metros. Positivo
  /// hacia la normal (−dy, dx) del lado, como `PlanSegment.curve`.
  final double bulgeM;

  /// Ventanal: alféizar y dintel, en metros.
  final double sillM;
  final double? headM;

  /// Ventanal: ancho de cada módulo de vidrio, en metros.
  final double moduleM;

  /// Bambalinas: largo de la tela.
  final double drapeLengthM;

  const HallEdge({
    this.kind = HallEdgeKind.wall,
    this.bulgeM = 0,
    this.sillM = 0,
    this.headM,
    this.moduleM = 1.5,
    this.drapeLengthM = 1.1,
  });

  HallEdge copyWith({
    HallEdgeKind? kind,
    double? bulgeM,
    double? sillM,
    double? headM,
    double? moduleM,
    double? drapeLengthM,
  }) => HallEdge(
    kind: kind ?? this.kind,
    bulgeM: bulgeM ?? this.bulgeM,
    sillM: sillM ?? this.sillM,
    headM: headM ?? this.headM,
    moduleM: moduleM ?? this.moduleM,
    drapeLengthM: drapeLengthM ?? this.drapeLengthM,
  );

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    if (bulgeM != 0) 'bulgeM': bulgeM,
    if (kind == HallEdgeKind.glass) ...{
      'sillM': sillM,
      'headM': ?headM,
      'moduleM': moduleM,
    },
    if (kind == HallEdgeKind.drape) 'drapeLengthM': drapeLengthM,
  };

  static HallEdge fromJson(Object? raw) {
    if (raw is! Map) return const HallEdge();
    double n(String k, double f) => (raw[k] as num?)?.toDouble() ?? f;
    return HallEdge(
      kind: HallEdgeKind.values.firstWhere(
        (k) => k.name == raw['kind'],
        orElse: () => HallEdgeKind.wall,
      ),
      bulgeM: n('bulgeM', 0),
      sillM: n('sillM', 0),
      headM: (raw['headM'] as num?)?.toDouble(),
      moduleM: n('moduleM', 1.5),
      drapeLengthM: n('drapeLengthM', 1.1),
    );
  }
}

/// Receta de una nave: perímetro libre (con lados curvos), altura,
/// cubierta, pilares y rejilla de truss. El constructor la convierte en
/// paredes, ventanales, telas, pilares y truss normales de la planta; la
/// receta se guarda en un elemento [RigType.hall] para poder rehacerlos.
///
/// Las medidas van en metros, relativas al origen de la nave y con los ejes
/// del lienzo (x a la derecha, y hacia abajo).
class HallRecipe {
  final List<Offset> outline;
  final List<HallEdge> edges;

  /// Altura al alero.
  final double eaveM;
  final HallRoof roof;

  /// Altura de la cumbrera sobre el alero.
  final double riseM;

  /// Lona: caída en el centro entre cerchas.
  final double sagM;

  /// Dirección de la cumbrera en el lienzo, en grados (0 = horizontal).
  final double ridgeDeg;

  final double pillarSpacingM;
  final String pillarShape;
  final double pillarSizeM;

  /// Separación de los pilares sueltos de dentro. 0 = sin pilares dentro.
  final double interiorPillarsM;

  final bool grid;
  final double gridSpacingM;
  final double gridLowM;
  final double gridMarginM;
  final TrussProfile gridProfile;
  final int gridSizeCm;

  /// Cota del suelo de la nave (entreplanta, escenario).
  final double levelM;

  const HallRecipe({
    required this.outline,
    required this.edges,
    this.eaveM = 4.5,
    this.roof = HallRoof.tensile,
    this.riseM = 2,
    this.sagM = 0.3,
    this.ridgeDeg = 0,
    this.pillarSpacingM = 6,
    this.pillarShape = PlanPillar.square,
    this.pillarSizeM = 0.15,
    this.interiorPillarsM = 0,
    this.grid = true,
    this.gridSpacingM = 3.25,
    this.gridLowM = 4,
    this.gridMarginM = 1.2,
    this.gridProfile = TrussProfile.square,
    this.gridSizeCm = 30,
    this.levelM = 0,
  });

  /// Nave rectangular: el primer lado (el de abajo en el lienzo) es el
  /// frente.
  factory HallRecipe.rectangle({
    double width = 24,
    double depth = 12,
    HallEdgeKind front = HallEdgeKind.drape,
    HallEdgeKind sides = HallEdgeKind.wall,
    HallEdgeKind back = HallEdgeKind.wall,
    double eaveM = 4.5,
    HallRoof roof = HallRoof.tensile,
    double riseM = 2,
    double sagM = 0.3,
    double pillarSpacingM = 6,
    bool grid = true,
    double gridSpacingM = 3.25,
    double gridLowM = 4,
    TrussProfile gridProfile = TrussProfile.square,
    int gridSizeCm = 30,
  }) => HallRecipe(
    // Frente abajo, sentido antihorario en pantalla.
    outline: [
      Offset(0, depth),
      Offset(width, depth),
      Offset(width, 0),
      const Offset(0, 0),
    ],
    edges: [
      HallEdge(kind: front),
      HallEdge(kind: sides),
      HallEdge(kind: back),
      HallEdge(kind: sides),
    ],
    eaveM: eaveM,
    roof: roof,
    riseM: riseM,
    sagM: sagM,
    ridgeDeg: width >= depth ? 0 : 90,
    pillarSpacingM: pillarSpacingM,
    pillarShape: roof == HallRoof.tensile
        ? PlanPillar.round
        : PlanPillar.square,
    pillarSizeM: roof == HallRoof.tensile ? 0.12 : 0.2,
    grid: grid,
    gridSpacingM: gridSpacingM,
    gridLowM: gridLowM,
    gridProfile: gridProfile,
    gridSizeCm: gridSizeCm,
  );

  HallRecipe copyWith({
    List<Offset>? outline,
    List<HallEdge>? edges,
    double? eaveM,
    HallRoof? roof,
    double? riseM,
    double? sagM,
    double? ridgeDeg,
    double? pillarSpacingM,
    String? pillarShape,
    double? pillarSizeM,
    double? interiorPillarsM,
    bool? grid,
    double? gridSpacingM,
    double? gridLowM,
    double? gridMarginM,
    TrussProfile? gridProfile,
    int? gridSizeCm,
    double? levelM,
  }) => HallRecipe(
    outline: outline ?? this.outline,
    edges: edges ?? this.edges,
    eaveM: eaveM ?? this.eaveM,
    roof: roof ?? this.roof,
    riseM: riseM ?? this.riseM,
    sagM: sagM ?? this.sagM,
    ridgeDeg: ridgeDeg ?? this.ridgeDeg,
    pillarSpacingM: pillarSpacingM ?? this.pillarSpacingM,
    pillarShape: pillarShape ?? this.pillarShape,
    pillarSizeM: pillarSizeM ?? this.pillarSizeM,
    interiorPillarsM: interiorPillarsM ?? this.interiorPillarsM,
    grid: grid ?? this.grid,
    gridSpacingM: gridSpacingM ?? this.gridSpacingM,
    gridLowM: gridLowM ?? this.gridLowM,
    gridMarginM: gridMarginM ?? this.gridMarginM,
    gridProfile: gridProfile ?? this.gridProfile,
    gridSizeCm: gridSizeCm ?? this.gridSizeCm,
    levelM: levelM ?? this.levelM,
  );

  HallEdge edge(int i) => i < edges.length ? edges[i] : const HallEdge();

  /// Parte el lado `i` en dos por su centro: una esquina más que mover.
  HallRecipe splitEdge(int i) {
    final mid = edgePoint(i, 0.5);
    final e = edge(i).copyWith(bulgeM: 0);
    return copyWith(
      outline: [...outline]..insert(i + 1, mid),
      edges: [
        for (var k = 0; k < outline.length; k++) ...[
          if (k == i) ...[e, e] else edge(k),
        ],
      ],
    );
  }

  /// Quita la esquina `i`: sus dos lados se unen en uno, del tipo del
  /// primero.
  HallRecipe removeVertex(int i) {
    if (outline.length <= 3) return this;
    final prev = (i - 1 + outline.length) % outline.length;
    return copyWith(
      outline: [...outline]..removeAt(i),
      edges: [
        for (var k = 0; k < outline.length; k++)
          if (k != i) k == prev ? edge(k).copyWith(bulgeM: 0) : edge(k),
      ],
    );
  }

  Map<String, dynamic> toJson() => {
    'outline': [
      for (final p in outline) {'x': p.dx, 'y': p.dy},
    ],
    'edges': [for (var i = 0; i < outline.length; i++) edge(i).toJson()],
    'eaveM': eaveM,
    'roof': roof.name,
    'riseM': riseM,
    'sagM': sagM,
    'ridgeDeg': ridgeDeg,
    'pillarSpacingM': pillarSpacingM,
    'pillarShape': pillarShape,
    'pillarSizeM': pillarSizeM,
    'interiorPillarsM': interiorPillarsM,
    'grid': grid,
    'gridSpacingM': gridSpacingM,
    'gridLowM': gridLowM,
    'gridMarginM': gridMarginM,
    'gridProfile': gridProfile.name,
    'gridSizeCm': gridSizeCm,
    if (levelM != 0) 'levelM': levelM,
  };

  static HallRecipe? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final pts = raw['outline'];
    if (pts is! List || pts.length < 3) return null;
    double n(String k, double f) => (raw[k] as num?)?.toDouble() ?? f;
    final edges = raw['edges'] is List ? raw['edges'] as List : const [];
    return HallRecipe(
      outline: [
        for (final p in pts)
          Offset(
            ((p as Map)['x'] as num).toDouble(),
            (p['y'] as num).toDouble(),
          ),
      ],
      edges: [for (final e in edges) HallEdge.fromJson(e)],
      eaveM: n('eaveM', 4.5),
      roof: HallRoof.values.firstWhere(
        (r) => r.name == raw['roof'],
        orElse: () => HallRoof.flat,
      ),
      riseM: n('riseM', 2),
      sagM: n('sagM', 0.3),
      ridgeDeg: n('ridgeDeg', 0),
      pillarSpacingM: n('pillarSpacingM', 6),
      pillarShape: raw['pillarShape'] as String? ?? PlanPillar.square,
      pillarSizeM: n('pillarSizeM', 0.2),
      interiorPillarsM: n('interiorPillarsM', 0),
      grid: raw['grid'] as bool? ?? true,
      gridSpacingM: n('gridSpacingM', 3.25),
      gridLowM: n('gridLowM', 4),
      gridMarginM: n('gridMarginM', 1.2),
      gridProfile: TrussProfile.values.firstWhere(
        (p) => p.name == raw['gridProfile'],
        orElse: () => TrussProfile.square,
      ),
      gridSizeCm: (raw['gridSizeCm'] as num?)?.toInt() ?? 30,
      levelM: n('levelM', 0),
    );
  }

  // ── Geometría, en metros y en el sistema de la receta ───────────────────

  /// Punto a `t` (0–1) del lado `i`, con su curva.
  Offset edgePoint(int i, double t) {
    final a = outline[i], b = outline[(i + 1) % outline.length];
    final bulge = edge(i).bulgeM;
    if (bulge == 0) return Offset.lerp(a, b, t)!;
    final d = b - a, len = d.distance;
    final normal = len == 0 ? Offset.zero : Offset(-d.dy / len, d.dx / len);
    final control = a + d / 2 + normal * (bulge * 2);
    final u = 1 - t;
    return a * (u * u) + control * (2 * u * t) + b * (t * t);
  }

  /// El lado `i` en puntos, cada `stepM` metros como mucho.
  List<Offset> edgePolyline(int i, {double stepM = 0.25}) {
    if (edge(i).bulgeM == 0) {
      return [outline[i], outline[(i + 1) % outline.length]];
    }
    final chord = (outline[(i + 1) % outline.length] - outline[i]).distance;
    final n = math.max(8, (chord * 1.3 / stepM).ceil());
    return [for (var k = 0; k <= n; k++) edgePoint(i, k / n)];
  }

  /// Todo el perímetro en puntos, con los lados curvos troceados.
  List<Offset> polygon({double stepM = 0.25}) => [
    for (var i = 0; i < outline.length; i++)
      ...() {
        final pts = edgePolyline(i, stepM: stepM);
        return pts.take(pts.length - 1);
      }(),
  ];

  Offset get _ridgeDir {
    final r = ridgeDeg * math.pi / 180;
    return Offset(math.cos(r), math.sin(r));
  }

  // Lo que la cubierta necesita y no cambia: se calcula una vez por receta.
  static final _geometry = Expando<_RoofGeometry>();

  _RoofGeometry get _geo => _geometry[this] ??= _RoofGeometry(this);

  Offset get centroid => _geo.centroid;

  /// Distancia máxima del perímetro a la cumbrera: media luz de la nave.
  double get halfSpanM => _geo.halfSpan;

  /// Altura de la cubierta en un punto, sobre el suelo de la nave.
  double roofAt(Offset p) {
    if (roof == HallRoof.flat) return eaveM;
    final g = _geo, dir = _ridgeDir, n = Offset(-dir.dy, dir.dx);
    final v = p - g.centroid;
    final across = ((v.dx * n.dx + v.dy * n.dy).abs() / g.halfSpan).clamp(
      0.0,
      1.0,
    );
    var z = eaveM + riseM * (1 - across);
    if (roof == HallRoof.tensile && sagM > 0 && pillarSpacingM > 0) {
      final along = v.dx * dir.dx + v.dy * dir.dy - g.frameOrigin;
      final f = ((along / pillarSpacingM) % 1 + 1) % 1;
      // Cae más hacia el alero que en la cumbrera.
      z -= sagM * math.sin(math.pi * f) * (0.25 + 0.75 * across);
    }
    return z;
  }

  bool contains(Offset p) => _inside(p, polygon(stepM: 0.25));

  static bool _inside(Offset p, List<Offset> poly) {
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
}

/// Convierte una receta en elementos de la planta y los rehace cuando la
/// receta cambia.
class PlanHall {
  PlanHall._();

  static const recipeKey = 'recipe';

  /// En todo lo que genera una nave: el `uid` de su elemento receta.
  static const hallKey = 'hallUid';

  /// Un elemento generado que se ha tocado a mano: la receta ya no lo
  /// rehace.
  static const detachedKey = 'detached';

  /// Truss con ruedas de cadena de 500 kg; torre de ground support de 750.
  static const double maxGroundSupportSpanM = 8;

  static bool isHall(PlanElement el) => RigTypeCodec.of(el) == RigType.hall;

  static HallRecipe? recipeOf(PlanElement hall) =>
      HallRecipe.fromJson(hall.props[recipeKey]);

  static String? hallUidOf(PlanElement el) => el.props[hallKey] as String?;

  /// Lado del perímetro del que sale una pared de la nave, o `null`.
  static int? edgeIndexOf(PlanElement wall) {
    final hall = hallUidOf(wall), uid = LightOverrides.uidOf(wall);
    if (hall == null || uid == null || !uid.startsWith('$hall-e')) return null;
    return int.tryParse(uid.substring(hall.length + 2));
  }

  /// Lleva a la receta lo que se ha hecho a mano con una pared de la nave
  /// (mover un extremo, curvarla): el perímetro se edita en la planta.
  /// Devuelve si la receta ha cambiado; luego hay que [regenerate].
  static bool syncFromWall(
    PlanElement hall,
    PlanElement wall,
    double metersPerUnit,
  ) {
    final recipe = recipeOf(hall);
    final i = edgeIndexOf(wall);
    if (recipe == null || i == null || i >= recipe.outline.length) {
      return false;
    }
    Offset m(Offset canvas) => (canvas - hall.position) * metersPerUnit;
    final outline = [...recipe.outline];
    final edges = [for (var k = 0; k < outline.length; k++) recipe.edge(k)];
    outline[i] = m(PlanSegment.start(wall));
    outline[(i + 1) % outline.length] = m(PlanSegment.end(wall));
    edges[i] = edges[i].copyWith(
      bulgeM: PlanSegment.curve(wall) * metersPerUnit,
    );
    hall.props[recipeKey] = recipe
        .copyWith(outline: outline, edges: edges)
        .toJson();
    return true;
  }

  /// Receta a partir de paredes que cierran un recinto (en cualquier
  /// orden y sentido). Devuelve el origen en el lienzo y la receta, o
  /// `null` si las paredes no cierran.
  static (Offset, HallRecipe)? fromWalls(
    List<PlanElement> walls,
    double metersPerUnit, {
    HallRecipe? base,
  }) {
    final segs = walls.where(PlanSegment.isSegment).toList();
    if (segs.length < 3) return null;
    final tolerance = 0.15 / metersPerUnit;
    final order = <(Offset, Offset, double)>[];
    final left = [...segs];
    var first = left.removeAt(0);
    order.add((
      PlanSegment.start(first),
      PlanSegment.end(first),
      PlanSegment.curve(first),
    ));
    while (left.isNotEmpty) {
      final tail = order.last.$2;
      final next = left.indexWhere(
        (s) =>
            (PlanSegment.start(s) - tail).distance < tolerance ||
            (PlanSegment.end(s) - tail).distance < tolerance,
      );
      if (next < 0) return null;
      final s = left.removeAt(next);
      // Un tramo dibujado al revés se da la vuelta, y su curva también.
      order.add(
        (PlanSegment.start(s) - tail).distance < tolerance
            ? (PlanSegment.start(s), PlanSegment.end(s), PlanSegment.curve(s))
            : (PlanSegment.end(s), PlanSegment.start(s), -PlanSegment.curve(s)),
      );
    }
    if ((order.last.$2 - order.first.$1).distance >= tolerance) return null;
    final origin = order.first.$1;
    final recipe = (base ?? HallRecipe.rectangle()).copyWith(
      outline: [for (final s in order) (s.$1 - origin) * metersPerUnit],
      edges: [for (final s in order) HallEdge(bulgeM: s.$3 * metersPerUnit)],
    );
    return (origin, recipe);
  }

  /// Elemento receta de una nave nueva con su origen en `origin`.
  static PlanElement create(Offset origin, HallRecipe recipe) {
    final hall = RigTypeCodec.create(
      RigType.hall,
      origin,
      props: {recipeKey: recipe.toJson()},
    );
    LightOverrides.ensureUids([hall]);
    return hall;
  }

  /// Rehace lo generado por la nave: quita lo que generó antes (salvo lo
  /// desligado) y añade lo nuevo. Lo colgado de sus truss los sigue,
  /// porque cada truss conserva su `uid`.
  static void regenerate(
    List<PlanElement> elements,
    PlanElement hall,
    double metersPerUnit,
  ) {
    final uid = LightOverrides.uidOf(hall);
    if (uid == null) return;
    final kept = <String>{
      for (final el in elements)
        if (hallUidOf(el) == uid && el.props[detachedKey] == true)
          if (LightOverrides.uidOf(el) != null) LightOverrides.uidOf(el)!,
    };
    elements.removeWhere(
      (el) => hallUidOf(el) == uid && el.props[detachedKey] != true,
    );
    elements.addAll(
      build(
        hall,
        metersPerUnit,
      ).where((el) => !kept.contains(LightOverrides.uidOf(el))),
    );
    TrussMagnet.follow(elements, metersPerUnit);
  }

  /// Los elementos que salen de la receta de `hall`, sin el propio `hall`.
  static List<PlanElement> build(PlanElement hall, double metersPerUnit) {
    final recipe = recipeOf(hall);
    final hallUid = LightOverrides.uidOf(hall);
    if (recipe == null || hallUid == null) return const [];
    final origin = hall.position;
    Offset at(Offset m) => origin + m / metersPerUnit;
    final out = <PlanElement>[];
    // Cada pieza lleva un uid fijo que dice de dónde sale (`e2` es el
    // lado 2, `t0` el primer truss): al rehacer la receta conserva el
    // mismo, y lo que cuelga de ella la sigue.
    void add(PlanElement el, String tag) {
      el.props[LightOverrides.uidKey] = '$hallUid-$tag';
      el.props[hallKey] = hallUid;
      PlanLevel.set(el, recipe.levelM);
      out.add(el);
    }

    // Pilares: en cada vértice y a lo largo de cada lado, repartidos.
    final perimeterPillars = <Offset>[];
    final pillarsByEdge = <int, List<Offset>>{};
    for (var i = 0; i < recipe.outline.length; i++) {
      final pts = _alongEdge(recipe, i, recipe.pillarSpacingM);
      pillarsByEdge[i] = pts;
      for (final p in pts) {
        if (perimeterPillars.every((q) => (q - p).distance > 0.1)) {
          perimeterPillars.add(p);
        }
      }
    }
    for (final (k, p) in perimeterPillars.indexed) {
      add(
        PlanPillar.create(
          at(p),
          shape: recipe.pillarShape,
          sizeM: recipe.pillarSizeM,
          heightM: recipe.roofAt(p),
        ),
        'p$k',
      );
    }
    if (recipe.interiorPillarsM > 0) {
      for (final (k, p) in _interiorGrid(recipe).indexed) {
        add(
          PlanPillar.create(
            at(p),
            shape: recipe.pillarShape,
            sizeM: math.max(recipe.pillarSizeM, 0.25),
            heightM: recipe.roofAt(p),
          ),
          'pi$k',
        );
      }
    }

    // Lados.
    for (var i = 0; i < recipe.outline.length; i++) {
      final edge = recipe.edge(i);
      final a = recipe.outline[i];
      final b = recipe.outline[(i + 1) % recipe.outline.length];
      switch (edge.kind) {
        case HallEdgeKind.wall || HallEdgeKind.glass:
          final wall = PlanSegment.create(start: at(a), end: at(b));
          if (edge.bulgeM != 0) {
            wall.props['curve'] = edge.bulgeM / metersPerUnit;
          }
          wall.props[PlanPillar.heightKey] = recipe.eaveM;
          add(wall, 'e$i');
          if (edge.kind == HallEdgeKind.glass) {
            final head = edge.headM ?? recipe.eaveM - 0.15;
            final length = _edgeLength(recipe, i);
            final n = math.max(1, (length / edge.moduleM).ceil());
            for (var k = 0; k < n; k++) {
              final p0 = recipe.edgePoint(i, k / n);
              final p1 = recipe.edgePoint(i, (k + 1) / n);
              final mid = recipe.edgePoint(i, (k + 0.5) / n);
              final d = p1 - p0;
              add(
                PlanElement(
                  id: 0,
                  type: ElementType.wall,
                  position: at(mid),
                  rotation:
                      ((math.atan2(d.dy, d.dx) * 180 / math.pi) % 360 + 360) %
                      360,
                  label: ArchitectureType.window.dbValue,
                  props: {
                    PlanOpening.widthKey: d.distance / metersPerUnit,
                    PlanOpening.sillKey: edge.sillM,
                    PlanOpening.headKey: head,
                    PlanOpening.openKey: 0,
                  },
                ),
                'e$i-g$k',
              );
            }
          }
        case HallEdgeKind.drape:
          final pts = pillarsByEdge[i]!;
          for (var k = 0; k < pts.length - 1; k++) {
            final z = math.min(
              recipe.roofAt(pts[k]),
              recipe.roofAt(pts[k + 1]),
            );
            final drape = PlanDrape.create(
              at(pts[k]),
              at(pts[k + 1]),
              anchorM: z - 0.05,
              sagM: 0.4,
              lengthM: edge.drapeLengthM,
              material: 'raso',
            );
            add(drape, 'e$i-c$k');
          }
        case HallEdgeKind.open:
          break;
      }
    }

    // Rejilla de truss y sus puntos.
    if (recipe.grid) {
      final depth = PlanTruss.outerM(recipe.gridSizeCm);
      final low = math.min(recipe.gridLowM, recipe.eaveM - 0.2 - depth);
      final lines = _gridLines(recipe);
      for (final (j, line) in lines.main.indexed) {
        final truss = PlanTruss.create(
          at(line.$1),
          at(line.$2),
          profile: recipe.gridProfile,
          sizeCm: recipe.gridSizeCm,
          lowM: low,
        );
        add(truss, 't$j');
        final lengthM = (line.$2 - line.$1).distance;
        final outer = j == 0 || j == lines.main.length - 1;
        final ground = recipe.roof == HallRoof.tensile;
        final List<double> ts;
        if (ground) {
          ts = outer
              ? _spaced(lengthM, maxGroundSupportSpanM)
              : const [0.0, 1.0];
        } else {
          ts = _spaced(lengthM, recipe.pillarSpacingM);
        }
        for (final (k, t) in ts.indexed) {
          add(
            PlanRigPoint.create(
              ground ? RigType.groundSupport : RigType.motor,
              truss,
              t,
              metersPerUnit,
            ),
            't$j-r$k',
          );
        }
      }
      for (final (k, line) in lines.cross.indexed) {
        add(
          PlanTruss.create(
            at(line.$1),
            at(line.$2),
            profile: recipe.gridProfile,
            sizeCm: recipe.gridSizeCm,
            lowM: low,
          ),
          'x$k',
        );
      }
    }
    return out;
  }

  /// Posiciones (0–1) repartidas a lo largo de un largo, sin pasar de
  /// `maxGap` entre una y otra, extremos incluidos.
  static List<double> _spaced(double length, double maxGap) {
    final n = math.max(1, (length / math.max(maxGap, 0.5)).ceil());
    return [for (var k = 0; k <= n; k++) k / n];
  }

  static double _edgeLength(HallRecipe r, int i) {
    final pts = r.edgePolyline(i, stepM: 0.1);
    var total = 0.0;
    for (var k = 1; k < pts.length; k++) {
      total += (pts[k] - pts[k - 1]).distance;
    }
    return total;
  }

  /// Puntos repartidos por un lado (con su curva), sin pasar de `spacing`,
  /// extremos incluidos.
  static List<Offset> _alongEdge(HallRecipe r, int i, double spacing) {
    final pts = r.edgePolyline(i, stepM: 0.05);
    final cum = <double>[0];
    for (var k = 1; k < pts.length; k++) {
      cum.add(cum.last + (pts[k] - pts[k - 1]).distance);
    }
    final total = cum.last;
    final n = math.max(1, (total / math.max(spacing, 0.5)).ceil());
    final out = <Offset>[];
    var k = 0;
    for (var s = 0; s <= n; s++) {
      final target = total * s / n;
      while (k < cum.length - 2 && cum[k + 1] < target) {
        k++;
      }
      final seg = cum[k + 1] - cum[k];
      final t = seg == 0 ? 0.0 : (target - cum[k]) / seg;
      out.add(Offset.lerp(pts[k], pts[k + 1], t.clamp(0.0, 1.0))!);
    }
    return out;
  }

  /// Pilares sueltos de dentro: una cuadrícula alineada con la cumbrera,
  /// lejos de las paredes.
  static List<Offset> _interiorGrid(HallRecipe r) {
    final s = r.interiorPillarsM;
    final poly = r.polygon();
    final frame = _Frame(r);
    final local = [for (final p in poly) frame.toLocal(p)];
    final (minU, maxU, minV, maxV) = _bounds(local);
    final out = <Offset>[];
    for (final u in _evenly(minU, maxU, s)) {
      for (final v in _evenly(minV, maxV, s)) {
        final p = frame.toWorld(Offset(u, v));
        if (!HallRecipe._inside(p, poly)) continue;
        if (_distanceToPolygon(p, poly) < s * 0.4) continue;
        out.add(p);
      }
    }
    return out;
  }

  /// Valores interiores repartidos entre `lo` y `hi` cada `step` como
  /// mucho, sin los extremos.
  static List<double> _evenly(double lo, double hi, double step) {
    final n = ((hi - lo) / step).round();
    if (n < 2) return const [];
    return [for (var k = 1; k < n; k++) lo + (hi - lo) * k / n];
  }

  static (double, double, double, double) _bounds(List<Offset> pts) {
    var minU = double.infinity, maxU = -double.infinity;
    var minV = double.infinity, maxV = -double.infinity;
    for (final p in pts) {
      minU = math.min(minU, p.dx);
      maxU = math.max(maxU, p.dx);
      minV = math.min(minV, p.dy);
      maxV = math.max(maxV, p.dy);
    }
    return (minU, maxU, minV, maxV);
  }

  static double _distanceToPolygon(Offset p, List<Offset> poly) {
    var best = double.infinity;
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length], ab = b - a;
      final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
      final t = len2 == 0
          ? 0.0
          : (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(
              0.0,
              1.0,
            );
      best = math.min(best, (p - (a + ab * t)).distance);
    }
    return best;
  }

  /// Líneas de la rejilla: las principales, paralelas a la cumbrera, y dos
  /// travesaños que las atan por los extremos. Todo recortado al
  /// perímetro y apartado de él `gridMarginM`.
  static ({List<(Offset, Offset)> main, List<(Offset, Offset)> cross})
  _gridLines(HallRecipe r) {
    final poly = r.polygon();
    final frame = _Frame(r);
    final local = [for (final p in poly) frame.toLocal(p)];
    final (minU, maxU, minV, maxV) = _bounds(local);
    final m = r.gridMarginM;
    final main = <(Offset, Offset)>[];
    if (maxV - minV <= 2 * m) return (main: main, cross: const []);
    final n = math.max(1, ((maxV - minV - 2 * m) / r.gridSpacingM).round());
    var lo = double.infinity, hi = -double.infinity;
    for (var k = 0; k <= n; k++) {
      final v = minV + m + (maxV - minV - 2 * m) * k / n;
      for (final (u0, u1) in _crossings(local, v, horizontal: true)) {
        final a = u0 + m, b = u1 - m;
        if (b - a < 1) continue;
        main.add((frame.toWorld(Offset(a, v)), frame.toWorld(Offset(b, v))));
        lo = math.min(lo, a);
        hi = math.max(hi, b);
      }
    }
    final cross = <(Offset, Offset)>[];
    if (main.length >= 2) {
      final vFirst = minV + m, vLast = maxV - m;
      for (final u in [lo, hi]) {
        for (final (v0, v1) in _crossings(local, u, horizontal: false)) {
          final a = math.max(v0, vFirst), b = math.min(v1, vLast);
          if (b - a < 1) continue;
          cross.add((frame.toWorld(Offset(u, a)), frame.toWorld(Offset(u, b))));
        }
      }
    }
    return (main: main, cross: cross);
  }

  /// Tramos de una recta (v constante si `horizontal`, u constante si no)
  /// que quedan dentro del polígono.
  static List<(double, double)> _crossings(
    List<Offset> poly,
    double value, {
    required bool horizontal,
  }) {
    final hits = <double>[];
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      final av = horizontal ? a.dy : a.dx, bv = horizontal ? b.dy : b.dx;
      final au = horizontal ? a.dx : a.dy, bu = horizontal ? b.dx : b.dy;
      if ((av > value) != (bv > value)) {
        hits.add(au + (bu - au) * (value - av) / (bv - av));
      }
    }
    hits.sort();
    return [
      for (var k = 0; k + 1 < hits.length; k += 2) (hits[k], hits[k + 1]),
    ];
  }
}

/// Ejes de la cumbrera: u a lo largo, v de través.
class _Frame {
  final Offset c;
  final Offset dir;

  _Frame(HallRecipe r)
    : c = r.centroid,
      dir = Offset(
        math.cos(r.ridgeDeg * math.pi / 180),
        math.sin(r.ridgeDeg * math.pi / 180),
      );

  Offset toLocal(Offset p) {
    final v = p - c;
    return Offset(
      v.dx * dir.dx + v.dy * dir.dy,
      -v.dx * dir.dy + v.dy * dir.dx,
    );
  }

  Offset toWorld(Offset l) =>
      c + Offset(l.dx * dir.dx - l.dy * dir.dy, l.dx * dir.dy + l.dy * dir.dx);
}

class _RoofGeometry {
  final Offset centroid;
  final double halfSpan;

  /// Dónde cae la primera cercha, a lo largo de la cumbrera.
  final double frameOrigin;

  factory _RoofGeometry(HallRecipe r) {
    final poly = r.polygon(stepM: 0.5);
    var area = 0.0, cx = 0.0, cy = 0.0;
    for (var i = 0; i < poly.length; i++) {
      final a = poly[i], b = poly[(i + 1) % poly.length];
      final cross = a.dx * b.dy - b.dx * a.dy;
      area += cross;
      cx += (a.dx + b.dx) * cross;
      cy += (a.dy + b.dy) * cross;
    }
    final c = area.abs() < 1e-9
        ? poly.first
        : Offset(cx / (3 * area), cy / (3 * area));
    final dir = r._ridgeDir, n = Offset(-dir.dy, dir.dx);
    var half = 0.1, lo = double.infinity;
    for (final p in poly) {
      final v = p - c;
      half = math.max(half, (v.dx * n.dx + v.dy * n.dy).abs());
      lo = math.min(lo, v.dx * dir.dx + v.dy * dir.dy);
    }
    return _RoofGeometry._(c, half, lo);
  }

  const _RoofGeometry._(this.centroid, this.halfSpan, this.frameOrigin);
}
