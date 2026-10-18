import 'floor_plan_repository.dart';
import 'shot_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/utils/project_color_scheme.dart';
import '../../shared/annotations/annotation_document.dart';
import 'camera_plan_element_model.dart';
import 'camera_plan_painter.dart';
import 'camera_plan_grouping.dart';
import 'floor_plan_json.dart';
import 'light_overrides.dart';

/// Colores de los esquemas de luz, por orden dentro de su set.
const kLightSetupColors = [
  Color(0xFFFFB300),
  Color(0xFF26C6DA),
  Color(0xFFEC407A),
  Color(0xFF9CCC65),
  Color(0xFFAB47BC),
  Color(0xFFFF7043),
];

/// Todo lo que hace falta para pintar las plantas de un proyecto: el mapa
/// global y el navegador de la pantalla de trabajo leen de aquí.
class PlanProjectData {
  final List<LocationSite> sites;
  final List<LocationBasePlan> sets;
  final List<LightSetup> setups;
  final List<Scene> scenes;
  final List<Shot> shots;

  /// Elementos de planta de todos los planos.
  final List<CameraPlanElement> elementRows;

  /// Dibujos a mano de las plantas (bocetos), uno por planta.
  final List<ProjectAnnotationDocument> drawingRows;
  final ProjectColorScheme colors;
  final _drawings = <String, AnnotationDocument>{};

  PlanProjectData({
    required this.sites,
    required this.sets,
    required this.setups,
    required this.scenes,
    required this.shots,
    this.elementRows = const [],
    this.drawingRows = const [],
  }) : colors = ProjectColorScheme.resolve(
         sites: sites,
         sets: sets,
         scenes: scenes,
       );

  bool get isEmpty => sites.isEmpty && sets.isEmpty && setups.isEmpty;

  LocationSite? site(int? id) {
    for (final s in sites) {
      if (s.id == id) return s;
    }
    return null;
  }

  LocationBasePlan? set(int? id) {
    for (final s in sets) {
      if (s.id == id) return s;
    }
    return null;
  }

  Scene? scene(int? id) {
    for (final s in scenes) {
      if (s.id == id) return s;
    }
    return null;
  }

  List<LocationBasePlan> setsOfSite(int siteId) =>
      sets.where((s) => s.siteId == siteId).toList();

  /// Sets que no pertenecen a ninguna localización.
  List<LocationBasePlan> get orphanSets =>
      sets.where((s) => site(s.siteId) == null).toList();

  /// Esquemas de verdad (los que llevan planos); sin los bocetos.
  Iterable<LightSetup> get planSetups =>
      setups.where((s) => !LightSetupKind.isSketch(s));

  List<LightSetup> setupsOfSet(int setId) =>
      planSetups.where((s) => s.locationBasePlanId == setId).toList();

  /// Esquemas de la localización que no son de ningún set.
  List<LightSetup> setupsOfSite(int siteId) => planSetups
      .where((s) => s.locationBasePlanId == null && s.locationSiteId == siteId)
      .toList();

  /// Plantas libres: sin set ni localización.
  List<LightSetup> get freeSetups => planSetups
      .where((s) => s.locationBasePlanId == null && s.locationSiteId == null)
      .toList();

  /// Bocetos de una escena (con elementos o a mano), en orden de creación.
  List<LightSetup> sketchesOfScene(int sceneId) => [
    for (final s in setups)
      if (LightSetupKind.isSketch(s) && s.sceneId == sceneId) s,
  ];

  /// Bocetos que no son de ninguna escena.
  List<LightSetup> get freeSketches => [
    for (final s in setups)
      if (LightSetupKind.isSketch(s) && scene(s.sceneId) == null) s,
  ];

  /// Localización a la que pertenece un esquema, directa o por su set.
  int? siteIdOfSetup(LightSetup setup) =>
      setup.locationSiteId ?? set(setup.locationBasePlanId)?.siteId;

  List<Shot> shotsOfSetup(int setupId) =>
      _inScriptOrder(shots.where((s) => s.lightSetupId == setupId));

  List<Scene> scenesOfSet(int setId) =>
      scenesInScriptOrder(scenes.where((s) => s.locationId == setId).toList());

  /// Escenas de la localización que no están en ningún set.
  List<Scene> scenesOfSiteWithoutSet(int siteId) => scenesInScriptOrder(
    scenes
        .where((s) => s.locationSiteId == siteId && set(s.locationId) == null)
        .toList(),
  );

  List<Shot> shotsOfScenes(Iterable<Scene> sceneList) {
    final ids = sceneList.map((s) => s.id).toSet();
    return _inScriptOrder(shots.where((s) => ids.contains(s.sceneId)));
  }

