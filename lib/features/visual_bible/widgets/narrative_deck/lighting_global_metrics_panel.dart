import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/visual_bible/bible_lighting_data.dart';
import '../../../../shared/visual_bible/lighting_metrics.dart';
import '../bible_cards_widget.dart';
import '../bible_form_widgets.dart';
import '../bible_point_panel.dart';
import '../lighting/lighting_metrics_widget.dart';

/// Métricas generales de la luz del proyecto: color, contraste, qué hace
/// falta para conseguirlos y con qué fuentes se trabaja.
class LightingGlobalMetricsPanel extends StatelessWidget {
  final Map<String, dynamic> lightingData;
  final Future<void> Function(Map<String, dynamic> patch) onUpdate;

  /// Balance de blancos de la cámara, si se conoce.
  final int? whiteBalance;

  const LightingGlobalMetricsPanel({
    super.key,
    required this.lightingData,
    required this.onUpdate,
    this.whiteBalance,
  });

  /// Las métricas generales guardadas; si la biblia es anterior, lo que el
  /// usuario llegó a mover en el panel antiguo.
  static LightingMetrics metricsOf(Map<String, dynamic> data) =>
      data.containsKey('metrics')
      ? LightingMetrics.fromJson(data['metrics'])
      : LightingMetrics.fromLegacy(data);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = BiblePointPanel.labelStyle(palette);
    final types = BibleLightingData.fixtureTypeLabels(lightingData);
    final note = (lightingData['temperatureNote'] as String?) ?? '';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BiblePointPanel.decoration(palette),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LightingMetricsWidget(
            value: metricsOf(lightingData),
            whiteBalance: whiteBalance,
            onChanged: (next) => onUpdate({
              'metrics': next.toJson(),
              // Lo que leen el PDF y la planta mientras no usen lo nuevo.
              if (next.kelvin != null) ...{
                'colorTemp': next.kelvin,
                'targetKelvin': next.kelvin,
              },
              if (next.ratio != null) ...{
                'contrastNum': next.ratio!.round(),
                'contrastRatio': next.ratioOption!.label,
              },
            }),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('CÓMO SE SIENTE ESTA LUZ', style: label),
          const SizedBox(height: 6),
          BibleTextField(
            label: '',
            hint: 'Fría y clínica, cálida y cercana, sucia, limpia…',
            maxLines: 3,
            initialValue: note,
            onChanged: (v) => onUpdate({'temperatureNote': v}),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('FUENTES PRINCIPALES', style: label),
          const SizedBox(height: 6),
          BibleTagsWidget(
            tags: types,
            onChanged: (tags) => onUpdate({'fixtureTypes': tags}),
          ),
        ],
      ),
    );
  }
}
