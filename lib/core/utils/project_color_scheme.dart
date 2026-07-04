import 'package:flutter/material.dart';

import '../database/app_database.dart';
import 'scene_color.dart';

/// Colores unificados del proyecto: localización (base) → set (variante) → escena.
class ProjectColorScheme {
  final Map<int, Color> _siteBaseById;
  final Map<String, Color> _orphanSiteBaseByKey;
  final Map<int, Color> _setColorById;
  final Map<String, LocationBasePlan> _setByNameLower;
  final Map<String, String> _pendingSetColors;

  ProjectColorScheme._({
    required Map<int, Color> siteBaseById,
    required Map<String, Color> orphanSiteBaseByKey,
    required Map<int, Color> setColorById,
    required Map<String, LocationBasePlan> setByNameLower,
    required Map<String, String> pendingSetColors,
  })  : _siteBaseById = siteBaseById,
        _orphanSiteBaseByKey = orphanSiteBaseByKey,
        _setColorById = setColorById,
        _setByNameLower = setByNameLower,
        _pendingSetColors = pendingSetColors;

  factory ProjectColorScheme({
    required List<LocationSite> sites,
    required List<LocationBasePlan> sets,
    List<Scene>? scenes,
    Map<String, String>? pendingSetColorsByName,
  }) {
    final pending = <String, String>{};
    if (pendingSetColorsByName != null) {
      for (final e in pendingSetColorsByName.entries) {
        pending[e.key.trim().toLowerCase()] = e.value;
      }
    }
    final setByName = {
      for (final s in sets) s.locationName.trim().toLowerCase(): s,
    };

    final sortedSites = [...sites]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    final setsBySite = <int, List<LocationBasePlan>>{};
    final orphanSets = <LocationBasePlan>[];

    for (final set in sets) {
      if (set.siteId == null) {
        orphanSets.add(set);
        continue;
      }
      setsBySite.putIfAbsent(set.siteId!, () => []).add(set);
    }
    for (final list in setsBySite.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    orphanSets.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final siteBaseById = <int, Color>{};
    final setColorById = <int, Color>{};

    for (var i = 0; i < sortedSites.length; i++) {
      final site = sortedSites[i];
      final siteSets = setsBySite[site.id] ?? [];
      final base = _deriveSiteBase(
        siteSets: siteSets,
        siteIndex: i,
        pending: pending,
        scenes: scenes,
        siteId: site.id,
      );
      siteBaseById[site.id] = base;
      _assignSetColors(
        siteSets: siteSets,
        base: base,
        pending: pending,
        setColorById: setColorById,
      );
    }

    var orphanSiteIndex = sortedSites.length;
    for (final set in orphanSets) {
      final hex = _setHex(set, pending);
      final base = locationBlockColor(
        orphanSiteIndex,
        existing: hex != null ? sceneDisplayColor(hex) : null,
      );
      setColorById[set.id] = base;
      orphanSiteIndex++;
    }

    final orphanSiteBaseByKey = <String, Color>{};
    if (scenes != null) {
      final orphanKeys = <String>[];
      for (final scene in scenes) {
        if (scene.locationSiteId != null || scene.locationId != null) continue;
        final key = _orphanSiteKey(scene);
        if (!orphanKeys.contains(key)) orphanKeys.add(key);
      }
      for (var i = 0; i < orphanKeys.length; i++) {
        orphanSiteBaseByKey[orphanKeys[i]] =
            locationBlockColor(sortedSites.length + orphanSets.length + i);
      }
    }

    return ProjectColorScheme._(
      siteBaseById: siteBaseById,
      orphanSiteBaseByKey: orphanSiteBaseByKey,
      setColorById: setColorById,
      setByNameLower: setByName,
      pendingSetColors: pending,
    );
  }

  static String _orphanSiteKey(Scene scene) {
    final pure = scene.locationPureName.trim();
    if (pure.isNotEmpty) return pure.toLowerCase();
    return scene.locationCanonical.trim().toLowerCase();
  }

  static String? _setHex(LocationBasePlan set, Map<String, String> pending) {
    final key = set.locationName.trim().toLowerCase();
    final pendingHex = pending[key];
    if (pendingHex != null && pendingHex.isNotEmpty) return pendingHex;
    if (set.color.isNotEmpty && set.color != kSceneColorNeutral) {
      return set.color;
    }
    return null;
  }

  static Color _deriveSiteBase({
    required List<LocationBasePlan> siteSets,
    required int siteIndex,
    required Map<String, String> pending,
    required List<Scene>? scenes,
    required int siteId,
  }) {
    if (siteSets.isNotEmpty) {
      final hex = _setHex(siteSets.first, pending);
      if (hex != null) {
        return locationBlockColor(siteIndex, existing: sceneDisplayColor(hex));
      }
    }
    if (scenes != null) {
      for (final scene in scenes) {
        if (scene.locationSiteId != siteId) continue;
        final override = persistSceneColor(scene.locationColor);
        if (override != null) {
          return locationBlockColor(
            siteIndex,
            existing: sceneDisplayColor(override),
          );
        }
      }
    }
    return locationBlockColor(siteIndex);
  }

  static void _assignSetColors({
    required List<LocationBasePlan> siteSets,
    required Color base,
    required Map<String, String> pending,
    required Map<int, Color> setColorById,
  }) {
    final count = siteSets.length;
    for (var i = 0; i < count; i++) {
      final hex = _setHex(siteSets[i], pending);
      setColorById[siteSets[i].id] = hex != null
          ? sceneDisplayColor(hex)
          : setVariantColor(base, i, count);
    }
  }

  /// Color base de una localización contenedora.
  Color siteColor(int? siteId, {String? orphanSiteKey}) {
    if (siteId != null) {
      return _siteBaseById[siteId] ?? sceneDisplayColor(null);
    }
    if (orphanSiteKey != null) {
      return _orphanSiteBaseByKey[orphanSiteKey.trim().toLowerCase()] ??
          sceneDisplayColor(null);
    }
    return sceneDisplayColor(null);
  }

  /// Color de un set (variante dentro de su localización).
  Color setColor(LocationBasePlan set) {
    return _setColorById[set.id] ??
        locationBaseColor(sceneDisplayColor(_setHex(set, _pendingSetColors)));
  }

  Color setColorById(int? setId) {
    if (setId == null) return sceneDisplayColor(null);
    return _setColorById[setId] ?? sceneDisplayColor(null);
  }

  /// Color de escena coherente en todas las pantallas.
  Color sceneColor(Scene scene) {
    final override = persistSceneColor(scene.locationColor);
    if (override != null) return sceneDisplayColor(override);

    if (scene.locationId != null) {
      return setColorById(scene.locationId);
    }
    if (scene.locationSiteId != null) {
      return siteColor(scene.locationSiteId);
    }
    return siteColor(null, orphanSiteKey: _orphanSiteKey(scene));
  }

  /// Guion literario / escenas aún no vinculadas por id.
  Color forShootSet(
    String shootSet, {
    String? sceneColorOverride,
    int? locationSiteId,
  }) {
    final override = persistSceneColor(sceneColorOverride);
    if (override != null) return sceneDisplayColor(override);

    final set = _setByNameLower[shootSet.trim().toLowerCase()];
    if (set != null) return setColor(set);

    final pending = _pendingSetColors[shootSet.trim().toLowerCase()];
    if (pending != null && pending.isNotEmpty) {
      return locationBaseColor(sceneDisplayColor(pending));
    }

    if (locationSiteId != null) return siteColor(locationSiteId);
    return sceneDisplayColor(null);
  }

  Map<int, Color> colorsBySourceStartIndex({
    required Iterable<
            ({int? sourceStartIndex, String shootSet, String? sceneColorOverride})>
        scenes,
  }) {
    final map = <int, Color>{};
    for (final s in scenes) {
      if (s.sourceStartIndex == null) continue;
      map[s.sourceStartIndex!] = forShootSet(
        s.shootSet,
        sceneColorOverride: s.sceneColorOverride,
      );
    }
    return map;
  }
}
