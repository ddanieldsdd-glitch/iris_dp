import 'dart:convert';
import 'dart:io';

import 'shot_route.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/painting.dart' show Offset, Rect;

import '../../core/database/app_database.dart';
import '../../core/utils/shot_reference_import.dart';
import 'camera_plan_constants.dart';
import 'camera_links.dart';
import 'camera_plan_element_model.dart';
import 'floor_plan_json.dart';
import 'group_light.dart';
import 'floor_plan_scope.dart';
import 'light/ambient.dart';
import 'env_overrides.dart';
import 'light_overrides.dart';
import 'set_environment.dart';
import 'plan_images.dart';
import 'plan_prefs.dart';

/// Capas de una planta, de abajo arriba. Cada nivel ve las anteriores por
/// referencia: nada se copia.
class PlanLayers {
  /// Entorno de la localización.
  final List<PlanElement> environment;

  /// Añadidos propios del set.
  final List<PlanElement> set;

  /// Luz compartida del grupo de sets, con los ajustes del plano.
  final List<PlanElement> groupLight;

  /// Luces y grip del esquema de luz.
  final List<PlanElement> light;

  /// Cámaras y actores del plano.
  final List<PlanElement> shot;

  final LightSetup? lightSetup;

  /// Grupo del set, si lo tiene.
  final SetGroup? group;

  const PlanLayers({
    this.environment = const [],
    this.set = const [],
    this.groupLight = const [],
    this.light = const [],
    this.shot = const [],
    this.lightSetup,
    this.group,
  });

  /// Todo lo que se ve, en orden de pintado.
  List<PlanElement> get all => [
    ...environment,
    ...set,
    ...groupLight,
    ...light,
    ...shot,
  ];
}

/// Qué es un esquema de luz (`LightSetups.kind`).
abstract final class LightSetupKind {
  /// Esquema de verdad: lo comparten planos del guion técnico.
  static const plan = 'planta';

  /// Boceto con elementos de la planta, sin planos.
  static const sketchElements = 'boceto_elementos';

  /// Boceto a mano alzada, en su propio lienzo.
  static const sketchFreehand = 'boceto_mano';

  static bool isSketch(LightSetup setup) => setup.kind != plan;
}

/// Resuelve y persiste las capas de planta.
class FloorPlanRepository {
  final AppDatabase db;

  FloorPlanRepository(this.db);

  /// Elementos propios de un nivel (los que se editan en él).
  Future<List<PlanElement>> loadElements({
    required FloorPlanScope scope,
    int? siteId,
    int? setId,
    int? lightSetupId,
    int? shotId,
  }) async {
    switch (scope) {
      case FloorPlanScope.site:
        final site = siteId != null ? await db.getSiteById(siteId) : null;
        return FloorPlanJson.decode(site?.floorPlanJson);
      case FloorPlanScope.set:
        final set = setId != null ? await db.getLocationById(setId) : null;
        return FloorPlanJson.decode(set?.floorPlanJson);
      case FloorPlanScope.lightSetup:
        final setup = lightSetupId != null
            ? await db.getLightSetupById(lightSetupId)
            : null;
        return FloorPlanJson.decode(setup?.planJson);
      case FloorPlanScope.shot:
        if (shotId == null) return [];
        return _shotElements(shotId);
    }
  }

  Future<List<PlanElement>> _shotElements(int shotId) async {
    final rows = await db.getCameraPlanElementsForShot(shotId);
    final elements = <PlanElement>[];
    for (final row in rows) {
      final pathRows = await db.getPathPointsForElement(row.id);
      elements.add(PlanElement.fromDb(row, pathRows: pathRows));
    }
    return elements;
  }

