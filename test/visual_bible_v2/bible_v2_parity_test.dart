import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/bible_block_catalog.dart';
import 'package:iris_dp/features/visual_bible/bible_blueprint.dart';
import 'package:iris_dp/features/visual_bible/v2/bible_engine_v2_flag.dart';
import 'package:iris_dp/features/visual_bible/v2/layout/page_layout_recipe_registry.dart';
import 'package:iris_dp/features/visual_bible/v2/migration/legacy_to_document_migrator.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_block.dart';
import 'package:iris_dp/features/visual_bible/v2/theme/bible_theme.dart';
import 'package:iris_dp/features/visual_bible/v2/widgets/bible_block_compositor.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('las 13 secciones canónicas tienen receta v2', () {
    for (final id in BibleSectionId.all) {
      expect(
        PageLayoutRecipeRegistry.recipeIdForSection(id),
        isNotNull,
        reason: '$id debe tener receta',
      );
    }
  });

  test('migrador asigna layoutRecipeId a cada sección canónica', () {
    final doc = LegacyToDocumentMigrator.migrate(
      projectId: 1,
      bibleId: 2,
      groups: const [
        LegacyBibleGroupSnapshot(id: 'main', label: 'Main'),
      ],
      sections: [
        for (var i = 0; i < BibleSectionId.all.length; i++)
          LegacyBibleSectionSnapshot(
            id: BibleSectionId.all[i],
            groupId: 'main',
            label: BibleSectionId.label(BibleSectionId.all[i]),
            sortOrder: i,
          ),
      ],
    );

    expect(doc.pages, hasLength(BibleSectionId.all.length));
    for (final page in doc.pages) {
      expect(page.layoutRecipeId, isNotNull, reason: page.legacySectionId);
      expect(
        page.layoutRecipeId,
        PageLayoutRecipeRegistry.recipeIdForSection(page.legacySectionId!),
      );
    }
  });

  test('flag v2 sigue apagado por defecto', () async {
    SharedPreferences.setMockInitialValues({});
    expect(await BibleEngineV2Flag.isEnabled(99), isFalse);
  });

  test('color_image pack no recomienda dynamicBlocks', () {
    expect(
      BibleBlueprintPacks.blocksFor(
        BibleSectionId.colorImage,
        BibleBlueprintType.fiction,
      ),
      isNot(contains(BibleBlockKind.dynamicBlocks)),
    );
  });

  testWidgets('kinds live renderizan en compositor', (tester) async {
    final theme = BibleTheme.builtin(BibleThemeIds.cinematic);
    final live = BibleBlockKind.values
        .where((k) => k.status == BibleBlockStatus.live)
        .toList();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ListView(
            children: [
              for (final kind in live)
                SizedBox(
                  height: 160,
                  child: BibleBlockRenderer(
                    block: BibleBlock(
                      id: kind.name,
                      type: kind,
                      content: _smokeContent(kind),
                    ),
                    theme: theme,
                    projectId: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(BibleBlockRenderer), findsWidgets);
    expect(find.textContaining('Luz íntima'), findsOneWidget);
  });
}

Map<String, dynamic> _smokeContent(BibleBlockKind kind) => switch (kind) {
  BibleBlockKind.narrative => {'text': 'Luz íntima'},
  BibleBlockKind.text => {'text': 'Cuerpo'},
  BibleBlockKind.moodboardRefs => {'images': <Map<String, dynamic>>[]},
  BibleBlockKind.colorPalette => {
    'colors': [
      {'hex': '#FF8800', 'name': 'Ámbar'},
    ],
  },
  BibleBlockKind.telemetry => {'kelvin': '3200K'},
  BibleBlockKind.chipSelect => {
    'chips': ['TENSIÓN'],
    'selected': <String>[],
  },
  BibleBlockKind.equipmentList => {
    'items': ['Fresnel'],
  },
  BibleBlockKind.specsTable => {
    'columns': ['label', 'value'],
    'rows': [
      {'label': 'ISO', 'value': '800'},
    ],
  },
  BibleBlockKind.workflowPipeline => {'steps': kBibleWorkflowDefaultSteps},
  BibleBlockKind.lightingDiagram => {
    'label': 'Setup',
    'nodes': [
      {'type': 'key', 'x': 80, 'y': 80},
    ],
  },
  BibleBlockKind.heroImage => <String, dynamic>{},
  BibleBlockKind.dynamicBlocks => {'count': 0},
};
