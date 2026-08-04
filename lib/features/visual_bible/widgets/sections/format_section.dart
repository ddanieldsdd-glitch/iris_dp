import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_card.dart';
import '../../bible_section_fields.dart';
import '../../visual_bible_model.dart';
import '../aspect_ratio_preview.dart';
import '../bible_form_widgets.dart';
import 'section_scaffold.dart';

class FormatSection extends StatelessWidget {
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

  static const _ratios = ['2.39:1', '1.85:1', '1.78:1', '1.66:1', '4:3'];

  @override
  Widget build(BuildContext context) {
    final settingsLabel = BibleSectionFieldsConfig.labelFor(
      sectionContentJson,
      BibleSectionId.format,
      'formatSettings',
      'Aspect ratio y entrega',
    );

    return BibleSectionScaffold(
      sectionId: BibleSectionId.format,
      projectId: projectId,
      data: data,
      onChanged: onChanged,
      sectionContentJson: sectionContentJson,
      narrativeHint:
          '¿Por qué este aspect ratio? Qué sensación de encuadre '
          'y composición queremos transmitir…',
      fieldWidgets: {
        'formatSettings': AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                settingsLabel,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: AppSpacing.md),
              BibleDropdown(
                label: 'Aspect ratio',
                options: _ratios,
                value: data.aspectRatio,
                onChanged: (v) {
                  data.aspectRatio = v;
                  onChanged(data);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              AspectRatioPreview(
                aspectRatio: data.aspectRatio,
                label: 'Preview proporcional del encuadre',
              ),
              const SizedBox(height: AppSpacing.lg),
              BibleTextField(
                label: 'Justificación narrativa',
                hint: 'Por qué este ratio…',
                maxLines: 4,
                initialValue: data.aspectRatioJustification,
                onChanged: (v) {
                  data.aspectRatioJustification =
                      v.trim().isEmpty ? null : v.trim();
                  onChanged(data);
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              const Divider(),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Captura y entrega',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: BibleTextField(
                      label: 'Resolución de captura',
                      hint: '4K DCI',
                      initialValue: data.captureResolution,
                      onChanged: (v) {
                        data.captureResolution =
                            v.trim().isEmpty ? null : v.trim();
                        onChanged(data);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: BibleTextField(
                      label: 'Resolución de entrega',
                      hint: '2K DCI (reencuadre)',
                      initialValue: data.deliveryResolution,
                      onChanged: (v) {
                        data.deliveryResolution =
                            v.trim().isEmpty ? null : v.trim();
                        onChanged(data);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      },
    );
  }
}
