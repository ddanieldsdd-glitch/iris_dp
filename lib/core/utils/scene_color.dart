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

/// Color de escena dentro del bloque: hereda del set o de la localización.
Color sceneBlockColor({
  required Color locationBase,
  int? setIndex,
  int setCount = 1,
  String? sceneColorOverride,
}) {
  final override = persistSceneColor(sceneColorOverride);
  if (override != null) return sceneDisplayColor(override);
  if (setIndex != null) {
    return setVariantColor(locationBase, setIndex, setCount);
  }
  return locationBaseColor(locationBase);
}

/// Color efectivo: override de escena → color de localización → neutro.
Color effectiveSceneColor({
  String? sceneColorOverride,
  String? locationColor,
}) {
  final override = persistSceneColor(sceneColorOverride);
  if (override != null) return sceneDisplayColor(override);
  if (locationColor != null && locationColor.isNotEmpty) {
    return sceneDisplayColor(locationColor);
  }
  return sceneDisplayColor(null);
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
