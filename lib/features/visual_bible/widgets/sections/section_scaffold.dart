// lib/features/visual_bible/widgets/sections/section_scaffold.dart
//
// Layout común para secciones técnicas de la Biblia de Fotografía.
// Cuando se proporciona [fieldWidgets], los sub-apartados se renderizan
// según el orden y nombres definidos en [sectionContentJson].

import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../bible_navigation_scope.dart';
import '../bible_section_shared_widgets.dart';
import '../bible_unified_references_panel.dart';
import '../narrative_bridge_card.dart';

/// Layout común para secciones técnicas de la biblia.
///
/// Cuando se proporciona [fieldWidgets], los sub-apartados se renderizan
/// según el orden y nombres definidos en [sectionContentJson].
class BibleSectionScaffold extends StatefulWidget {
  final String sectionId;
  final int projectId;
  final VisualBibleData data;
  final BibleChanged onChanged;
  final String narrativeHint;
  final String? sectionContentJson;
  final Map<String, Widget> fieldWidgets;
  /// Número de sección para la cabecera (ej. '01', '02'…).
  final String? sectionNumber;
  /// Título de la cabecera. Si no se proporciona, usa el label del sectionId.
  final String? sectionTitle;

  const BibleSectionScaffold({
    super.key,
    required this.sectionId,
    required this.projectId,
    required this.data,
    required this.onChanged,
    required this.narrativeHint,
    this.sectionContentJson,
    required this.fieldWidgets,
    this.sectionNumber,
    this.sectionTitle,
  });

  @override
  State<BibleSectionScaffold> createState() => _BibleSectionScaffoldState();
}

class _BibleSectionScaffoldState extends State<BibleSectionScaffold> {
  BibleVisualMode _mode = BibleVisualMode.cinematic;

  @override
  Widget build(BuildContext context) {
    final fields = BibleSectionFieldsConfig.parse(
      widget.sectionContentJson,
      widget.sectionId,
    );

    final items = <Widget>[];
    for (final field in fields) {
      final w = _buildField(context, field);
      if (w != null) items.add(w);
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        // Cabecera con número + título + selector de modo visual
        if (widget.sectionNumber != null)
          BibleSectionHeader(
            number: widget.sectionNumber!,
            title: widget.sectionTitle ?? BibleSectionId.label(widget.sectionId),
            trailing: BibleSectionModeDropdown(
              value: _mode,
              onChanged: (m) => setState(() => _mode = m),
            ),
          ),
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          items[i],
        ],
      ],
    );
  }

  Widget? _buildField(BuildContext context, BibleSectionField field) {
    return switch (field.type) {
      BibleSectionFieldType.narrative => NarrativeBridgeCard(
          title: field.label,
          hint: field.hint ?? widget.narrativeHint,
          subtitle: null,
          value: widget.data.narrativeIntentForSection(widget.sectionId),
          onChanged: (v) {
            widget.data.setNarrativeIntentForSection(
              widget.sectionId,
              v.trim().isEmpty ? null : v.trim(),
            );
            widget.onChanged(widget.data);
          },
        ),
      BibleSectionFieldType.references ||
      BibleSectionFieldType.image =>
        widget.data.id > 0
            ? BibleReferencesPanel(
                projectId: widget.projectId,
                sectionId: widget.sectionId,
                bibleId: widget.data.id,
                title: field.label,
                onOpenMoodboard: () =>
                    BibleNavigationScope.openMoodboardForSection(
                  context,
                  widget.sectionId,
                ),
              )
            : null,
      BibleSectionFieldType.blocks ||
      BibleSectionFieldType.text =>
        widget.fieldWidgets[field.key],
    };
  }
}
