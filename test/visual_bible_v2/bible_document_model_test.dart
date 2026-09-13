import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/features/visual_bible/bible_block_catalog.dart';
import 'package:iris_dp/features/visual_bible/bible_blueprint.dart';
import 'package:iris_dp/features/visual_bible/v2/ai/bible_ai_assist.dart';
import 'package:iris_dp/features/visual_bible/v2/commands/bible_document_history.dart';
import 'package:iris_dp/features/visual_bible/v2/commands/bible_editor_commands.dart';
import 'package:iris_dp/features/visual_bible/v2/bible_block_schemas.dart';
import 'package:iris_dp/features/visual_bible/v2/migration/legacy_to_document_migrator.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_block.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_block_layout.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_document.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_page.dart';
import 'package:iris_dp/features/visual_bible/v2/pdf/bible_pdf_layout_bridge.dart';
import 'package:iris_dp/features/visual_bible/v2/templates/bible_template_package.dart';
import 'package:iris_dp/features/visual_bible/v2/theme/bible_theme.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';

void main() {
  group('BibleDocument serialize', () {
    test('roundtrip', () {
      final doc = BibleDocument(
        projectId: 1,
        bibleId: 9,
        themeId: BibleThemeIds.technical,
        groups: const [
          BibleDocumentGroup(id: 'g1', label: 'Narrativa', sortOrder: 0),
        ],
        pages: [
          BiblePage(
            id: BibleSectionId.direction,
            groupId: 'g1',
            label: 'Dirección',
            blocks: [
              BibleBlock(
                id: 'b1',
                type: BibleBlockKind.narrative,
                layout: const BibleBlockLayout(colSpan: 6),
                content: const {'text': 'Hello'},
              ),
            ],
          ),
        ],
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      final encoded = LegacyToDocumentMigrator.encode(doc);
      final decoded = LegacyToDocumentMigrator.decode(encoded);
      expect(decoded.projectId, 1);
      expect(decoded.bibleId, 9);
      expect(decoded.themeId, BibleThemeIds.technical);
      expect(decoded.pages.first.blocks.first.content['text'], 'Hello');
      expect(decoded.pages.first.blocks.first.layout.colSpan, 6);
    });
  });

  group('LegacyToDocumentMigrator', () {
    test('maps fields to blocks', () {
      final doc = LegacyToDocumentMigrator.migrate(
        projectId: 3,
        bibleId: 1,
        defaultStyle: BibleSectionStyle.cinematic,
        groups: const [
          LegacyBibleGroupSnapshot(id: 'narrative', label: 'Narrativa'),
        ],
        sections: const [
          LegacyBibleSectionSnapshot(
            id: BibleSectionId.direction,
            groupId: 'narrative',
            label: 'Dirección',
            template: 'standard',
          ),
        ],
      );
      expect(doc.pages, isNotEmpty);
      expect(doc.pages.first.legacySectionId, BibleSectionId.direction);
      expect(doc.pages.first.blocks, isNotEmpty);
      expect(
        doc.pages.first.blocks.any((b) => b.type == BibleBlockKind.narrative),
        isTrue,
      );
    });

    test('mapea solo toneStrategies, transitionLanguage y emotionTags', () {
      final values = {
        'directionData': jsonEncode({
          'emotionTags': ['TENSION', 'CLAUSTROPHOBIA'],
          'tonePoints': [
            {'title': 'Frío', 'body': 'Cian'},
          ],
          'transitionLanguage': [
            {'title': 'Match', 'body': 'Líneas'},
          ],
          'sceneTag': 'SCENE 01 / INT. APARTMENT',
          'extraStrategies': [
            {'title': 'Luz', 'body': 'Hard'},
          ],
          'act1Title': 'Orden',
          'keyFrameIntent': 'Hero',
        }),
      };
      final contentJson = BibleSectionFieldsConfig.encode(
        BibleSectionFieldsConfig.defaultsFor(BibleSectionId.direction),
        values: values,
      );
      final doc = LegacyToDocumentMigrator.migrate(
        projectId: 3,
        bibleId: 1,
        groups: const [
          LegacyBibleGroupSnapshot(id: 'narrative', label: 'Narrativa'),
        ],
        sections: [
          LegacyBibleSectionSnapshot(
            id: BibleSectionId.direction,
            groupId: 'narrative',
            label: 'Dirección',
            template: 'standard',
            contentJson: contentJson,
          ),
        ],
      );
      final blocks = doc.pages.first.blocks;
      BibleBlock byKey(String key) =>
          blocks.firstWhere((b) => b.content['fieldKey'] == key);

      final narrative = byKey('narrative');
      expect(
        narrative.content['subsectionKind'],
        BibleBlockSchemas.narrativeIntent,
      );
      expect(narrative.content['tags'], ['TENSION', 'CLAUSTROPHOBIA']);

      final tone = byKey('toneStrategies');
      expect(tone.content['subsectionKind'], BibleBlockSchemas.tonePoints);
      expect(tone.content['points'], [
        {'title': 'Frío', 'body': 'Cian'},
      ]);

      final transitions = byKey('transitions');
      expect(
        transitions.content['subsectionKind'],
        BibleBlockSchemas.transitions,
      );
      expect(transitions.content['points'], [
        {'title': 'Match', 'body': 'Líneas'},
      ]);

      final acts = byKey('acts');
      expect(acts.content['act1Title'], isNull);
      expect(acts.content['points'], isNull);
      expect(blocks.every((b) => b.content['sceneTag'] == null), isTrue);
      expect(blocks.every((b) => b.content['keyFrameIntent'] == null), isTrue);
    });
  });

  group('BibleDocumentHistory', () {
    test('undo redo add/delete', () {
      final empty = BibleDocument(
        projectId: 1,
        pages: [const BiblePage(id: 'p1', groupId: 'g', label: 'Page')],
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final history = BibleDocumentHistory(empty);
      final block = const BibleBlock(id: 'x', type: BibleBlockKind.text);

      history.execute(AddBlockCommand(pageId: 'p1', block: block));
      expect(history.current.pages.first.blocks, hasLength(1));

      history.undo();
      expect(history.current.pages.first.blocks, isEmpty);

      history.redo();
      expect(history.current.pages.first.blocks.first.id, 'x');

      history.execute(
        DeleteBlockCommand(pageId: 'p1', removed: block, index: 0),
      );
      expect(history.current.pages.first.blocks, isEmpty);
      history.undo();
      expect(history.current.pages.first.blocks, hasLength(1));
    });
  });

  group('BibleTemplatePackage', () {
    test('fromDocument + duplicate version', () {
      final doc = BibleDocument(
        projectId: 1,
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final pack = BibleTemplatePackage.fromDocument(
        document: doc,
        id: 't1',
        name: 'My Template',
      );
      final copy = pack.duplicate(newId: 't2');
      expect(copy.version, 2);
      expect(
        BibleTemplatePackage.tryDecode(pack.encode())?.name,
        'My Template',
      );
    });
  });

  group('BiblePdfLayoutBridge', () {
    test('emits pages payload', () {
      final doc = BibleDocument(
        projectId: 1,
        pages: const [BiblePage(id: 'p1', groupId: 'g', label: 'A')],
        updatedAt: DateTime.utc(2026, 1, 1),
      );
      final payload = BiblePdfLayoutBridge.layoutPayload(doc);
      expect(payload['pages'], isA<List>());
      expect((payload['pages'] as List).first['id'], 'p1');
      expect(payload['gridColumns'], 12);
    });
  });

  group('BibleAiAssist', () {
    test('analyzeGaps', () {
      final gaps = BibleAiAssist.analyzeGaps(
        hasPrimaryCamera: false,
        hasPrimaryLens: true,
        hasMoodboardRefs: false,
        hasLightingSetup: true,
        hasColorPalette: true,
      );
      expect(gaps.length, 2);
    });

    test('suggestWidgets', () {
      expect(
        BibleAiAssist.suggestWidgets('ISO 800 Codec ARRIRAW'),
        contains('specsTable'),
      );
    });
  });

  group('BibleBlockKind status', () {
    test('pickerKinds incluye todos los kinds live', () {
      expect(
        BibleBlockCatalog.pickerKinds,
        contains(BibleBlockKind.dynamicBlocks),
      );
      expect(BibleBlockKind.text.status, BibleBlockStatus.live);
      expect(BibleBlockKind.moodboardRefs.status, BibleBlockStatus.live);
      expect(BibleBlockKind.colorPalette.status, BibleBlockStatus.live);
      expect(BibleBlockKind.telemetry.status, BibleBlockStatus.live);
      expect(BibleBlockKind.lightingDiagram.status, BibleBlockStatus.live);
      expect(BibleBlockKind.workflowPipeline.status, BibleBlockStatus.live);
      expect(BibleBlockKind.dynamicBlocks.status, BibleBlockStatus.live);
      expect(
        BibleBlockCatalog.pickerKinds,
        contains(BibleBlockKind.moodboardRefs),
      );
    });
  });

  group('BiblePdfLayoutBridge gaps', () {
    test('no deja gaps de PDF clásico', () {
      expect(BiblePdfLayoutBridge.pdfGaps, isEmpty);
      expect(BiblePdfLayoutBridge.gridColumns, 12);
    });
  });
}
