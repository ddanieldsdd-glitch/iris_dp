import '../../../../shared/visual_bible/bible_section_fields.dart';
import '../../../../shared/visual_bible/bible_widget_size.dart';
import '../../bible_block_catalog.dart';
import '../../bible_kind_block_mapping.dart';
import '../model/bible_block.dart';
import '../model/bible_block_layout.dart';
import '../model/project_entity_reference.dart';

/// Convierte instancias Stitch (fields con kind + size S/M/L) a [BibleBlock] v2.
abstract final class StitchToBlockBridge {
  static BibleBlock fieldToBlock({
    required String sectionId,
    required BibleSectionField field,
    required int row,
    Map<String, String>? values,
  }) {
    final kind = BibleKindBlockMapping.blockKindForField(sectionId, field);
    final colSpan = field.size.colSpan;
    final rowSpan = switch (field.size) {
      BibleWidgetSize.small => 1,
      BibleWidgetSize.medium => 2,
      BibleWidgetSize.large => switch (kind) {
          BibleBlockKind.narrative ||
          BibleBlockKind.moodboardRefs ||
          BibleBlockKind.heroImage =>
            3,
          _ => 2,
        },
    };

    final content = <String, dynamic>{
      'label': field.label,
      if (field.hint != null) 'hint': field.hint,
      'maxLines': field.maxLines,
      'text': values?[field.key] ?? '',
      'fieldKey': field.key,
      'widgetSize': field.size.storageKey,
      'subsectionKind': field.resolvedKind(sectionId).name,
      if (field.binding != null) 'binding': field.binding,
    };

    return BibleBlock(
      id: '${sectionId}__${field.key}',
      type: kind,
      layout: BibleBlockLayout(
        col: 0,
        row: row,
        colSpan: colSpan,
        rowSpan: rowSpan,
      ),
      content: content,
      binding: field.binding != null
          ? ProjectEntityReference(
              entity: 'stitch_binding',
              id: field.binding!,
            )
          : null,
    );
  }

  static List<BibleBlock> fieldsToBlocks({
    required String sectionId,
    required List<BibleSectionField> fields,
    Map<String, String>? values,
  }) {
    final blocks = <BibleBlock>[];
    var row = 0;
    for (final field in fields) {
      blocks.add(
        fieldToBlock(
          sectionId: sectionId,
          field: field,
          row: row,
          values: values,
        ),
      );
      row += field.size == BibleWidgetSize.small ? 1 : 2;
    }
    return blocks;
  }
}
