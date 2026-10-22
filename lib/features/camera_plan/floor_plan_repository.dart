import 'dart:convert';

import 'shot_route.dart';
import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'floor_plan_json.dart';
import 'floor_plan_scope.dart';
import 'light/ambient.dart';
import 'light_overrides.dart';
import 'plan_prefs.dart';

/// Capas de una planta, de abajo arriba. Cada nivel ve las anteriores por
/// referencia: nada se copia.
class PlanLayers {
  /// Entorno de la localización.
  final List<PlanElement> environment;

  /// Añadidos propios del set.
  final List<PlanElement> set;

  /// Luces y grip del esquema de luz.
  final List<PlanElement> light;

  /// Cámaras y actores del plano.
  final List<PlanElement> shot;

  final LightSetup? lightSetup;

  const PlanLayers({
    this.environment = const [],
    this.set = const [],
    this.light = const [],
    this.shot = const [],
    this.lightSetup,
  });

  /// Todo lo que se ve, en orden de pintado.
  List<PlanElement> get all => [...environment, ...set, ...light, ...shot];
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
        await db.updateLightSetup(
          setup.copyWith(planJson: Value(_reencode(setup.planJson, elements))),
        );
      case FloorPlanScope.shot:
        if (shotId == null) return;
        await _replaceShotElements(shotId, elements);
    }
  }

  /// Cambia los elementos conservando la escala y el fondo de la capa.
  String _reencode(String? previousJson, List<PlanElement> elements) {
    final previous = FloorPlanJson.decodeDocument(previousJson);
    return FloorPlanJson.encodeDocument(
      FloorPlanDocument(
        elements: elements,
        metersPerUnit: previous.metersPerUnit,
        underlay: previous.underlay,
        ambient: previous.ambient,
      ),
    );
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
        return _baseLayers(
          setId: setup.locationBasePlanId,
          siteId: setup.locationSiteId,
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
          light: layers.light,
          lightSetup: layers.lightSetup,
        );
    }
  }

  /// Todas las capas de un plano: entorno, set, esquema de luz y lo propio.
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
    );
    // En una secuencia, cada tramo ve solo lo que se colocó en él.
    final own = await _shotElements(shot.id);
    final legIndex = route.isEmpty ? null : (leg ?? 0);
    return PlanLayers(
      environment: base.environment,
      set: base.set,
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
    );
  }

  /// Tramo de la secuencia en el que está un elemento propio del plano.
  static const legKey = 'leg';
  static int legOf(PlanElement el) => (el.props[legKey] as num?)?.toInt() ?? 0;

  /// Elementos que se ven en un plano, ya aplanados. Para PDF y exportadores.
  Future<List<PlanElement>> resolvedElementsForShot(Shot shot) async =>
      (await layersForShot(shot)).all;

  Future<PlanLayers> _baseLayers({int? setId, int? siteId}) async {
    final set = setId != null ? await db.getLocationById(setId) : null;
    return PlanLayers(
      environment: await _environment(set?.siteId ?? siteId),
      set: FloorPlanJson.decode(set?.floorPlanJson),
    );
  }

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
    final doc = FloorPlanJson.decodeDocument(setup.planJson);
    await db.updateLightSetup(
      setup.copyWith(
        planJson: Value(
          FloorPlanJson.encodeDocument(
            FloorPlanDocument(
              elements: doc.elements,
              metersPerUnit: doc.metersPerUnit,
              underlay: doc.underlay,
              ambient: ambient.toJson(),
            ),
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
        planJson: Value(source.planJson),
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

  /// Esquemas que puede usar un plano: los de su set, los de su localización
  /// y las plantas libres.
  Future<List<LightSetup>> lightSetupsForScene(Scene scene) async {
    final all = await db.getLightSetupsForProject(scene.projectId);
    int? siteId = scene.locationSiteId;
    if (siteId == null && scene.locationId != null) {
      siteId = (await db.getLocationById(scene.locationId!))?.siteId;
    }
    return all.where((s) {
      // Los bocetos no llevan planos.
      if (s.kind != LightSetupKind.plan) return false;
      if (s.locationBasePlanId != null) {
        return s.locationBasePlanId == scene.locationId;
      }
      if (s.locationSiteId != null) return s.locationSiteId == siteId;
      return true;
    }).toList();
  }

  /// ¿Tiene el plano algo propio o heredado que enseñar?
  static bool hasLights(Iterable<PlanElement> elements) =>
      elements.any((e) => e.type == ElementType.light);
}
