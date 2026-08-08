import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris_dp/features/visual_bible/bible_block_catalog.dart';
import 'package:iris_dp/features/visual_bible/data/visual_bible_repository.dart';
import 'package:iris_dp/features/visual_bible/export/builder/bible_export_composition_builder.dart';
import 'package:iris_dp/features/visual_bible/export/model/bible_export_composition.dart';
import 'package:iris_dp/features/visual_bible/export/store/bible_export_composition_store.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_block.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_document.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_page.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_export_config.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final now = DateTime.utc(2026, 8, 8, 10);
  final config = VisualBibleExportConfig(
    id: 'config-1',
    name: 'Entrega DP',
    audience: VisualBibleExportAudience.general,
    mode: VisualBibleExportMode.full,
    sections: const {BibleSectionId.direction, BibleSectionId.lighting},
    destination: VisualBibleExportDestination.saveFile,
    updatedAt: now,
  );

  VisualBibleExportBundle bundle({
    String direction = 'Mirada original',
    bool withLighting = false,
  }) => (
    data: VisualBibleData(
      id: 7,
      projectId: 4,
      directionNarrativeIntent: direction,
    ),
    blocks: <ColorBlockModel>[],
    exposureBlocks: <ExposureBlockModel>[],
    lightingSetups: withLighting
        ? [
            LightingSetupModel(
              id: 8,
              bibleId: 7,
              setupName: 'Ventana día',
              diagramJson:
                  '[{"type":"camera","x":120,"y":160},'
                  '{"type":"key","x":360,"y":80}]',
            ),
          ]
        : <LightingSetupModel>[],
    cameraTests: <CameraTestModel>[],
    moodboard: <MoodboardImageModel>[],
  );

  BibleDocument document({String direction = 'Mirada original'}) =>
      BibleDocument(
        bibleId: 7,
        projectId: 4,
        pages: [
          BiblePage(
            id: BibleSectionId.direction,
            groupId: 'narrative',
            label: 'Dirección',
            sortOrder: 0,
            blocks: [
              BibleBlock(
                id: 'direction-text',
                type: BibleBlockKind.narrative,
                content: {
                  'text': direction,
                  'tags': ['íntimo'],
                },
              ),
            ],
          ),
          const BiblePage(
            id: BibleSectionId.camera,
            groupId: 'technical',
            label: 'Cámara',
            sortOrder: 1,
          ),
          const BiblePage(
            id: BibleSectionId.lighting,
            groupId: 'technical',
            label: 'Iluminación',
            sortOrder: 2,
          ),
        ],
        updatedAt: now,
      );

  group('BibleExportComposition model', () {
    test('serializes page source, format, margins and config', () {
      final composition =
          BibleExportCompositionBuilder(
            idFactory: () => 'composition-1',
            clock: () => now,
          ).build(
            projectId: 4,
            config: config,
            bundle: bundle(),
            sourceDocument: document(),
            format: BibleExportPageFormat.a4Landscape,
            margins: const BibleExportPageMargins(
              top: 10,
              right: 20,
              bottom: 30,
              left: 40,
            ),
          );

      final decoded = BibleExportComposition.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(jsonEncode(composition.toJson())) as Map,
        ),
      );

      expect(decoded.schemaVersion, kBibleExportCompositionSchemaVersion);
      expect(decoded.config.id, config.id);
      expect(decoded.pages.first.type, BibleExportPageType.cover);
      expect(decoded.pages[1].format, BibleExportPageFormat.a4Landscape);
      expect(decoded.pages[1].margins.left, 40);
      expect(decoded.pages[1].source?.pageId, BibleSectionId.direction);
      expect(decoded.pages[1].annotationTargetId, 'composition-1__direction');
      expect(kBibleExportAnnotationTargetType, 'visual_bible_export_page');
    });
  });

  group('BibleExportCompositionBuilder', () {
    test('incluye los setups de iluminación como bloques editables', () {
      final composition =
          BibleExportCompositionBuilder(
            idFactory: () => 'composition-light',
            clock: () => now,
          ).build(
            projectId: 4,
            config: config,
            bundle: bundle(withLighting: true),
            sourceDocument: document(),
            includeCover: false,
          );

      final lighting = composition.pages.firstWhere(
        (page) => page.source?.sectionId == BibleSectionId.lighting,
      );
      expect(
        lighting.blocks.any(
          (block) => block.type == BibleBlockKind.lightingDiagram,
        ),
        isTrue,
      );
      expect(lighting.metadata['sourceBlocks'], isA<List>());
    });

    test('selects configured v2 pages without sharing mutable content', () {
      final source = document();
      final composition =
          BibleExportCompositionBuilder(
            idFactory: () => 'composition-1',
            clock: () => now,
          ).build(
            projectId: 4,
            config: config,
            bundle: bundle(),
            sourceDocument: source,
          );

      expect(composition.pages.map((page) => page.label), [
        'Entrega DP',
        'Dirección',
        'Iluminación',
      ]);
      final exportedTags =
          composition.pages[1].blocks.first.content['tags'] as List;
      exportedTags.add('cálido');
      expect(source.pages.first.blocks.first.content['tags'], ['íntimo']);
      expect(composition.metadata['source'], 'bible_document_v2');
    });

    test('uses legacy migrator when no v2 document is supplied', () {
      final composition =
          BibleExportCompositionBuilder(
            idFactory: () => 'legacy-composition',
            clock: () => now,
          ).build(
            projectId: 4,
            config: config,
            bundle: bundle(direction: 'Contraluz natural'),
            includeCover: false,
          );

      expect(composition.metadata['source'], 'legacy_migration');
      expect(
        composition.pages.first.blocks.any(
          (block) => block.content['text'] == 'Contraluz natural',
        ),
        isTrue,
      );
    });

    test('restores one edited page from current source', () {
      final builder = BibleExportCompositionBuilder(
        idFactory: () => 'composition-1',
        clock: () => now,
      );
      final original = builder.build(
        projectId: 4,
        config: config,
        bundle: bundle(),
        sourceDocument: document(),
        includeCover: false,
      );
      final editedPage = original.pages.first.copyWith(
        blocks: const [
          BibleBlock(
            id: 'custom',
            type: BibleBlockKind.text,
            content: {'text': 'Edición de montaje'},
          ),
        ],
      );
      final edited = original.copyWith(
        pages: [editedPage, ...original.pages.skip(1)],
      );

      final restored = builder.restorePage(
        composition: edited,
        pageId: editedPage.id,
        bundle: bundle(),
        sourceDocument: document(direction: 'Fuente actualizada'),
      );

      expect(restored.pages.first.id, editedPage.id);
      expect(
        restored.pages.first.blocks.first.content['text'],
        'Fuente actualizada',
      );
      expect(restored.pages[1], same(edited.pages[1]));
    });
  });

  group('BibleExportCompositionStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('saves bounded versions and restores as a new revision', () async {
      final preferences = await SharedPreferences.getInstance();
      var tick = 0;
      final store = BibleExportCompositionStore(
        preferences,
        maxVersions: 3,
        clock: () => now.add(Duration(minutes: tick++)),
      );
      var composition =
          BibleExportCompositionBuilder(
            idFactory: () => 'composition-1',
            clock: () => now,
          ).build(
            projectId: 4,
            config: config,
            bundle: bundle(),
            sourceDocument: document(),
          );

      composition = await store.save(composition, label: 'Inicial');
      composition = await store.save(composition, label: 'Segunda');
      composition = await store.save(composition, label: 'Tercera');
      composition = await store.save(composition, label: 'Cuarta');

      final versions = await store.loadVersions(4, composition.id);
      expect(versions.map((version) => version.revision), [2, 3, 4]);
      expect((await store.loadLatest(4, composition.id))?.revision, 4);
      expect(await store.listLatest(4), hasLength(1));

      final restored = await store.restoreVersion(
        projectId: 4,
        compositionId: composition.id,
        revision: 2,
      );
      expect(restored.revision, 5);
      expect(
        (await store.loadVersions(4, composition.id)).last.label,
        'Restaurada desde revisión 2',
      );

      await store.delete(4, composition.id);
      expect(await store.loadLatest(4, composition.id), isNull);
      expect(await store.listLatest(4), isEmpty);
    });
  });
}
