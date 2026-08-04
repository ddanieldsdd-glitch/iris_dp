import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../bible_form_widgets.dart';
import 'section_scaffold.dart';

class TextureSection extends StatelessWidget {
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

  static const _textures = [
    'Grano orgánico',
    'Limpieza digital',
    'Degradado',
    'Mixto',
  ];
  static const _grains = ['Ninguno', 'Sutil', 'Medio', 'Pronunciado'];

  @override
  Widget build(BuildContext context) {
    final settingsLabel = BibleSectionFieldsConfig.labelFor(
      sectionContentJson,
      BibleSectionId.texture,
      'textureSettings',
      'Estilo de textura',
    );

    return BibleSectionScaffold(
      sectionId: BibleSectionId.texture,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          '¿Qué textura de imagen refuerza el tono emocional? '
          'Grano, halation, ruido en sombras…',
      fieldWidgets: {
        'textureSettings': AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settingsLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.md),
              BibleDropdown(
                label: 'Textura de imagen',
                options: _textures,
                value: data.imageTexture,
                onChanged: (v) {
                  data.imageTexture = v;
                  onChanged(data);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              BibleDropdown(
                label: 'Grano',
                options: _grains,
                value: data.grainLevel,
                onChanged: (v) {
                  data.grainLevel = v;
                  onChanged(data);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              BibleTextField(
                label: 'Comportamiento del sensor en sombras',
                hint: 'Ruido limpio vs. textura orgánica…',
                maxLines: 3,
                initialValue: data.sensorShadowBehavior,
                onChanged: (v) {
                  data.sensorShadowBehavior =
                      v.trim().isEmpty ? null : v.trim();
                  onChanged(data);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              BibleTextField(
                label: 'Diffusion / halation como textura',
                hint: '1/4 Pro-Mist para suavizar highlights…',
                maxLines: 3,
                initialValue: data.diffusionNotes,
                onChanged: (v) {
                  data.diffusionNotes = v.trim().isEmpty ? null : v.trim();
                  onChanged(data);
                },
              ),
            ],
          ),
        ),
      },
    );
  }
}
