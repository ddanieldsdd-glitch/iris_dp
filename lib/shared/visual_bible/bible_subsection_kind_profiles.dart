import 'bible_section_ids.dart';
import 'bible_subsection_kind_catalog.dart';
import 'bible_widget_size.dart';

/// Perfiles S/M/L por tipo de widget: qué tamaños tiene sentido y cuál es el default.
abstract final class BibleSubsectionKindProfiles {
  static Set<BibleWidgetSize> allowedSizes(BibleSubsectionKindId id) =>
      switch (id) {
        BibleSubsectionKindId.behaviorMosaic ||
        BibleSubsectionKindId.lightingDiagram ||
        BibleSubsectionKindId.setupList =>
          {BibleWidgetSize.medium, BibleWidgetSize.large},
        BibleSubsectionKindId.headerTags ||
        BibleSubsectionKindId.textField ||
        BibleSubsectionKindId.telemetryPanel =>
          {BibleWidgetSize.small, BibleWidgetSize.medium},
        _ => {
            BibleWidgetSize.small,
            BibleWidgetSize.medium,
            BibleWidgetSize.large,
          },
      };

  static BibleWidgetSize defaultSize(BibleSubsectionKindId id) {
    final allowed = allowedSizes(id);
    if (allowed.contains(BibleWidgetSize.large)) {
      return BibleWidgetSize.large;
    }
    if (allowed.contains(BibleWidgetSize.medium)) {
      return BibleWidgetSize.medium;
    }
    return BibleWidgetSize.small;
  }

  static BibleWidgetSize clampSize(
    BibleSubsectionKindId id,
    BibleWidgetSize size,
  ) {
    final allowed = allowedSizes(id);
    if (allowed.contains(size)) return size;
    return defaultSize(id);
  }
}

/// Kinds recomendados por pantalla para el picker de «Añadir widget».
abstract final class BibleSectionKindRecommendations {
  static List<BibleSubsectionKindId> forSection(String sectionId) =>
      switch (sectionId) {
        BibleSectionId.lighting => const [
            BibleSubsectionKindId.narrativeIntent,
            BibleSubsectionKindId.telemetryPanel,
            BibleSubsectionKindId.behaviorMosaic,
            BibleSubsectionKindId.cardDeck,
            BibleSubsectionKindId.moodboardRefs,
            BibleSubsectionKindId.setupList,
            BibleSubsectionKindId.lightingDiagram,
          ],
        BibleSectionId.camera || BibleSectionId.optics => const [
            BibleSubsectionKindId.narrativeIntent,
            BibleSubsectionKindId.textField,
            BibleSubsectionKindId.moodboardRefs,
          ],
        BibleSectionId.location => const [
            BibleSubsectionKindId.heroWithCaption,
            BibleSubsectionKindId.telemetryPanel,
            BibleSubsectionKindId.moodboardRefs,
            BibleSubsectionKindId.textField,
          ],
        BibleSectionId.workflow => const [
            BibleSubsectionKindId.textField,
            BibleSubsectionKindId.narrativeIntent,
            BibleSubsectionKindId.moodboardRefs,
          ],
        _ => const [
            BibleSubsectionKindId.narrativeIntent,
            BibleSubsectionKindId.textField,
            BibleSubsectionKindId.moodboardRefs,
            BibleSubsectionKindId.referenceImages,
            BibleSubsectionKindId.cardDeck,
          ],
      };
}
