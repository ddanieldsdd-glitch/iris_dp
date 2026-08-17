import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/bible_block_catalog.dart';
import 'package:iris_dp/features/visual_bible/data/visual_bible_repository.dart';
import 'package:iris_dp/features/visual_bible/export/builder/bible_export_composition_builder.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_block.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_block_layout.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_document.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_page.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_export_config.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_pdf_service.dart';

void main() {
  group('exportSectionsForMoodboardImage', () {
    MoodboardImageModel img({
      String? category,
      List<String> assigned = const [],
    }) => MoodboardImageModel(
      id: 1,
      projectId: 1,
      imagePath: '/tmp/a.jpg',
      source: MoodboardSource.manual,
      category: category,
      assignedSections: assigned,
    );

    test('category lighting no duplica lighting+exposure', () {
      expect(
        VisualBiblePdfService.exportSectionsForMoodboardImage(
          img(category: MoodboardCategory.lighting),
        ),
        [BibleSectionId.lighting],
      );
    });

    test('assignedSections se deduplican preservando orden', () {
      expect(
        VisualBiblePdfService.exportSectionsForMoodboardImage(
          img(
            assigned: [
              BibleSectionId.lighting,
              BibleSectionId.concept,
              BibleSectionId.lighting,
            ],
          ),
        ),
        [BibleSectionId.lighting, BibleSectionId.concept],
      );
    });

    test('sin category ni assigned → vacío', () {
      expect(
        VisualBiblePdfService.exportSectionsForMoodboardImage(img()),
        isEmpty,
      );
    });
  });

  group('BibleSectionId.sectionForMoodboardCategory', () {
    test('mapeo 1:1 estable', () {
      expect(
        BibleSectionId.sectionForMoodboardCategory(MoodboardCategory.lighting),
        BibleSectionId.lighting,
      );
      expect(
        BibleSectionId.sectionForMoodboardCategory(MoodboardCategory.color),
        BibleSectionId.colorImage,
      );
      expect(
        BibleSectionId.sectionForMoodboardCategory(MoodboardCategory.framing),
        BibleSectionId.concept,
      );
    });
  });

  group('BibleExportCompositionBuilder moodboardRefs', () {
    final now = DateTime.utc(2026, 8, 10, 12);
    final config = VisualBibleExportConfig(
      id: 'cfg',
      name: 'Test',
      audience: VisualBibleExportAudience.general,
      mode: VisualBibleExportMode.full,
      sections: {BibleSectionId.moodboard},
      destination: VisualBibleExportDestination.saveFile,
      updatedAt: now,
    );

    VisualBibleExportBundle bundle() => (
      data: VisualBibleData(id: 1, projectId: 1),
      blocks: <ColorBlockModel>[],
      exposureBlocks: <ExposureBlockModel>[],
      lightingSetups: <LightingSetupModel>[],
      cameraTests: <CameraTestModel>[],
      moodboard: [
        MoodboardImageModel(
          id: 10,
          projectId: 1,
          imagePath: '/tmp/still.jpg',
          source: MoodboardSource.manual,
          caption: 'Still A',
        ),
      ],
      narrativeCards: <NarrativeCardModel>[],
    sectionContentJsonById: const <String, String?>{},
      primaryCameraLabel: null,
    );

    test('rellena placeholder vacío sin duplicar bloque', () {
      final doc = BibleDocument(
        bibleId: 1,
        projectId: 1,
        pages: [
          BiblePage(
            id: BibleSectionId.moodboard,
            groupId: 'refs',
            label: 'Moodboard',
            sortOrder: 0,
            blocks: [
              BibleBlock(
                id: 'placeholder',
                type: BibleBlockKind.moodboardRefs,
                layout: const BibleBlockLayout(row: 0),
                content: const {'images': <Object>[]},
              ),
            ],
          ),
        ],
        updatedAt: now,
      );

      final composition = BibleExportCompositionBuilder(
        idFactory: () => 'comp',
        clock: () => now,
      ).build(
        projectId: 1,
        config: config,
        bundle: bundle(),
        sourceDocument: doc,
        compositionId: 'comp',
        includeCover: false,
      );

      final page = composition.pages.singleWhere(
        (p) => p.source?.sectionId == BibleSectionId.moodboard,
      );
      final refs = page.blocks
          .where((b) => b.type == BibleBlockKind.moodboardRefs)
          .toList();
      expect(refs, hasLength(1));
      expect(refs.single.id, 'placeholder');
      final images = refs.single.content['images'] as List;
      expect(images, hasLength(1));
      expect(images.single['path'], '/tmp/still.jpg');
      expect(images.single['caption'], 'Still A');
    });

    test('incluye details de meta en el bloque moodboardRefs', () {
      final bundleWithMeta = (
        data: VisualBibleData(id: 1, projectId: 1),
        blocks: <ColorBlockModel>[],
        exposureBlocks: <ExposureBlockModel>[],
        lightingSetups: <LightingSetupModel>[],
        cameraTests: <CameraTestModel>[],
        moodboard: [
          MoodboardImageModel(
            id: 10,
            projectId: 1,
            imagePath: '/tmp/still.jpg',
            source: MoodboardSource.manual,
            caption: 'Still A',
            meta: const MoodboardReferenceMeta(
              tags: ['teal'],
              lightingLook: 'Suave',
              technicalNotes: 'Ventana norte',
            ),
          ),
        ],
        narrativeCards: <NarrativeCardModel>[],
    sectionContentJsonById: const <String, String?>{},
        primaryCameraLabel: null,
      );

      final composition = BibleExportCompositionBuilder(
        idFactory: () => 'comp-meta',
        clock: () => now,
      ).build(
        projectId: 1,
        config: config,
        bundle: bundleWithMeta,
        compositionId: 'comp-meta',
        includeCover: false,
      );

      final page = composition.pages.singleWhere(
        (p) => p.source?.sectionId == BibleSectionId.moodboard,
      );
      final refs = page.blocks
          .where((b) => b.type == BibleBlockKind.moodboardRefs)
          .single;
      final images = refs.content['images'] as List;
      expect(images.single['details'], [
        'teal · Suave',
        'Ventana norte',
      ]);
    });

    test('no añade segundo bloque si ya hay refs con imágenes', () {
      final doc = BibleDocument(
        bibleId: 1,
        projectId: 1,
        pages: [
          BiblePage(
            id: BibleSectionId.moodboard,
            groupId: 'refs',
            label: 'Moodboard',
            sortOrder: 0,
            blocks: [
              BibleBlock(
                id: 'existing',
                type: BibleBlockKind.moodboardRefs,
                layout: const BibleBlockLayout(row: 0),
                content: {
                  'images': [
                    {'path': '/tmp/manual.jpg', 'caption': 'Manual'},
                  ],
                },
              ),
            ],
          ),
        ],
        updatedAt: now,
      );

      final composition = BibleExportCompositionBuilder(
        idFactory: () => 'comp2',
        clock: () => now,
      ).build(
        projectId: 1,
        config: config,
        bundle: bundle(),
        sourceDocument: doc,
        compositionId: 'comp2',
        includeCover: false,
      );

      final page = composition.pages.singleWhere(
        (p) => p.source?.sectionId == BibleSectionId.moodboard,
      );
      final refs = page.blocks
          .where((b) => b.type == BibleBlockKind.moodboardRefs)
          .toList();
      expect(refs, hasLength(1));
      expect(refs.single.id, 'existing');
      final images = refs.single.content['images'] as List;
      expect(images.single['path'], '/tmp/manual.jpg');
    });
  });
}
