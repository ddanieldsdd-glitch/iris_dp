import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/v2/bible_block_schemas.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_dark_glass_panel.dart';
import 'package:iris_dp/features/visual_bible/widgets/catalog/bible_widget_catalog.dart';
import 'package:iris_dp/features/visual_bible/widgets/catalog/direction/direction_acts_widget.dart';
import 'package:iris_dp/features/visual_bible/widgets/catalog/direction/direction_visual_strategy_widget.dart';
import 'package:iris_dp/features/visual_bible/widgets/catalog/shared/bible_point_list_widget.dart';
import 'package:iris_dp/features/visual_bible/widgets/catalog/shared/bible_references_widget.dart';
import 'package:iris_dp/features/visual_bible/widgets/catalog/shared/bible_tagged_text_widget.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );
    await tester.pump();
  }

  test('el catálogo registra shared y direction sin compositor', () {
    expect(BibleWidgetCatalog.all, hasLength(5));
    expect(
      BibleWidgetCatalog.forOrigin(BibleWidgetCatalogOrigin.shared),
      hasLength(3),
    );
    expect(
      BibleWidgetCatalog.forOrigin(BibleWidgetCatalogOrigin.direction),
      hasLength(2),
    );
    expect(
      BibleWidgetCatalog.byId(BibleWidgetCatalog.taggedText)?.subsectionKind,
      BibleBlockSchemas.narrativeIntent,
    );
    expect(BibleWidgetCatalog.widgetTypes, hasLength(5));
  });

  testWidgets('BibleTaggedTextWidget pinta texto, tags y glass', (
    tester,
  ) async {
    await pump(
      tester,
      const BibleTaggedTextWidget(
        text: 'La cámara observa',
        tags: ['TENSION', 'CALMA'],
      ),
    );
    expect(find.byType(BibleTaggedTextWidget), findsOneWidget);
    expect(find.byType(BibleDarkGlassPanel), findsOneWidget);
    expect(find.textContaining('INTENCIÓN NARRATIVA'), findsOneWidget);
    expect(find.textContaining('La cámara observa'), findsOneWidget);
    expect(find.text('TENSION'), findsOneWidget);
    expect(find.text('CALMA'), findsOneWidget);
  });

  testWidgets('BiblePointListWidget pinta puntos', (tester) async {
    await pump(
      tester,
      const BiblePointListWidget(
        points: [
          {'title': 'Frío e Industrial', 'body': 'Cian desaturado'},
        ],
      ),
    );
    expect(find.byType(BiblePointListWidget), findsOneWidget);
    expect(find.textContaining('TONO Y ATMÓSFERA'), findsOneWidget);
    expect(find.text('Frío e Industrial'), findsOneWidget);
    expect(find.text('Cian desaturado'), findsOneWidget);
  });

  testWidgets('BibleReferencesWidget narrative pinta ficha', (tester) async {
    await pump(
      tester,
      const BibleReferencesWidget(
        title: 'Referencias de dirección',
        mode: ReferencesWidgetMode.narrative,
        items: [
          BibleReferenceItem(
            moodboardImageId: 12,
            title: 'Composición y Espacio Negativo',
            body: 'Tercio inferior.',
            refLabel: 'REF: FINCHER / SE7EN',
            specs: [
              {'label': 'LENS', 'value': '35mm'},
            ],
          ),
        ],
      ),
    );
    expect(find.byType(BibleReferencesWidget), findsOneWidget);
    expect(find.textContaining('REFERENCIAS DE DIRECCIÓN'), findsOneWidget);
    expect(find.text('Composición y Espacio Negativo'), findsOneWidget);
    expect(find.text('Tercio inferior.'), findsOneWidget);
    expect(find.textContaining('FINCHER'), findsOneWidget);
    expect(find.text('35mm'), findsOneWidget);
  });

  testWidgets('DirectionVisualStrategyWidget pinta pilares', (tester) async {
    await pump(
      tester,
      const DirectionVisualStrategyWidget(
        pillars: [
          DirectionStrategyPillar(
            id: 'camera',
            title: 'Cámara',
            body: 'Dolly lento',
            icon: Icons.videocam_outlined,
          ),
          DirectionStrategyPillar(
            id: 'blocking',
            title: 'Blocking',
            body: 'Espacio negativo',
          ),
          DirectionStrategyPillar(id: 'pov', title: 'POV', body: '24mm-35mm'),
        ],
      ),
    );
    expect(find.byType(DirectionVisualStrategyWidget), findsOneWidget);
    expect(find.textContaining('ESTRATEGIA VISUAL'), findsOneWidget);
    expect(find.text('Cámara'), findsOneWidget);
    expect(find.text('Dolly lento'), findsOneWidget);
    expect(find.text('Blocking'), findsOneWidget);
    expect(find.text('POV'), findsOneWidget);
  });

  testWidgets('DirectionActsWidget pinta tres actos', (tester) async {
    await pump(
      tester,
      const DirectionActsWidget(
        acts: [
          DirectionActItem(
            phase: 'ACTO I: ESTABLECIMIENTO',
            title: 'Orden y Rigidez',
            body: 'Simetría',
          ),
          DirectionActItem(
            phase: 'ACTO II: DESESTABILIZACIÓN',
            title: 'Fragmentación',
            body: 'Holandeses',
          ),
          DirectionActItem(
            phase: 'ACTO III: RESOLUCIÓN',
            title: 'Abstracción',
            body: 'Siluetas',
          ),
        ],
      ),
    );
    expect(find.byType(DirectionActsWidget), findsOneWidget);
    expect(find.textContaining('INTENCIÓN VISUAL POR ACTO'), findsOneWidget);
    expect(find.text('Orden y Rigidez'), findsOneWidget);
    expect(find.text('Fragmentación'), findsOneWidget);
    expect(find.text('Abstracción'), findsOneWidget);
  });
}
