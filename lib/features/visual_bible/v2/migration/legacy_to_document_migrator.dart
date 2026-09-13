import 'dart:convert';

import '../../../../shared/visual_bible/bible_section_fields.dart';
import '../../../../shared/visual_bible/bible_widget_size.dart';
import '../../bible_block_catalog.dart';
import '../../bible_blueprint.dart';
import '../../visual_bible_model.dart';
import '../model/bible_block.dart';
import '../model/bible_document.dart';
import '../model/bible_page.dart';
import '../migration/freeform_v2_blocks_codec.dart';
import '../migration/stitch_to_block_bridge.dart';
import '../layout/page_layout_recipe_registry.dart';
import '../bible_block_schemas.dart';
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
      migrationVersion: 1,
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
      final content = <String, dynamic>{
        'label': field.label,
        if (field.hint != null) 'hint': field.hint,
        'maxLines': field.maxLines,
        'text': values[field.key] ?? '',
        'fieldKey': field.key,
      };

      if (data != null) {
        _enrichContentFromData(section.id, field.key, content, data);
      }

      final block = StitchToBlockBridge.fieldToBlock(
        sectionId: section.id,
        field: field,
        row: row,
        values: values,
      );
      final merged = <String, dynamic>{...block.content, ...content};
      if (section.id == 'direction') {
        _applyApprovedDirectionFieldMapping(
          fieldKey: field.key,
          content: merged,
          directionData: _parseDirectionData(values),
        );
      }
      blocks.add(block.copyWith(content: merged));
      row += field.size == BibleWidgetSize.small ? 1 : 2;
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

  /// Solo los fieldKeys de [BibleBlockSchemas.approvedDirectionLegacyFieldKeys].
  static void _applyApprovedDirectionFieldMapping({
    required String fieldKey,
    required Map<String, dynamic> content,
    required Map<String, dynamic> directionData,
  }) {
    if (fieldKey == 'toneStrategies') {
      content['subsectionKind'] = BibleBlockSchemas.tonePoints;
      final points = BibleBlockSchemas.parsePointList(
        directionData['tonePoints'],
      );
      if (points.isNotEmpty) content['points'] = points;
      return;
    }

    if (fieldKey == 'transitionLanguage' || fieldKey == 'transitions') {
      if (fieldKey == 'transitions' &&
          !directionData.containsKey('transitionLanguage')) {
        return;
      }
      content['subsectionKind'] = BibleBlockSchemas.transitions;
      final points = BibleBlockSchemas.parsePointList(
        directionData['transitionLanguage'],
      );
      if (points.isNotEmpty) content['points'] = points;
      return;
    }

    if (fieldKey == 'emotionTags' || fieldKey == 'narrative') {
      if (fieldKey == 'narrative' &&
          !directionData.containsKey('emotionTags')) {
        return;
      }
      content['subsectionKind'] = BibleBlockSchemas.narrativeIntent;
      final tags = BibleBlockSchemas.parseTags(directionData['emotionTags']);
      if (tags.isNotEmpty) content['tags'] = tags;
    }
  }

  static Map<String, dynamic> _parseDirectionData(Map<String, String> values) {
    final raw = values['directionData'];
    if (raw == null || raw.isEmpty) return const {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return const {};
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
