import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/features/visual_bible/bible_block_catalog.dart';
import 'package:iris_dp/features/visual_bible/export/commands/bible_export_composition_history.dart';
import 'package:iris_dp/features/visual_bible/export/model/bible_export_composition.dart';
import 'package:iris_dp/features/visual_bible/v2/model/bible_block.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_export_config.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';

void main() {
  final now = DateTime.utc(2026, 8, 8);
  final config = VisualBibleExportConfig(
    id: 'config',
    name: 'Montaje',
    audience: VisualBibleExportAudience.general,
    mode: VisualBibleExportMode.full,
    sections: const {},
    destination: VisualBibleExportDestination.saveFile,
    updatedAt: now,
  );

  BibleExportComposition composition() => BibleExportComposition(
    id: 'composition',
    projectId: 1,
    config: config,
    pages: const [
      BibleExportPage(id: 'a', label: 'A', type: BibleExportPageType.generated),
      BibleExportPage(
        id: 'b',
        label: 'B',
        type: BibleExportPageType.generated,
        sortOrder: 1,
      ),
      BibleExportPage(
        id: 'c',
        label: 'C',
        type: BibleExportPageType.generated,
        sortOrder: 2,
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );

  test('reordena páginas y normaliza sortOrder', () {
    final reordered = reorderBibleExportPages(composition(), 0, 2);

    expect(reordered.pages.map((page) => page.id), ['b', 'c', 'a']);
    expect(reordered.pages.map((page) => page.sortOrder), [0, 1, 2]);
  });

  test('deshace y rehace edición de un bloque', () {
    final initial = composition();
    final history = BibleExportCompositionHistory(initial);
    const block = BibleBlock(
      id: 'text',
      type: BibleBlockKind.text,
      content: {'text': 'Nota'},
    );

    final edited = history.execute(
      (current) => replaceBibleExportPage(
        current,
        current.pages.first.copyWith(blocks: const [block]),
      ),
    );

    expect(edited.pages.first.blocks.single.id, 'text');
    expect(history.canUndo, isTrue);
    expect(history.undo()?.pages.first.blocks, isEmpty);
    expect(history.redo()?.pages.first.blocks.single.id, 'text');
  });

  test('añade un folio al final', () {
    const blank = BibleExportPage(
      id: 'blank',
      label: 'Folio blanco',
      type: BibleExportPageType.blank,
    );

    final edited = appendBibleExportPage(composition(), blank);

    expect(edited.pages.last.id, 'blank');
    expect(edited.pages.last.sortOrder, 3);
  });
}
