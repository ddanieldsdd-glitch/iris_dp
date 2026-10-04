import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'floor_plan_json.dart';
import 'floor_plan_scope.dart';

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
      ),
    );
  }

  Future<void> _replaceShotElements(
    int shotId,
    List<PlanElement> elements,
  ) async {
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
  Future<PlanLayers> layersForShot(Shot shot) async {
    final scene = await (db.select(
      db.scenes,
    )..where((s) => s.id.equals(shot.sceneId))).getSingleOrNull();
    final setup = shot.lightSetupId != null
        ? await db.getLightSetupById(shot.lightSetupId!)
        : null;
    final base = await _baseLayers(
      setId: scene?.locationId ?? setup?.locationBasePlanId,
      siteId: scene?.locationSiteId ?? setup?.locationSiteId,
    );
    return PlanLayers(
      environment: base.environment,
      set: base.set,
      light: FloorPlanJson.decode(setup?.planJson),
      shot: await _shotElements(shot.id),
      lightSetup: setup,
    );
  }

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

  // ── Esquemas de luz ───────────────────────────────────────────────────────

  /// Crea un esquema de luz. Sin set ni localización es una planta libre.
  Future<LightSetup> createLightSetup({
    required int projectId,
    String? name,
    int? setId,
    int? siteId,
    String status = 'boceto',
    String origin = 'planta',
  }) async {
    final existing = (await db.getLightSetupsForProject(projectId))
        .where(
          (s) => s.locationBasePlanId == setId && s.locationSiteId == siteId,
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
      ),
    );
    return (await db.getLightSetupById(id))!;
  }

  /// Copia un esquema para hacer una variante.
  Future<LightSetup> duplicateLightSetup(LightSetup source) async {
    final siblings = (await db.getLightSetupsForProject(source.projectId))
        .where(
          (s) =>
              s.locationBasePlanId == source.locationBasePlanId &&
              s.locationSiteId == source.locationSiteId,
        )
        .toList();
    final id = await db.insertLightSetup(
      LightSetupsCompanion.insert(
        projectId: source.projectId,
        locationBasePlanId: Value(source.locationBasePlanId),
        locationSiteId: Value(source.locationSiteId),
        name: '${source.name} (copia)',
        status: Value(source.status),
        origin: const Value('planta'),
        category: Value(source.category),
        planJson: Value(source.planJson),
        sketchJson: Value(source.sketchJson),
        sketchImagePath: Value(source.sketchImagePath),
        sortOrder: Value(siblings.length),
      ),
    );
    return (await db.getLightSetupById(id))!;
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
