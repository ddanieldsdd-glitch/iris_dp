import 'dart:convert';

import 'bible_section_fields.dart';

/// Resolución del modo de sensor en Format (P3): catálogo PHFX ↔ blob formatData.
///
/// Clave canónica: [nameKey] (`sensorModeName`).
/// [legacyRatioKey] (`sensorMode`) sigue usándose como token de ratio para el
/// cálculo de `activeRatio` (compat con datos viejos tipo `4:3`).
abstract final class FormatSensorModeResolve {
  FormatSensorModeResolve._();

  static const nameKey = 'sensorModeName';
  static const legacyRatioKey = 'sensorMode';
  static const detailKey = 'sensorDetail';

  static String? modeName(Map<String, dynamic> blob) {
    final name = blob[nameKey]?.toString().trim();
    if (name != null && name.isNotEmpty) return name;
    return null;
  }

  /// Lee el nombre canónico desde `contentJson` de la sección Format.
  static String? modeNameFromSectionContentJson(String? contentJson) {
    final values = BibleSectionFieldsConfig.parseValues(contentJson);
    final raw = values['formatData'];
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      return modeName(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  /// Título UI: nombre PHFX si existe; si no, ratio legacy.
  static String displayTitle(Map<String, dynamic> blob) =>
      modeName(blob) ??
      (blob[legacyRatioKey]?.toString().trim().isNotEmpty == true
          ? blob[legacyRatioKey].toString().trim()
          : '4:3');

  static String displayDetail(Map<String, dynamic> blob) {
    final detail = blob[detailKey]?.toString().trim();
    if (detail != null && detail.isNotEmpty) return detail;
    return modeName(blob) != null ? 'Modo de catálogo' : 'Open Gate';
  }

  /// Token para [_parseRatio] / sync de activeRatio.
  static String ratioTokenForCalc(
    Map<String, dynamic> blob, {
    String? aspectRatio,
    double? widthMm,
    double? heightMm,
  }) {
    final aspect = aspectRatio?.trim();
    if (aspect != null && aspect.isNotEmpty) return aspect;
    if (widthMm != null && heightMm != null && heightMm > 0) {
      return '${widthMm.toStringAsFixed(4)}:${heightMm.toStringAsFixed(4)}';
    }
    final legacy = blob[legacyRatioKey]?.toString().trim();
    if (legacy != null && legacy.isNotEmpty) return legacy;
    return '4:3';
  }

  static String detailForMode({
    required String name,
    int? widthPx,
    int? heightPx,
    double? widthMm,
    double? heightMm,
  }) {
    final parts = <String>[];
    if (widthPx != null &&
        heightPx != null &&
        widthPx > 0 &&
        heightPx > 0) {
      parts.add('$widthPx×$heightPx');
    }
    if (widthMm != null && heightMm != null) {
      parts.add(
        '${widthMm.toStringAsFixed(1)}×${heightMm.toStringAsFixed(1)} mm',
      );
    }
    return parts.isEmpty ? name : parts.join(' · ');
  }

  /// Payload blob al elegir un modo de catálogo (sin tocar resolution/captureResolution).
  static Map<String, dynamic> blobUpdateForMode({
    required String name,
    String? aspectRatio,
    int? widthPx,
    int? heightPx,
    double? widthMm,
    double? heightMm,
  }) {
    final ratio = ratioTokenForCalc(
      const {},
      aspectRatio: aspectRatio,
      widthMm: widthMm,
      heightMm: heightMm,
    );
    return {
      nameKey: name,
      legacyRatioKey: ratio,
      detailKey: detailForMode(
        name: name,
        widthPx: widthPx,
        heightPx: heightPx,
        widthMm: widthMm,
        heightMm: heightMm,
      ),
    };
  }
}
