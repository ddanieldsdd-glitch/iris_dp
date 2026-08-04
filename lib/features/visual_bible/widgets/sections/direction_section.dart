import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_navigation_scope.dart';
import '../bible_unified_references_panel.dart';
import '../narrative_bridge_card.dart';
import 'section_scaffold.dart';

/// Apartado Dirección: sub-apartados configurables desde el editor de estructura.
class DirectionSection extends StatelessWidget {
  final VisualBibleData data;
  final int projectId;
  final String sectionLabel;
  final String? contentJson;
  final BibleChanged onChanged;

  const DirectionSection({
    super.key,
    required this.data,
    required this.projectId,
    required this.sectionLabel,
    this.contentJson,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final fields = BibleSectionFieldsConfig.parse(
      contentJson,
      BibleSectionId.direction,
    );
    final textFields =
        fields.where((f) => f.type == BibleSectionFieldType.text).toList();
    final hasReferences = fields.any(
      (f) => f.type == BibleSectionFieldType.references,
    );

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        for (final field in fields) ...[
          if (field.type == BibleSectionFieldType.narrative) ...[
            NarrativeBridgeCard(
              hint: field.hint ??
                  '¿Cuál es la intención global de la fotografía respecto a la historia?',
              title: field.label,
              value: data.narrativeIntentForSection(BibleSectionId.direction),
              onChanged: (v) {
                data.setNarrativeIntentForSection(
                  BibleSectionId.direction,
                  v.trim().isEmpty ? null : v.trim(),
                );
                onChanged(data);
              },
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ],
        if (textFields.isNotEmpty)
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sectionLabel, style: AppTypography.titleMedium(palette)),
                const SizedBox(height: AppSpacing.md),
                for (var i = 0; i < textFields.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.sm),
                  BibleTextField(
                    label: textFields[i].label,
                    hint: textFields[i].hint ?? '',
                    maxLines: textFields[i].maxLines,
                    initialValue:
                        DirectionFieldBinding.read(data, textFields[i].key),
                    onChanged: (v) {
                      DirectionFieldBinding.write(
                        data,
                        textFields[i].key,
                        v.trim().isEmpty ? null : v.trim(),
                      );
                      onChanged(data);
                    },
                  ),
                ],
              ],
            ),
          ),
        if (hasReferences && data.id > 0) ...[
          const SizedBox(height: AppSpacing.xl),
          BibleReferencesPanel(
            projectId: projectId,
            sectionId: BibleSectionId.direction,
            bibleId: data.id,
            title: fields
                .where((f) => f.type == BibleSectionFieldType.references)
                .map((f) => f.label)
                .firstOrNull,
            onOpenMoodboard: () => BibleNavigationScope.openMoodboardForSection(
              context,
              BibleSectionId.direction,
            ),
          ),
        ],
      ],
    );
  }
}
