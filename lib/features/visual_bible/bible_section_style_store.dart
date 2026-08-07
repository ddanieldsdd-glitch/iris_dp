import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/visual_bible/bible_section_ids.dart';
import 'bible_blueprint.dart';

/// Persistencia de estilo visual por sección (NO usa la columna `template`).
///
/// La columna Drift `template` guarda el **renderer** (`moodboard`,
/// `blocks_lighting`, `freeform`…). El estilo Cinematic/Technical/Minimalist
/// vive aquí.
abstract final class BibleSectionStyleStore {
  static const _prefix = 'iris_bible_section_styles_';

  /// Incrementa al guardar para que las secciones recarguen el estilo.
  static final ValueNotifier<int> revision = ValueNotifier(0);

  static Future<Map<String, BibleSectionStyle>> loadAll(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_prefix$projectId');
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (k, v) => MapEntry(k.toString(), _styleFromKey(v?.toString())),
      );
    } catch (_) {
      return {};
    }
  }

  static Future<BibleSectionStyle> load(
    int projectId,
    String sectionId, {
    BibleBlueprintType? blueprint,
  }) async {
    final all = await loadAll(projectId);
    return all[sectionId] ??
        defaultStyleForSection(
          sectionId,
          blueprint ?? BibleBlueprintType.fiction,
        );
  }

  static Future<void> save(
    int projectId,
    String sectionId,
    BibleSectionStyle style,
  ) async {
    final all = await loadAll(projectId);
    all[sectionId] = style;
    await _persist(projectId, all);
  }

  static Future<void> saveMany(
    int projectId,
    Map<String, BibleSectionStyle> styles,
  ) async {
    final all = await loadAll(projectId);
    all.addAll(styles);
    await _persist(projectId, all);
  }

  static Future<void> _persist(
    int projectId,
    Map<String, BibleSectionStyle> all,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_prefix$projectId',
      jsonEncode(all.map((k, v) => MapEntry(k, v.storageKey))),
    );
    revision.value++;
  }

  static BibleSectionStyle _styleFromKey(String? key) =>
      BibleSectionStyle.values.firstWhere(
        (e) => e.name == key,
        orElse: () => BibleSectionStyle.cinematic,
      );
}

/// Renderer keys válidos en columna `template` (no confundir con estilo).
abstract final class BibleSectionRenderer {
  static const freeform = 'freeform';
  static const standard = 'standard';
  static const locations = 'locations';
  static const tests = 'tests';
  static const moodboard = 'moodboard';
  static const blocksColor = 'blocks_color';
  static const blocksExposure = 'blocks_exposure';
  static const blocksLighting = 'blocks_lighting';

  static const aestheticNames = {'cinematic', 'technical', 'minimalist'};

  static bool isCorruptedAesthetic(String template) =>
      aestheticNames.contains(template);

  static String builtinFor(String sectionId) => switch (sectionId) {
        BibleSectionId.location => locations,
        BibleSectionId.cameraTests => tests,
        BibleSectionId.moodboard => moodboard,
        BibleSectionId.workflow => standard,
        BibleSectionId.colorImage => blocksColor,
        BibleSectionId.exposure => blocksExposure,
        BibleSectionId.lighting => blocksLighting,
        _ => standard,
      };

  static String label(String template) => switch (template) {
        freeform => 'Libre (widgets)',
        locations => 'Localizaciones',
        tests => 'Pruebas',
        moodboard => 'Moodboard',
        blocksColor => 'Color / bloques',
        blocksExposure => 'Exposición / bloques',
        blocksLighting => 'Iluminación / bloques',
        standard => 'Estándar',
        _ => template,
      };
}
