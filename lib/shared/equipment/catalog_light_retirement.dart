import 'dart:convert';

import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';

/// Retira del catálogo las luces duplicadas sin romper lo que apuntaba a
/// ellas.
///
/// [into] lleva el `externalId` retirado al que se queda. Lo que el
/// proyecto tenía asignado y las luces de las plantas (planos, esquemas de
/// luz, localizaciones y planos base) pasan a la ficha que se queda; luego
/// se borra la retirada. Las luces propias del usuario no se tocan.
///
/// Devuelve cuántas fichas se retiraron.
Future<int> retireCatalogLights(
  AppDatabase db,
  Map<String, String> into,
) async {
  var removed = 0;
  final touched = <int>{};
  await db.transaction(() async {
    for (final MapEntry(key: oldId, value: newId) in into.entries) {
      final old = await db.getLightByExternalId(oldId);
      final kept = await db.getLightByExternalId(newId);
      if (old == null || old.isCustom || kept == null || kept.id == old.id) {
        continue;
      }
      touched.addAll(await _moveAssignments(db, old.id, kept.id));
      touched.addAll(await _movePlanReferences(db, old.id, kept.id));
      await db.deleteLight(old.id);
      removed++;
    }
  });
  for (final projectId in touched) {
    await db.touchProjectContent(projectId);
  }
  return removed;
}

/// El equipo de cada proyecto: la retirada pasa a ser la que se queda, sin
/// repetirla si el proyecto ya la tenía.
Future<Set<int>> _moveAssignments(AppDatabase db, int from, int to) async {
  final projects = <int>{};
  final rows =
      await (db.select(db.projectEquipment)..where(
            (e) => e.equipmentType.equals('light') & e.equipmentId.equals(from),
          ))
          .get();
  for (final row in rows) {
    projects.add(row.projectId);
    final already =
        await (db.select(db.projectEquipment)..where(
              (e) =>
                  e.projectId.equals(row.projectId) &
                  e.equipmentType.equals('light') &
                  e.equipmentId.equals(to),
            ))
            .get();
    if (already.isNotEmpty) {
      await (db.delete(
        db.projectEquipment,
      )..where((e) => e.id.equals(row.id))).go();
    } else {
      await (db.update(db.projectEquipment)..where((e) => e.id.equals(row.id)))
          .write(ProjectEquipmentCompanion(equipmentId: Value(to)));
    }
  }
  return projects;
}

/// Las luces de las plantas guardan la ficha del catálogo en
/// `catalogLightId`, dentro de su vínculo externo.
Future<Set<int>> _movePlanReferences(AppDatabase db, int from, int to) async {
  final projects = <int>{};
  const marker = '%catalogLightId%';

  final elements = await (db.select(
    db.cameraPlanElements,
  )..where((e) => e.externalMappingJson.like(marker))).get();
  for (final el in elements) {
    final moved = repointCatalogLight(el.externalMappingJson, from, to);
    if (moved == null) continue;
    await (db.update(db.cameraPlanElements)..where((e) => e.id.equals(el.id)))
        .write(CameraPlanElementsCompanion(externalMappingJson: Value(moved)));
    final shot = await (db.select(
      db.shots,
    )..where((s) => s.id.equals(el.shotId))).getSingleOrNull();
    if (shot != null) projects.add(shot.projectId);
  }

  for (final setup in await (db.select(
    db.lightSetups,
  )..where((s) => s.planJson.like(marker))).get()) {
    final moved = repointCatalogLight(setup.planJson, from, to);
    if (moved == null) continue;
    await (db.update(db.lightSetups)..where((s) => s.id.equals(setup.id)))
        .write(LightSetupsCompanion(planJson: Value(moved)));
    projects.add(setup.projectId);
  }

  for (final site in await (db.select(
    db.locationSites,
  )..where((s) => s.floorPlanJson.like(marker))).get()) {
    final moved = repointCatalogLight(site.floorPlanJson, from, to);
    if (moved == null) continue;
    await (db.update(db.locationSites)..where((s) => s.id.equals(site.id)))
        .write(LocationSitesCompanion(floorPlanJson: Value(moved)));
    projects.add(site.projectId);
  }

  for (final plan in await (db.select(
    db.locationBasePlans,
  )..where((p) => p.floorPlanJson.like(marker))).get()) {
    final moved = repointCatalogLight(plan.floorPlanJson, from, to);
    if (moved == null) continue;
    await (db.update(db.locationBasePlans)..where((p) => p.id.equals(plan.id)))
        .write(LocationBasePlansCompanion(floorPlanJson: Value(moved)));
    projects.add(plan.projectId);
  }
  return projects;
}

/// El mismo JSON con cada `catalogLightId` igual a [from] cambiado a [to],
/// o `null` si no había ninguno.
String? repointCatalogLight(String? json, int from, int to) {
  if (json == null || json.isEmpty) return null;
  final Object? data;
  try {
    data = jsonDecode(json);
  } catch (_) {
    return null;
  }
  var changed = false;
  void walk(Object? node) {
    if (node is Map) {
      if (node['catalogLightId'] is num &&
          (node['catalogLightId'] as num).toInt() == from) {
        node['catalogLightId'] = to;
        changed = true;
      }
      node.values.forEach(walk);
    } else if (node is List) {
      node.forEach(walk);
    }
  }

  walk(data);
  return changed ? jsonEncode(data) : null;
}