  Future<void> saveElements({
    required FloorPlanScope scope,
    required List<PlanElement> elements,
    int? siteId,
    int? setId,
    int? lightSetupId,
    int? shotId,
  }) async {
    switch (scope) {
      case FloorPlanScope.site:
        if (siteId == null) return;
        final site = await db.getSiteById(siteId);
        await db.saveFloorPlanToSite(
          siteId,
          _reencode(site?.floorPlanJson, elements),
        );
      case FloorPlanScope.set:
        if (setId == null) return;
        final set = await db.getLocationById(setId);
        await db.saveFloorPlanToSet(
          setId,
          _reencode(set?.floorPlanJson, elements),
        );
      case FloorPlanScope.lightSetup:
        if (lightSetupId == null) return;
        final setup = await db.getLightSetupById(lightSetupId);
        if (setup == null) return;
        final before = FloorPlanJson.decode(setup.planJson);
        await db.updateLightSetup(
          setup.copyWith(planJson: Value(_reencode(setup.planJson, elements))),
        );
        // Las cámaras vinculadas a planos llevan con ellas sus copias.
        await CameraLinks(db).followCameras(lightSetupId, before, elements);
      case FloorPlanScope.shot:
        if (shotId == null) return;
        await _replaceShotElements(shotId, elements);
    }
  }

  /// La luz compartida de un grupo de sets (SG.2).
  Future<void> saveGroupElements(
    int groupId,
    List<PlanElement> elements,
  ) async {
    final group = await db.getSetGroupById(groupId);
    if (group == null) return;
    await db.setSetGroupPlanJson(groupId, _reencode(group.planJson, elements));
  }

  /// Cambia los elementos conservando la escala y el fondo de la capa.
  /// Con [hiddenGroupLights], cambia también las luces del grupo que el set
  /// no lleva.
  String _reencode(
    String? previousJson,
    List<PlanElement> elements, {
    List<String>? hiddenGroupLights,
  }) {
    return FloorPlanJson.encodeDocument(
      FloorPlanJson.decodeDocument(previousJson).copyWith(
        elements: elements,
        hiddenGroupLights: hiddenGroupLights,
      ),
    );
  }

  /// Las luces del grupo que el set no lleva (SG.3).
  Future<void> saveHiddenGroupLights(int setupId, List<String> uids) async {
    final setup = await db.getLightSetupById(setupId);
    if (setup == null) return;
    final doc = FloorPlanJson.decodeDocument(setup.planJson);
    await db.updateLightSetup(
      setup.copyWith(
        planJson: Value(
          _reencode(setup.planJson, doc.elements, hiddenGroupLights: uids),
        ),
      ),
    );
  }

  /// El entorno de un set o una localización (F6.21.1), de su planta.
  static SetEnvironment environmentOf(String? planJson) =>
      SetEnvironment.fromJson(
        FloorPlanJson.decodeDocument(planJson).environment,
      );

  /// El entorno de un set: el de su planta o, si no lo tiene (se eligió
  /// antes de haber set), el de su localización.
  static SetEnvironment environmentOfSet(String? setJson, String? siteJson) {
    final own = FloorPlanJson.decodeDocument(setJson).environment;
    return SetEnvironment.fromJson(
      own ?? FloorPlanJson.decodeDocument(siteJson).environment,
    );
  }

  /// Guarda el entorno en la planta del set [setId] o, sin set, en la de la
  /// localización [siteId], sin tocar lo demás.
  Future<void> saveEnvironment(
    SetEnvironment environment, {
    int? setId,
    int? siteId,
  }) async {
    String with_(String? json) => FloorPlanJson.encodeDocument(
      FloorPlanJson.decodeDocument(
        json,
      ).copyWith(environment: environment.toJson()),
    );

    if (setId != null) {
      final set = await db.getLocationById(setId);
      if (set == null) return;
      await db.saveFloorPlanToSet(setId, with_(set.floorPlanJson));
    } else if (siteId != null) {
      final site = await db.getSiteById(siteId);
      if (site == null) return;
      await db.saveFloorPlanToSite(siteId, with_(site.floorPlanJson));
    }
  }

  Future<void> _replaceShotElements(
    int shotId,
    List<PlanElement> elements,
  ) async {
    final shot = await (db.select(
      db.shots,
    )..where((s) => s.id.equals(shotId))).getSingleOrNull();
    if (shot != null) await db.touchProjectContent(shot.projectId);
    final existing = await db.getCameraPlanElementsForShot(shotId);
    for (final row in existing) {
      await db.deleteCameraPlanElement(row.id);
    }
    for (var i = 0; i < elements.length; i++) {
      final el = elements[i];
      el.id = 0;
      final newId = await db.insertCameraPlanElement(
        el.toCompanion(shotId, sortOrder: i),
      );
      el.id = newId;
      await db.replacePathPoints(
        newId,
        el.pathPoints.map((p) => (x: p.dx, y: p.dy)).toList(),
      );
    }
  }

