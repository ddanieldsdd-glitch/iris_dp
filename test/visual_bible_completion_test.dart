import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_completion.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';

void main() {
  group('completitud extendida de Biblia', () {
    late VisualBibleData data;

    setUp(() {
      data = VisualBibleData(projectId: 1);
    });

    test('usa elementos hijos en secciones con tablas propias', () {
      expect(
        bibleSectionCompletionExtended(
          data: data,
          sectionId: BibleSectionId.moodboard,
          moodboardCount: 6,
        ),
        closeTo(0.6, 0.001),
      );
      expect(
        bibleSectionCompletionExtended(
          data: data,
          sectionId: BibleSectionId.location,
          locationRefCount: 1,
        ),
        0.4,
      );
    });

    test('el progreso global promedia únicamente pantallas conocidas', () {
      data.tone = 'Naturalista';
      data.creativeIntention = 'Cercanía';
      data.stagingApproach = 'Observacional';
      data.pointOfView = 'Personaje';
      data.directionNarrativeIntent = 'Íntimo';

      final progress = bibleOverallCompletion(
        data: data,
        sectionIds: const [
          BibleSectionId.direction,
          BibleSectionId.moodboard,
          'freeform_custom',
        ],
        moodboardCount: 12,
      );

      expect(progress, 1);
    });

    test('el progreso global vacío es cero', () {
      expect(
        bibleOverallCompletion(
          data: data,
          sectionIds: const ['freeform_custom'],
        ),
        0,
      );
    });
  });
}
