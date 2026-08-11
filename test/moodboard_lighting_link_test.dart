import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/moodboard_reference_meta.dart';
import 'package:iris_dp/features/visual_bible/services/moodboard_lighting_link_service.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:iris_dp/shared/visual_bible/narrative_card_kind.dart';

void main() {
  group('MoodboardLightingTags', () {
    test('matchesImage requires all card criteria', () {
      const card = MoodboardLightingTags(
        lightingLook: 'Dura',
        lightSource: 'HMI',
      );
      expect(
        card.matchesImage(
          const MoodboardLightingTags(
            lightingLook: 'Dura',
            lightSource: 'HMI',
            lightTexture: 'Especular',
          ),
        ),
        isTrue,
      );
      expect(
        card.matchesImage(
          const MoodboardLightingTags(
            lightingLook: 'Suave',
            lightSource: 'HMI',
          ),
        ),
        isFalse,
      );
    });

    test('card without tags does not match', () {
      const card = MoodboardLightingTags();
      expect(
        card.matchesImage(
          const MoodboardLightingTags(lightingLook: 'Dura'),
        ),
        isFalse,
      );
    });
  });

  group('LightingBehaviorTagFilter', () {
    test('matches OR within and across dimensions', () {
      const filter = LightingBehaviorTagFilter(
        lightingLooks: ['Dura', 'Contraluz'],
        colorMoods: ['Fría'],
      );
      expect(
        filter.matchesMeta(
          const MoodboardReferenceMeta(
            lightingLook: 'Contraluz',
            colorMood: 'Fría',
          ),
        ),
        isTrue,
      );
      // Solo look coincide → entra (OR entre familias).
      expect(
        filter.matchesMeta(
          const MoodboardReferenceMeta(
            lightingLook: 'Contraluz',
            colorMood: 'Cálida',
          ),
        ),
        isTrue,
      );
      // Solo colorMood coincide → entra.
      expect(
        filter.matchesMeta(
          const MoodboardReferenceMeta(
            lightingLook: 'Suave',
            colorMood: 'Fría',
          ),
        ),
        isTrue,
      );
      expect(
        filter.matchesMeta(
          const MoodboardReferenceMeta(
            lightingLook: 'Suave',
            colorMood: 'Cálida',
          ),
        ),
        isFalse,
      );
    });

    test('imagesMatchingContainer includes assigned or tag-matched', () {
      final filterCard = NarrativeCardModel(
        id: 10,
        bibleId: 1,
        sectionId: BibleSectionId.lighting,
        kind: NarrativeCardKind.style,
        title: 'Niebla',
        meta: {
          'tagFilters': {
            'lightTexture': ['Humo / niebla'],
            'colorMood': ['Fría'],
          },
        },
      );
      final pool = [
        MoodboardImageModel(
          id: 1,
          projectId: 1,
          imagePath: '/a.jpg',
          source: 'paste',
          meta: const MoodboardReferenceMeta(lightTexture: 'Humo / niebla'),
        ),
        MoodboardImageModel(
          id: 2,
          projectId: 1,
          imagePath: '/b.jpg',
          source: 'paste',
          assignedCardIds: const [10],
          meta: const MoodboardReferenceMeta(colorMood: 'Cálida'),
        ),
        MoodboardImageModel(
          id: 3,
          projectId: 1,
          imagePath: '/c.jpg',
          source: 'paste',
          meta: const MoodboardReferenceMeta(lightingLook: 'Dura'),
        ),
      ];
      final matched = MoodboardLightingLinkService.imagesMatchingContainer(
        pool: pool,
        container: filterCard,
      );
      expect(matched.map((m) => m.id).toList(), [1, 2]);
    });

    test('fromCard reads tagFilters meta and legacy single values', () {
      final multi = NarrativeCardModel(
        id: 1,
        bibleId: 1,
        sectionId: BibleSectionId.lighting,
        kind: NarrativeCardKind.style,
        title: 'Temp',
        meta: {
          'tagFilters': {
            'colorMood': ['Fría', 'Cálida'],
            'lightTexture': ['Especular'],
          },
        },
      );
      final f = LightingBehaviorTagFilter.fromCard(multi);
      expect(f.colorMoods, ['Fría', 'Cálida']);
      expect(f.lightTextures, ['Especular']);

      final legacy = NarrativeCardModel(
        id: 2,
        bibleId: 1,
        sectionId: BibleSectionId.lighting,
        kind: NarrativeCardKind.style,
        title: 'Legacy',
      )..lightingLook = 'Dura';
      final lf = LightingBehaviorTagFilter.fromCard(legacy);
      expect(lf.lightingLooks, ['Dura']);
    });
  });

  group('MoodboardLightingLinkService', () {
    test('matchingCards finds style cards with aligned tags', () {
      final cards = [
        NarrativeCardModel(
          id: 1,
          bibleId: 1,
          sectionId: BibleSectionId.lighting,
          kind: NarrativeCardKind.style,
          title: 'Hard HMI',
          meta: {
            'tagFilters': {
              'lightingLook': ['Dura'],
              'lightSource': ['HMI'],
            },
          },
        ),
        NarrativeCardModel(
          id: 2,
          bibleId: 1,
          sectionId: BibleSectionId.lighting,
          kind: NarrativeCardKind.style,
          title: 'Soft only',
        )..lightingLook = 'Suave',
        NarrativeCardModel(
          id: 3,
          bibleId: 1,
          sectionId: BibleSectionId.lighting,
          kind: NarrativeCardKind.locationLight,
          title: 'Set',
        )..lightingLook = 'Dura',
      ];

      final meta = const MoodboardReferenceMeta(
        lightingLook: 'Dura',
        lightSource: 'HMI',
      );

      final matches = MoodboardLightingLinkService.matchingCards(
        cards: cards,
        meta: meta,
      );
      expect(matches.map((c) => c.id).toList(), [1]);
    });

    test('matchesFilter applies AND across dimensions', () {
      const meta = MoodboardReferenceMeta(
        lightingLook: 'Dura',
        lightSource: 'LED',
        colorMood: 'Fría',
      );
      expect(
        MoodboardLightingLinkService.matchesFilter(
          meta: meta,
          lightingLook: 'Dura',
          colorMood: 'Fría',
        ),
        isTrue,
      );
      expect(
        MoodboardLightingLinkService.matchesFilter(
          meta: meta,
          lightingLook: 'Dura',
          lightSource: 'HMI',
        ),
        isFalse,
      );
    });
  });
}