  // ── Capas ─────────────────────────────────────────────────────────────────

  /// Capas heredadas de un nivel: lo que se ve debajo y no se edita en él.
  Future<PlanLayers> inheritedLayers({
    required FloorPlanScope scope,
    int? setId,
    int? lightSetupId,
    int? shotId,
  }) async {
    switch (scope) {
      case FloorPlanScope.site:
        return const PlanLayers();
      case FloorPlanScope.set:
        final set = setId != null ? await db.getLocationById(setId) : null;
        return PlanLayers(environment: await _environment(set?.siteId));
      case FloorPlanScope.lightSetup:
        final setup = lightSetupId != null
            ? await db.getLightSetupById(lightSetupId)
            : null;
        if (setup == null) return const PlanLayers();
        final base = await _baseLayers(
          setId: setup.locationBasePlanId,
          siteId: setup.locationSiteId,
          setup: setup,
        );
        final group = await _groupOf(setup);
        return PlanLayers(
          environment: base.environment,
          set: base.set,
          groupLight: GroupLight.visible(group?.planJson, setup.planJson),
          lightSetup: setup,
          group: group,
        );
      case FloorPlanScope.shot:
        if (shotId == null) return const PlanLayers();
        final shot = await (db.select(
          db.shots,
        )..where((s) => s.id.equals(shotId))).getSingleOrNull();
        if (shot == null) return const PlanLayers();
        final layers = await layersForShot(shot);
        return PlanLayers(
          environment: layers.environment,
          set: layers.set,
          groupLight: layers.groupLight,
          light: layers.light,
          lightSetup: layers.lightSetup,
          group: layers.group,
        );
    }
  }

  /// Todas las capas de un plano: entorno (con los cambios del set), set,
  /// luz del grupo, esquema de luz y lo propio. Los ajustes de luz del plano
  /// valen para la luz del grupo y para la del esquema.
  ///
  /// El set es el del plano y, si no tiene uno propio, el de su escena. En
  /// un plano secuencia, [leg] elige el tramo: su set, su luz y lo que se
  /// colocó en él.
  Future<PlanLayers> layersForShot(Shot shot, {int? leg}) async {
    final scene = await (db.select(
      db.scenes,
    )..where((s) => s.id.equals(shot.sceneId))).getSingleOrNull();
    final route = ShotRoute.decode(shot.routeJson);
    final onLeg = leg != null && leg >= 0 && leg < route.length
        ? route[leg]
        : null;
    final setupId = onLeg != null ? onLeg.lightSetupId : shot.lightSetupId;
    final setup = setupId != null ? await db.getLightSetupById(setupId) : null;
    final setId =
        onLeg?.setId ??
        shot.locationBasePlanId ??
        scene?.locationId ??
        setup?.locationBasePlanId;
    // La localización es la del set; si no hay set, la de la escena.
    final ownSet = setId != null ? await db.getLocationById(setId) : null;
    final base = await _baseLayers(
      setId: setId,
      siteId:
          onLeg?.siteId ??
          ownSet?.siteId ??
          scene?.locationSiteId ??
          setup?.locationSiteId,
      setup: setup,
    );
    final group = setup != null ? await _groupOf(setup) : null;
    // En una secuencia, cada tramo ve solo lo que se colocó en él.
    final own = await _shotElements(shot.id);
    final legIndex = route.isEmpty ? null : (leg ?? 0);
    return PlanLayers(
      // El entorno, con lo que este plano apaga o ajusta solo para él (EN).
      environment: LightOverrides.apply(
        base.environment,
        shot.lightOverridesJson,
      ),
      set: LightOverrides.apply(base.set, shot.lightOverridesJson),
      // La luz compartida del grupo, también con los ajustes del plano.
      groupLight: LightOverrides.apply(
        GroupLight.visible(group?.planJson, setup?.planJson),
        shot.lightOverridesJson,
      ),
      // La luz del esquema, con los ajustes propios de este plano.
      light: LightOverrides.apply(
        FloorPlanJson.decode(setup?.planJson),
        shot.lightOverridesJson,
      ),
      shot: legIndex == null
          ? own
          : [
              for (final el in own)
                if (legOf(el) == legIndex) el,
            ],
      lightSetup: setup,
      group: group,
    );
  }

