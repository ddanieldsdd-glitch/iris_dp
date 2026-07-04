import '../../core/database/app_database.dart';
import 'camera_plan_element_model.dart';
import 'floor_plan_json.dart';
import 'floor_plan_scope.dart';

/// Resuelve y persiste planos en los tres niveles de la jerarquía.
class FloorPlanRepository {
  final AppDatabase db;

  FloorPlanRepository(this.db);

  Future<List<PlanElement>> loadElements({
    required FloorPlanScope scope,
    int? siteId,
    int? setId,
    int? shotId,
  }) async {
    switch (scope) {
      case FloorPlanScope.site:
        final site = siteId != null ? await db.getSiteById(siteId) : null;
        return FloorPlanJson.decode(site?.floorPlanJson);
      case FloorPlanScope.set:
        final set = setId != null ? await db.getLocationById(setId) : null;
        return FloorPlanJson.decode(set?.floorPlanJson);
      case FloorPlanScope.shot:
        if (shotId == null) return [];
        final rows = await db.getCameraPlanElementsForShot(shotId);
        final elements = <PlanElement>[];
        for (final row in rows) {
          final pathRows = await db.getPathPointsForElement(row.id);
          elements.add(PlanElement.fromDb(row, pathRows: pathRows));
        }
        return elements;
    }
  }

  Future<void> saveElements({
    required FloorPlanScope scope,
    required List<PlanElement> elements,
    int? siteId,
    int? setId,
    int? shotId,
  }) async {
    switch (scope) {
      case FloorPlanScope.site:
        if (siteId == null) return;
        await db.saveFloorPlanToSite(siteId, FloorPlanJson.encode(elements));
      case FloorPlanScope.set:
        if (setId == null) return;
        await db.saveFloorPlanToSet(setId, FloorPlanJson.encode(elements));
      case FloorPlanScope.shot:
        if (shotId == null) return;
        await _replaceShotElements(shotId, elements);
    }
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

  /// Plantilla para un plano: set → sitio (fallback).
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

  Future<bool> seedShotFromSceneTemplate(int shotId, Scene scene) async {
    final json = await resolveTemplateJsonForScene(scene);
    if (json == null) return false;
    final elements = FloorPlanJson.decode(json);
    await _replaceShotElements(shotId, elements);
    return true;
  }

  bool hasStoredPlan(
    FloorPlanScope scope, {
    String? json,
    int elementCount = 0,
  }) {
    return switch (scope) {
      FloorPlanScope.site || FloorPlanScope.set =>
        json != null && json.isNotEmpty,
      FloorPlanScope.shot => elementCount > 0,
    };
  }
}
