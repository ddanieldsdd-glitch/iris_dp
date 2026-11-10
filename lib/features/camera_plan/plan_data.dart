import 'dart:async';

import 'shot_plan_view.dart';
import 'floor_plan_repository.dart';
import 'shot_route.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/utils/project_color_scheme.dart';
import '../../shared/annotations/annotation_document.dart';
import 'camera_plan_constants.dart';
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

  /// Recorridos de cámaras y personajes; los necesitan los documentos.
  final List<CameraPathPoint> pathRows;

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
    this.pathRows = const [],
    this.drawingRows = const [],
  }) : colors = ProjectColorScheme.resolve(
         sites: sites,
         sets: sets,
         scenes: scenes,
       );

  /// Todas las plantas del proyecto, de una vez, para los documentos.
  static Future<PlanProjectData> load(AppDatabase db, int projectId) async =>
      PlanProjectData(
        pathRows: await db.select(db.cameraPathPoints).get(),
        sites: await db.watchSitesForProject(projectId).first,
        sets: await db.watchLocationsForProject(projectId).first,
        setups: await db.getLightSetupsForProject(projectId),
        scenes: await db.watchScenesForProject(projectId).first,
        shots: await db.getShotsForProject(projectId),
        groups: await db.watchSetGroupsForProject(projectId).first,
        elementRows: await db
            .watchCameraPlanElementsForProject(projectId)
            .first,
        drawingRows: await db.watchPlanAnnotationDocuments(projectId).first,
      );

  bool get isEmpty => sites.isEmpty && sets.isEmpty && setups.isEmpty;

  // Una instancia no cambia: lo calculado sobre ella vale mientras viva. Cada
  // celda y miniatura pregunta lo mismo varias veces por fotograma.
  late final _siteById = {for (final s in sites) s.id: s};
  late final _setById = {for (final s in sets) s.id: s};
  late final _sceneById = {for (final s in scenes) s.id: s};
  late final _setupById = {for (final s in setups) s.id: s};
  late final _groupById = {for (final g in groups) g.id: g};

  /// Planos de cada escena, en su orden.
  late final Map<int, List<Shot>> shotsByScene = () {
    final map = <int, List<Shot>>{};
    for (final shot in shots) {
      map.putIfAbsent(shot.sceneId, () => []).add(shot);
    }
    return map;
  }();

  late final Map<int, List<CameraPathPoint>> _pathsByElement = () {
    final map = <int, List<CameraPathPoint>>{};
    for (final row in pathRows) {
      map.putIfAbsent(row.elementId, () => []).add(row);
    }
    return map;
  }();

  /// Filas de planta de cada plano, en el orden en que llegan.
  late final Map<int, List<CameraPlanElement>> _rowsByShot = () {
    final map = <int, List<CameraPlanElement>>{};
    for (final row in elementRows) {
      map.putIfAbsent(row.shotId, () => []).add(row);
    }
    return map;
  }();

  late final Map<int, int> _sceneOrder = {
    for (final (i, s) in scenesInScriptOrder(scenes).indexed) s.id: i,
  };

  /// Plantas ya leídas, por su JSON. Se guardan entre instancias: casi todo
  /// sigue igual tras cada cambio del proyecto, y las plantas son lo más
  /// caro de leer. Son de solo lectura: quien edita lee las suyas.
  static const _decodedKept = 128;
  static final _decoded = <String, List<PlanElement>>{};

  static List<PlanElement> _decode(String? json) {
    if (json == null || json.isEmpty) return const [];
    final kept = _decoded.remove(json);
    if (kept != null) return _decoded[json] = kept;
    final list = List<PlanElement>.unmodifiable(FloorPlanJson.decode(json));
    _decoded[json] = list;
    while (_decoded.length > _decodedKept) {
      _decoded.remove(_decoded.keys.first);
    }
    return list;
  }

  final _ownOfShot = <int, List<PlanElement>>{};
  final _lightOfShot = <(int, int?, String?), List<PlanElement>>{};
  final _baseOfShot = <(int, int?, int?, String?), List<PlanElement>>{};
  final _groupLight = <int, List<PlanElement>>{};
  final _inheritedOfSetup = <int, List<PlanElement>>{};

  LocationSite? site(int? id) => _siteById[id];

  LocationBasePlan? set(int? id) => _setById[id];

  Scene? scene(int? id) => _sceneById[id];

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
    return list.toList()..sort((a, b) {
      final byScene = (_sceneOrder[a.sceneId] ?? 0).compareTo(
        _sceneOrder[b.sceneId] ?? 0,
      );
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

  SetGroup? group(int? id) => _groupById[id];

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
    var best = 1 << 30;
    for (final shot in shotsOfSetup(setup.id)) {
      final i = (_sceneOrder[shot.sceneId] ?? 0) * 10000 + shot.number;
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

  LightSetup? setup(int? id) => _setupById[id];

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
    final rows = _rowsByShot[shot.id] ?? const <CameraPlanElement>[];
    if (!tagged) {
      return _ownOfShot[shot.id] ??= List.unmodifiable([
        for (final row in rows)
          PlanElement.fromDb(
            row,
            pathRows: _pathsByElement[row.id] ?? const [],
          ),
      ]);
    }
    final sceneNumber = scene(shot.sceneId)?.number;
    return [
      for (final row in rows)
        PlanElement.fromDb(row, pathRows: _pathsByElement[row.id] ?? const [])
          ..props.addAll({
            if (row.type == 'camera')
              'shotTag': sceneNumber == null
                  ? 'P${shot.number}'
                  : '$sceneNumber·${shot.number}',
          }),
    ];
  }

  /// Letras de las cámaras de un plano (A, B…), sin repetir.
  List<String> camerasOfShot(Shot shot) => {
    for (final row in _rowsByShot[shot.id] ?? const <CameraPlanElement>[])
      if (row.type == 'camera') row.cameraLetter,
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
    return _lightOfShot[(
      shot.id,
      shot.lightSetupId,
      shot.lightOverridesJson,
    )] ??= List.unmodifiable(
      LightOverrides.apply(ownOfSetup(own), shot.lightOverridesJson),
    );
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
  List<PlanElement> baseOfShot(Shot shot) =>
      _baseOfShot[(
        shot.id,
        shot.lightSetupId,
        shot.locationBasePlanId,
        shot.lightOverridesJson,
      )] ??= List.unmodifiable(
        _resolveBaseOfShot(shot),
      );

  List<PlanElement> _resolveBaseOfShot(Shot shot) {
    // Con su set: el entorno como lo ve el set (lo que apaga o quita) y lo
    // que el plano ajusta solo para él (EN).
    final own = setup(shot.lightSetupId);
    if (own != null && siteIdOfSetup(own) != null) {
      return LightOverrides.apply(
        inheritedOfSetup(own),
        shot.lightOverridesJson,
      );
    }
    final sc = scene(shot.sceneId);
    final owner = set(setIdOfShot(shot));
    return LightOverrides.apply([
      ...environmentOf(owner?.siteId ?? sc?.locationSiteId),
      if (owner != null) ...ownOfSet(owner),
    ], shot.lightOverridesJson);
  }

  /// Las luces del entorno que ve un set: las de su localización y su
  /// zona, con lo que el set apaga o quita (EN).
  List<PlanElement> environmentLightsOfSetup(LightSetup setup) => [
    for (final e in inheritedOfSetup(setup))
      if (e.type == ElementType.light) e,
  ];

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
    crop:
        decodeShotPlanView(shot.planViewJson) ??
        documentViewOf(setup(shot.lightSetupId)),
  );

  /// Sección del esquema para los documentos; la del plano va por delante.
  Rect? documentViewOf(LightSetup? setup) {
    final json = setup?.planJson;
    if (json == null || !json.contains('documentView')) return null;
    return FloorPlanJson.decodeDocument(json).documentView;
  }

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
      _decode(site(siteId)?.floorPlanJson);

  List<PlanElement> ownOfSet(LocationBasePlan set) =>
      _decode(set.floorPlanJson);

  List<PlanElement> ownOfSetup(LightSetup setup) => _decode(setup.planJson);

  /// La luz compartida del grupo del set (SG.1).
  List<PlanElement> groupLightOf(LightSetup setup) =>
      _groupLight[setup.id] ??= List.unmodifiable(
        GroupLight.visible(group(setup.groupId)?.planJson, setup.planJson),
      );

  /// Lo que un esquema ve debajo: entorno de la localización y set.
  List<PlanElement> inheritedOfSetup(LightSetup setup) =>
      _inheritedOfSetup[setup.id] ??= List.unmodifiable(
        _resolveInheritedOfSetup(setup),
      );

  List<PlanElement> _resolveInheritedOfSetup(LightSetup setup) {
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
  bool updateShouldNotify(PlanDataScope oldWidget) =>
      !identical(oldWidget.data, data);
}

/// Escucha localizaciones, sets, esquemas, escenas y planos de un proyecto.
class PlanDataBuilder extends ConsumerStatefulWidget {
  final int projectId;
  final Widget Function(BuildContext context, PlanProjectData data) builder;

  const PlanDataBuilder({
    super.key,
    required this.projectId,
    required this.builder,
  });

  @override
  ConsumerState<PlanDataBuilder> createState() => _PlanDataBuilderState();
}

class _PlanDataBuilderState extends ConsumerState<PlanDataBuilder> {
  AppDatabase? _db;
  int? _projectId;
  var _subscriptions = <StreamSubscription<Object?>>[];

  List<LocationSite>? _sites;
  List<LocationBasePlan>? _sets;
  List<LightSetup>? _setups;
  List<Scene>? _scenes;
  List<Shot>? _shots;
  List<CameraPlanElement>? _elements;
  List<ProjectAnnotationDocument>? _drawings;
  List<SetGroup>? _groups;

  /// El último resultado: mientras nada cambie es el mismo objeto, y quien
  /// depende de [PlanDataScope] no se reconstruye.
  PlanProjectData? _data;
  var _stale = true;

  /// Las consultas viven aquí y no en el árbol: un stream de Drift es nuevo
  /// en cada `watch()`, y creado en un `build` se suscribe otra vez cada vez
  /// que se reconstruye lo que tiene encima.
  void _subscribe(AppDatabase db, int projectId) {
    _cancel();
    _db = db;
    _projectId = projectId;
    _sites = null;
    _sets = null;
    _setups = null;
    _scenes = null;
    _shots = null;
    _elements = null;
    _drawings = null;
    _groups = null;
    _data = null;
    _stale = true;
    _subscriptions = [
      _follow(
        db.watchSitesForProject(projectId),
        () => _sites,
        (rows) => _sites = rows,
      ),
      _follow(
        db.watchLocationsForProject(projectId),
        () => _sets,
        (rows) => _sets = rows,
      ),
      _follow(
        db.watchLightSetupsForProject(projectId),
        () => _setups,
        (rows) => _setups = rows,
      ),
      _follow(
        db.watchScenesForProject(projectId),
        () => _scenes,
        (rows) => _scenes = rows,
      ),
      _follow(
        db.watchShotsForProject(projectId),
        () => _shots,
        (rows) => _shots = rows,
      ),
      _follow(
        db.watchCameraPlanElementsForProject(projectId),
        () => _elements,
        (rows) => _elements = rows,
      ),
      _follow(
        db.watchPlanAnnotationDocuments(projectId),
        () => _drawings,
        (rows) => _drawings = rows,
      ),
      _follow(
        db.watchSetGroupsForProject(projectId),
        () => _groups,
        (rows) => _groups = rows,
      ),
    ];
  }

  /// Sigue una consulta. Si devuelve lo mismo que tenía (Drift avisa por
  /// tabla, no por fila), no pasa nada. Varias respuestas en un mismo
  /// fotograma se quedan en una reconstrucción.
  StreamSubscription<List<T>> _follow<T>(
    Stream<List<T>> stream,
    List<T>? Function() current,
    void Function(List<T>) store,
  ) => stream.listen(
    (rows) {
      if (listEquals(current(), rows)) return;
      store(rows);
      _stale = true;
      if (mounted) setState(() {});
    },
    // Como un StreamBuilder: se sigue enseñando lo último que llegó.
    onError: (Object error, StackTrace stack) =>
        debugPrint('PlanDataBuilder: $error'),
  );

  void _cancel() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions = [];
  }

  PlanProjectData? _current() {
    if (!_stale) return _data;
    final (sites, sets, setups, scenes, shots, elements, drawings, groups) = (
      _sites,
      _sets,
      _setups,
      _scenes,
      _shots,
      _elements,
      _drawings,
      _groups,
    );
    if (sites == null ||
        sets == null ||
        setups == null ||
        scenes == null ||
        shots == null ||
        elements == null ||
        drawings == null ||
        groups == null) {
      return null;
    }
    _stale = false;
    return _data = PlanProjectData(
      sites: sites,
      sets: sets,
      setups: setups,
      scenes: scenes,
      shots: shots,
      groups: groups,
      elementRows: elements,
      drawingRows: drawings,
    );
  }

  @override
  void dispose() {
    _cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(databaseProvider);
    if (!identical(db, _db) || widget.projectId != _projectId) {
      _subscribe(db, widget.projectId);
    }
    final data = _current();
    if (data == null) return const Center(child: CircularProgressIndicator());
    return widget.builder(context, data);
  }
}