  List<Shot> _inScriptOrder(Iterable<Shot> list) {
    final order = {
      for (final (i, s) in scenesInScriptOrder(scenes).indexed) s.id: i,
    };
    return list.toList()..sort((a, b) {
      final byScene = (order[a.sceneId] ?? 0).compareTo(order[b.sceneId] ?? 0);
      return byScene != 0 ? byScene : a.number.compareTo(b.number);
    });
  }

  String shotLabel(Shot shot) {
    final number = scene(shot.sceneId)?.number;
    return number == null
        ? 'Plano ${shot.number}'
        : 'Esc $number · Plano ${shot.number}';
  }

  // ── Esquema de cada plano ─────────────────────────────────────────────────

  LightSetup? setup(int? id) {
    for (final s in setups) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Esquemas con el mismo dueño (set, localización o ninguno).
  List<LightSetup> siblingsOf(LightSetup setup) => setups
      .where(
        (s) =>
            s.locationBasePlanId == setup.locationBasePlanId &&
            s.locationSiteId == setup.locationSiteId,
      )
      .toList();

  /// Color de un esquema: fijo por su orden dentro de su set. Es el mismo
  /// en la leyenda del set, en la etiqueta del plano y en el editor.
  Color setupColor(LightSetup setup) {
    final index = siblingsOf(setup).indexWhere((s) => s.id == setup.id);
    return kLightSetupColors[(index < 0 ? 0 : index) %
        kLightSetupColors.length];
  }

  /// Esquemas que puede usar una escena: los de su set, los generales de su
  /// localización y las plantas libres.
  List<LightSetup> setupsForScene(Scene scene) {
    final siteId = scene.locationSiteId ?? set(scene.locationId)?.siteId;
    return planSetups.where((s) {
      if (s.locationBasePlanId != null) {
        return s.locationBasePlanId == scene.locationId;
      }
      if (s.locationSiteId != null) return s.locationSiteId == siteId;
      return true;
    }).toList();
  }

  List<Shot> shotsOfScene(int sceneId) =>
      shots.where((s) => s.sceneId == sceneId).toList()
        ..sort((a, b) => a.number.compareTo(b.number));

  /// Escenas sin localización ni set conocidos.
  List<Scene> get scenesWithoutLocation => scenesInScriptOrder(
    scenes
        .where(
          (s) => site(s.locationSiteId) == null && set(s.locationId) == null,
        )
        .toList(),
  );

  /// Lo propio de un plano: cámaras y actores. Con [tagged], cada cámara
  /// lleva el rótulo de su plano («1·3»), para verlas juntas en una planta.
  List<PlanElement> ownOfShot(Shot shot, {bool tagged = false}) {
    final sceneNumber = scene(shot.sceneId)?.number;
    return [
      for (final row in elementRows)
        if (row.shotId == shot.id)
          PlanElement.fromDb(row)
            ..props.addAll({
              if (tagged && row.type == 'camera')
                'shotTag': sceneNumber == null
                    ? 'P${shot.number}'
                    : '$sceneNumber·${shot.number}',
            }),
    ];
  }

  AnnotationDocument? _drawing(String type, int id) {
    final key = '$type:$id';
    final cached = _drawings[key];
    if (cached != null) return cached.isEmpty ? null : cached;
    var document = const AnnotationDocument();
    for (final row in drawingRows) {
      if (row.targetType == type && row.targetId == '$id') {
        document = AnnotationDocument.decode(row.documentJson);
        break;
      }
    }
    _drawings[key] = document;
    return document.isEmpty ? null : document;
  }

  /// Lo dibujado a mano en un esquema de luz.
  List<AnnotationDocument> drawingsOfSetup(LightSetup setup) => [
    ?_drawing('camera_plan_light_setup', setup.id),
  ];

  /// Lo dibujado a mano que se ve en un plano: lo de su esquema y lo suyo.
  List<AnnotationDocument> drawingsOfShot(Shot shot) => [
    if (setup(shot.lightSetupId) case final own?) ...drawingsOfSetup(own),
    ?_drawing('camera_plan_shot', shot.id),
  ];

  /// ¿Tiene el esquema algo dibujado, con elementos o a mano?
  bool setupHasDrawing(LightSetup setup) =>
      setup.sketchImagePath != null ||
      ownOfSetup(setup).isNotEmpty ||
      drawingsOfSetup(setup).isNotEmpty;

  /// Bocetos que se pueden enseñar en una escena: esquemas en estado
  /// «boceto» con algo dibujado, primero los del set de la escena.
  List<LightSetup> sketchesForScene(Scene scene) {
    final list = [
      // Primero los bocetos de la propia escena.
      for (final s in sketchesOfScene(scene.id))
        if (setupHasDrawing(s)) s,
      for (final s in setupsForScene(scene))
        if (s.status == 'boceto' && setupHasDrawing(s)) s,
    ];
    final siteId = scene.locationSiteId ?? set(scene.locationId)?.siteId;
    // Y los de los demás sets de su localización.
    for (final s in setups) {
      if (list.contains(s) || s.status != 'boceto' || !setupHasDrawing(s)) {
        continue;
      }
      if (siteId != null && siteIdOfSetup(s) == siteId) list.add(s);
    }
    return list;
  }

  /// La luz de un plano: la de su esquema, con sus ajustes propios.
  List<PlanElement> lightOfShot(Shot shot) {
    final own = setup(shot.lightSetupId);
    if (own == null) return const [];
    return LightOverrides.apply(ownOfSetup(own), shot.lightOverridesJson);
  }

  /// ¿Tiene el plano ajustes de luz propios sobre su esquema?
  bool hasLightOverrides(Shot shot) =>
      LightOverrides.decode(shot.lightOverridesJson).isNotEmpty;

  /// Los tiros de una escena: sus planos agrupados por el esquema de luz
  /// que comparten, en el orden en que aparece cada esquema. Los planos sin
  /// luz van al final, con esquema `null`.
  List<({LightSetup? setup, List<Shot> shots})> tirosOf(Scene scene) {
    final groups = <int?, List<Shot>>{};
    for (final shot in shotsOfScene(scene.id)) {
      final id = setup(shot.lightSetupId)?.id;
      groups.putIfAbsent(id, () => []).add(shot);
    }
    return [
      for (final entry in groups.entries)
        if (entry.key != null) (setup: setup(entry.key), shots: entry.value),
      if (groups[null] case final loose?) (setup: null, shots: loose),
    ];
  }

  /// Lo que se ve debajo de un plano, sin la luz: entorno y set.
  List<PlanElement> baseOfShot(Shot shot) {
    final sc = scene(shot.sceneId);
    final owner = set(setIdOfShot(shot));
    return [
      ...environmentOf(owner?.siteId ?? sc?.locationSiteId),
      if (owner != null) ...ownOfSet(owner),
    ];
  }

  // ── Tablero de una escena ────────────────────────────────────────────────

  /// Set en el que se rueda un plano: el suyo o, si no, el de su escena.
  int? setIdOfShot(Shot shot) =>
      set(shot.locationBasePlanId)?.id ?? scene(shot.sceneId)?.locationId;

  /// Localización de una escena: la suya o la de su set.
  int? siteIdOfScene(Scene scene) =>
      site(scene.locationSiteId)?.id ?? set(scene.locationId)?.siteId;

  /// Tramos de un plano secuencia; vacío si no lo es.
  List<ShotLeg> legsOf(Shot shot) => ShotRoute.decode(shot.routeJson);
  bool isSequence(Shot shot) => legsOf(shot).isNotEmpty;

  /// Planos secuencia de una escena.
  List<Shot> sequencesOf(Scene scene) =>
      shotsOfScene(scene.id).where(isSequence).toList();

  /// Sets del tablero de una escena: el suyo primero, después los otros
  /// sets de su localización donde se ruede algún plano y los que se hayan
  /// añadido a mano ([extra]). `null` = la escena no tiene set.
  List<LocationBasePlan?> boardSetsOf(
    Scene scene, {
    Iterable<int> extra = const [],
  }) {
    final own = set(scene.locationId);
    final ids = <int>{
      for (final shot in shotsOfScene(scene.id))
        if (!isSequence(shot) && setIdOfShot(shot) != null) setIdOfShot(shot)!,
      ...extra,
    }..remove(own?.id);
    return [
      own,
      for (final s in sets)
        if (ids.contains(s.id)) s,
    ];
  }

  /// Sets de la localización de la escena que aún no están en su tablero.
  List<LocationBasePlan> setsToAdd(Scene scene, Iterable<int?> shown) {
    final siteId = siteIdOfScene(scene);
    if (siteId == null) return const [];
    return [
      for (final s in setsOfSite(siteId))
        if (!shown.contains(s.id)) s,
    ];
  }

  /// Planos (no secuencia) de una escena que se ruedan en un set.
  List<Shot> _boardShots(Scene scene, int? setId) => [
    for (final shot in shotsOfScene(scene.id))
      if (!isSequence(shot) && setIdOfShot(shot) == setId) shot,
  ];

  /// Columnas de un set en el tablero: sus esquemas y, además, cualquier
  /// otro (de la localización o libre) que use algún plano de ahí.
  List<LightSetup> boardSetupsOf(Scene scene, int? setId) {
    final used = {
      for (final shot in _boardShots(scene, setId))
        if (setup(shot.lightSetupId) != null) shot.lightSetupId!,
    };
    return [
      for (final s in planSetups)
        if ((setId != null && s.locationBasePlanId == setId) ||
            used.contains(s.id))
          s,
    ];
  }

  /// Planos de una casilla del tablero. `setupId` nulo = «Sin luz».
  List<Shot> boardShots(Scene scene, int? setId, int? setupId) => [
    for (final shot in _boardShots(scene, setId))
      if (setup(shot.lightSetupId)?.id == setupId) shot,
  ];

  /// Lo propio de un plano en un tramo de su secuencia.
  List<PlanElement> ownOfLeg(Shot shot, int leg) => [
    for (final el in ownOfShot(shot))
      if (FloorPlanRepository.legOf(el) == leg) el,
  ];

  /// Lo que se ve debajo de un tramo: entorno y set.
  List<PlanElement> baseOfLeg(ShotLeg leg) {
    final owner = set(leg.setId);
    return [
      ...environmentOf(owner?.siteId ?? leg.siteId),
      if (owner != null) ...ownOfSet(owner),
    ];
  }

  /// Recorridos de los planos secuencia que pasan por una localización:
  /// el centro de la zona de cada set, en orden.
  List<List<Offset>> routesThroughSite(int siteId) => [
    for (final shot in shots)
      if (isSequence(shot))
        [
          for (final leg in legsOf(shot))
            if (set(leg.setId)?.siteId == siteId)
              if (zoneOf(set(leg.setId)) case final zone?) zone.center,
        ],
  ].where((route) => route.length > 1).toList();

  // ── Zonas de los sets ─────────────────────────────────────────────────────

  Rect? zoneOf(LocationBasePlan? set) => SetZone.decode(set?.sitePlacementJson);

  /// Zonas marcadas sobre el plano maestro de una localización.
  List<PlanZone> zonesOfSite(int siteId) => [
    for (final set in setsOfSite(siteId))
      if (zoneOf(set) case final rect?)
        PlanZone(
          rect: rect,
          color: colors.setColor(set),
          label: set.locationName,
        ),
  ];

  // ── Capas, para miniaturas ────────────────────────────────────────────────

  List<PlanElement> environmentOf(int? siteId) =>
      FloorPlanJson.decode(site(siteId)?.floorPlanJson);

  List<PlanElement> ownOfSet(LocationBasePlan set) =>
      FloorPlanJson.decode(set.floorPlanJson);

  List<PlanElement> ownOfSetup(LightSetup setup) =>
      FloorPlanJson.decode(setup.planJson);

  /// Lo que un esquema ve debajo: entorno de la localización y set.
  List<PlanElement> inheritedOfSetup(LightSetup setup) {
    final owner = set(setup.locationBasePlanId);
    return [
      ...environmentOf(siteIdOfSetup(setup)),
      if (owner != null) ...ownOfSet(owner),
    ];
  }
}

/// Escucha localizaciones, sets, esquemas, escenas y planos de un proyecto.
class PlanDataBuilder extends ConsumerWidget {
  final int projectId;
  final Widget Function(BuildContext context, PlanProjectData data) builder;

