import 'shot_plan_view.dart';
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
import 'env_overrides.dart';
import 'floor_plan_json.dart';
import 'group_light.dart';
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

  /// Grupos de sets: los que comparten luz (SG.1).
  final List<SetGroup> groups;

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
    this.groups = const [],
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

  // ── Sets de una localización (SG.2) ───────────────────────────────────────

  SetGroup? group(int? id) {
    for (final g in groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  /// Todos los sets de una localización, estén o no en una zona.
  List<LightSetup> lightSetsOfSite(int siteId) => [
    for (final s in planSetups)
      if (siteIdOfSetup(s) == siteId) s,
  ];

  /// Grupos de una localización (y los que tienen sets suyos).
  List<SetGroup> groupsOfSite(int siteId) {
    final used = {
      for (final s in lightSetsOfSite(siteId))
        if (s.groupId != null) s.groupId,
    };
    return [
      for (final g in groups)
        if (g.locationSiteId == siteId || used.contains(g.id)) g,
    ];
  }

  List<LightSetup> setsOfGroup(int groupId) => [
    for (final s in planSetups)
      if (s.groupId == groupId) s,
  ];

  /// Escenas que se ruedan en un set, en orden de guion.
  List<Scene> scenesOfSetup(int setupId) {
    final ids = {for (final s in shotsOfSetup(setupId)) s.sceneId};
    return scenesInScriptOrder(
      scenes.where((s) => ids.contains(s.id)).toList(),
    );
  }

  /// Posición en el guion del primer plano del set; sin planos, al final.
  int _narrativeIndex(LightSetup setup) {
    final order = {
      for (final (i, s) in scenesInScriptOrder(scenes).indexed) s.id: i,
    };
    var best = 1 << 30;
    for (final shot in shotsOfSetup(setup.id)) {
      final i = (order[shot.sceneId] ?? 0) * 10000 + shot.number;
      if (i < best) best = i;
    }
    return best;
  }

  /// Los sets de una localización en el orden elegido ([mode], o el de la
  /// localización): por grupo (fondo), narrativo o a mano. Ese orden es el
  /// de rodaje y el del PDF. Cada tramo lleva su grupo; en el orden por
  /// grupo, los sueltos van al final con grupo nulo.
  List<({SetGroup? group, List<LightSetup> sets})> orderedSets(
    int siteId, {
    String? mode,
  }) {
    final all = lightSetsOfSite(siteId);
    int bySort(LightSetup a, LightSetup b) {
      final c = a.sortOrder.compareTo(b.sortOrder);
      return c != 0 ? c : a.id.compareTo(b.id);
    }

    switch (SetOrderMode.of(mode ?? site(siteId)?.setOrderMode)) {
      case SetOrderMode.narrative:
        final list = [...all]
          ..sort((a, b) {
            final c = _narrativeIndex(a).compareTo(_narrativeIndex(b));
            return c != 0 ? c : bySort(a, b);
          });
        return [(group: null, sets: list)];
      case SetOrderMode.manual:
        final list = [...all]
          ..sort((a, b) {
            final c = (a.shootOrder ?? 1 << 30).compareTo(
              b.shootOrder ?? 1 << 30,
            );
            return c != 0
                ? c
                : _narrativeIndex(a).compareTo(_narrativeIndex(b));
          });
        return [(group: null, sets: list)];
      case SetOrderMode.group:
        final out = <({SetGroup? group, List<LightSetup> sets})>[];
        for (final g in groupsOfSite(siteId)) {
          out.add((
            group: g,
            sets: [
              for (final s in all)
                if (s.groupId == g.id) s,
            ]..sort(bySort),
          ));
        }
        final loose = [
          for (final s in all)
            if (group(s.groupId) == null) s,
        ]..sort(bySort);
        if (loose.isNotEmpty) out.add((group: null, sets: loose));
        return out;
    }
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

  /// Sets que puede usar una escena: todos los de su localización (estén en
  /// la zona que estén, SG.2) y las plantas libres.
  List<LightSetup> setupsForScene(Scene scene) {
    final siteId = siteIdOfScene(scene);
    return planSetups.where((s) {
      final own = siteIdOfSetup(s);
      if (own != null) return own == siteId;
      return s.locationBasePlanId == null ||
          s.locationBasePlanId == scene.locationId;
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

  /// Letras de las cámaras de un plano (A, B…), sin repetir.
  List<String> camerasOfShot(Shot shot) => {
    for (final row in elementRows)
      if (row.shotId == shot.id && row.type == 'camera') row.cameraLetter,
  }.toList()..sort();

  /// Planos de las escenas de una localización que aún no están en ninguno
  /// de sus sets, en orden de guion.
  List<Shot> shotsWithoutSetOfSite(int siteId) {
    final sets = {for (final s in lightSetsOfSite(siteId)) s.id};
    return _inScriptOrder(
      shots.where((shot) {
        final sc = scene(shot.sceneId);
        if (sc == null || siteIdOfScene(sc) != siteId) return false;
        return !sets.contains(shot.lightSetupId);
      }),
    );
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

  // ── Tablero por grupos y sets (SG.2) ─────────────────────────────────────

  /// Hasta cuántos sets de la localización se ven todos en el tablero.
  static const boardAllSetsUpTo = 4;

  /// Sets del tablero de una escena: los que usan sus planos y los
  /// añadidos a mano ([extra]), por grupo y en el orden de la localización.
  List<({SetGroup? group, List<LightSetup> sets})> boardGroupsOf(
    Scene scene, {
    Iterable<int> extra = const [],
  }) {
    final siteId = siteIdOfScene(scene);
    final ofSite = siteId == null
        ? const <LightSetup>[]
        : lightSetsOfSite(siteId);
    final ids = <int>{
      for (final shot in shotsOfScene(scene.id))
        if (!isSequence(shot) && setup(shot.lightSetupId) != null)
          shot.lightSetupId!,
      ...extra,
      // Con pocos sets en la localización, se ven todos.
      if (ofSite.length <= boardAllSetsUpTo) ...ofSite.map((s) => s.id),
    };
    final order = <int>[
      if (siteId != null)
        for (final part in orderedSets(siteId, mode: 'group'))
          for (final s in part.sets) s.id,
    ];
    final shown =
        [
          for (final s in planSetups)
            if (ids.contains(s.id)) s,
        ]..sort((a, b) {
          int at(LightSetup s) {
            final i = order.indexOf(s.id);
            return i < 0 ? 1 << 20 : i;
          }

          return at(a).compareTo(at(b));
        });
    final out = <({SetGroup? group, List<LightSetup> sets})>[];
    final groupIds = <int?>[];
    for (final s in shown) {
      final g = group(s.groupId)?.id;
      if (!groupIds.contains(g)) groupIds.add(g);
    }
    // Los sueltos, al final.
    if (groupIds.remove(null)) groupIds.add(null);
    for (final g in groupIds) {
      out.add((
        group: group(g),
        sets: [
          for (final s in shown)
            if (group(s.groupId)?.id == g) s,
        ],
      ));
    }
    return out;
  }

  /// Sets de la localización de la escena que aún no están en su tablero.
  List<LightSetup> lightSetsToAdd(Scene scene, Iterable<int> shown) {
    final siteId = siteIdOfScene(scene);
    final list = siteId == null ? freeSetups : lightSetsOfSite(siteId);
    return [
      for (final s in list)
        if (!shown.contains(s.id)) s,
    ];
  }

  /// Planos (no secuencia) de la escena en un set; `null` = sin luz.
  List<Shot> boardShotsOfSet(Scene scene, int? setupId) => [
    for (final shot in shotsOfScene(scene.id))
      if (!isSequence(shot) && setup(shot.lightSetupId)?.id == setupId) shot,
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

  /// Encuadre del plano en su planta: la sección elegida o, sin ella, la
  /// zona de su set. Toda pantalla y export sale de aquí.
  ({Rect? focus, Rect? crop}) framingOf(Shot shot) => (
    focus: zoneOf(set(setIdOfShot(shot))),
    crop: decodeShotPlanView(shot.planViewJson),
  );

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

  /// La luz compartida del grupo del set (SG.1).
  List<PlanElement> groupLightOf(LightSetup setup) =>
      GroupLight.visible(group(setup.groupId)?.planJson, setup.planJson);

  /// Lo que un esquema ve debajo: entorno de la localización y set.
  List<PlanElement> inheritedOfSetup(LightSetup setup) {
    final owner = set(setup.locationBasePlanId);
    // Con los cambios de entorno propios del set (SG.3).
    final resolved = EnvOverrides.apply(
      environment: environmentOf(siteIdOfSetup(setup)),
      set: owner == null ? const [] : ownOfSet(owner),
      json: setup.envOverridesJson,
    );
    return [...resolved.environment, ...resolved.set];
  }
}

/// Cómo se ordenan los sets de una localización (`LocationSites.setOrderMode`).
enum SetOrderMode {
  /// Por grupo: los sets con el mismo fondo, juntos.
  group,

  /// Por el orden del guion.
  narrative,

  /// A mano: el orden de rodaje.
  manual;

  static SetOrderMode of(String? value) => switch (value) {
    'narrative' => narrative,
    'manual' => manual,
    _ => group,
  };
}

/// Datos de plantas del proyecto, al alcance de cada celda o tarjeta de plano
/// sin obligar a repintar la fila entera cuando cambian.
class PlanDataScope extends InheritedWidget {
  final PlanProjectData data;

  const PlanDataScope({super.key, required this.data, required super.child});

  static PlanProjectData of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlanDataScope>()!.data;

  @override
  bool updateShouldNotify(PlanDataScope oldWidget) => oldWidget.data != data;
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
                          builder: (context, drawings) =>
                              StreamBuilder<List<SetGroup>>(
                                stream: db.watchSetGroupsForProject(projectId),
                                builder: (context, groups) {
                                  if (!groups.hasData ||
                                      !sites.hasData ||
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
                                      groups: groups.data!,
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
      ),
    );
  }
}
