import 'dart:convert';

import 'package:flutter/material.dart';

import 'scene_color.dart';

/// Normaliza el nombre de personaje para claves consistentes.
String characterColorKey(String name) => name.trim().toUpperCase();

Map<String, String> decodeCharacterColors(String? json) {
  if (json == null || json.trim().isEmpty) return {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return {};
    return {
      for (final entry in decoded.entries)
        if (entry.key is String &&
            entry.value is String &&
            entry.value.toString().trim().isNotEmpty)
          characterColorKey(entry.key as String): entry.value as String,
    };
  } catch (_) {
    return {};
  }
}

String? encodeCharacterColors(Map<String, String> colors) {
  if (colors.isEmpty) return null;
  final cleaned = <String, String>{};
  for (final entry in colors.entries) {
    final key = characterColorKey(entry.key);
    final hex = entry.value.trim();
    if (key.isEmpty || hex.isEmpty) continue;
    cleaned[key] = hex;
  }
  if (cleaned.isEmpty) return null;
  return jsonEncode(cleaned);
}

Color characterDisplayColor(String? hex, {int? characterIndex}) {
  if (hex != null && hex.isNotEmpty) {
    return sceneDisplayColor(hex);
  }
  if (characterIndex != null) {
    return sceneDisplayColor(defaultSceneColorForIndex(characterIndex));
  }
  return sceneDisplayColor(kSceneColorNeutral);
}

/// Asigna colores por defecto a personajes nuevos, preservando los existentes.
Map<String, String> buildDefaultCharacterColors(
  Iterable<String> names, {
  Map<String, String>? preserve,
}) {
  final result = <String, String>{};
  if (preserve != null) {
    result.addAll(preserve);
  }

  final sorted = names
      .map(characterColorKey)
      .where((name) => name.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  var colorIndex = result.length;
  for (final name in sorted) {
    if (result.containsKey(name)) continue;
    result[name] = defaultSceneColorForIndex(colorIndex);
    colorIndex++;
  }

  return result;
}
