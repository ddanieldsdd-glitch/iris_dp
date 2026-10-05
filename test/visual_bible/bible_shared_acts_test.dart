import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/visual_bible/bible_acts.dart';
import 'package:iris_dp/shared/visual_bible/bible_cards.dart';
import 'package:iris_dp/shared/visual_bible/direction_points.dart';

void main() {
  group('actos del proyecto', () {
    test('sin definir, nacen tres con su fase y sin título', () {
      final acts = BibleSharedActs.resolve(const []);
      expect(acts.map((a) => a.kicker), kDefaultActPhases);
      expect(acts.every((a) => a.title.isEmpty), isTrue);
      expect(acts.map((a) => a.id), ['act1', 'act2', 'act3']);
    });

    test('sin definir, recogen lo escrito antes en Dirección y Concepto', () {
      final acts = BibleSharedActs.resolve(
        const [],
        directionBlob: {'act1Phase': 'CALMA', 'act1Title': 'Orden'},
        conceptBlob: {
          'actTitles': {'1': 'No gana', '2': 'El descenso'},
        },
      );
      expect(acts[0].kicker, 'CALMA');
      expect(acts[0].title, 'Orden', reason: 'manda Dirección');
      expect(acts[1].title, 'El descenso');
      expect(acts[2].title, isEmpty);
    });

    test('guardados, se leen tal cual, con sus puntos de giro', () {
      final stored = BibleSharedActs.encode(const [
        BibleCard(id: 'a', kicker: 'Calma', title: 'Orden'),
        BibleCard(id: 'b', title: 'La carta', turn: true),
      ]);
      final acts = BibleSharedActs.resolve(
        stored,
        directionBlob: {'act1Title': 'Antiguo'},
      );
      expect(acts.map((a) => a.title), ['Orden', 'La carta']);
      expect(acts[1].turn, isTrue);
    });

    test('si el usuario los quita todos, no vuelven los de partida', () {
      final stored = BibleSharedActs.encode(const []);
      expect(BibleSharedActs.resolve(stored), isEmpty);
    });

    test('los actos nuevos reciben identidad sin tocar la de los demás', () {
      final acts = BibleSharedActs.withIds(const [
        BibleCard(id: 'a'),
        BibleCard(title: 'Nuevo'),
        BibleCard(title: 'Otro'),
      ]);
      expect(acts.first.id, 'a');
      expect(acts.map((a) => a.id).toSet().length, 3);
      expect(acts.every((a) => a.id.isNotEmpty), isTrue);
    });
  });

  group('punto «División por actos»', () {
    const shared = [
      BibleCard(id: 'a', title: 'Orden'),
      BibleCard(id: 'b', title: 'Ruptura'),
    ];

    test('un array es el formato anterior: actos propios', () {
      final value = BibleActsValue.decode('[{"title":"Mío","body":"x"}]');
      expect(value.shared, isFalse);
      expect(value.resolve(shared).single.title, 'Mío');
    });

    test('compartido: la estructura es del proyecto y el texto de la '
        'pantalla', () {
      final value = const BibleActsValue(shared: true).withLayersOf(const [
        BibleCard(id: 'a', title: 'Orden', body: 'Cámara fija', imageIds: [4]),
      ]);
      final again = BibleActsValue.decode(value.encode());
      final acts = again.resolve(shared);
      expect(acts.map((a) => a.title), ['Orden', 'Ruptura']);
      expect(acts[0].body, 'Cámara fija');
      expect(acts[0].imageIds, [4]);
      expect(acts[1].body, isEmpty);
      expect(again.imageIds, [4]);
    });

    test('pasar a propios y volver no pierde nada', () {
      final value = const BibleActsValue(shared: true)
          .withLayersOf(const [BibleCard(id: 'a', body: 'Del proyecto')])
          .copyWith(shared: false, own: const [BibleCard(title: 'Solo aquí')]);
      final back = BibleActsValue.decode(value.encode()).copyWith(shared: true);
      expect(back.resolve(shared).first.body, 'Del proyecto');
      expect(back.own.single.title, 'Solo aquí');
    });

    test('un punto de fábrica sin valor nace compartido', () {
      expect(
        BibleActsValue.decode(null, sharedByDefault: true).shared,
        isTrue,
      );
      expect(BibleActsValue.decode(null).shared, isFalse);
    });
  });

  group('puntos de Dirección', () {
    test('sin valor propio, se leen de donde estaban', () {
      final blob = {
        'tonePoints': [
          {'title': 'Frío', 'body': 'Fluorescentes'},
        ],
        'extraStrategies': [
          {'title': 'Ritmo', 'body': 'Planos largos'},
        ],
        'transitionLanguage': [
          {'title': 'Match cuts', 'body': ''},
        ],
        'act2Desc': 'Se rompe la simetría',
      };
      expect(DirectionPoints.toneCards({}, blob).single.title, 'Frío');
      final pillars = DirectionPoints.strategyCards(
        {},
        blob,
        camera: 'Lenta',
      );
      expect(pillars.map((c) => c.title), ['Cámara', 'Blocking', 'POV', 'Ritmo']);
      expect(pillars.first.body, 'Lenta');
      expect(
        DirectionPoints.transitionCards({}, blob).single.title,
        'Match cuts',
      );
      final acts = DirectionPoints.actsValue({}, blob);
      expect(acts.shared, isTrue);
      expect(acts.layers['act2']!.body, 'Se rompe la simetría');
    });

    test('con valor propio manda él, aunque esté vacío', () {
      final blob = {
        'tonePoints': [
          {'title': 'Frío', 'body': ''},
        ],
      };
      expect(DirectionPoints.toneCards({'tone': '[]'}, blob), isEmpty);
      expect(
        DirectionPoints.strategyCards({'strategies': '[]'}, const {}),
        isEmpty,
      );
    });

    test('el texto de un pilar se encuentra por su título', () {
      const cards = [
        BibleCard(title: 'cámara', body: ' Lenta '),
        BibleCard(title: 'POV', body: ''),
      ];
      expect(DirectionPoints.pillarBody(cards, 'Cámara'), 'Lenta');
      expect(DirectionPoints.pillarBody(cards, 'POV'), isNull);
      expect(DirectionPoints.pillarBody(cards, 'Blocking'), isNull);
    });
  });
}
