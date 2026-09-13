import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/bible_block_catalog.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_block.dart';
import 'package:iris_dp/features/visual_bible/v2/templates/bible_iris_standard_template.dart';
import 'package:iris_dp/features/visual_bible/v2/theme/bible_theme.dart';
import 'package:iris_dp/features/visual_bible/v2/widgets/bible_block_compositor.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_dark_glass_panel.dart';
import 'package:iris_dp/features/visual_bible/widgets/catalog/direction/direction_acts_widget.dart';
import 'package:iris_dp/features/visual_bible/widgets/catalog/direction/direction_visual_strategy_widget.dart';
import 'package:iris_dp/features/visual_bible/widgets/catalog/shared/bible_point_list_widget.dart';
import 'package:iris_dp/features/visual_bible/widgets/catalog/shared/bible_references_widget.dart';
import 'package:iris_dp/features/visual_bible/widgets/catalog/shared/bible_tagged_text_widget.dart';
import 'package:iris_dp/features/visual_bible/widgets/color_palette_strip.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpBlock(WidgetTester tester, BibleBlock block) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: BibleBlockRenderer(
            block: block,
            theme: BibleTheme.builtin(BibleThemeIds.irisStandard),
            projectId: 1,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('narrativeIntent usa panel glass y título', (tester) async {
    await pumpBlock(
      tester,
      const BibleBlock(
        id: 'n',
        type: BibleBlockKind.narrative,
        content: {
          'text': 'La cámara observa',
          'label': 'Intención narrativa',
          'subsectionKind': 'narrativeIntent',
        },
      ),
    );
    expect(find.byType(BibleDarkGlassPanel), findsOneWidget);
    expect(find.textContaining('INTENCIÓN NARRATIVA'), findsOneWidget);
    expect(find.textContaining('La cámara observa'), findsOneWidget);
    expect(find.byType(BibleTaggedTextWidget), findsOneWidget);
  });

  testWidgets('tonePoints usa BiblePointListWidget', (tester) async {
    await pumpBlock(
      tester,
      const BibleBlock(
        id: 'tone',
        type: BibleBlockKind.text,
        content: {
          'label': 'Tono y atmósfera',
          'subsectionKind': 'tonePoints',
          'points': [
            {'title': 'Frío e Industrial', 'body': 'Cian'},
          ],
        },
      ),
    );
    expect(find.byType(BiblePointListWidget), findsOneWidget);
    expect(find.text('Frío e Industrial'), findsOneWidget);
  });

  testWidgets('visualStrategy usa DirectionVisualStrategyWidget', (
    tester,
  ) async {
    await pumpBlock(
      tester,
      const BibleBlock(
        id: 'st',
        type: BibleBlockKind.text,
        content: {
          'subsectionKind': 'visualStrategy',
          'pillars': [
            {'id': 'camera', 'title': 'Cámara', 'body': 'Dolly'},
          ],
        },
      ),
    );
    expect(find.byType(DirectionVisualStrategyWidget), findsOneWidget);
    expect(find.text('Dolly'), findsOneWidget);
  });

  testWidgets('acts usa DirectionActsWidget', (tester) async {
    await pumpBlock(
      tester,
      const BibleBlock(
        id: 'acts',
        type: BibleBlockKind.dynamicBlocks,
        content: {
          'subsectionKind': 'acts',
          'acts': [
            {'phase': 'ACTO I', 'title': 'Orden y Rigidez', 'body': 'Simetría'},
          ],
        },
      ),
    );
    expect(find.byType(DirectionActsWidget), findsOneWidget);
    expect(find.text('Orden y Rigidez'), findsOneWidget);
  });

  testWidgets('narrativeRefs usa BibleReferencesWidget', (tester) async {
    await pumpBlock(
      tester,
      const BibleBlock(
        id: 'refs',
        type: BibleBlockKind.moodboardRefs,
        content: {
          'label': 'Referencias de dirección',
          'subsectionKind': 'narrativeRefs',
          'images': [
            {
              'title': 'Composición y Espacio Negativo',
              'body': 'Tercio inferior',
              'refLabel': 'FINCHER / SE7EN',
              'specs': [
                {'label': 'LENS', 'value': '35mm'},
              ],
            },
          ],
        },
      ),
    );
    expect(find.byType(BibleReferencesWidget), findsOneWidget);
    expect(find.text('Composición y Espacio Negativo'), findsOneWidget);
    expect(find.text('35mm'), findsOneWidget);
  });

  testWidgets('textField usa label en mono', (tester) async {
    await pumpBlock(
      tester,
      const BibleBlock(
        id: 't',
        type: BibleBlockKind.text,
        content: {
          'text': 'Cuerpo técnico',
          'label': 'Filosofía de cámara',
          'subsectionKind': 'textField',
        },
      ),
    );
    expect(find.textContaining('FILOSOFÍA DE CÁMARA'), findsOneWidget);
    expect(find.text('Cuerpo técnico'), findsOneWidget);
  });

  testWidgets('paletteTarget pinta ColorPaletteStrip', (tester) async {
    await pumpBlock(
      tester,
      const BibleBlock(
        id: 'p',
        type: BibleBlockKind.colorPalette,
        content: {
          'subsectionKind': 'paletteTarget',
          'colors': [
            {'hex': '#FF8800', 'name': 'Ámbar'},
          ],
        },
      ),
    );
    expect(find.byType(ColorPaletteStrip), findsOneWidget);
    expect(find.textContaining('Ámbar'), findsOneWidget);
  });

  testWidgets('headerTags renderiza chips', (tester) async {
    await pumpBlock(
      tester,
      const BibleBlock(
        id: 'c',
        type: BibleBlockKind.chipSelect,
        content: {
          'subsectionKind': 'headerTags',
          'chips': ['INT', 'NOCHE'],
          'selected': ['INT'],
        },
      ),
    );
    expect(find.text('INT'), findsOneWidget);
    expect(find.text('NOCHE'), findsOneWidget);
  });

  testWidgets('moodboardRefs V2 no se desvía a refs narrativas', (tester) async {
    await pumpBlock(
      tester,
      const BibleBlock(
        id: 'mb',
        type: BibleBlockKind.moodboardRefs,
        content: {
          'subsectionKind': 'moodboardRefs',
          'title': 'Referencias visuales',
          'images': <Map<String, dynamic>>[],
        },
      ),
    );
    expect(find.byType(BibleReferencesWidget), findsNothing);
    expect(find.textContaining('Sin referencias'), findsOneWidget);
  });

  testWidgets('página Moodboard IRIS monta en el compositor V2', (tester) async {
    final page = BibleIrisStandardTemplate.package.document!.pages
        .firstWhere((p) => p.id == 'moodboard');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: BibleBlockCompositor(
            blocks: page.blocks,
            theme: BibleTheme.builtin(BibleThemeIds.irisStandard),
            projectId: 1,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(BibleBlockRenderer), findsNWidgets(page.blocks.length));
    expect(find.byType(BibleReferencesWidget), findsNothing);
    expect(find.textContaining('Sin referencias'), findsOneWidget);
  });
}
