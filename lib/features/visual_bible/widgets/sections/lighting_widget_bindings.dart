import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../shared/visual_bible/bible_section_ids.dart';
import '../../../../shared/visual_bible/bible_subsection_kind_catalog.dart';
import '../../../../shared/visual_bible/bible_widget_size.dart';
import '../../../../shared/visual_bible/narrative_card_kind.dart';
import '../../visual_bible_model.dart';
import '../narrative_deck/lighting_behaviors_block.dart';
import '../narrative_deck/lighting_global_metrics_panel.dart';
import '../narrative_deck/lighting_tagged_refs_block.dart';
import '../narrative_deck/narrative_deck_block.dart';
import '../bible_widget_renderer_registry.dart';

/// Dependencias para renderizar widgets de Iluminación vía registry.
class LightingWidgetBindingsContext {
  final int projectId;
  final int bibleId;
  final Map<String, dynamic> lightingData;
  final Future<void> Function(Map<String, dynamic> patch) onUpdateLightingData;
  final int? selectedPlanId;
  final AppDatabase db;
  final VisualBibleData data;
  final BibleChanged onChanged;
  final Future<void> Function(int planId, Map<String, dynamic> patch)
      onUpdatePlan;
  final Future<void> Function(int planId, String note) onSyncLightingNote;
  final Future<void> Function(BuildContext context, int? planId) onAddSetup;
  final Widget Function(dynamic card) locationTechnicalPanelBuilder;

  const LightingWidgetBindingsContext({
    required this.projectId,
    required this.bibleId,
    required this.lightingData,
    required this.onUpdateLightingData,
    required this.selectedPlanId,
    required this.db,
    required this.data,
    required this.onChanged,
    required this.onUpdatePlan,
    required this.onSyncLightingNote,
    required this.onAddSetup,
    required this.locationTechnicalPanelBuilder,
  });
}

/// Registra renderers Stitch de Iluminación (kind + binding → widget).
abstract final class LightingWidgetBindings {
  static LightingWidgetBindingsContext? _ctx;
  static bool _registered = false;

  /// Actualiza el contexto vivo y registra renderers la primera vez.
  static void bind(LightingWidgetBindingsContext ctx) {
    _ctx = ctx;
    if (_registered) return;
    _registered = true;
    _registerAll();
  }

  static void _registerAll() {
    final sectionId = BibleSectionId.lighting;

    BibleWidgetRendererRegistry.registerBinding(sectionId, 'overview', (renderCtx) {
      final c = _ctx!;
      return LightingOverviewBlock(
        projectId: c.projectId,
        bibleId: c.bibleId,
        lightingData: c.lightingData,
        onUpdateLightingData: c.onUpdateLightingData,
        compact: renderCtx.size == BibleWidgetSize.small,
      );
    });

    BibleWidgetRendererRegistry.registerBinding(sectionId, 'globalMetrics', (renderCtx) {
      final c = _ctx!;
      return LightingGlobalMetricsPanel(
        lightingData: c.lightingData,
        onUpdate: c.onUpdateLightingData,
        compact: renderCtx.size == BibleWidgetSize.small,
      );
    });

    BibleWidgetRendererRegistry.registerBinding(sectionId, 'lightBehaviors', (renderCtx) {
      final c = _ctx!;
      return LightingBehaviorsBlock(
        projectId: c.projectId,
        bibleId: c.bibleId,
        compact: renderCtx.size == BibleWidgetSize.small,
      );
    });

    BibleWidgetRendererRegistry.registerBinding(sectionId, 'filmRefs', (renderCtx) {
      final c = _ctx!;
      return NarrativeDeckBlock(
        projectId: c.projectId,
        bibleId: c.bibleId,
        sectionId: sectionId,
        kind: NarrativeCardKind.filmRef,
        title: 'Referencias fílmicas',
        subtitle: 'Películas que nos inspiran y nos ayudan a definir la luz',
        gridColumns: _deckColumns(renderCtx.size),
      );
    });

    BibleWidgetRendererRegistry.registerBinding(
      sectionId,
      'locationLights',
      (renderCtx) {
        final c = _ctx!;
        return NarrativeDeckBlock(
          projectId: c.projectId,
          bibleId: c.bibleId,
          sectionId: sectionId,
          kind: NarrativeCardKind.locationLight,
          title: 'Localizaciones',
          subtitle: 'Cómo afrontamos la luz en cada set',
          allowAdd: false,
          allowDelete: false,
          gridColumns: _deckColumns(renderCtx.size),
          technicalPanelBuilder: (card) => c.locationTechnicalPanelBuilder(card),
        );
      },
    );

    BibleWidgetRendererRegistry.registerBinding(sectionId, 'lightStyles', (renderCtx) {
      final c = _ctx!;
      return NarrativeDeckBlock(
        projectId: c.projectId,
        bibleId: c.bibleId,
        sectionId: sectionId,
        kind: NarrativeCardKind.style,
        title: 'Comportamiento de la luz',
        subtitle:
            'Textura, calidad, color y cómo se comporta la luz en el proyecto',
        gridColumns: _deckColumns(renderCtx.size),
      );
    });

    BibleWidgetRendererRegistry.registerBinding(sectionId, 'lightingTagRefs', (renderCtx) {
      final c = _ctx!;
      return LightingTaggedRefsBlock(
        projectId: c.projectId,
        bibleId: c.bibleId,
      );
    });

    BibleWidgetRendererRegistry.registerKind(
      sectionId,
      BibleSubsectionKindId.cardDeck,
      (renderCtx) {
        final binding = renderCtx.field.binding ?? renderCtx.field.key;
        final c = _ctx!;
        final kind = switch (binding) {
          'locationLights' => NarrativeCardKind.locationLight,
          'lightStyles' => NarrativeCardKind.style,
          _ => NarrativeCardKind.filmRef,
        };
        return NarrativeDeckBlock(
          projectId: c.projectId,
          bibleId: c.bibleId,
          sectionId: sectionId,
          kind: kind,
          title: renderCtx.field.label,
          gridColumns: _deckColumns(renderCtx.size),
        );
      },
    );
  }

  static int? _deckColumns(BibleWidgetSize size) => switch (size) {
        BibleWidgetSize.small => 1,
        BibleWidgetSize.medium => 2,
        BibleWidgetSize.large => null,
      };

  @visibleForTesting
  static void resetForTest() {
    _registered = false;
    _ctx = null;
    BibleWidgetRendererRegistry.clearSection(BibleSectionId.lighting);
  }
}
