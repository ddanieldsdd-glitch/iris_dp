// /Users/danieldiaz/Documents/IRIS DP/iris_dp/lib/features/visual_bible/widgets/sections/workflow_section.dart
import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import '../bible_section_shared_widgets.dart';
import 'section_scaffold.dart';

class _WorkflowStep {
  final IconData icon;
  final String name;
  final String software;
  final String format;
  final String support;
  const _WorkflowStep({required this.icon, required this.name, required this.software, required this.format, required this.support});
}

const _workflowSteps = [
  _WorkflowStep(icon: Icons.videocam_outlined, name: 'CÁMARA', software: 'ARRI Alexa / RED', format: 'ARRIRAW / R3D', support: 'DIT'),
  _WorkflowStep(icon: Icons.backup_outlined, name: 'BACKUP', software: 'YoYotta / Silverstack', format: 'Clone x3', support: 'DIT / Wrangler'),
  _WorkflowStep(icon: Icons.play_circle_outline, name: 'DAILIES', software: 'DaVinci Resolve', format: 'ProRes 422 HQ', support: 'Colorista'),
  _WorkflowStep(icon: Icons.palette_outlined, name: 'COLOR', software: 'DaVinci Resolve', format: 'EXR / DCP', support: 'Colorista'),
  _WorkflowStep(icon: Icons.send_outlined, name: 'ENTREGA', software: 'Aspera / Signiant', format: 'IMF / DCP', support: 'Post'),
];

class WorkflowSection extends ConsumerStatefulWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const WorkflowSection({
    super.key,
    required this.data,
    required this.projectId,
    this.sectionContentJson,
    required this.onChanged,
  });

  @override
  ConsumerState<WorkflowSection> createState() => _WorkflowSectionState();
}

class _WorkflowSectionState extends ConsumerState<WorkflowSection> {
  int _selectedStep = 0;

  Map<String, dynamic> _getCustomData() {
    if (widget.sectionContentJson == null) return {};
    try {
      final decoded = jsonDecode(widget.sectionContentJson!);
      if (decoded is Map<String, dynamic> && decoded.containsKey('_values')) {
        final vals = decoded['_values'] as Map<String, dynamic>;
        if (vals.containsKey('workflowData')) {
          return jsonDecode(vals['workflowData'] as String);
        }
      }
    } catch (_) {}
    return {};
  }

  Future<void> _updateCustomData(Map<String, dynamic> update) async {
    final current = _getCustomData();
    final newData = { ...current, ...update };
    final db = ref.read(databaseProvider);
    final def = await (db.select(db.bibleSectionDefinitions)
      ..where((d) => d.bibleId.equals(widget.data.id) & d.id.equals(BibleSectionId.workflow))).getSingleOrNull();
    if (def != null) {
      final fields = BibleSectionFieldsConfig.parse(def.contentJson, BibleSectionId.workflow);
      final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
      values['workflowData'] = jsonEncode(newData);
      await db.upsertBibleSectionDefinition(def.copyWith(
        contentJson: drift.Value(BibleSectionFieldsConfig.encode(fields, values: values)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final customData = _getCustomData();
    final ditName = customData['ditName'] as String? ?? '';
    final wranglerName = customData['wranglerName'] as String? ?? '';
    final technicalNote = customData['technicalNote'] as String? ?? '';

    final step = _workflowSteps[_selectedStep];

    return BibleSectionScaffold(
      sectionId: BibleSectionId.workflow,
      projectId: widget.projectId,
      data: widget.data,
      onChanged: widget.onChanged,
      sectionContentJson: widget.sectionContentJson,
      narrativeHint: 'Pipeline y equipo de DIT',
      sectionNumber: '12',
      sectionTitle: 'Workflow',
      fieldWidgets: {
        'workflowSettings': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Stepper horizontal
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_workflowSteps.length, (i) {
                  final s = _workflowSteps[i];
                  final isActive = i == _selectedStep;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedStep = i),
                    child: Row(
                      children: [
                        Column(
                          children: [
                            CircleAvatar(
                              backgroundColor: isActive ? context.palette.accent : context.palette.surfaceElevated,
                              child: Icon(s.icon, color: isActive ? context.palette.background : context.palette.textSecondary),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(s.name, style: AppTypography.caption(context.palette).copyWith(color: isActive ? context.palette.accent : context.palette.textSecondary)),
                          ],
                        ),
                        if (i < _workflowSteps.length - 1)
                          Container(
                            width: 30,
                            height: 2,
                            color: context.palette.border,
                            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 20),
                          ),
                      ],
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Panel de detalle
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: AppCard(
                key: ValueKey(_selectedStep),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(step.name, style: AppTypography.titleMedium(context.palette)),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: BibleTechCard(label: 'Software', value: step.software)),
                        Expanded(child: BibleTechCard(label: 'Formato', value: step.format)),
                        Expanded(child: BibleTechCard(label: 'Soporte', value: step.support)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Responsabilidades
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('DIT', style: AppTypography.label(context.palette)),
                        const SizedBox(height: AppSpacing.sm),
                        BibleTextField(
                          label: 'Nombre DIT',
                          hint: 'Nombre...',
                          initialValue: ditName,
                          onChanged: (v) => _updateCustomData({'ditName': v}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Data Wrangler', style: AppTypography.label(context.palette)),
                        const SizedBox(height: AppSpacing.sm),
                        BibleTextField(
                          label: 'Nombre Wrangler',
                          hint: 'Nombre...',
                          initialValue: wranglerName,
                          onChanged: (v) => _updateCustomData({'wranglerName': v}),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Technical Note
            BibleTechNoteBox(text: technicalNote, title: 'Nota técnica de Workflow'),
            const SizedBox(height: AppSpacing.sm),
            BibleTextField(
              label: 'Editar nota técnica',
              maxLines: 3,
              initialValue: technicalNote,
              onChanged: (v) => _updateCustomData({'technicalNote': v}),
            ),
          ],
        ),
      },
    );
  }
}