  /// Tramo de la secuencia en el que está un elemento propio del plano.
  static const legKey = 'leg';
  static int legOf(PlanElement el) => (el.props[legKey] as num?)?.toInt() ?? 0;

  /// Elementos que se ven en un plano, ya aplanados. Para PDF y exportadores.
  Future<List<PlanElement>> resolvedElementsForShot(Shot shot) async =>
      (await layersForShot(shot)).all;

  /// Entorno y zona; con [setup], ya con sus cambios de entorno.
  Future<PlanLayers> _baseLayers({
    int? setId,
    int? siteId,
    LightSetup? setup,
  }) async {
    final set = setId != null ? await db.getLocationById(setId) : null;
    final resolved = EnvOverrides.apply(
      environment: await _environment(set?.siteId ?? siteId),
      set: FloorPlanJson.decode(set?.floorPlanJson),
      json: setup?.envOverridesJson,
    );
    return PlanLayers(environment: resolved.environment, set: resolved.set);
  }

  Future<SetGroup?> _groupOf(LightSetup setup) async =>
      setup.groupId != null ? await db.getSetGroupById(setup.groupId!) : null;

  Future<List<PlanElement>> _environment(int? siteId) async {
    if (siteId == null) return const [];
    final site = await db.getSiteById(siteId);
    return FloorPlanJson.decode(site?.floorPlanJson);
  }

  /// Plano base que ve una escena: el del set o, si no hay, el de la
  /// localización. `null` si no hay ninguno.
  Future<String?> resolveTemplateJsonForScene(Scene scene) async {
    LocationBasePlan? set;
    LocationSite? site;

    if (scene.locationId != null) {
      set = await db.getLocationById(scene.locationId!);
    }
    if (scene.locationSiteId != null) {
      site = await db.getSiteById(scene.locationSiteId!);
    } else if (set?.siteId != null) {
      site = await db.getSiteById(set!.siteId!);
    }

    final setJson = set?.floorPlanJson;
    if (setJson != null && setJson.isNotEmpty) return setJson;

    final siteJson = site?.floorPlanJson;
    if (siteJson != null && siteJson.isNotEmpty) return siteJson;

    return null;
  }

  bool hasStoredPlan(
    FloorPlanScope scope, {
    String? json,
    int elementCount = 0,
  }) {
    return switch (scope) {
      FloorPlanScope.site ||
      FloorPlanScope.set ||
      FloorPlanScope.lightSetup => json != null && json.isNotEmpty,
      FloorPlanScope.shot => elementCount > 0,
    };
  }

  /// Ambiente de un esquema de luz (sol, cielo, rebote de paredes).
  static PlanAmbient ambientOf(LightSetup? setup) => PlanAmbient.fromJson(
    FloorPlanJson.decodeDocument(setup?.planJson).ambient,
  );

  Future<void> saveAmbient(int lightSetupId, PlanAmbient ambient) async {
    final setup = await db.getLightSetupById(lightSetupId);
    if (setup == null) return;
    await db.updateLightSetup(
      setup.copyWith(
        planJson: Value(
          FloorPlanJson.encodeDocument(
            FloorPlanJson.decodeDocument(
              setup.planJson,
            ).copyWith(ambient: ambient.toJson()),
          ),
        ),
      ),
    );
  }

  /// Sección del esquema que sale en los documentos; nula, la planta entera.
  Future<void> saveDocumentView(int lightSetupId, Rect? view) async {
    final setup = await db.getLightSetupById(lightSetupId);
    if (setup == null) return;
    await db.updateLightSetup(
      setup.copyWith(
        planJson: Value(
          FloorPlanJson.encodeDocument(
            FloorPlanJson.decodeDocument(
              setup.planJson,
            ).copyWith(documentView: () => view),
          ),
        ),
      ),
    );
  }

  /// Guarda los ajustes de luz propios de un plano.
  Future<void> saveLightOverrides(
    int shotId,
    Map<String, PlanElement> overrides,
  ) async {
    final shot = await (db.select(
      db.shots,
    )..where((s) => s.id.equals(shotId))).getSingleOrNull();
    if (shot == null) return;
    await db.updateShot(
      shot.copyWith(
        lightOverridesJson: Value(LightOverrides.encode(overrides)),
      ),
    );
  }

  // ── Esquemas de luz ───────────────────────────────────────────────────────

