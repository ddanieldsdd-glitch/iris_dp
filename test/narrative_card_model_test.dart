import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/shared/visual_bible/moodboard_association.dart';
import 'package:iris_dp/shared/visual_bible/narrative_card_kind.dart';

void main() {
  group('MoodboardAssociation.decodeCardIds', () {
    test('parses int list', () {
      expect(MoodboardAssociation.decodeCardIds('[1, 2, 3]'), [1, 2, 3]);
    });

    test('empty / null', () {
      expect(MoodboardAssociation.decodeCardIds(null), isEmpty);
      expect(MoodboardAssociation.decodeCardIds(''), isEmpty);
      expect(MoodboardAssociation.decodeCardIds('not-json'), isEmpty);
    });
  });

  group('NarrativeCardModel', () {
    test('summary prefers meta.summary then truncates body', () {
      final withMeta = NarrativeCardModel(
        id: 1,
        bibleId: 1,
        sectionId: 'lighting',
        kind: NarrativeCardKind.locationLight,
        title: 'Bosque',
        body: 'Cuerpo largo de desarrollo de luz',
        meta: {'summary': 'Pincelada corta'},
      );
      expect(withMeta.summary, 'Pincelada corta');

      final longBody = NarrativeCardModel(
        id: 2,
        bibleId: 1,
        sectionId: 'lighting',
        kind: NarrativeCardKind.style,
        title: 'Soft top',
        body: 'x' * 200,
      );
      expect(longBody.summary!.endsWith('…'), isTrue);
      expect(longBody.summary!.length, lessThanOrEqualTo(180));
    });

    test('hero caption and reinforcement blocks', () {
      final card = NarrativeCardModel(
        id: 4,
        bibleId: 1,
        sectionId: 'lighting',
        kind: NarrativeCardKind.style,
        title: 'Niebla',
      );
      card.heroCaption = 'Plano amplio con niebla densa';
      card.reinforcementBlocks = [
        ContainerReinforcementBlock.text('Atmósfera húmeda'),
        ContainerReinforcementBlock.image(42),
      ];
      expect(card.heroCaption, 'Plano amplio con niebla densa');
      expect(card.reinforcementBlocks.length, 2);
      expect(card.reinforcementBlocks.first.text, 'Atmósfera húmeda');
      expect(card.reinforcementBlocks.last.imageId, 42);

      card.reinforcementBlocks = [
        ContainerReinforcementBlock.text(''),
      ];
      expect(card.reinforcementBlocks.length, 1);
      expect(card.reinforcementBlocks.first.text, '');
    });

    test('film meta getters', () {
      final card = NarrativeCardModel(
        id: 3,
        bibleId: 1,
        sectionId: 'lighting',
        kind: NarrativeCardKind.filmRef,
        title: 'Ref',
      );
      card.filmTitle = 'Blade Runner';
      card.filmDp = 'Jordan Cronenweth';
      card.filmYear = '1982';
      expect(card.filmTitle, 'Blade Runner');
      expect(card.meta['filmYear'], '1982');
    });
  });

  group('NarrativeCardKind', () {
    test('labels', () {
      expect(NarrativeCardKind.label(NarrativeCardKind.style), 'Contenedor de luz');
      expect(
        NarrativeCardKind.label(NarrativeCardKind.locationLight),
        'Localización (luz)',
      );
    });
  });
}
