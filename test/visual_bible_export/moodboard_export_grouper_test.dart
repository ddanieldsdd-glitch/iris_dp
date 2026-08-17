import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/moodboard_export_grouper.dart';
import 'package:iris_dp/features/visual_bible/moodboard_export_layout.dart';
import 'package:iris_dp/features/visual_bible/moodboard_reference_meta.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';

MoodboardImageModel _image({
  int id = 1,
  String? category,
  MoodboardReferenceMeta meta = const MoodboardReferenceMeta(),
  String? linkedLocationName,
  String? filmReference,
  String? caption,
  List<String>? assignedSections,
}) => MoodboardImageModel(
  id: id,
  projectId: 1,
  imagePath: '/tmp/$id.jpg',
  source: MoodboardSource.manual,
  category: category,
  caption: caption,
  filmReference: filmReference,
  linkedLocationName: linkedLocationName,
  assignedSections: assignedSections,
  meta: meta,
);

void main() {
  test('primaryFacet prioriza luz sobre localización', () {
    final image = _image(
      meta: const MoodboardReferenceMeta(
        lightingLook: 'soft',
        locationName: 'calle',
      ),
    );
    expect(
      MoodboardExportGrouper.primaryFacet(image),
      MoodboardExportFacet.light,
    );
  });

  test('byFacet agrupa y limita por faceta', () {
    final images = [
      _image(
        id: 1,
        category: MoodboardCategory.lighting,
      ),
      _image(
        id: 2,
        category: MoodboardCategory.lighting,
      ),
      _image(
        id: 3,
        category: MoodboardCategory.color,
      ),
      _image(
        id: 4,
        category: MoodboardCategory.texture,
      ),
    ];
    final layout = MoodboardExportLayout(
      grouping: MoodboardExportGrouping.byFacet,
      facets: MoodboardExportFacet.values.toSet(),
      maxImagesPerFacet: 1,
    );
    final groups = MoodboardExportGrouper.group(images, layout);

    expect(groups.byFacet[MoodboardExportFacet.light]?.length, 1);
    expect(groups.byFacet[MoodboardExportFacet.color]?.length, 1);
    expect(groups.byFacet[MoodboardExportFacet.texture]?.length, 1);
    expect(groups.flat, isEmpty);
  });

  test('flat respeta maxImagesFlat', () {
    final images = List.generate(
      30,
      (i) => _image(id: i, category: MoodboardCategory.reference),
    );
    final groups = MoodboardExportGrouper.group(
      images,
      const MoodboardExportLayout(
        grouping: MoodboardExportGrouping.flat,
        maxImagesFlat: 10,
      ),
    );
    expect(groups.flat.length, 10);
  });

  test('densidad minimal no incluye caption ni detalles', () {
    final image = _image(
      caption: 'nota',
      filmReference: 'Film X',
      meta: const MoodboardReferenceMeta(colorMood: 'frío'),
    );
    expect(
      MoodboardExportGrouper.captionFor(
        image,
        MoodboardExportDensity.minimal,
      ),
      isNull,
    );
    expect(
      MoodboardExportGrouper.detailLinesFor(
        image,
        MoodboardExportDensity.minimal,
      ),
      isEmpty,
    );
  });

  test('densidad rich incluye film y créditos', () {
    final image = _image(
      filmReference: 'Blade Runner',
      meta: const MoodboardReferenceMeta(
        title: 'Still 1',
        year: '1982',
        director: 'Scott',
      ),
    );
    final lines = MoodboardExportGrouper.detailLinesFor(
      image,
      MoodboardExportDensity.rich,
    );
    expect(lines.first, 'Blade Runner');
    expect(lines.any((l) => l.contains('Scott')), isTrue);
  });

  test('imagesForSection usa assignedSections y categoría canónica', () {
    final assigned = _image(
      id: 1,
      assignedSections: [BibleSectionId.exposure],
    );
    final byCategory = _image(
      id: 2,
      category: MoodboardCategory.texture,
    );
    final other = _image(id: 3, category: MoodboardCategory.lighting);
    expect(
      MoodboardExportGrouper.imagesForSection(
        [assigned, byCategory, other],
        BibleSectionId.texture,
      ),
      [byCategory],
    );
    expect(
      MoodboardExportGrouper.imagesForSection(
        [assigned, byCategory, other],
        BibleSectionId.exposure,
      ),
      [assigned, other],
    );
  });

  test('maxImagesFlat 0 exporta todas las stills', () {
    final images = List.generate(
      30,
      (i) => _image(id: i, category: MoodboardCategory.reference),
    );
    final groups = MoodboardExportGrouper.group(
      images,
      const MoodboardExportLayout(
        grouping: MoodboardExportGrouping.flat,
        maxImagesFlat: 0,
      ),
    );
    expect(groups.flat.length, 30);
  });
}
