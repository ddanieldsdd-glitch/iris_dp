import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/database/app_database.dart';
import '../../shared/visual_bible/bible_section_ids.dart';
import '../../shared/visual_bible/moodboard_association.dart';
import 'moodboard_reference_meta.dart';
import 'visual_bible_model.dart';

/// Claves del catálogo cinematográfico editable por proyecto.
enum MoodboardCatalogKey {
  intExt,
  timeOfDay,
  lightingLook,
  lightSource,
  lightTexture,
  composition,
  colorMood,
}

/// Opciones custom del catálogo (SharedPreferences por proyecto).
class MoodboardProjectCatalog {
  final Map<MoodboardCatalogKey, List<String>> customByKey;

  const MoodboardProjectCatalog({this.customByKey = const {}});

  List<String> customFor(MoodboardCatalogKey key) =>
      customByKey[key] ?? const [];
}

/// Catálogo + marcadores de pantalla: fuente única moodboard ↔ biblia ↔ PDF.
abstract final class MoodboardCatalogService {
  static String _prefsKey(int projectId) =>
      'iris_moodboard_catalog_$projectId';

  static const _keyNames = {
    MoodboardCatalogKey.intExt: 'intExt',
    MoodboardCatalogKey.timeOfDay: 'timeOfDay',
    MoodboardCatalogKey.lightingLook: 'lightingLook',
    MoodboardCatalogKey.lightSource: 'lightSource',
    MoodboardCatalogKey.lightTexture: 'lightTexture',
    MoodboardCatalogKey.composition: 'composition',
    MoodboardCatalogKey.colorMood: 'colorMood',
  };

  static List<String> _defaults(MoodboardCatalogKey key) => switch (key) {
        MoodboardCatalogKey.intExt => kMoodboardIntExt,
        MoodboardCatalogKey.timeOfDay => kMoodboardTimesOfDay,
        MoodboardCatalogKey.lightingLook => kMoodboardLightingLooks,
        MoodboardCatalogKey.lightSource => kMoodboardLightSources,
        MoodboardCatalogKey.lightTexture => kMoodboardLightTextures,
        MoodboardCatalogKey.composition => kMoodboardCompositions,
        MoodboardCatalogKey.colorMood => kMoodboardColorMoods,
      };

  static Future<MoodboardProjectCatalog> loadForProject(int projectId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey(projectId));
    if (raw == null || raw.isEmpty) return const MoodboardProjectCatalog();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final out = <MoodboardCatalogKey, List<String>>{};
      for (final entry in _keyNames.entries) {
        final list = json[entry.value];
        if (list is List) {
          out[entry.key] = list.map((e) => e.toString()).toList();
        }
      }
      return MoodboardProjectCatalog(customByKey: out);
    } catch (_) {
      return const MoodboardProjectCatalog();
    }
  }

  static Future<void> addCustomOption({
    required int projectId,
    required MoodboardCatalogKey key,
    required String value,
  }) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    final catalog = await loadForProject(projectId);
    final merged = options(key, catalog);
    if (merged.any((o) => o.toLowerCase() == trimmed.toLowerCase())) return;

    final nextCustom = Map<MoodboardCatalogKey, List<String>>.from(
      catalog.customByKey,
    );
    nextCustom[key] = [...catalog.customFor(key), trimmed];

    final prefs = await SharedPreferences.getInstance();
    final payload = <String, dynamic>{};
    for (final entry in _keyNames.entries) {
      final list = nextCustom[entry.key];
      if (list != null && list.isNotEmpty) {
        payload[entry.value] = list;
      }
    }
    if (payload.isEmpty) {
      await prefs.remove(_prefsKey(projectId));
    } else {
      await prefs.setString(_prefsKey(projectId), jsonEncode(payload));
    }
  }

  /// Defaults + custom, sin duplicados (case-insensitive).
  static List<String> options(
    MoodboardCatalogKey key,
    MoodboardProjectCatalog catalog,
  ) {
    final seen = <String>{};
    final out = <String>[];
    for (final value in [..._defaults(key), ...catalog.customFor(key)]) {
      final token = value.toLowerCase();
      if (seen.add(token)) out.add(value);
    }
    return out;
  }

  /// Pantallas sugeridas a partir del catálogo y vínculos de set.
  static List<String> suggestSections({
    required MoodboardReferenceMeta meta,
    String? linkedLocationName,
    int? linkedLocationBasePlanId,
  }) {
    final out = <String>{};

    if (meta.locationKind != null ||
        (meta.locationName != null && meta.locationName!.trim().isNotEmpty) ||
        (linkedLocationName != null && linkedLocationName.trim().isNotEmpty) ||
        linkedLocationBasePlanId != null) {
      out.add(BibleSectionId.location);
    }
    if (meta.lightingLook != null ||
        meta.lightSource != null ||
        meta.lightTexture != null) {
      out.add(BibleSectionId.lighting);
    }
    if (meta.composition != null && meta.composition!.trim().isNotEmpty) {
      out.add(BibleSectionId.concept);
    }
    if (meta.colorMood != null && meta.colorMood!.trim().isNotEmpty) {
      out.add(BibleSectionId.colorImage);
    }
    if ((meta.camera != null && meta.camera!.trim().isNotEmpty) ||
        (meta.lenses != null && meta.lenses!.trim().isNotEmpty)) {
      out.add(BibleSectionId.optics);
    }
    if (meta.camera != null && meta.camera!.trim().isNotEmpty) {
      out.add(BibleSectionId.camera);
    }

    return MoodboardAssociation.assignableSections()
        .where(out.contains)
        .toList();
  }

  /// Persiste marcadores de pantalla y categoría derivada (bidireccional).
  static Future<MoodboardImageModel?> updateImagePlacement({
    required AppDatabase db,
    required MoodboardImageModel image,
    required List<String> assignedSections,
    String? linkedLocationName,
    int? linkedLocationBasePlanId,
  }) async {
    var sections = List<String>.from(assignedSections);
    final locName = linkedLocationName ?? image.linkedLocationName;
    final planId = linkedLocationBasePlanId ?? image.linkedLocationBasePlanId;

    if ((locName != null && locName.trim().isNotEmpty) || planId != null) {
      if (!sections.contains(BibleSectionId.location)) {
        sections.add(BibleSectionId.location);
      }
    }

    final row = await (db.select(db.moodboardImages)
          ..where((t) => t.id.equals(image.id)))
        .getSingleOrNull();
    if (row == null) return null;

    final category = MoodboardAssociation.deriveCategoryFromSections(sections);
    await db.updateMoodboardImage(
      row.copyWith(
        assignedSections: Value(
          sections.isEmpty ? null : jsonEncode(sections),
        ),
        category: Value(category),
        linkedLocationName: locName != null
            ? Value(locName)
            : const Value.absent(),
        linkedLocationBasePlanId: planId != null
            ? Value(planId)
            : const Value.absent(),
      ),
    );

    image.assignedSections = sections;
    image.linkedLocationName = locName;
    image.linkedLocationBasePlanId = planId;
    if (category != null) {
      image.category = category;
    }
    return image;
  }
}
