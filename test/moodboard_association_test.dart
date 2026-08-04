import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/moodboard_association.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';

void main() {
  group('MoodboardAssociation.visibleInSection', () {
    test('usa asignación explícita si existe', () {
      expect(
        MoodboardAssociation.visibleInSection(
          category: MoodboardCategory.color,
          assignedSections: [BibleSectionId.direction],
          sectionId: BibleSectionId.direction,
        ),
        isTrue,
      );
      expect(
        MoodboardAssociation.visibleInSection(
          category: MoodboardCategory.color,
          assignedSections: [BibleSectionId.direction],
          sectionId: BibleSectionId.colorImage,
        ),
        isFalse,
      );
    });

    test('sin asignación explícita usa categoría mapeada (legacy)', () {
      expect(
        MoodboardAssociation.visibleInSection(
          category: MoodboardCategory.lighting,
          assignedSections: [],
          sectionId: BibleSectionId.lighting,
        ),
        isTrue,
      );
      expect(
        MoodboardAssociation.visibleInSection(
          category: MoodboardCategory.lighting,
          assignedSections: [],
          sectionId: BibleSectionId.concept,
        ),
        isFalse,
      );
    });
  });

  group('MoodboardAssociation.deriveCategoryFromSections', () {
    test('deriva categoría de la primera pantalla mapeada', () {
      expect(
        MoodboardAssociation.deriveCategoryFromSections([
          BibleSectionId.direction,
          BibleSectionId.lighting,
        ]),
        MoodboardCategory.lighting,
      );
      expect(
        MoodboardAssociation.deriveCategoryFromSections([
          BibleSectionId.location,
        ]),
        MoodboardCategory.location,
      );
      expect(
        MoodboardAssociation.deriveCategoryFromSections([
          BibleSectionId.direction,
        ]),
        isNull,
      );
    });
  });

  group('MoodboardAssociation.matchesCategoryFilter', () {
    test('coincide por pantalla o categoría legacy', () {
      expect(
        MoodboardAssociation.matchesCategoryFilter(
          filterCategory: MoodboardCategory.lighting,
          category: null,
          assignedSections: [BibleSectionId.lighting],
        ),
        isTrue,
      );
      expect(
        MoodboardAssociation.matchesCategoryFilter(
          filterCategory: MoodboardCategory.color,
          category: MoodboardCategory.color,
          assignedSections: [],
        ),
        isTrue,
      );
    });
  });

  group('MoodboardAssociation.matchesLocationFilter', () {
    test('incluye refs con pantalla, set o categoría legacy', () {
      expect(
        MoodboardAssociation.matchesLocationFilter(
          category: null,
          assignedSections: [BibleSectionId.location],
          linkedLocationBasePlanId: null,
          linkedLocationName: null,
        ),
        isTrue,
      );
      expect(
        MoodboardAssociation.matchesLocationFilter(
          category: null,
          assignedSections: [],
          linkedLocationBasePlanId: 42,
          linkedLocationName: 'CALLE RAVAL',
        ),
        isTrue,
      );
    });
  });

  group('MoodboardAssociation.isUnassigned', () {
    test('sin pantallas ni set vinculado', () {
      expect(
        MoodboardAssociation.isUnassigned(
          assignedSections: [],
          linkedLocationBasePlanId: null,
          linkedLocationName: null,
        ),
        isTrue,
      );
      expect(
        MoodboardAssociation.isUnassigned(
          assignedSections: [BibleSectionId.lighting],
          linkedLocationBasePlanId: null,
          linkedLocationName: null,
        ),
        isFalse,
      );
    });
  });

  group('MoodboardAssociation.visibleInTechnicalLayer', () {
    test('incluye refs técnicas por categoría o sección', () {
      expect(
        MoodboardAssociation.visibleInTechnicalLayer(
          category: MoodboardCategory.texture,
          assignedSections: [],
        ),
        isTrue,
      );
      expect(
        MoodboardAssociation.visibleInTechnicalLayer(
          category: MoodboardCategory.reference,
          assignedSections: [BibleSectionId.camera],
        ),
        isTrue,
      );
    });
  });

  group('MoodboardAssociation.visibleInLocation', () {
    test('solo coincide con set vinculado', () {
      expect(
        MoodboardAssociation.visibleInLocation(
          linkedLocationName: 'INT. COCINA',
          locationName: 'INT. COCINA',
        ),
        isTrue,
      );
      expect(
        MoodboardAssociation.visibleInLocation(
          linkedLocationName: 'INT. COCINA',
          locationName: 'EXT. JARDÍN',
        ),
        isFalse,
      );
    });
  });
}