  const PlanDataBuilder({
    super.key,
    required this.projectId,
    required this.builder,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    Widget loading() => const Center(child: CircularProgressIndicator());

    return StreamBuilder<List<LocationSite>>(
      stream: db.watchSitesForProject(projectId),
      builder: (context, sites) => StreamBuilder<List<LocationBasePlan>>(
        stream: db.watchLocationsForProject(projectId),
        builder: (context, sets) => StreamBuilder<List<LightSetup>>(
          stream: db.watchLightSetupsForProject(projectId),
          builder: (context, setups) => StreamBuilder<List<Scene>>(
            stream: db.watchScenesForProject(projectId),
            builder: (context, scenes) => StreamBuilder<List<Shot>>(
              stream: db.watchShotsForProject(projectId),
              builder: (context, shots) =>
                  StreamBuilder<List<CameraPlanElement>>(
                    stream: db.watchCameraPlanElementsForProject(projectId),
                    builder: (context, elements) =>
                        StreamBuilder<List<ProjectAnnotationDocument>>(
                          stream: db.watchPlanAnnotationDocuments(projectId),
                          builder: (context, drawings) {
                            if (!sites.hasData ||
                                !sets.hasData ||
                                !setups.hasData ||
                                !scenes.hasData ||
                                !shots.hasData ||
                                !elements.hasData ||
                                !drawings.hasData) {
                              return loading();
                            }
                            return builder(
                              context,
                              PlanProjectData(
                                sites: sites.data!,
                                sets: sets.data!,
                                setups: setups.data!,
                                scenes: scenes.data!,
                                shots: shots.data!,
                                elementRows: elements.data!,
                                drawingRows: drawings.data!,
                              ),
                            );
                          },
                        ),
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
