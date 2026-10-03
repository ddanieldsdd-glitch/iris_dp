import 'package:flutter_test/flutter_test.dart';
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
}