  /// Crea un esquema de luz. Sin set ni localización es una planta libre.
  Future<LightSetup> createLightSetup({
    required int projectId,
    String? name,
    int? setId,
    int? siteId,
    String status = 'boceto',
    String origin = 'planta',
    String kind = LightSetupKind.plan,
    int? sceneId,
  }) async {
    final existing = (await db.getLightSetupsForProject(projectId))
        .where(
          (s) =>
              s.locationBasePlanId == setId &&
              s.locationSiteId == siteId &&
              s.kind == kind,
        )
        .toList();
    final id = await db.insertLightSetup(
      LightSetupsCompanion.insert(
        projectId: projectId,
        locationBasePlanId: Value(setId),
        locationSiteId: Value(siteId),
        name: name ?? nextSetupName(existing.map((s) => s.name)),
        status: Value(status),
        origin: Value(origin),
        sortOrder: Value(existing.length),
        kind: Value(kind),
        sceneId: Value(sceneId),
        planJson: Value(_newSetupPlanJson(projectId)),
      ),
    );
    return (await db.getLightSetupById(id))!;
  }

  /// Documento inicial de un esquema nuevo: solo el ambiente de Ajustes, si
  /// difiere del de fábrica (si no, se deja vacío como hasta ahora).
  static String? _newSetupPlanJson(int projectId) {
    final ambient = PlanPrefs.newSetupAmbient(projectId).toJson();
    if (jsonEncode(ambient) == jsonEncode(const PlanAmbient().toJson())) {
      return null;
    }
    return FloorPlanJson.encodeDocument(FloorPlanDocument(ambient: ambient));
  }

  /// Copia un esquema para hacer una variante.
  Future<LightSetup> duplicateLightSetup(LightSetup source) => copyLightSetup(
    source,
    setId: source.locationBasePlanId,
    siteId: source.locationSiteId,
  );

  /// Copia un esquema a un set ([setId]), a la luz general de una
  /// localización ([siteId]) o, sin ninguno, a las plantas libres. Si allí
  /// ya hay uno con su nombre, la copia se llama «… (copia)».
  Future<LightSetup> copyLightSetup(
    LightSetup source, {
    int? setId,
    int? siteId,
    String? name,
    String? kind,
    bool renewUids = false,
  }) async {
    final siblings = (await db.getLightSetupsForProject(source.projectId))
        .where(
          (s) => s.locationBasePlanId == setId && s.locationSiteId == siteId,
        )
        .toList();
    final taken = siblings.map((s) => s.name).toSet();
    var copyName = name ?? source.name;
    while (taken.contains(copyName)) {
      copyName = '$copyName (copia)';
    }
    final id = await db.insertLightSetup(
      LightSetupsCompanion.insert(
        projectId: source.projectId,
        locationBasePlanId: Value(setId),
        locationSiteId: Value(setId == null ? siteId : null),
        name: copyName,
        status: Value(source.status),
        origin: const Value('planta'),
        category: Value(source.category),
        planJson: Value(
          renewUids ? renewedPlanJson(source.planJson) : source.planJson,
        ),
        sketchJson: Value(source.sketchJson),
        sketchImagePath: Value(source.sketchImagePath),
        sortOrder: Value(siblings.length),
        kind: Value(kind ?? source.kind),
        // Un boceto sigue en su escena; un esquema de verdad no tiene.
        sceneId: Value(
          (kind ?? source.kind) == LightSetupKind.plan ? null : source.sceneId,
        ),
      ),
    );
    return (await db.getLightSetupById(id))!;
  }

  /// La misma planta con identificadores nuevos en sus elementos: una copia
  /// que ya no es la de partida (ni en el 3D ni en los ajustes de un plano).
  /// Conserva escala, fondo, ambiente y entorno.
  static String? renewedPlanJson(String? json) {
    if (json == null || json.isEmpty) return json;
    final doc = FloorPlanJson.decodeDocument(json);
    final copies = doc.elements.map(LightOverrides.clone).toList();
    LightOverrides.renewUids(copies);
    return FloorPlanJson.encodeDocument(
      FloorPlanDocument(
        elements: copies,
        metersPerUnit: doc.metersPerUnit,
        underlay: doc.underlay,
        ambient: doc.ambient,
        environment: doc.environment,
        documentView: doc.documentView,
      ),
    );
  }

