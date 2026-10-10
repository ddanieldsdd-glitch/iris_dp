import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/lighting/lighting_card_view.dart';
import 'package:iris_dp/shared/visual_bible/bible_cards.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:iris_dp/shared/visual_bible/lighting_card_page.dart';
import 'package:iris_dp/shared/visual_bible/narrative_card_kind.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/snapshot.dart';

void main() {
  test('una idea de luz antigua abre con todo lo suyo en sus puntos', () {
    final page = LightingCardPage.of(
      kind: NarrativeCardKind.style,
      body: 'Niebla que rompe la luz',
      meta: {
        'metrics': {'colorTemp': 4300, 'contrastNum': 8},
        'points': [
          {'title': 'Niebla con luz dura', 'body': 'Haces marcados'},
        ],
        'reinforcementBlocks': [
          {'type': 'text', 'text': 'Humo denso al fondo'},
          {'type': 'image', 'imageId': 12},
        ],
        'palette': [
          {'hex': '#112233', 'name': 'Noche'},
        ],
      },
    );
    expect(page.fields.map((f) => f.key), [
      'main',
      'mosaic',
      'light',
      'palette',
      'how',
      'where',
    ]);
    expect(page.values['main'], 'Niebla que rompe la luz');
    expect(page.metrics.kelvin, 4300);
    expect(page.metrics.ratio, 8);
    // Sub-puntos y bloques de refuerzo, juntos en el mosaico.
    final cards = BibleCard.listFrom(page.values['mosaic']);
    expect(cards.map((c) => c.title), ['Niebla con luz dura', '', '']);
    expect(cards[1].body, 'Humo denso al fondo');
    expect(cards[2].imageIds, [12]);
    expect(page.firstImageId, 12);
    expect(page.values['palette'], contains('#112233'));
  });

  test('la página guardada manda, y el cuerpo y la luz viven en la ficha', () {
    final first = LightingCardPage.of(
      kind: NarrativeCardKind.locationLight,
      body: 'Sodio',
      meta: const {},
    );
    final edited = first
        .withValue('day', 'Sol rasante')
        .withFields(
          [
            for (final f in first.fields)
              if (f.key != 'night') f,
          ],
          dropValues: {'night'},
        );
    final json = edited.toJson();
    // Ni el cuerpo ni las métricas se duplican dentro de la página.
    expect((json['values'] as Map).containsKey('main'), isFalse);
    final back = LightingCardPage.of(
      kind: NarrativeCardKind.locationLight,
      body: 'Sodio y sombra',
      meta: {
        'page': jsonDecode(jsonEncode(json)),
        'light': {'kelvin': 2100},
      },
    );
    expect(back.fields.any((f) => f.key == 'night'), isFalse);
    expect(back.values['day'], 'Sol rasante');
    expect(back.values['main'], 'Sodio y sombra');
    expect(back.metrics.kelvin, 2100);
  });

  test('una referencia de cine: película o grupo de stills', () {
    final film = LightingCardPage.of(
      kind: NarrativeCardKind.filmRef,
      body: null,
      meta: {'filmTitle': 'Good Time', 'filmDp': 'Sean Price Williams'},
    );
    expect(film.fields.first.key, 'film');
    expect(film.values['film'], contains('Good Time'));
    expect(film.fields.any((f) => f.key == 'take'), isTrue);

    final stills = LightingCardPage.of(
      kind: NarrativeCardKind.filmRef,
      body: null,
      meta: {'refType': 'stills'},
    );
    expect(stills.fields.any((f) => f.key == 'film'), isFalse);
    expect(stills.fields.first.label, 'La idea que comparten');
  });

  testWidgets('la ficha de una idea de luz: cabecera, puntos y añadir más', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await loadSnapshotFonts();
    tester.view.physicalSize = const Size(1300, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // Base en memoria, sin cerrar: con consultas vivas el cierre espera.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    late int projectId;
    late int bibleId;
    late int cardId;
    await tester.runAsync(() async {
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
      bibleId = (await db.ensureVisualBibleForProject(projectId)).id;
      cardId = await db.insertNarrativeCard(
        VisualBibleNarrativeCardsCompanion.insert(
          bibleId: bibleId,
          sectionId: BibleSectionId.lighting,
          kind: NarrativeCardKind.style,
          title: 'Niebla y luz rota',
          body: const Value('La niebla hace visible la luz'),
          metaJson: Value(
            jsonEncode({
              'light': {'kelvin': 4300, 'ratio': 8},
              'points': [
                {
                  'title': 'Niebla con luz dura',
                  'kicker': 'CONTRASTE 16:1 · HACES',
                  'body': 'Fuentes pequeñas y lejanas',
                },
                {'title': 'Niebla con luz rota', 'body': 'A través de ramas'},
              ],
            }),
          ),
        ),
      );
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: LightingCardScreen(
            projectId: projectId,
            bibleId: bibleId,
            cardId: cardId,
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(tester.takeException(), isNull);

    expect(find.text('Niebla y luz rota'), findsOneWidget);
    expect(find.text('IDEA DE LUZ'), findsOneWidget);
    expect(find.text('La niebla hace visible la luz'), findsOneWidget);
    expect(find.text('4300 K'), findsWidgets);
    // El mosaico, con sus datos cortos como pastillas.
    expect(find.text('Niebla con luz dura'), findsOneWidget);
    expect(find.text('CONTRASTE 16:1'), findsOneWidget);
    expect(find.text('HACES'), findsOneWidget);
    expect(find.text('Niebla con luz rota'), findsOneWidget);
    for (final point in [
      'QUÉ ES ESTA LUZ',
      'VARIANTES',
      'PALETA DE ESTA LUZ',
      'CÓMO SE CONSIGUE',
      'DÓNDE APARECE',
    ]) {
      expect(find.text(point), findsOneWidget, reason: point);
    }
    expect(find.text('AÑADIR PUNTO'), findsOneWidget);

    await saveSnapshot(tester, 'luz_idea');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
