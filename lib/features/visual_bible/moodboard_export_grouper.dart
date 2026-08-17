import '../../shared/visual_bible/moodboard_association.dart';
import 'moodboard_export_layout.dart';
import 'moodboard_reference_meta.dart';
import 'visual_bible_model.dart';

/// Resultado de agrupar stills para export PDF.
class MoodboardExportGroups {
  final List<MoodboardImageModel> flat;
  final Map<MoodboardExportFacet, List<MoodboardImageModel>> byFacet;
  final List<MoodboardImageModel> unclassified;

  const MoodboardExportGroups({
    this.flat = const [],
    this.byFacet = const {},
    this.unclassified = const [],
  });

  bool get isEmpty =>
      flat.isEmpty && byFacet.isEmpty && unclassified.isEmpty;
}

/// Agrupa stills del moodboard según [MoodboardExportLayout].
abstract final class MoodboardExportGrouper {
  static const facetOrder = [
    MoodboardExportFacet.light,
    MoodboardExportFacet.location,
    MoodboardExportFacet.color,
    MoodboardExportFacet.texture,
    MoodboardExportFacet.composition,
  ];

  static MoodboardExportGroups group(
    List<MoodboardImageModel> images,
    MoodboardExportLayout layout,
  ) {
    if (layout.grouping == MoodboardExportGrouping.flat) {
      final limit = layout.maxImagesFlat <= 0 ? images.length : layout.maxImagesFlat;
      return MoodboardExportGroups(
        flat: images.take(limit).toList(),
      );
    }

    final activeFacets = layout.facets.isEmpty
        ? MoodboardExportFacet.values.toSet()
        : layout.facets;
    final byFacet = <MoodboardExportFacet, List<MoodboardImageModel>>{};
    final unclassified = <MoodboardImageModel>[];
    final perFacetLimit =
        layout.maxImagesPerFacet <= 0 ? null : layout.maxImagesPerFacet;

    for (final image in images) {
      final facet = primaryFacet(image);
      if (facet != null && activeFacets.contains(facet)) {
        final bucket = byFacet.putIfAbsent(facet, () => []);
        if (perFacetLimit == null || bucket.length < perFacetLimit) {
          bucket.add(image);
        }
      } else if (layout.includeUnclassified) {
        if (perFacetLimit == null || unclassified.length < perFacetLimit) {
          unclassified.add(image);
        }
      }
    }

    return MoodboardExportGroups(byFacet: byFacet, unclassified: unclassified);
  }

  /// Un still → un grupo primario (prioridad: luz → loc → color → textura → comp).
  static MoodboardExportFacet? primaryFacet(MoodboardImageModel image) {
    final meta = image.meta;
    if (_hasLight(meta) || image.category == MoodboardCategory.lighting) {
      return MoodboardExportFacet.light;
    }
    if (_hasLocation(meta, image) ||
        image.category == MoodboardCategory.location) {
      return MoodboardExportFacet.location;
    }
    if (_hasColor(meta) || image.category == MoodboardCategory.color) {
      return MoodboardExportFacet.color;
    }
    if (image.category == MoodboardCategory.texture) {
      return MoodboardExportFacet.texture;
    }
    if (_hasComposition(meta) || image.category == MoodboardCategory.framing) {
      return MoodboardExportFacet.composition;
    }
    return null;
  }

  static String? captionFor(
    MoodboardImageModel image,
    MoodboardExportDensity density,
  ) {
    if (density == MoodboardExportDensity.minimal) return null;
    final caption = image.caption?.trim();
    if (caption == null || caption.isEmpty) return null;
    return caption;
  }

  static List<String> detailLinesFor(
    MoodboardImageModel image,
    MoodboardExportDensity density,
  ) {
    if (density == MoodboardExportDensity.minimal) return const [];

    if (density == MoodboardExportDensity.standard) {
      return image.meta.exportDetailLines;
    }

    final lines = <String>[];
    final film = image.filmReference?.trim();
    if (film != null && film.isNotEmpty) lines.add(film);

    final meta = image.meta;
    final title = meta.title?.trim();
    if (title != null && title.isNotEmpty) lines.add(title);

    final credits = [
      if (meta.year?.trim().isNotEmpty == true) meta.year!.trim(),
      if (meta.director?.trim().isNotEmpty == true) meta.director!.trim(),
      if (meta.dop?.trim().isNotEmpty == true) meta.dop!.trim(),
    ];
    if (credits.isNotEmpty) lines.add(credits.join(' · '));

    lines.addAll(meta.exportDetailLines);
    return lines.take(4).toList();
  }

  /// Stills asignados a una pantalla (o categoría canónica si no hay assigned).
  static List<MoodboardImageModel> imagesForSection(
    List<MoodboardImageModel> images,
    String sectionId,
  ) {
    return [
      for (final image in images)
        if (_belongsToSection(image, sectionId)) image,
    ];
  }

  static bool _belongsToSection(MoodboardImageModel image, String sectionId) {
    return MoodboardAssociation.visibleInSection(
      category: image.category,
      assignedSections: image.assignedSections,
      sectionId: sectionId,
    );
  }

  static bool _hasLight(MoodboardReferenceMeta meta) =>
      _nonEmpty(meta.lightingLook) ||
      _nonEmpty(meta.lightSource) ||
      _nonEmpty(meta.lightTexture);

  static bool _hasLocation(MoodboardReferenceMeta meta, MoodboardImageModel image) =>
      _nonEmpty(meta.locationKind) ||
      _nonEmpty(meta.locationName) ||
      _nonEmpty(image.linkedLocationName);

  static bool _hasColor(MoodboardReferenceMeta meta) => _nonEmpty(meta.colorMood);

  static bool _hasComposition(MoodboardReferenceMeta meta) =>
      _nonEmpty(meta.composition);

  static bool _nonEmpty(String? value) =>
      value != null && value.trim().isNotEmpty;
}
