import 'dart:convert';

import '../../../../shared/visual_bible/bible_section_fields.dart';
import '../../bible_block_catalog.dart';
import '../../bible_blueprint.dart';
import '../../visual_bible_model.dart';
import '../model/bible_block.dart';
import '../model/bible_block_layout.dart';
import '../model/bible_document.dart';
import '../model/bible_page.dart';
import '../migration/freeform_v2_blocks_codec.dart';
import '../layout/page_layout_recipe_registry.dart';
import '../model/bible_page_mode.dart';
import '../theme/bible_theme.dart';

/// Entrada legacy mínima para migración (sin acoplar a Drift en tests).
class LegacyBibleSectionSnapshot {
  final String id;
  final String groupId;
  final String label;
  final String? iconKey;
  final int sortOrder;
  final bool isHidden;
  final String template;
  final String? contentJson;

  const LegacyBibleSectionSnapshot({
    required this.id,
    required this.groupId,
    required this.label,
    this.iconKey,
    this.sortOrder = 0,
    this.isHidden = false,
    this.template = 'standard',
    this.contentJson,
  });
}

class LegacyBibleGroupSnapshot {
  final String id;
  final String label;
  final int sortOrder;

  const LegacyBibleGroupSnapshot({
    required this.id,
    required this.label,
    this.sortOrder = 0,
  });
}

/// Convierte Group→Section→Fields a [BibleDocument] (read-only / lazy).
///
/// No escribe en DB legacy. Reversible: conserva `legacySectionId`.
abstract final class LegacyToDocumentMigrator {
  static BibleDocument migrate({
    required int projectId,
    int? bibleId,
    required List<LegacyBibleGroupSnapshot> groups,
    required List<LegacyBibleSectionSnapshot> sections,
    VisualBibleData? data,
    BibleSectionStyle? defaultStyle,
    String? lastPageId,
  }) {
    final themeId = switch (defaultStyle) {
      BibleSectionStyle.technical => BibleThemeIds.technical,
      BibleSectionStyle.minimalist => BibleThemeIds.minimalist,
      _ => BibleThemeIds.cinematic,
    };

    final docGroups =
        groups
            .map(
              (g) => BibleDocumentGroup(
                id: g.id,
                label: g.label,
                sortOrder: g.sortOrder,
              ),
            )
            .toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final pages = <BiblePage>[];
    for (final s in sections) {
      if (s.id == 'settings') continue;
      final isFreeform = s.template == 'freeform';
      final recipeId = isFreeform
          ? PageLayoutRecipeRegistry.freeformGrid
          : PageLayoutRecipeRegistry.recipeIdForSection(s.id);
      pages.add(
        BiblePage(
          id: s.id,
          groupId: s.groupId,
          label: s.label,
          iconKey: s.iconKey,
          sortOrder: s.sortOrder,
          isHidden: s.isHidden,
          legacySectionId: s.id,
          legacyTemplate: s.template,
          layoutRecipeId: recipeId,
          pageMode: isFreeform ? BiblePageMode.freeform : BiblePageMode.recipe,
          blocks: _blocksFromSection(s, data),
        ),
      );
    }
    pages.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return BibleDocument(
      bibleId: bibleId,
      projectId: projectId,
      themeId: themeId,
      themes: const [],
      groups: docGroups,
      pages: pages,
      navigation: {if (lastPageId != null) 'lastPageId': lastPageId},
      updatedAt: DateTime.now().toUtc(),
    );
  }

