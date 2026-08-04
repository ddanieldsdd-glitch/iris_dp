import 'package:flutter/material.dart';

/// Color por defecto de escenas recién detectadas (sin agrupar aún).
const kSceneColorNeutral = '#94A3B8';

/// Paleta para asignación manual o futura agrupación por localización.
const kSceneColorPalette = [
  '#E63946',
  '#F4A261',
  '#E9C46A',
  '#2A9D8F',
  '#264653',
  '#6366F1',
  '#EC4899',
  '#14B8A6',
  '#F97316',
  '#8B5CF6',
];

Color? colorFromHex(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var value = hex.replaceFirst('#', '');
  if (value.length == 6) value = 'FF$value';
  if (value.length != 8) return null;
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) return null;
  return Color(parsed);
}

String hexFromColor(Color color) {
  return '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
}

String defaultSceneColorForIndex(int index) {
  if (index < 0) return kSceneColorPalette.first;
  return kSceneColorPalette[index % kSceneColorPalette.length];
}

/// Color efectivo en UI: null o vacío → neutro.
Color sceneDisplayColor(String? hex, {int? sceneNumber}) {
  return colorFromHex(hex?.isNotEmpty == true ? hex : null) ??
      colorFromHex(kSceneColorNeutral)!;
}

/// Normaliza un color a la referencia de «localización» (misma tonalidad, S/L base).
Color locationBaseColor(Color color) {
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withSaturation(hsl.saturation.clamp(0.45, 0.72))
      .withLightness(0.46)
      .toColor();
}

/// Color base de localización por índice o color existente del grupo.
Color locationBlockColor(int locationIndex, {Color? existing}) {
  if (existing != null) return locationBaseColor(existing);
  return locationBaseColor(
    colorFromHex(defaultSceneColorForIndex(locationIndex))!,
  );
}

/// Variante de set dentro de un bloque: misma tonalidad, distinta S/L.
Color setVariantColor(Color locationBase, int setIndex, int setCount) {
  final base = locationBaseColor(locationBase);
  if (setCount <= 1) return base;
  final t = setIndex / (setCount - 1);
  final hsl = HSLColor.fromColor(base);
  final sat = (0.38 + t * 0.44).clamp(0.0, 1.0);
  final light = (0.34 + t * 0.26).clamp(0.0, 1.0);
  return hsl.withSaturation(sat).withLightness(light).toColor();
}

/// Hex del color base de una localización por índice global.
String siteBaseHexForIndex(int siteIndex, {String? existingHex}) {
  final existing = existingHex != null ? sceneDisplayColor(existingHex) : null;
  return hexFromColor(locationBlockColor(siteIndex, existing: existing));
}

/// Hex por defecto de un set dentro de su localización.
String defaultSetHexForSite({
  required int siteIndex,
  required int setIndex,
  required int totalSets,
  String? explicitHex,
}) {
  if (explicitHex != null && explicitHex.isNotEmpty) {
    return sceneColorForPicker(explicitHex);
  }
  final base = colorFromHex(siteBaseHexForIndex(siteIndex))!;
  return hexFromColor(setVariantColor(base, setIndex, totalSets));
}

/// Variantes hex de todos los sets de una localización a partir de un color base.
List<String> setVariantHexesForSiteBase(String baseHex, int setCount) {
  if (setCount <= 0) return const [];
  final base = locationBaseColor(sceneDisplayColor(baseHex));
  return [
    for (var i = 0; i < setCount; i++)
      hexFromColor(setVariantColor(base, i, setCount)),
  ];
}

/// Mapa site|set → hex para el workspace de importación.
Map<String, String> pendingSetColorsForSite({
  required String locationSite,
  required Iterable<String> setNames,
  required int siteIndex,
  required String baseHex,
}) {
  final siteKey = locationSite.trim().toLowerCase();
  final sorted = setNames
      .map((name) => name.trim().toLowerCase())
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
  final base = locationBaseColor(sceneDisplayColor(baseHex));
  return {
    for (var i = 0; i < sorted.length; i++)
      '$siteKey|${sorted[i]}':
          hexFromColor(setVariantColor(base, i, sorted.length)),
  };
}

/// Normaliza al guardar: el neutro se persiste como null (sin color asignado).
String? persistSceneColor(String? hex) {
  if (hex == null || hex.isEmpty || hex.toUpperCase() == kSceneColorNeutral) {
    return null;
  }
  return hex;
}

/// Valor para el selector cuando la escena no tiene color propio.
String sceneColorForPicker(String? hex) {
  if (hex == null || hex.isEmpty) return kSceneColorNeutral;
  return hex;
}

/// Clave compuesta site|set para colores pendientes en el workspace de import.
String setColorKey(String siteName, String setName) =>
    '${siteName.trim().toLowerCase()}|${setName.trim().toLowerCase()}';

/// Resuelve color pendiente por site+set, con fallback al nombre de set solo.
String? pendingSetColorHex(
  Map<String, String> pending, {
  required String shootSet,
  String? locationSite,
}) {
  if (locationSite != null && locationSite.trim().isNotEmpty) {
    final composite = pending[setColorKey(locationSite, shootSet)];
    if (composite != null && composite.isNotEmpty) return composite;
  }
  return pending[shootSet.trim().toLowerCase()];
}

/// Asigna un color base distinto por localización y variantes por set.
Map<String, String> buildPendingSetColorsFromScenes(
  Iterable<({String locationSite, String shootSet})> scenes, {
  Map<String, String>? preserve,
}) {
  final result = <String, String>{};
  if (preserve != null) {
    result.addAll(preserve);
  }

  final siteOrder = <String>[];
  final setsBySite = <String, List<String>>{};

  for (final scene in scenes) {
    final setName = scene.shootSet.trim();
    if (setName.isEmpty) continue;

    final siteName = scene.locationSite.trim().isEmpty
        ? setName
        : scene.locationSite.trim();
    final siteKey = siteName.toLowerCase();
    if (!siteOrder.contains(siteKey)) siteOrder.add(siteKey);

    final setKey = setName.toLowerCase();
    final list = setsBySite.putIfAbsent(siteKey, () => []);
    if (!list.contains(setKey)) list.add(setKey);
  }

  for (var siteIdx = 0; siteIdx < siteOrder.length; siteIdx++) {
    final siteKey = siteOrder[siteIdx];
    final setKeys = setsBySite[siteKey]!..sort();
    final assigned = pendingSetColorsForSite(
      locationSite: siteKey,
      setNames: setKeys,
      siteIndex: siteIdx,
      baseHex: siteBaseHexForIndex(siteIdx),
    );
    for (final entry in assigned.entries) {
      if (result.containsKey(entry.key)) continue;
      result[entry.key] = entry.value;
    }
  }

  return result;
}
