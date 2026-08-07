import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../../core/database/app_database.dart';
import 'visual_bible_model.dart';

/// Sincroniza dominios técnicos compartidos entre secciones de la biblia.
abstract final class BibleTechSync {
  BibleTechSync._();

  /// Kelvin canónico desde string tipo "3200K" o "3200".
  static int? parseKelvin(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final digits = RegExp(r'(\d{3,5})').firstMatch(raw);
    if (digits == null) return null;
    return int.tryParse(digits.group(1)!);
  }

  static String formatKelvin(int kelvin) => '${kelvin}K';

  /// Lighting / Color → lightSource + color blocks opcional.
  static void applyKelvinToData(
    VisualBibleData data,
    int kelvin, {
    ColorBlockModel? activeColorBlock,
  }) {
    data.lightSource = formatKelvin(kelvin);
    if (activeColorBlock != null) {
      activeColorBlock.colorTempKelvin = kelvin;
    }
  }

  /// Contraste / key:fill desde lighting.
  static void applyContrastRatio(
    VisualBibleData data, {
    required String ratio,
    bool night = true,
  }) {
    data.contrastStyle = 'High contrast $ratio';
    if (night) {
      data.keyFillRatioNight = ratio;
    } else {
      data.keyFillRatioDay = ratio;
    }
  }

  /// Texture escribe grain; Concept solo lee data.grainLevel.
  static void applyGrain(VisualBibleData data, String grainLabel) {
    data.grainLevel = grainLabel;
  }

  /// Highlight / shadow strategies compartidas.
  static void applyExposureIntent(
    VisualBibleData data, {
    String? highlights,
    String? shadows,
  }) {
    if (highlights != null && highlights.trim().isNotEmpty) {
      data.highlightBehavior = highlights.trim();
    }
    if (shadows != null && shadows.trim().isNotEmpty) {
      data.shadowBehavior = shadows.trim();
    }
  }

  /// LUT creativo solo vive en Color (no Concept).
  static void applyCreativeLut(VisualBibleData data, String? name) {
    data.creativeLutName =
        name == null || name.trim().isEmpty ? null : name.trim();
  }

  /// Persiste color block tras sync de Kelvin.
  static Future<void> persistColorBlock(
    AppDatabase db,
    ColorBlockModel model,
  ) async {
    final row = await (db.select(db.visualBibleColorBlocks)
          ..where((t) => t.id.equals(model.id)))
        .getSingleOrNull();
    if (row == null) return;
    await db.updateColorBlock(
      row.copyWith(
        colorTempKelvin: Value(model.colorTempKelvin),
        dominantColors: jsonEncode(model.dominantColors),
      ),
    );
  }
}
