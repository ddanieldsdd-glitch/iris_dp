import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/project_color_scheme.dart';
import 'camera_plan_scene_badge.dart';

/// Jerarquía: localización → sets → escenas/planos.
class CameraPlanHierarchy {
  final int? siteId;
  final String siteName;
  final Color accentColor;
  final String? siteFloorPlanJson;
  final List<SetPlanNode> sets;
  final List<Scene> unassignedScenes;

  const CameraPlanHierarchy({
    required this.siteId,
    required this.siteName,
    required this.accentColor,
    this.siteFloorPlanJson,
    required this.sets,
    required this.unassignedScenes,
  });

  int get sceneCount =>
      sets.fold<int>(0, (n, s) => n + s.scenes.length) + unassignedScenes.length;
}

class SetPlanNode {
  final LocationBasePlan set;
  final List<Scene> scenes;

  const SetPlanNode({required this.set, required this.scenes});

  String? get floorPlanJson => set.floorPlanJson;

  bool get hasPlan =>
      floorPlanJson != null && floorPlanJson!.isNotEmpty;
}

List<CameraPlanHierarchy> buildCameraPlanHierarchy({
  required List<Scene> scenes,
  required List<LocationSite> sites,
  required List<LocationBasePlan> allSets,
  required ProjectColorScheme colors,
}) {
  final sitesById = {for (final s in sites) s.id: s};
  final setsBySite = <int, List<LocationBasePlan>>{};
  for (final set in allSets) {
    if (set.siteId == null) continue;
    setsBySite.putIfAbsent(set.siteId!, () => []).add(set);
  }
  for (final list in setsBySite.values) {
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  final orderedKeys = <String>[];
  final siteScenes = <String, List<Scene>>{};

  for (final scene in scenes) {
    final site = scene.locationSiteId != null
        ? sitesById[scene.locationSiteId]
        : null;
    final siteName = site?.name ??
        (scene.locationPureName.trim().isNotEmpty
            ? scene.locationPureName.trim()
            : 'Sin localización');
    final key = site != null ? site.id.toString() : siteName.toLowerCase();
    siteScenes.putIfAbsent(key, () => []);
    if (!orderedKeys.contains(key)) orderedKeys.add(key);
    siteScenes[key]!.add(scene);
  }

  return orderedKeys.map((key) {
    final groupScenes = siteScenes[key]!;
    final first = groupScenes.first;
    final site = first.locationSiteId != null
        ? sitesById[first.locationSiteId]
        : null;
    final siteName = site?.name ??
        (first.locationPureName.trim().isNotEmpty
            ? first.locationPureName.trim()
            : 'Sin localización');

    final siteSets = site != null ? (setsBySite[site.id] ?? []) : <LocationBasePlan>[];
    final scenesBySet = <int?, List<Scene>>{};
    for (final scene in groupScenes) {
      scenesBySet.putIfAbsent(scene.locationId, () => []).add(scene);
    }

    final setNodes = siteSets
        .map(
          (set) => SetPlanNode(
            set: set,
            scenes: scenesInScriptOrder(scenesBySet[set.id] ?? []),
          ),
        )
        .toList();

    final assignedSetIds = siteSets.map((s) => s.id).toSet();
    final orphanFromSets = scenesBySet.entries
        .where((e) => e.key != null && !assignedSetIds.contains(e.key))
        .expand((e) => e.value)
        .toList();
    final unassigned = scenesInScriptOrder([
      ...?scenesBySet[null],
      ...orphanFromSets,
    ]);

    final accent = site != null
        ? colors.siteColor(site.id)
        : colors.siteColor(null, orphanSiteKey: siteName);

    return CameraPlanHierarchy(
      siteId: site?.id,
      siteName: siteName,
      accentColor: accent,
      siteFloorPlanJson: site?.floorPlanJson,
      sets: setNodes,
      unassignedScenes: unassigned,
    );
  }).toList();
}

/// Escenas en orden de guion (sortOrder, luego número).
List<Scene> scenesInScriptOrder(List<Scene> scenes) {
  final copy = [...scenes];
  copy.sort((a, b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    if (byOrder != 0) return byOrder;
    return a.number.compareTo(b.number);
  });
  return copy;
}

/// Clave estable para anclar scroll a una localización.
String cameraPlanLocationKey({required int? siteId, required String siteName}) =>
    siteId?.toString() ?? siteName.trim().toLowerCase();

class NavLocationGroup {
  final String siteName;
  final Color accentColor;
  final List<CameraPlanNavTarget> targets;

  const NavLocationGroup({
    required this.siteName,
    required this.accentColor,
    required this.targets,
  });
}

List<NavLocationGroup> groupNavTargetsBySite(List<CameraPlanNavTarget> targets) {
  final orderedKeys = <String>[];
  final groups = <String, NavLocationGroup>{};

  for (final target in targets) {
    final key = target.siteName.toLowerCase();
    if (!groups.containsKey(key)) {
      orderedKeys.add(key);
      groups[key] = NavLocationGroup(
        siteName: target.siteName,
        accentColor: target.sceneColor,
        targets: [target],
      );
    } else {
      final existing = groups[key]!;
      groups[key] = NavLocationGroup(
        siteName: existing.siteName,
        accentColor: existing.accentColor,
        targets: [...existing.targets, target],
      );
    }
  }

  return orderedKeys.map((k) => groups[k]!).toList();
}
