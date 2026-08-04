import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../bible_navigation_scope.dart';
import '../bible_unified_references_panel.dart';
import '../narrative_bridge_card.dart';

/// Layout común para secciones técnicas de la biblia.
///
/// Cuando se proporciona [fieldWidgets], los sub-apartados se renderizan
/// según el orden y nombres definidos en [sectionContentJson].
class BibleSectionScaffold extends StatelessWidget {
  final String sectionId;
  final int projectId;
  final VisualBibleData data;
  final BibleChanged onChanged;
  final String narrativeHint;
  final String? sectionContentJson;
  final Map<String, Widget> fieldWidgets;

  const BibleSectionScaffold({
    super.key,
    required this.sectionId,
    required this.projectId,
    required this.data,
    required this.onChanged,
    required this.narrativeHint,
    this.sectionContentJson,
    required this.fieldWidgets,
  });

  @override
  Widget build(BuildContext context) {
    final fields = BibleSectionFieldsConfig.parse(
      sectionContentJson,
      sectionId,
    );

    final items = <Widget>[];
    for (final field in fields) {
      final widget = _buildField(context, field);
      if (widget != null) items.add(widget);
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
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
          hint: field.hint ?? narrativeHint,
          subtitle: null,
          value: data.narrativeIntentForSection(sectionId),
          onChanged: (v) {
            data.setNarrativeIntentForSection(
              sectionId,
              v.trim().isEmpty ? null : v.trim(),
            );
            onChanged(data);
          },
        ),
      BibleSectionFieldType.references => data.id > 0
          ? BibleReferencesPanel(
              projectId: projectId,
              sectionId: sectionId,
              bibleId: data.id,
              title: field.label,
              onOpenMoodboard: () =>
                  BibleNavigationScope.openMoodboardForSection(
                context,
                sectionId,
              ),
            )
          : null,
      BibleSectionFieldType.blocks ||
      BibleSectionFieldType.text =>
        fieldWidgets[field.key],
    };
  }
}

typedef BibleChanged = void Function(VisualBibleData data);
