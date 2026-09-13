import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/bible_block_catalog.dart';
import 'package:iris_dp/features/visual_bible/v2/bible_block_contract.dart';
import 'package:iris_dp/features/visual_bible/v2/bible_block_schemas.dart';
import 'package:iris_dp/features/visual_bible/v2/layout/bible_grid_layout.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_block.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_block_layout.dart';

void main() {
  test('el catálogo picker solo ofrece contratos completos', () {
    expect(
      BibleBlockCatalog.pickerKinds.toSet(),
      BibleBlockContract.completeKinds.toSet(),
    );
    expect(BibleBlockKind.dynamicBlocks.status, BibleBlockStatus.live);
  });

  test('grid agrupa por fila y respeta colSpan', () {
    final blocks = [
      BibleBlock(
        id: 'a',
        type: BibleBlockKind.text,
        layout: const BibleBlockLayout(row: 0, col: 0, colSpan: 6),
      ),
      BibleBlock(
        id: 'b',
        type: BibleBlockKind.narrative,
        layout: const BibleBlockLayout(row: 0, col: 6, colSpan: 6),
      ),
      BibleBlock(
        id: 'c',
        type: BibleBlockKind.heroImage,
        layout: const BibleBlockLayout(row: 1, col: 0, colSpan: 12),
      ),
    ];
    final rows = BibleGridLayout.rows(blocks);
    expect(rows, hasLength(2));
    expect(rows.first.map((b) => b.id), ['a', 'b']);
    expect(BibleGridLayout.rowFitsGrid(rows.first), isTrue);
    expect(BibleGridLayout.rowFitsGrid(rows.last), isFalse);
  });

  test('dynamicBlocks anida JSON de bloques o items', () {
    final parent = BibleBlock(
      id: 'dyn',
      type: BibleBlockKind.dynamicBlocks,
      content: {
        'blocks': [
          {
            'id': 'n1',
            'type': 'text',
            'content': {'text': 'Hola'},
          },
          {'title': 'Setup', 'text': 'Key suave'},
        ],
      },
    );
    final nested = BibleGridLayout.nestedBlocks(parent);
    expect(nested, hasLength(2));
    expect(nested.first.type, BibleBlockKind.text);
    expect(nested.first.content['text'], 'Hola');
    expect(nested.last.content['label'], 'Setup');
  });

  test('narrative y text incluyen tags y points en el contrato', () {
    final narrative = BibleBlockContract.defaultContent(
      BibleBlockKind.narrative,
    );
    expect(narrative['tags'], isEmpty);
    expect(narrative['text'], '');

    final text = BibleBlockContract.defaultContent(BibleBlockKind.text);
    expect(text['points'], isEmpty);
    expect(text['text'], '');
  });

  test('schemas de subsection Dirección son tagged text o point list', () {
    expect(
      BibleBlockContract.defaultContentForSubsection(
        BibleBlockSchemas.narrativeIntent,
      )['tags'],
      isEmpty,
    );
    expect(
      BibleBlockContract.defaultContentForSubsection(
        BibleBlockSchemas.tonePoints,
      )['points'],
      isEmpty,
    );
    expect(
      BibleBlockContract.defaultContentForSubsection(
        BibleBlockSchemas.transitions,
      )['label'],
      'Lenguaje de transiciones',
    );
    expect(BibleBlockSchemas.approvedDirectionLegacyFieldKeys, {
      'toneStrategies': BibleBlockSchemas.tonePoints,
      'transitionLanguage': BibleBlockSchemas.transitions,
      'emotionTags': BibleBlockSchemas.narrativeIntent,
    });
  });
}
