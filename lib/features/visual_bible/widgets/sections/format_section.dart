// /Users/danieldiaz/Documents/IRIS DP/iris_dp/lib/features/visual_bible/widgets/sections/format_section.dart
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

class FormatSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const FormatSection({
    super.key,
    required this.data,
    required this.projectId,
    this.sectionContentJson,
    required this.onChanged,
  });

  Map<String, dynamic> _getCustomData() {
    if (sectionContentJson == null) return {};
    try {
      final decoded = jsonDecode(sectionContentJson!);
      if (decoded is Map<String, dynamic> && decoded.containsKey('_values')) {
        final vals = decoded['_values'] as Map<String, dynamic>;
        if (vals.containsKey('formatData')) {
          return jsonDecode(vals['formatData'] as String);
        }
      }
    } catch (_) {}
    return {};
  }

  Future<void> _updateCustomData(WidgetRef ref, Map<String, dynamic> update) async {
    final current = _getCustomData();
    final newData = { ...current, ...update };
    final db = ref.read(databaseProvider);
    final def = await (db.select(db.bibleSectionDefinitions)
      ..where((d) => d.bibleId.equals(data.id) & d.id.equals(BibleSectionId.format))).getSingleOrNull();
    if (def != null) {
      final fields = BibleSectionFieldsConfig.parse(def.contentJson, BibleSectionId.format);
      final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
      values['formatData'] = jsonEncode(newData);
      await db.upsertBibleSectionDefinition(def.copyWith(
        contentJson: drift.Value(BibleSectionFieldsConfig.encode(fields, values: values)),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customData = _getCustomData();
    final activeRatio = customData['activeRatio'] as String? ?? data.aspectRatio ?? '2.39:1';
    final sensorMode = customData['sensorMode'] as String? ?? 'Open Gate';
    final squeezeFactor = customData['squeezeFactor'] as String? ?? '2x';
    final desqueeze = customData['desqueeze'] as String? ?? 'In-camera';
    final blanking = customData['blanking'] as String? ?? 'Custom Framelines';
    final cinematographerNotes = customData['cinematographerNotes'] as String? ?? '';

    final ratioOptions = ['2.39:1 Scope', '1.85:1 Flat', '1.78:1 HD', '1.33:1 Academy', '4:3 Vintage'];

    return BibleSectionScaffold(
      sectionId: BibleSectionId.format,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint: '¿Cómo afecta el encuadre a la relación del personaje con el espacio?',
      sectionNumber: '09',
      sectionTitle: 'Aspect Ratio',
      fieldWidgets: {
        'formatSettings': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Reference Monitor con framelines
            AppCard(
              padding: EdgeInsets.zero,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  color: context.palette.surfaceElevated,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Simulated frame lines
                      _buildFrameline(context, 2.39, activeRatio.contains('2.39'), '2.39:1'),
                      _buildFrameline(context, 1.85, activeRatio.contains('1.85'), '1.85:1'),
                      _buildFrameline(context, 1.78, activeRatio.contains('1.78'), '1.78:1'),
                      _buildFrameline(context, 1.33, activeRatio.contains('1.33'), '1.33:1'),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Aspect Ratio Selector
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: ratioOptions.map((opt) {
                  final isActive = activeRatio == opt || opt.contains(activeRatio);
                  return GestureDetector(
                    onTap: () {
                      _updateCustomData(ref, {'activeRatio': opt.split(' ').first});
                      data.aspectRatio = opt.split(' ').first;
                      onChanged(data);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: isActive ? context.palette.accent.withValues(alpha: 0.15) : context.palette.background,
                        border: Border.all(color: isActive ? context.palette.accent : context.palette.border),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(opt, style: AppTypography.titleMedium(context.palette).copyWith(color: isActive ? context.palette.accent : context.palette.textPrimary)),
                          if (isActive) Icon(Icons.check_circle, color: context.palette.accent),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Technical Parameters
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            BibleTechCard(label: 'Sensor Mode', value: sensorMode),
                            const SizedBox(height: AppSpacing.sm),
                            BibleTextField(
                              label: '', hint: 'Sensor...', initialValue: sensorMode,
                              onChanged: (v) => _updateCustomData(ref, {'sensorMode': v}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          children: [
                            BibleTechCard(label: 'Squeeze', value: squeezeFactor),
                            const SizedBox(height: AppSpacing.sm),
                            BibleTextField(
                              label: '', hint: 'Squeeze...', initialValue: squeezeFactor,
                              onChanged: (v) => _updateCustomData(ref, {'squeezeFactor': v}),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            BibleTechCard(label: 'Desqueeze', value: desqueeze),
                            const SizedBox(height: AppSpacing.sm),
                            BibleTextField(
                              label: '', hint: 'Desqueeze...', initialValue: desqueeze,
                              onChanged: (v) => _updateCustomData(ref, {'desqueeze': v}),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          children: [
                            BibleTechCard(label: 'Blanking', value: blanking),
                            const SizedBox(height: AppSpacing.sm),
                            BibleTextField(
                              label: '', hint: 'Blanking...', initialValue: blanking,
                              onChanged: (v) => _updateCustomData(ref, {'blanking': v}),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Cinematographer's Notes
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: context.palette.border),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: BibleTextField(
                label: 'Notas del DF sobre el formato',
                hint: 'Nota editorial sobre el ratio...',
                maxLines: 5,
                italic: true,
                initialValue: cinematographerNotes,
                onChanged: (v) => _updateCustomData(ref, {'cinematographerNotes': v}),
              ),
            ),
          ],
        ),
      },
    );
  }

  Widget _buildFrameline(BuildContext context, double targetRatio, bool isActive, String label) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final screenRatio = screenWidth / screenHeight;

        double width = screenWidth;
        double height = screenHeight;

        if (targetRatio > screenRatio) {
          height = screenWidth / targetRatio;
        } else {
          width = screenHeight * targetRatio;
        }

        return Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            border: Border.all(
              color: isActive ? context.palette.accent : context.palette.border.withValues(alpha: 0.5),
              width: isActive ? 2 : 1,
            ),
          ),
          alignment: Alignment.topLeft,
          padding: const EdgeInsets.all(4),
          child: Text(
            label,
            style: AppTypography.caption(context.palette).copyWith(
              color: isActive ? context.palette.accent : context.palette.textSecondary,
              fontSize: 10,
            ),
          ),
        );
      },
    );
  }
}
