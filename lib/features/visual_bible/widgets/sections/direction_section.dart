// /Users/danieldiaz/Documents/IRIS DP/iris_dp/lib/features/visual_bible/widgets/sections/direction_section.dart
import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_section_shared_widgets.dart';
import '../narrative_bridge_card.dart';
import '../bible_navigation_scope.dart';
import '../bible_unified_references_panel.dart';

class DirectionSection extends StatefulWidget {
  final VisualBibleData data;
  final int projectId;
  final String sectionLabel;
  final String? contentJson;
  final ValueChanged<String>? onContentJsonChanged;
  final BibleChanged onChanged;

  const DirectionSection({
    super.key,
    required this.data,
    required this.projectId,
    required this.sectionLabel,
    this.contentJson,
    this.onContentJsonChanged,
    required this.onChanged,
  });

  @override
  State<DirectionSection> createState() => _DirectionSectionState();
}

class _DirectionSectionState extends State<DirectionSection> {
  BibleVisualMode _mode = BibleVisualMode.cinematic;

  Map<String, dynamic> _parseContent(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  String _encodeContent(Map<String, dynamic> m) => jsonEncode(m);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final content = _parseContent(widget.contentJson);
    final emotionTags = (content['emotionTags'] as List?)?.cast<String>() ?? [];
    final tonePoints = (content['tonePoints'] as List?)?.cast<String>() ?? [];
    final act1Title = content['act1Title'] as String? ?? 'Presentación';
    final act1Desc = content['act1Desc'] as String? ?? '';
    final act2Title = content['act2Title'] as String? ?? 'Confrontación';
    final act2Desc = content['act2Desc'] as String? ?? '';
    final act3Title = content['act3Title'] as String? ?? 'Resolución';
    final act3Desc = content['act3Desc'] as String? ?? '';
    final transitionLanguage = (content['transitionLanguage'] as List?)?.cast<String>() ?? [];

    void updateContent(String key, dynamic value) {
      content[key] = value;
      widget.onContentJsonChanged?.call(_encodeContent(content));
    }

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        BibleSectionHeader(
          number: '01',
          title: 'Dirección',
          trailing: BibleSectionModeDropdown(
            value: _mode,
            onChanged: (m) => setState(() => _mode = m),
          ),
        ),
        NarrativeBridgeCard(
          hint: '¿Cuál es la intención global de la fotografía respecto a la historia?',
          value: widget.data.directionNarrativeIntent,
          onChanged: (v) {
            widget.data.directionNarrativeIntent = v;
            widget.onChanged(widget.data);
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('EMOCIÓN Y TONO', style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.md),
              BibleSelectableChipRow(
                options: const [
                  'Tensión', 'Claustrofobia', 'Esperanza', 'Melancolía',
                  'Euforia', 'Soledad', 'Peligro', 'Calma',
                  'Ambigüedad', 'Amor', 'Pérdida', 'Poder'
                ],
                selected: emotionTags,
                onChanged: (v) => updateContent('emotionTags', v),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: BibleEditableList(
            title: 'Tono y atmósfera',
            items: tonePoints,
            onChanged: (v) => updateContent('tonePoints', v),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ESTRATEGIA VISUAL', style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.md),
              BibleThreePillarRow(
                pillars: [
                  BiblePillarData(
                    label: 'CÁMARA',
                    title: 'Filosofía de cámara',
                    description: widget.data.cameraPhilosophy ?? 'Sin definir',
                  ),
                  BiblePillarData(
                    label: 'BLOCKING',
                    title: 'Staging Approach',
                    description: widget.data.stagingApproach ?? 'Sin definir',
                  ),
                  BiblePillarData(
                    label: 'POV',
                    title: 'Punto de Vista',
                    description: widget.data.pointOfView ?? 'Sin definir',
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              BibleTextField(
                label: 'Filosofía de cámara',
                initialValue: widget.data.cameraPhilosophy,
                onChanged: (v) {
                  widget.data.cameraPhilosophy = v;
                  widget.onChanged(widget.data);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              BibleTextField(
                label: 'Staging Approach',
                initialValue: widget.data.stagingApproach,
                onChanged: (v) {
                  widget.data.stagingApproach = v;
                  widget.onChanged(widget.data);
                },
              ),
              const SizedBox(height: AppSpacing.sm),
              BibleTextField(
                label: 'Punto de Vista',
                initialValue: widget.data.pointOfView,
                onChanged: (v) {
                  widget.data.pointOfView = v;
                  widget.onChanged(widget.data);
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('INTENCIÓN POR ACTO', style: AppTypography.titleMedium(palette)),
              const SizedBox(height: AppSpacing.md),
              BibleThreePillarRow(
                pillars: [
                  BiblePillarData(
                    label: 'ACTO I',
                    title: act1Title,
                    description: act1Desc,
                  ),
                  BiblePillarData(
                    label: 'ACTO II',
                    title: act2Title,
                    description: act2Desc,
                  ),
                  BiblePillarData(
                    label: 'ACTO III',
                    title: act3Title,
                    description: act3Desc,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(child: BibleTextField(label: 'Título Acto 1', initialValue: act1Title, onChanged: (v) => updateContent('act1Title', v))),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(flex: 2, child: BibleTextField(label: 'Desc', initialValue: act1Desc, onChanged: (v) => updateContent('act1Desc', v))),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: BibleTextField(label: 'Título Acto 2', initialValue: act2Title, onChanged: (v) => updateContent('act2Title', v))),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(flex: 2, child: BibleTextField(label: 'Desc', initialValue: act2Desc, onChanged: (v) => updateContent('act2Desc', v))),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(child: BibleTextField(label: 'Título Acto 3', initialValue: act3Title, onChanged: (v) => updateContent('act3Title', v))),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(flex: 2, child: BibleTextField(label: 'Desc', initialValue: act3Desc, onChanged: (v) => updateContent('act3Desc', v))),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: BibleEditableList(
            title: 'Lenguaje de transiciones',
            items: transitionLanguage,
            onChanged: (v) => updateContent('transitionLanguage', v),
          ),
        ),
        if (widget.data.id > 0) ...[
          const SizedBox(height: AppSpacing.xl),
          BibleReferencesPanel(
            projectId: widget.projectId,
            sectionId: BibleSectionId.direction,
            bibleId: widget.data.id,
            title: 'Referencias de Dirección',
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
