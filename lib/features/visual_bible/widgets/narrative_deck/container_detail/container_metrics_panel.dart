import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/visual_bible/bible_lighting_data.dart';
import '../../../visual_bible_model.dart';
import '../../bible_form_widgets.dart';

/// Métricas de luz del contenedor (Kelvin, tint, contraste, negros, fixtures).
///
/// Widget propio de la pantalla de contenedor; persiste en `card.meta['metrics']`.
class ContainerMetricsPanel extends StatefulWidget {
  final NarrativeCardModel card;
  final AppPalette palette;
  final ValueChanged<NarrativeCardModel> onChanged;

  const ContainerMetricsPanel({
    super.key,
    required this.card,
    required this.palette,
    required this.onChanged,
  });

  static Map<String, dynamic> metricsOf(NarrativeCardModel card) {
    final raw = card.meta['metrics'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  @override
  State<ContainerMetricsPanel> createState() => _ContainerMetricsPanelState();
}

class _ContainerMetricsPanelState extends State<ContainerMetricsPanel> {
  late double _temp;
  late double _tint;
  late double _contrast;
  late double _blackLevel;
  late bool _crushedBlacks;

  @override
  void initState() {
    super.initState();
    _syncFromCard();
  }

  @override
  void didUpdateWidget(covariant ContainerMetricsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.card.meta != widget.card.meta) {
      _syncFromCard();
    }
  }

  void _syncFromCard() {
    final data = ContainerMetricsPanel.metricsOf(widget.card);
    _temp = BibleLightingData.colorTemp(data).toDouble();
    _tint = BibleLightingData.tintValue(data);
    _contrast = BibleLightingData.contrastNum(data).toDouble();
    _blackLevel = (data['blackLevelIre'] as num?)?.toDouble() ?? 0;
    _crushedBlacks = data['crushedBlacks'] == true;
  }

  String get _tintLabel {
    final sign = _tint >= 0 ? '+' : '';
    final side = _tint >= 0 ? 'G' : 'M';
    final abs = _tint.abs();
    return '$sign${abs.toStringAsFixed(2)} $side';
  }

  Future<void> _patch(Map<String, dynamic> patch) async {
    final nextMeta = Map<String, dynamic>.from(widget.card.meta);
    final metrics = {
      ...ContainerMetricsPanel.metricsOf(widget.card),
      ...patch,
    };
    nextMeta['metrics'] = metrics;
    widget.onChanged(widget.card.copyWith(meta: nextMeta));
  }

  Future<void> _editFixtures() async {
    final current = BibleLightingData.fixtureTypeLabels(
      ContainerMetricsPanel.metricsOf(widget.card),
    );
    final ctrl = TextEditingController(text: current.join(', '));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Material / fixtures sugeridos'),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'HMI Par, LED Panels (Cool), Practicals…',
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
    await _patch({'fixtureTypes': types});
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final data = ContainerMetricsPanel.metricsOf(widget.card);
    final types = BibleLightingData.fixtureTypeLabels(data);
    final materialsNote = data['materialsNote']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xB31A1A1C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'MÉTRICAS DEL CONTENEDOR',
            style: AppTypography.mono(palette).copyWith(
              fontSize: 11,
              letterSpacing: 1.2,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: 14),
          _MetricLabel(
            label: 'Color temp',
            value: '${_temp.round()}K',
            palette: palette,
          ),
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
              onChangeEnd: (v) => _patch({
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
          const SizedBox(height: 14),
          _MetricLabel(
            label: 'Tint (M ↔ G)',
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
              onChangeEnd: (v) => _patch({
                'tintValue': v,
                'tint':
                    '${v >= 0 ? '+' : ''}${v.toStringAsFixed(2)} ${v >= 0 ? 'G' : 'M'}',
              }),
            ),
          ),
          const SizedBox(height: 10),
          _MetricLabel(
            label: 'Contraste',
            value: '${_contrast.round()}:1',
            palette: palette,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Container(height: 12, color: Colors.white),
              ),
              Expanded(
                flex: _contrast.round().clamp(1, 32),
                child: Container(
                  height: 12,
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
              onChangeEnd: (v) => _patch({
                'contrastNum': v.round(),
                'contrastRatio': '${v.round()}:1',
              }),
            ),
          ),
          const SizedBox(height: 10),
          _MetricLabel(
            label: 'Negros (IRE)',
            value: '${_blackLevel.round()}%',
            palette: palette,
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(trackHeight: 4),
            child: Slider(
              value: _blackLevel.clamp(0, 20),
              min: 0,
              max: 20,
              divisions: 20,
              activeColor: palette.accent,
              inactiveColor: Colors.white12,
              onChanged: (v) => setState(() => _blackLevel = v),
              onChangeEnd: (v) => _patch({'blackLevelIre': v.round()}),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Crushed blacks',
                  style: AppTypography.bodyMedium(palette).copyWith(fontSize: 12),
                ),
              ),
              Switch(
                value: _crushedBlacks,
                activeThumbColor: palette.accent,
                onChanged: (v) {
                  setState(() => _crushedBlacks = v);
                  _patch({'crushedBlacks': v});
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'MATERIAL / FIXTURES',
                  style: AppTypography.mono(palette).copyWith(
                    fontSize: 10,
                    letterSpacing: 1.1,
                    color: palette.textTertiary,
                  ),
                ),
              ),
              TextButton(
                onPressed: _editFixtures,
                child: Text(
                  'Editar',
                  style: TextStyle(color: palette.accent, fontSize: 12),
                ),
              ),
            ],
          ),
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
          const SizedBox(height: 12),
          BibleTextField(
            label: 'Ideas de material',
            hint: 'Difusión pesada, bounce blanco, gel ½ CTB…',
            maxLines: 3,
            initialValue: materialsNote,
            onChanged: (v) => _patch({'materialsNote': v}),
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
