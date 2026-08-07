// /Users/danieldiaz/Documents/IRIS DP/iris_dp/lib/features/visual_bible/widgets/sections/texture_section.dart
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

class TextureSection extends ConsumerStatefulWidget {
  final VisualBibleData data;
  final int projectId;
  final String? sectionContentJson;
  final BibleChanged onChanged;

  const TextureSection({
    super.key,
    required this.data,
    required this.projectId,
    this.sectionContentJson,
    required this.onChanged,
  });

  @override
  ConsumerState<TextureSection> createState() => _TextureSectionState();
}

class _TextureSectionState extends ConsumerState<TextureSection> {
  Map<String, dynamic> _getCustomData() {
    if (widget.sectionContentJson == null) return {};
    try {
      final decoded = jsonDecode(widget.sectionContentJson!);
      if (decoded is Map<String, dynamic> && decoded.containsKey('_values')) {
        final vals = decoded['_values'] as Map<String, dynamic>;
        if (vals.containsKey('textureData')) {
          return jsonDecode(vals['textureData'] as String);
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
      ..where((d) => d.bibleId.equals(widget.data.id) & d.id.equals(BibleSectionId.texture))).getSingleOrNull();
    if (def != null) {
      final fields = BibleSectionFieldsConfig.parse(def.contentJson, BibleSectionId.texture);
      final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
      values['textureData'] = jsonEncode(newData);
      await db.upsertBibleSectionDefinition(def.copyWith(
        contentJson: drift.Value(BibleSectionFieldsConfig.encode(fields, values: values)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final customData = _getCustomData();
    final grainEnabled = customData['grainEnabled'] as bool? ?? false;
    final grainSize = (customData['grainSize'] as num?)?.toDouble() ?? 0.5;
    final grainIntensity = (customData['grainIntensity'] as num?)?.toDouble() ?? 0.5;
    final grainColorVariation = (customData['grainColorVariation'] as num?)?.toDouble() ?? 0.5;
    final grainPreset = customData['grainPreset'] as String? ?? 'Kodak 5219';
    final diffusionEnabled = customData['diffusionEnabled'] as bool? ?? false;
    final diffusionFilter = customData['diffusionFilter'] as String? ?? 'Pro-Mist';
    final diffusionStrength = (customData['diffusionStrength'] as num?)?.toDouble() ?? 0.5;
    final diffusionDensity = (customData['diffusionDensity'] as num?)?.toDouble() ?? 0.5;
    final noiseFloorRaw = customData['noiseFloor'] as List<dynamic>? ?? [];
    final noiseFloor = noiseFloorRaw.map((e) => e.toString()).toList();

    return BibleSectionScaffold(
      sectionId: BibleSectionId.texture,
      projectId: widget.projectId,
      data: widget.data,
      onChanged: widget.onChanged,
      sectionContentJson: widget.sectionContentJson,
      narrativeHint: '¿Qué textura de imagen refuerza el tono emocional?',
      sectionNumber: '08',
      sectionTitle: 'Textura',
      fieldWidgets: {
        'textureSettings': Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Highlight / Shadow Split
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: context.palette.border.withValues(alpha: 0.5))),
                      ),
                      padding: const EdgeInsets.only(right: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('HIGHLIGHT ROLL-OFF', style: AppTypography.caption(context.palette).copyWith(color: context.palette.textSecondary)),
                          const SizedBox(height: AppSpacing.xs),
                          Text(widget.data.highlightBehavior ?? 'Sin definir', style: AppTypography.bodyMedium(context.palette)),
                          const SizedBox(height: AppSpacing.sm),
                          BibleTextField(
                            label: 'Notas Highlights',
                            hint: 'Rolloff suave...',
                            maxLines: 2,
                            initialValue: widget.data.highlightBehavior,
                            onChanged: (v) {
                              widget.data.highlightBehavior = v;
                              widget.onChanged(widget.data);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.only(left: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('SHADOW DETAIL', style: AppTypography.caption(context.palette).copyWith(color: context.palette.textSecondary)),
                          const SizedBox(height: AppSpacing.xs),
                          Text(widget.data.shadowBehavior ?? 'Sin definir', style: AppTypography.bodyMedium(context.palette)),
                          const SizedBox(height: AppSpacing.sm),
                          BibleTextField(
                            label: 'Notas Sombras',
                            hint: 'Negros lavados...',
                            maxLines: 2,
                            initialValue: widget.data.shadowBehavior,
                            onChanged: (v) {
                              widget.data.shadowBehavior = v;
                              widget.onChanged(widget.data);
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            
            // Film Grain
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Switch(
                            value: grainEnabled,
                            onChanged: (v) => _updateCustomData({'grainEnabled': v}),
                            activeThumbColor: context.palette.accent,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Grano activo', style: AppTypography.titleMedium(context.palette)),
                        ],
                      ),
                      SizedBox(
                        width: 220,
                        child: BibleDropdown(
                          label: '',
                          options: const ['Kodak 5219', 'Fuji 8522', 'Ilford HP5', 'Sin emulación'],
                          value: grainPreset,
                          onChanged: (v) => _updateCustomData({'grainPreset': v}),
                        ),
                      ),
                    ],
                  ),
                  if (grainEnabled) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildSlider(context, 'Tamaño', grainSize, (v) => _updateCustomData({'grainSize': v})),
                    _buildSlider(context, 'Intensidad', grainIntensity, (v) => _updateCustomData({'grainIntensity': v})),
                    _buildSlider(context, 'Variación de color', grainColorVariation, (v) => _updateCustomData({'grainColorVariation': v})),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  BibleTextField(
                    label: 'Notas de grano',
                    hint: 'Añadir notas sobre la textura del grano...',
                    maxLines: 2,
                    initialValue: widget.data.grainLevel,
                    onChanged: (v) {
                      widget.data.grainLevel = v;
                      widget.onChanged(widget.data);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Diffusion Optics
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Switch(
                            value: diffusionEnabled,
                            onChanged: (v) => _updateCustomData({'diffusionEnabled': v}),
                            activeThumbColor: context.palette.accent,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Text('Difusión activa', style: AppTypography.titleMedium(context.palette)),
                        ],
                      ),
                      SizedBox(
                        width: 220,
                        child: BibleDropdown(
                          label: '',
                          options: const ['Pro-Mist', 'Black Magic', 'Glimmerglass', 'Hollywood Black'],
                          value: diffusionFilter,
                          onChanged: (v) => _updateCustomData({'diffusionFilter': v}),
                        ),
                      ),
                    ],
                  ),
                  if (diffusionEnabled) ...[
                    const SizedBox(height: AppSpacing.md),
                    _buildSlider(context, 'Fuerza', diffusionStrength, (v) => _updateCustomData({'diffusionStrength': v})),
                    _buildSlider(context, 'Densidad', diffusionDensity, (v) => _updateCustomData({'diffusionDensity': v})),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  BibleTextField(
                    label: 'Notas de difusión',
                    hint: 'Efectos en highlights, halation...',
                    maxLines: 2,
                    initialValue: widget.data.diffusionNotes,
                    onChanged: (v) {
                      widget.data.diffusionNotes = v;
                      widget.onChanged(widget.data);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            
            // Sensor Noise Floor
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('COMPORTAMIENTO EN SOMBRAS', style: AppTypography.label(context.palette)),
                  const SizedBox(height: AppSpacing.sm),
                  BibleSelectableChipRow(
                    options: const ['Shadow Chroma Noise', 'Fixed Pattern Noise', 'Push-Pull Processing', 'Clean'],
                    selected: noiseFloor,
                    onChanged: (opts) => _updateCustomData({'noiseFloor': opts}),
                    activeColor: context.palette.accent,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  BibleTextField(
                    label: 'Notas sobre ruido de sensor',
                    hint: 'Textura del ruido digital...',
                    maxLines: 2,
                    initialValue: widget.data.sensorShadowBehavior,
                    onChanged: (v) {
                      widget.data.sensorShadowBehavior = v;
                      widget.onChanged(widget.data);
                    },
                  ),
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
        SizedBox(width: 120, child: Text(label, style: AppTypography.bodyMedium(context.palette))),
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
