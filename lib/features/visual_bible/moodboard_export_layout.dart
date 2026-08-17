enum MoodboardExportGrouping { flat, byFacet }

enum MoodboardExportFacet { light, location, color, texture, composition }

enum MoodboardExportDensity { minimal, standard, rich }

class MoodboardExportLayout {
  final MoodboardExportGrouping grouping;
  final Set<MoodboardExportFacet> facets;
  final MoodboardExportDensity density;
  final int maxImagesFlat;
  final int maxImagesPerFacet;
  final bool includeUnclassified;

  const MoodboardExportLayout({
    this.grouping = MoodboardExportGrouping.flat,
    this.facets = const {},
    this.density = MoodboardExportDensity.standard,
    this.maxImagesFlat = 24,
    this.maxImagesPerFacet = 8,
    this.includeUnclassified = true,
  });

  static const defaults = MoodboardExportLayout();

  MoodboardExportLayout copyWith({
    MoodboardExportGrouping? grouping,
    Set<MoodboardExportFacet>? facets,
    MoodboardExportDensity? density,
    int? maxImagesFlat,
    int? maxImagesPerFacet,
    bool? includeUnclassified,
  }) => MoodboardExportLayout(
    grouping: grouping ?? this.grouping,
    facets: facets ?? this.facets,
    density: density ?? this.density,
    maxImagesFlat: maxImagesFlat ?? this.maxImagesFlat,
    maxImagesPerFacet: maxImagesPerFacet ?? this.maxImagesPerFacet,
    includeUnclassified: includeUnclassified ?? this.includeUnclassified,
  );

  Map<String, dynamic> toJson() => {
    'grouping': grouping.name,
    'facets': facets.map((f) => f.name).toList(),
    'density': density.name,
    'maxImagesFlat': maxImagesFlat,
    'maxImagesPerFacet': maxImagesPerFacet,
    'includeUnclassified': includeUnclassified,
  };

  factory MoodboardExportLayout.fromJson(Map<String, dynamic>? json) {
    if (json == null) return defaults;
    return MoodboardExportLayout(
      grouping: MoodboardExportGrouping.values.firstWhere(
        (g) => g.name == json['grouping'],
        orElse: () => MoodboardExportGrouping.flat,
      ),
      facets: (json['facets'] as List<dynamic>? ?? [])
          .map(
            (s) => MoodboardExportFacet.values.firstWhere(
              (f) => f.name == s,
              orElse: () => MoodboardExportFacet.light,
            ),
          )
          .toSet(),
      density: MoodboardExportDensity.values.firstWhere(
        (d) => d.name == json['density'],
        orElse: () => MoodboardExportDensity.standard,
      ),
      maxImagesFlat: json['maxImagesFlat'] as int? ?? 24,
      maxImagesPerFacet: json['maxImagesPerFacet'] as int? ?? 8,
      includeUnclassified: json['includeUnclassified'] as bool? ?? true,
    );
  }

  static String groupingLabel(MoodboardExportGrouping grouping) =>
      switch (grouping) {
        MoodboardExportGrouping.flat => 'Plano',
        MoodboardExportGrouping.byFacet => 'Por faceta',
      };

  static String facetLabel(MoodboardExportFacet facet) => switch (facet) {
        MoodboardExportFacet.light => 'Luz',
        MoodboardExportFacet.location => 'Localización',
        MoodboardExportFacet.color => 'Color',
        MoodboardExportFacet.texture => 'Textura',
        MoodboardExportFacet.composition => 'Composición',
      };

  static String densityLabel(MoodboardExportDensity density) =>
      switch (density) {
        MoodboardExportDensity.minimal => 'Mínima',
        MoodboardExportDensity.standard => 'Estándar',
        MoodboardExportDensity.rich => 'Rica',
      };
}
