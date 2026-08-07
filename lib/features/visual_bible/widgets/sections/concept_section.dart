// /Users/danieldiaz/Documents/IRIS DP/iris_dp/lib/features/visual_bible/widgets/sections/concept_section.dart
import 'dart:convert';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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

class ConceptSection extends ConsumerWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const ConceptSection({
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
        if (vals.containsKey('conceptData')) {
          return jsonDecode(vals['conceptData'] as String);
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
      ..where((d) => d.bibleId.equals(data.id) & d.id.equals(BibleSectionId.concept))).getSingleOrNull();
    if (def != null) {
      final fields = BibleSectionFieldsConfig.parse(def.contentJson, BibleSectionId.concept);
      final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
      values['conceptData'] = jsonEncode(newData);
      await db.upsertBibleSectionDefinition(def.copyWith(
        contentJson: drift.Value(BibleSectionFieldsConfig.encode(fields, values: values)),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customData = _getCustomData();
    
    final rawChips = customData['lightingPhilosophyChips'] as List<dynamic>? ?? [];
    final lightingPhilosophyChips = rawChips.map((e) => e.toString()).toList();
    
    final rawColors = customData['colorSymbols'] as List<dynamic>? ?? [];
    final colorSymbols = rawColors.map((e) => e as Map<String, dynamic>).toList();
    
    final act1Intent = customData['act1Intent'] as String? ?? '';
    final act2Intent = customData['act2Intent'] as String? ?? '';
    final act3Intent = customData['act3Intent'] as String? ?? '';
    
    final rawRefs = customData['refsMetadata'] as List<dynamic>? ?? [];
    final refsMetadata = rawRefs.map((e) => e as Map<String, dynamic>).toList();
    
    final contrastValue = (customData['contrastValue'] as num?)?.toDouble() ?? 0.5;
    final saturationValue = (customData['saturationValue'] as num?)?.toDouble() ?? 0.5;
    final grainValue = (customData['grainValue'] as num?)?.toDouble() ?? 0.5;

    return BibleSectionScaffold(
      sectionId: BibleSectionId.concept,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint: '¿Qué debe sentir el ojo del espectador en cada acto?',
      sectionNumber: '06',
      sectionTitle: 'Concepto de Imagen',
      fieldWidgets: {
        'visualConcept': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Paleta Maestro
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('PALETA MAESTRO', style: AppTypography.label(context.palette)),
                  const SizedBox(height: AppSpacing.md),
                  Text('Definir en Color e Imagen', style: AppTypography.bodyMedium(context.palette).copyWith(color: context.palette.textSecondary)),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Filosofía de luz
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('FILOSOFÍA DE LUZ', style: AppTypography.label(context.palette)),
                  const SizedBox(height: AppSpacing.md),
                  BibleSelectableChipRow(
                    options: const ['Contraste', 'Motivación', 'Fill', 'Eye Light', 'Ambience', 'Práctico', 'Duro', 'Suave'],
                    selected: lightingPhilosophyChips,
                    onChanged: (opts) => _updateCustomData(ref, {'lightingPhilosophyChips': opts}),
                    activeColor: context.palette.accent,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BibleTextField(
                    label: 'Notas adicionales',
                    maxLines: 3,
                    initialValue: data.lightingPhilosophy,
                    onChanged: (v) {
                      data.lightingPhilosophy = v;
                      onChanged(data);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Simbología de color
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SIMBOLOGÍA DE COLOR', style: AppTypography.label(context.palette)),
                  const SizedBox(height: AppSpacing.md),
                  ...colorSymbols.map((sym) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      children: [
                        Container(
                          width: 24, height: 24,
                          decoration: BoxDecoration(color: context.palette.accent, borderRadius: BorderRadius.circular(4)),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: Text(sym['poeticName']?.toString() ?? 'Nombre', style: AppTypography.bodyMedium(context.palette))),
                        Expanded(flex: 2, child: Text(sym['narrativeMeaning']?.toString() ?? 'Significado', style: AppTypography.caption(context.palette).copyWith(color: context.palette.textSecondary))),
                      ],
                    ),
                  )),
                  TextButton.icon(
                    onPressed: () {
                      final updated = List<Map<String, dynamic>>.from(colorSymbols);
                      updated.add({'hex': '#FFFFFF', 'poeticName': 'Nuevo', 'narrativeMeaning': 'Significado'});
                      _updateCustomData(ref, {'colorSymbols': updated});
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir símbolo'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Intención visual por acto
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('INTENCIÓN POR ACTO', style: AppTypography.label(context.palette)),
                  const SizedBox(height: AppSpacing.md),
                  BibleThreePillarRow(
                    pillars: [
                      BiblePillarData(label: 'Acto I', title: 'Planteamiento', description: act1Intent),
                      BiblePillarData(label: 'Acto II', title: 'Desarrollo', description: act2Intent),
                      BiblePillarData(label: 'Acto III', title: 'Desenlace', description: act3Intent),
                    ],
                    onChanged: (idx, field, v) {
                      if (field == 'description') {
                        if (idx == 0) _updateCustomData(ref, {'act1Intent': v});
                        if (idx == 1) _updateCustomData(ref, {'act2Intent': v});
                        if (idx == 2) _updateCustomData(ref, {'act3Intent': v});
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Referencias clave
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('REFERENCIAS CLAVE', style: AppTypography.label(context.palette)),
                  const SizedBox(height: AppSpacing.md),
                  ...refsMetadata.map((refData) => Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.palette.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(refData['film']?.toString() ?? 'Película', style: AppTypography.titleMedium(context.palette)),
                        Text('${refData['dp'] ?? 'DP'} / ${refData['director'] ?? 'Dir'}', style: AppTypography.caption(context.palette).copyWith(color: context.palette.textSecondary)),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(child: BibleTechCard(label: 'Tono', value: refData['tone']?.toString() ?? '-')),
                            Expanded(child: BibleTechCard(label: 'Intención', value: refData['intent']?.toString() ?? '-')),
                          ],
                        ),
                      ],
                    ),
                  )),
                  TextButton.icon(
                    onPressed: () {
                      final updated = List<Map<String, dynamic>>.from(refsMetadata);
                      updated.add({'film': 'Nueva ref', 'dp': '', 'director': '', 'tone': '', 'intent': ''});
                      _updateCustomData(ref, {'refsMetadata': updated});
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Añadir referencia'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Global Attributes
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ATRIBUTOS GLOBALES', style: AppTypography.label(context.palette)),
                  const SizedBox(height: AppSpacing.md),
                  _buildSlider(context, 'Contraste', contrastValue, (v) => _updateCustomData(ref, {'contrastValue': v})),
                  _buildSlider(context, 'Saturación', saturationValue, (v) => _updateCustomData(ref, {'saturationValue': v})),
                  _buildSlider(context, 'Grano', grainValue, (v) => _updateCustomData(ref, {'grainValue': v})),
                ],
              ),
            ),
          ],
        ),
      },
    );
  }

  Widget _buildSlider(BuildContext context, String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(width: 100, child: Text(label, style: AppTypography.bodyMedium(context.palette))),
        Expanded(
          child: Slider(
            value: value,
            activeColor: context.palette.accent,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 40,
          child: Text(
            (value * 100).toInt().toString(),
            style: GoogleFonts.firaCode(textStyle: AppTypography.bodyMedium(context.palette)),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
