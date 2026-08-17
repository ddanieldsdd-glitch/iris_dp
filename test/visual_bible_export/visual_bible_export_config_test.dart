import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/moodboard_export_layout.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_export_config.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';

void main() {
  test('VisualBibleExportConfig round-trip incluye moodboardLayout', () {
    final config = VisualBibleExportConfig(
      id: 'test',
      name: 'Test',
      audience: VisualBibleExportAudience.general,
      mode: VisualBibleExportMode.full,
      sections: {BibleSectionId.moodboard},
      destination: VisualBibleExportDestination.saveFile,
      updatedAt: DateTime.utc(2026, 8, 10),
      moodboardLayout: MoodboardExportLayout(
        grouping: MoodboardExportGrouping.byFacet,
        facets: {
          MoodboardExportFacet.light,
          MoodboardExportFacet.color,
        },
        density: MoodboardExportDensity.rich,
        includeUnclassified: false,
      ),
    );

    final json = config.toJson();
    final restored = VisualBibleExportConfig.fromJson(json);

    expect(restored.moodboardLayout.grouping, MoodboardExportGrouping.byFacet);
    expect(restored.moodboardLayout.facets, {
      MoodboardExportFacet.light,
      MoodboardExportFacet.color,
    });
    expect(restored.moodboardLayout.density, MoodboardExportDensity.rich);
    expect(restored.moodboardLayout.includeUnclassified, isFalse);
  });

  test('round-trip incluye includeAllMoodboardImages', () {
    final config = VisualBibleExportConfig(
      id: 'test',
      name: 'Test',
      audience: VisualBibleExportAudience.general,
      mode: VisualBibleExportMode.pitch,
      sections: {BibleSectionId.moodboard},
      destination: VisualBibleExportDestination.saveFile,
      updatedAt: DateTime.utc(2026, 8, 10),
      includeAllMoodboardImages: true,
    );
    final restored = VisualBibleExportConfig.fromJson(config.toJson());
    expect(restored.includeAllMoodboardImages, isTrue);
  });

  test('fromJson sin includeAllMoodboardImages usa false', () {
    final restored = VisualBibleExportConfig.fromJson({
      'id': 'legacy',
      'name': 'Legacy',
      'audience': 'general',
      'mode': 'pitch',
      'sections': ['moodboard'],
      'destination': 'saveFile',
      'updatedAt': '2026-01-01T00:00:00.000Z',
    });
    expect(restored.includeAllMoodboardImages, isFalse);
  });

  test('fromJson sin moodboardLayout usa defaults', () {
    final restored = VisualBibleExportConfig.fromJson({
      'id': 'legacy',
      'name': 'Legacy',
      'audience': 'general',
      'mode': 'full',
      'sections': ['moodboard'],
      'destination': 'saveFile',
      'updatedAt': '2026-01-01T00:00:00.000Z',
    });

    expect(restored.moodboardLayout, MoodboardExportLayout.defaults);
  });

  test('defaultMoodboardLayoutForMode pitch y tech scout', () {
    final pitch =
        VisualBibleExportConfig.defaultMoodboardLayoutForMode(
          VisualBibleExportMode.pitch,
        );
    expect(pitch.grouping, MoodboardExportGrouping.flat);
    expect(pitch.density, MoodboardExportDensity.rich);
    expect(pitch.maxImagesFlat, 12);

    final tech =
        VisualBibleExportConfig.defaultMoodboardLayoutForMode(
          VisualBibleExportMode.techScout,
        );
    expect(tech.grouping, MoodboardExportGrouping.byFacet);
    expect(tech.facets, {
      MoodboardExportFacet.light,
      MoodboardExportFacet.location,
    });
    expect(tech.density, MoodboardExportDensity.standard);
  });

  test('defaultMoodboardLayoutForDepartment colorista y gaffer', () {
    final colorist =
        VisualBibleExportConfig.defaultMoodboardLayoutForDepartment(
          VisualBibleDepartment.colorist,
        );
    expect(colorist.grouping, MoodboardExportGrouping.byFacet);
    expect(colorist.facets, {
      MoodboardExportFacet.color,
      MoodboardExportFacet.texture,
    });
    expect(colorist.density, MoodboardExportDensity.rich);

    final gaffer =
        VisualBibleExportConfig.defaultMoodboardLayoutForDepartment(
          VisualBibleDepartment.gaffer,
        );
    expect(gaffer.facets, {
      MoodboardExportFacet.light,
      MoodboardExportFacet.location,
    });
  });

  test('defaults() incluye layout full sin límite plano', () {
    final config = VisualBibleExportConfig.defaults();
    expect(
      config.moodboardLayout,
      const MoodboardExportLayout(maxImagesFlat: 0),
    );
    expect(
      VisualBibleExportConfig.defaultMoodboardLayoutForMode(
        VisualBibleExportMode.full,
      ).maxImagesFlat,
      0,
    );
  });

  test('resolvedMoodboardLayout quita el tope en modo full', () {
    final capped = VisualBibleExportConfig.defaults().copyWith(
      moodboardLayout: const MoodboardExportLayout(maxImagesFlat: 24),
    );
    expect(capped.resolvedMoodboardLayout.maxImagesFlat, 0);
    expect(capped.resolvedMoodboardLayout.maxImagesPerFacet, 0);

    final pitch = VisualBibleExportConfig.defaults().copyWith(
      mode: VisualBibleExportMode.pitch,
      moodboardLayout: const MoodboardExportLayout(maxImagesFlat: 12),
    );
    expect(pitch.resolvedMoodboardLayout.maxImagesFlat, 12);
  });
}
