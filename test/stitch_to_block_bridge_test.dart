import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/visual_bible/bible_kind_block_mapping.dart';
import 'package:iris_dp/features/visual_bible/v2/migration/stitch_to_block_bridge.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:iris_dp/shared/visual_bible/bible_subsection_kind_catalog.dart';
import 'package:iris_dp/shared/visual_bible/bible_widget_size.dart';
import 'package:iris_dp/features/visual_bible/bible_block_catalog.dart';

void main() {
  test('fieldToBlock maps size to colSpan', () {
    const field = BibleSectionField(
      key: 'globalMetrics',
      label: 'Métricas',
      type: BibleSectionFieldType.blocks,
      kind: BibleSubsectionKindId.telemetryPanel,
      size: BibleWidgetSize.medium,
      binding: 'globalMetrics',
    );
    final block = StitchToBlockBridge.fieldToBlock(
      sectionId: BibleSectionId.lighting,
      field: field,
      row: 0,
    );
    expect(block.layout.colSpan, 6);
    expect(block.type, BibleBlockKind.telemetry);
  });

  test('blockKindForField uses subsection kind', () {
    const field = BibleSectionField(
      key: 'filmRefs',
      label: 'Film',
      type: BibleSectionFieldType.blocks,
      kind: BibleSubsectionKindId.cardDeck,
    );
    expect(
      BibleKindBlockMapping.blockKindForField(
        BibleSectionId.lighting,
        field,
      ),
      BibleBlockKind.dynamicBlocks,
    );
  });
}
