import 'package:flutter/widgets.dart';

import '../../shared/visual_bible/bible_section_fields.dart';
import '../../shared/visual_bible/bible_subsection_kind_catalog.dart';
import '../../shared/visual_bible/bible_widget_size.dart';
import 'bible_block_catalog.dart';

/// Mapeo entre kinds Stitch ([BibleSubsectionKindId]) y bloques v2 ([BibleBlockKind]).
abstract final class BibleKindBlockMapping {
  static BibleBlockKind? toBlockKind(BibleSubsectionKindId kind) =>
      switch (kind) {
        BibleSubsectionKindId.textField => BibleBlockKind.text,
        BibleSubsectionKindId.narrativeIntent ||
        BibleSubsectionKindId.reinforcementText =>
          BibleBlockKind.narrative,
        BibleSubsectionKindId.moodboardRefs ||
        BibleSubsectionKindId.reinforcementImages =>
          BibleBlockKind.moodboardRefs,
        BibleSubsectionKindId.referenceImages ||
        BibleSubsectionKindId.heroWithCaption =>
          BibleBlockKind.heroImage,
        BibleSubsectionKindId.headerTags => BibleBlockKind.chipSelect,
        BibleSubsectionKindId.paletteTarget => BibleBlockKind.colorPalette,
        BibleSubsectionKindId.telemetryPanel => BibleBlockKind.telemetry,
        BibleSubsectionKindId.setupList => BibleBlockKind.equipmentList,
        BibleSubsectionKindId.lightingDiagram => BibleBlockKind.lightingDiagram,
        BibleSubsectionKindId.dynamicBlocks ||
        BibleSubsectionKindId.behaviorMosaic ||
        BibleSubsectionKindId.cardDeck =>
          BibleBlockKind.dynamicBlocks,
      };

  static BibleSubsectionKindId? fromBlockKind(BibleBlockKind kind) =>
      switch (kind) {
        BibleBlockKind.text => BibleSubsectionKindId.textField,
        BibleBlockKind.narrative => BibleSubsectionKindId.narrativeIntent,
        BibleBlockKind.moodboardRefs => BibleSubsectionKindId.moodboardRefs,
        BibleBlockKind.heroImage => BibleSubsectionKindId.heroWithCaption,
        BibleBlockKind.chipSelect => BibleSubsectionKindId.headerTags,
        BibleBlockKind.colorPalette => BibleSubsectionKindId.paletteTarget,
        BibleBlockKind.telemetry => BibleSubsectionKindId.telemetryPanel,
        BibleBlockKind.equipmentList => BibleSubsectionKindId.setupList,
        BibleBlockKind.lightingDiagram =>
          BibleSubsectionKindId.lightingDiagram,
        BibleBlockKind.specsTable => BibleSubsectionKindId.textField,
        BibleBlockKind.workflowPipeline => BibleSubsectionKindId.textField,
        BibleBlockKind.dynamicBlocks => BibleSubsectionKindId.dynamicBlocks,
      };

  static BibleBlockKind blockKindForField(
    String sectionId,
    BibleSectionField field,
  ) {
    final subsectionKind = field.resolvedKind(sectionId);
    return toBlockKind(subsectionKind) ??
        switch (field.type) {
          BibleSectionFieldType.narrative => BibleBlockKind.narrative,
          BibleSectionFieldType.references ||
          BibleSectionFieldType.image =>
            BibleBlockKind.moodboardRefs,
          BibleSectionFieldType.blocks => BibleBlockKind.dynamicBlocks,
          BibleSectionFieldType.text => BibleBlockKind.text,
        };
  }
}
