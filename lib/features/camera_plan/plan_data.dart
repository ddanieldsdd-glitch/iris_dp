import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/utils/project_color_scheme.dart';
import 'camera_plan_element_model.dart';
import 'camera_plan_painter.dart';
import 'camera_plan_grouping.dart';
import 'floor_plan_json.dart';

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
  final ProjectColorScheme colors;

  PlanProjectData({
    required this.sites,
    required this.sets,
    required this.setups,
    required this.scenes,
    required this.shots,
    this.elementRows = const [],
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

  List<LightSetup> setupsOfSet(int setId) =>
      setups.where((s) => s.locationBasePlanId == setId).toList();

  /// Esquemas de la localización que no son de ningún set.
  List<LightSetup> setupsOfSite(int siteId) => setups
      .where((s) => s.locationBasePlanId == null && s.locationSiteId == siteId)
      .toList();

  /// Plantas libres: sin set ni localización.
  List<LightSetup> get freeSetups => setups
      .where((s) => s.locationBasePlanId == null && s.locationSiteId == null)
      .toList();

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
    return setups.where((s) {
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

  /// Lo propio de un plano: cámaras y actores.
  List<PlanElement> ownOfShot(Shot shot) => [
    for (final row in elementRows)
      if (row.shotId == shot.id) PlanElement.fromDb(row),
  ];

  /// Lo que se ve debajo de un plano, sin la luz: entorno y set.
  List<PlanElement> baseOfShot(Shot shot) {
    final sc = scene(shot.sceneId);
    final owner = set(sc?.locationId);
    return [
      ...environmentOf(sc?.locationSiteId ?? owner?.siteId),
      if (owner != null) ...ownOfSet(owner),
    ];
  }

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
                    builder: (context, elements) {
                      if (!sites.hasData ||
                          !sets.hasData ||
                          !setups.hasData ||
                          !scenes.hasData ||
                          !shots.hasData ||
                          !elements.hasData) {
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
                        ),
                      );
                    },
                  ),
            ),
          ),
        ),
      ),
    );
  }
}
