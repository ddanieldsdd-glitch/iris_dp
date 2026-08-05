import 'dart:convert';

import 'package:flutter/material.dart';

import 'scene_color.dart';

/// Normaliza el nombre de personaje para claves consistentes.
String characterColorKey(String name) => name.trim().toUpperCase();

const _manualCharacterLinesKey = '_manualCharacterLines';
const _lineTextOverridesKey = '_lineTextOverrides';

Map<String, String> decodeCharacterColors(String? json) {
  if (json == null || json.trim().isEmpty) return {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return {};
    return {
      for (final entry in decoded.entries)
        if (entry.key is String &&
            !entry.key.toString().startsWith('_') &&
            entry.value is String &&
            entry.value.toString().trim().isNotEmpty)
          characterColorKey(entry.key as String): entry.value as String,
    };
  } catch (_) {
    return {};
  }
}

Set<String> decodeManualCharacterLines(String? json) {
  if (json == null || json.trim().isEmpty) return {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return {};
    final raw = decoded[_manualCharacterLinesKey];
    if (raw is! List) return {};
    return raw
        .whereType<String>()
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet();
  } catch (_) {
    return {};
  }
}

Map<String, String> decodeLineTextOverrides(String? json) {
  if (json == null || json.trim().isEmpty) return {};
  try {
    final decoded = jsonDecode(json);
    if (decoded is! Map) return {};
    final raw = decoded[_lineTextOverridesKey];
    if (raw is! Map) return {};
    return {
      for (final entry in raw.entries)
        if (entry.key is String && entry.value is String)
          entry.key as String: entry.value as String,
    };
  } catch (_) {
    return {};
  }
}

String? encodeCharacterColors(
  Map<String, String> colors, {
  Set<String>? manualCharacterLines,
  Map<String, String>? lineTextOverrides,
}) {
  final cleaned = <String, String>{};
  for (final entry in colors.entries) {
    final key = characterColorKey(entry.key);
    final hex = entry.value.trim();
    if (key.isEmpty || hex.isEmpty) continue;
    cleaned[key] = hex;
  }

  final manual = manualCharacterLines
          ?.map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false) ??
      const <String>[];
  final overrides = <String, String>{};
  lineTextOverrides?.forEach((key, value) {
    final k = key.trim();
    final v = value.trim();
    if (k.isNotEmpty && v.isNotEmpty && k != v) {
      overrides[k] = v;
    }
  });

  if (cleaned.isEmpty && manual.isEmpty && overrides.isEmpty) return null;

  final payload = <String, dynamic>{...cleaned};
  if (manual.isNotEmpty) {
    payload[_manualCharacterLinesKey] = manual;
  }
  if (overrides.isNotEmpty) {
    payload[_lineTextOverridesKey] = overrides;
  }
  return jsonEncode(payload);
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