  /// Hace oficial un boceto: el mismo esquema pasa a ser una planta de verdad
  /// de [setId] o de la luz general de [siteId] (sin ninguno, una planta
  /// libre), con [shotIds] rodados en ella. Esos planos dejan de enseñarlo
  /// como boceto. Un boceto a mano entra como imagen de la planta, para
  /// colocar encima focos y cámaras.
  Future<LightSetup> promoteSketch(
    LightSetup sketch, {
    int? setId,
    int? siteId,
    String? name,
    Set<int> shotIds = const {},
  }) async {
    final siblings = (await db.getLightSetupsForProject(sketch.projectId))
        .where(
          (s) =>
              s.id != sketch.id &&
              s.kind == LightSetupKind.plan &&
              s.locationBasePlanId == setId &&
              s.locationSiteId == (setId == null ? siteId : null),
        )
        .toList();
    final taken = siblings.map((s) => s.name).toSet();
    final base = (name ?? sketch.name.replaceFirst('Boceto · ', '')).trim();
    final wanted = base.isEmpty ? nextSetupName(taken) : base;
    var finalName = wanted;
    for (var i = 2; taken.contains(finalName); i++) {
      finalName = '$wanted ($i)';
    }
    if (sketch.kind == LightSetupKind.sketchFreehand) {
      final path = sketch.sketchImagePath;
      if (path != null && File(path).existsSync()) {
        await PlanImageStore(db).add(
          projectId: sketch.projectId,
          scope: FloorPlanScope.lightSetup,
          targetId: sketch.id,
          bytes: await File(path).readAsBytes(),
          extension: '.png',
          source: PlanImageSource.file,
          center: const Offset(800, 600),
          longSide: 1600,
        );
      }
    }
    await db.updateLightSetup(
      sketch.copyWith(
        name: finalName,
        kind: LightSetupKind.plan,
        status: 'definitivo',
        sceneId: const Value(null),
        locationBasePlanId: Value(setId),
        locationSiteId: Value(setId == null ? siteId : null),
        sortOrder: siblings.length,
      ),
    );
    for (final shotId in shotIds) {
      final shot = await db.getShotById(shotId);
      if (shot == null) continue;
      await db.moveShot(
        shotId,
        setId: setId ?? shot.locationBasePlanId,
        lightSetupId: sketch.id,
      );
      await removeShotPlanSketch(
        db: db,
        shot: shot,
        path: 'setup:${sketch.id}',
      );
    }
    return (await db.getLightSetupById(sketch.id))!;
  }

  /// Esquemas de la luz general de una localización (sin set), de los que
  /// se puede partir para la luz de uno de sus sets.
  Future<List<LightSetup>> siteLightSetups(int projectId, int siteId) async =>
      (await db.getLightSetupsForProject(projectId))
          .where(
            (s) =>
                s.locationSiteId == siteId &&
                s.locationBasePlanId == null &&
                s.kind == LightSetupKind.plan,
          )
          .toList();

  /// Esquema nuevo de un set que empieza con las luces de [source] (la luz
  /// general de su localización u otro esquema) ya colocadas. Es una copia:
  /// lo que cambie después en [source] no le llega.
  Future<LightSetup> createLightSetupFrom(
    LightSetup source, {
    int? setId,
    int? siteId,
    String? name,
  }) => copyLightSetup(
    source,
    setId: setId,
    siteId: siteId,
    name: name,
    kind: LightSetupKind.plan,
    renewUids: true,
  );