  static List<BibleBlock> _blocksFromSection(
    LegacyBibleSectionSnapshot section,
    VisualBibleData? data,
  ) {
    if (section.template == 'freeform') {
      final v2Blocks = FreeformV2BlocksCodec.parseBlocks(section.contentJson);
      if (v2Blocks.isNotEmpty) return v2Blocks;
    }

    final fields = BibleSectionFieldsConfig.parse(
      section.contentJson,
      section.id,
    );
    final values = BibleSectionFieldsConfig.parseValues(section.contentJson);
    final blocks = <BibleBlock>[];
    var row = 0;

    for (final field in fields) {
      final kind = _kindForField(field);
      final content = <String, dynamic>{
        'label': field.label,
        if (field.hint != null) 'hint': field.hint,
        'maxLines': field.maxLines,
        'text': values[field.key] ?? '',
        'fieldKey': field.key,
      };

      // Enriquecer con columnas fat de VisualBibleData cuando existan.
      if (data != null) {
        _enrichContentFromData(section.id, field.key, content, data);
      }

      blocks.add(
        BibleBlock(
          id: '${section.id}__${field.key}',
          type: kind,
          layout: BibleBlockLayout(
            col: 0,
            row: row,
            colSpan:
                kind == BibleBlockKind.moodboardRefs ||
                    kind == BibleBlockKind.heroImage
                ? 12
                : 12,
            rowSpan: kind == BibleBlockKind.narrative ? 3 : 2,
          ),
          content: content,
        ),
      );
      row += 2;
    }

    if (blocks.isEmpty) {
      blocks.add(
        BibleBlock(
          id: '${section.id}__empty',
          type: BibleBlockKind.text,
          content: {'label': section.label, 'text': '', 'placeholder': true},
        ),
      );
    }

    return blocks;
  }

  static BibleBlockKind _kindForField(BibleSectionField field) {
    return switch (field.type) {
      BibleSectionFieldType.narrative => BibleBlockKind.narrative,
      BibleSectionFieldType.references ||
      BibleSectionFieldType.image => BibleBlockKind.moodboardRefs,
      BibleSectionFieldType.blocks => BibleBlockKind.dynamicBlocks,
      BibleSectionFieldType.text => BibleBlockKind.text,
    };
  }

  static void _enrichContentFromData(
    String sectionId,
    String fieldKey,
    Map<String, dynamic> content,
    VisualBibleData data,
  ) {
    if (fieldKey == 'narrative') {
      final narrative = _narrativeForSection(sectionId, data);
      if (narrative != null && narrative.isNotEmpty) {
        content['text'] = narrative;
      }
      return;
    }
    final extra = _fieldValueForSection(sectionId, fieldKey, data);
    if (extra != null && extra.isNotEmpty) {
      content['text'] = extra;
    }
  }

  static String? _fieldValueForSection(
    String sectionId,
    String fieldKey,
    VisualBibleData data,
  ) {
    return switch ((sectionId, fieldKey)) {
      ('direction', 'tone') => data.tone,
      ('direction', 'creativeIntention') => data.creativeIntention,
      ('direction', 'stagingApproach') => data.stagingApproach,
      ('direction', 'pointOfView') => data.pointOfView,
      ('concept', 'visualConcept') => data.visualConcept,
      ('concept', 'contrastStyle') => data.contrastStyle,
      ('camera', 'philosophy') => data.cameraPhilosophy,
      ('camera', 'movements') => data.movementStyle,
      ('optics', 'opticSettings') => data.lensPhilosophy,
      ('lighting', 'philosophy') => data.lightingPhilosophy,
      ('format', 'formatSettings') => data.aspectRatioJustification,
      ('texture', 'textureSettings') => data.imageTexture,
      _ => null,
    };
  }

  static String? _narrativeForSection(String sectionId, VisualBibleData data) {
    return switch (sectionId) {
      'direction' => data.directionNarrativeIntent ?? data.creativeIntention,
      'concept' => data.conceptNarrativeIntent ?? data.visualConcept,
      'camera' => data.cameraNarrativeIntent ?? data.cameraPhilosophy,
      'optics' => data.opticsNarrativeIntent ?? data.lensPhilosophy,
      'exposure' => data.exposureNarrativeIntent,
      'lighting' => data.lightingNarrativeIntent ?? data.lightingPhilosophy,
      'color_image' => data.colorNarrativeIntent,
      'format' => data.formatNarrativeIntent ?? data.aspectRatioJustification,
      'texture' => data.textureNarrativeIntent ?? data.imageTexture,
      'workflow' => data.workflowPipeline,
      _ => null,
    };
  }

  /// Serializa documento a JSON string (para store / tests).
  static String encode(BibleDocument doc) => jsonEncode(doc.toJson());

  static BibleDocument decode(String raw) =>
      BibleDocument.fromJson(jsonDecode(raw) as Map<String, dynamic>);
}
