import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/visual_bible/bible_lighting_data.dart';
import '../bible_form_widgets.dart';

/// Panel lateral del overview: sensación de temperatura + métricas globales.
class LightingGlobalMetricsPanel extends StatefulWidget {
  final Map<String, dynamic> lightingData;
  final Future<void> Function(Map<String, dynamic> patch) onUpdate;

  const LightingGlobalMetricsPanel({
    super.key,
    required this.lightingData,
    required this.onUpdate,
  });

  @override
  State<LightingGlobalMetricsPanel> createState() =>
      _LightingGlobalMetricsPanelState();
}

class _LightingGlobalMetricsPanelState extends State<LightingGlobalMetricsPanel> {
  late double _temp;
  late double _tint;
  late double _contrast;

  @override
  void initState() {
    super.initState();
    _syncFromData();
  }

  @override
  void didUpdateWidget(covariant LightingGlobalMetricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lightingData != widget.lightingData) {
      _syncFromData();
    }
  }

  void _syncFromData() {
    final data = widget.lightingData;
    _temp = BibleLightingData.colorTemp(data).toDouble();
    _tint = BibleLightingData.tintValue(data);
    _contrast = BibleLightingData.contrastNum(data).toDouble();
  }

  String get _tintLabel {
    final sign = _tint >= 0 ? '+' : '';
    return '$sign${_tint.toStringAsFixed(2)} G';
  }

  Future<void> _editFixtureTypes() async {
    final current = BibleLightingData.fixtureTypeLabels(widget.lightingData);
    final ctrl = TextEditingController(text: current.join(', '));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tipos de fixture principales'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'HMI Par, LED Panels, Practicals…',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final types = ctrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
    await widget.onUpdate({'fixtureTypes': types});
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final data = widget.lightingData;
    final types = BibleLightingData.fixtureTypeLabels(data);
    final tempNote = (data['temperatureNote'] as String?) ?? '';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xB31A1A1C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'SENSACIÓN DE TEMPERATURA',
            style: AppTypography.mono(palette).copyWith(
              fontSize: 11,
              letterSpacing: 1.2,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: 12),
          BibleTextField(
            label: 'Sensación general de la luz',
            hint: 'Fría y clínica, cálida y acogedora, mixta día/noche…',
            maxLines: 4,
            initialValue: tempNote,
            onChanged: (v) => widget.onUpdate({'temperatureNote': v}),
          ),
          const SizedBox(height: 20),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.08)),
          const SizedBox(height: 16),
          Text(
            'MÉTRICAS GLOBALES',
            style: AppTypography.mono(palette).copyWith(
              fontSize: 10,
              letterSpacing: 1.3,
              color: palette.textTertiary,
            ),
          ),
          const SizedBox(height: 14),
          _MetricLabel(
            label: 'Color temp',
            value: '${_temp.round()}K',
            palette: palette,
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: _temp.clamp(2000, 10000),
              min: 2000,
              max: 10000,
              divisions: 80,
              activeColor: palette.accent,
              inactiveColor: Colors.white12,
              onChanged: (v) => setState(() => _temp = v),
              onChangeEnd: (v) => widget.onUpdate({
                'colorTemp': v.round(),
                'targetKelvin': v.round(),
              }),
            ),
          ),
          Container(
            height: 5,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: const LinearGradient(
                colors: [Color(0xFFFF8914), Colors.white, Color(0xFF5C98FF)],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _MetricLabel(
            label: 'Tint / shift',
            value: _tintLabel,
            palette: palette,
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 4),
            child: Slider(
              value: _tint.clamp(-0.5, 0.5),
              min: -0.5,
              max: 0.5,
              divisions: 100,
              activeColor: palette.accent,
              inactiveColor: Colors.white12,
              onChanged: (v) => setState(() => _tint = v),
              onChangeEnd: (v) => widget.onUpdate({
                'tintValue': v,
                'tint': '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)} G',
              }),
            ),
          ),
          const SizedBox(height: 12),
          _MetricLabel(
            label: 'Contraste (objetivo)',
            value: '${_contrast.round()}:1',
            palette: palette,
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(height: 14, color: Colors.white),
              ),
              Expanded(
                flex: _contrast.round().clamp(1, 32),
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 2),
            child: Slider(
              value: _contrast.clamp(2, 32),
              min: 2,
              max: 32,
              divisions: 30,
              activeColor: palette.accent,
              inactiveColor: Colors.white12,
              onChanged: (v) => setState(() => _contrast = v),
              onChangeEnd: (v) => widget.onUpdate({
                'contrastNum': v.round(),
                'contrastRatio': '${v.round()}:1',
              }),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'FIXTURES PRINCIPALES',
                  style: AppTypography.mono(palette).copyWith(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: palette.textTertiary,
                  ),
                ),
              ),
              TextButton(
                onPressed: _editFixtureTypes,
                child: Text(
                  'Editar',
                  style: TextStyle(color: palette.accent, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (types.isEmpty)
            Text(
              'HMI, LED, prácticos…',
              style: AppTypography.bodyMedium(palette).copyWith(
                fontSize: 12,
                color: palette.textTertiary,
              ),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in types)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Text(
                      t,
                      style: AppTypography.mono(palette).copyWith(fontSize: 11),
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MetricLabel extends StatelessWidget {
  final String label;
  final String value;
  final AppPalette palette;

  const _MetricLabel({
    required this.label,
    required this.value,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label.toUpperCase(),
            style: AppTypography.mono(palette).copyWith(
              fontSize: 10,
              letterSpacing: 1.1,
              color: palette.textTertiary,
            ),
          ),
        ),
        Text(
          value,
          style: AppTypography.mono(palette).copyWith(
            fontSize: 12,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}