  /// Crea un set en [siteId]. Puede empezar desde otro set ([fromSet]: su
  /// planta y su entorno) o desde la localización ([fromSite]: su entorno de
  /// plató/interior/exterior) y, con [includeLights], con copias de los
  /// esquemas de luz de ese set o de la luz general de la localización.
  /// Las copias no siguen a su origen.
  Future<LocationBasePlan> createSet({
    required int projectId,
    required String name,
    int? siteId,
    LocationBasePlan? fromSet,
    bool fromSite = false,
    bool includeLights = false,
  }) async {
    final siblings = (await db.getLocationsMapForProject(
      projectId,
    )).values.where((l) => l.siteId == siteId).toList();
    String? planJson;
    if (fromSet != null) {
      planJson = renewedPlanJson(fromSet.floorPlanJson);
    } else if (fromSite && siteId != null) {
      final site = await db.getSiteById(siteId);
      final env = FloorPlanJson.decodeDocument(site?.floorPlanJson).environment;
      if (env != null) {
        planJson = FloorPlanJson.encodeDocument(
          FloorPlanDocument(environment: env),
        );
      }
    }
    final id = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        locationName: name,
        floorPlanJson: Value(planJson),
        sortOrder: Value(siblings.length),
      ),
    );
    if (includeLights) {
      final List<LightSetup> sources;
      if (fromSet != null) {
        sources = (await db.getLightSetupsForProject(projectId))
            .where(
              (s) =>
                  s.locationBasePlanId == fromSet.id &&
                  s.kind == LightSetupKind.plan,
            )
            .toList();
      } else if (fromSite && siteId != null) {
        sources = await siteLightSetups(projectId, siteId);
      } else {
        sources = const [];
      }
      for (final setup in sources) {
        await createLightSetupFrom(setup, setId: id, name: setup.name);
      }
    }
    return (await db.getLocationById(id))!;
  }

  /// Copia un set con su planta y sus esquemas de luz, en [siteId] (por
  /// defecto, su misma localización). Las escenas no se mueven: siguen en
  /// el set de partida.
  Future<LocationBasePlan> copySet(
    LocationBasePlan source, {
    int? siteId,
    bool keepSite = true,
  }) async {
    final target = keepSite ? source.siteId : siteId;
    final siblings = (await db.getLocationsMapForProject(
      source.projectId,
    )).values.where((l) => l.siteId == target).toList();
    final taken = siblings.map((l) => l.locationName).toSet();
    var name = source.locationName;
    while (taken.contains(name)) {
      name = '$name (copia)';
    }
    final id = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: source.projectId,
        siteId: Value(target),
        locationName: name,
        description: Value(source.description),
        color: Value(source.color),
        notes: Value(source.notes),
        floorPlanJson: Value(source.floorPlanJson),
        // En otra localización, su sitio en el plano maestro no vale.
        sitePlacementJson: Value(
          target == source.siteId ? source.sitePlacementJson : null,
        ),
        sortOrder: Value(siblings.length),
      ),
    );
    final setups = (await db.getLightSetupsForProject(
      source.projectId,
    )).where((s) => s.locationBasePlanId == source.id);
    for (final setup in setups) {
      await copyLightSetup(setup, setId: id, name: setup.name);
    }
    return (await db.getLocationById(id))!;
  }

  /// Borra un set con sus esquemas de luz. Sus escenas y planos se quedan
  /// sin set; los planos que usaban esos esquemas, sin luz.
  Future<void> deleteSet(LocationBasePlan set) async {
    final setups = (await db.getLightSetupsForProject(
      set.projectId,
    )).where((s) => s.locationBasePlanId == set.id);
    for (final setup in setups) {
      await db.deleteLightSetup(setup.id);
    }
    await db.deleteLocation(set.id);
  }

  /// «Setup A», «Setup B»… El primero libre.
  static String nextSetupName(Iterable<String> existing) {
    final taken = existing.toSet();
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    for (var i = 0; i < letters.length; i++) {
      final name = 'Setup ${letters[i]}';
      if (!taken.contains(name)) return name;
    }
    return 'Setup ${taken.length + 1}';
  }

  /// Sets que puede usar un plano: todos los de su localización (estén en
  /// la zona que estén, SG.2) y las plantas libres.
  Future<List<LightSetup>> lightSetupsForScene(Scene scene) async {
    final all = await db.getLightSetupsForProject(scene.projectId);
    final zones = await db.getLocationsMapForProject(scene.projectId);
    final siteId = scene.locationSiteId ?? zones[scene.locationId]?.siteId;
    return all.where((s) {
      // Los bocetos no llevan planos.
      if (s.kind != LightSetupKind.plan) return false;
      final own = s.locationSiteId ?? zones[s.locationBasePlanId]?.siteId;
      if (own != null) return own == siteId;
      return s.locationBasePlanId == null ||
          s.locationBasePlanId == scene.locationId;
    }).toList();
  }

  /// ¿Tiene el plano algo propio o heredado que enseñar?
  static bool hasLights(Iterable<PlanElement> elements) =>
      elements.any((e) => e.type == ElementType.light);
}
