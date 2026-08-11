import 'dart:convert';

import 'bible_layout.dart';
import 'bible_section_ids.dart';

/// Reglas de visibilidad de imágenes del moodboard en secciones y sets.
abstract final class MoodboardAssociation {
  MoodboardAssociation._();

  static const technicalFilter = '__technical__';
  static const locationViewFilter = '__by_location__';

  /// Secciones técnicas del grupo hardcoded (fallback).
  static List<String> get technicalSectionIds =>
      BibleLayoutGroup.sectionsByGroup[BibleLayoutGroup.technical]!;

  static const technicalCategories = [
    MoodboardCategory.optics,
    MoodboardCategory.lighting,
    MoodboardCategory.color,
    MoodboardCategory.texture,
    MoodboardCategory.cameraTest,
  ];

  /// Secciones asignables (excluye moodboard, que es el inbox).
  static List<String> assignableSections([
    List<String> customSectionIds = const [],
  ]) =>
      [
        BibleSectionId.direction,
        BibleSectionId.concept,
        BibleSectionId.camera,
        BibleSectionId.optics,
        BibleSectionId.exposure,
        BibleSectionId.lighting,
        BibleSectionId.colorImage,
        BibleSectionId.format,
        BibleSectionId.texture,
        BibleSectionId.location,
        BibleSectionId.cameraTests,
        BibleSectionId.workflow,
        ...customSectionIds,
      ];

  static String sectionLabel(String sectionId) =>
      BibleSectionId.label(sectionId);

  /// Si la imagen debe mostrarse en una sección de la biblia.
  static bool visibleInSection({
    required String? category,
    required List<String> assignedSections,
    required String sectionId,
  }) {
    if (assignedSections.isNotEmpty) {
      return assignedSections.contains(sectionId);
    }
    final mapped = BibleSectionId.moodboardCategory(sectionId);
    if (mapped == null) return false;
    return category == mapped;
  }

  /// Si la imagen pertenece a un set/localización concreto.
  static bool visibleInLocation({
    required String? linkedLocationName,
    int? linkedLocationBasePlanId,
    required String locationName,
    int? locationBasePlanId,
  }) {
    if (locationBasePlanId != null &&
        linkedLocationBasePlanId == locationBasePlanId) {
      return true;
    }
    return linkedLocationName != null &&
        linkedLocationName.isNotEmpty &&
        linkedLocationName == locationName;
  }

  static bool visibleInTechnicalLayer({
    required String? category,
    required List<String> assignedSections,
  }) {
    if (assignedSections.any(technicalSectionIds.contains)) return true;
    if (category != null && technicalCategories.contains(category)) {
      return true;
    }
    return false;
  }

  static bool isUnassigned({
    required List<String> assignedSections,
    int? linkedLocationBasePlanId,
    String? linkedLocationName,
  }) {
    if (assignedSections.isNotEmpty) return false;
    if (linkedLocationBasePlanId != null) return false;
    return linkedLocationName == null || linkedLocationName.isEmpty;
  }

  /// Categoría derivada de las pantallas asignadas (para filtros y sub-grupos).
  static String? deriveCategoryFromSections(List<String> sections) {
    for (final sectionId in assignableSections()) {
      if (!sections.contains(sectionId)) continue;
      final mapped = categoryForSection(sectionId);
      if (mapped != null) return mapped;
    }
    return null;
  }

  /// Coincide con un chip de categoría del moodboard (pantallas o categoría legacy).
  static bool matchesCategoryFilter({
    required String filterCategory,
    required String? category,
    required List<String> assignedSections,
  }) {
    if (category == filterCategory) return true;
    return assignedSections.any(
      (sid) => categoryForSection(sid) == filterCategory,
    );
  }

  /// Imágenes de localización (pantalla, set vinculado o categoría legacy).
  static bool matchesLocationFilter({
    required String? category,
    required List<String> assignedSections,
    int? linkedLocationBasePlanId,
    String? linkedLocationName,
  }) {
    if (assignedSections.contains(BibleSectionId.location)) return true;
    if (linkedLocationBasePlanId != null) return true;
    if (linkedLocationName != null && linkedLocationName.isNotEmpty) {
      return true;
    }
    return category == MoodboardCategory.location;
  }

  static List<String> decodeSections(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  static List<int> decodeCardIds(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) {
        return decoded
            .map((e) => int.tryParse(e.toString()))
            .whereType<int>()
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static String? categoryForSection(String sectionId) =>
      BibleSectionId.moodboardCategory(sectionId);
}
