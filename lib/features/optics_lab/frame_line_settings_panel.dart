import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'frame_line_geometry.dart';
import 'frame_line_models.dart';

/// Panel de ajustes FLT estilo ARRI (tabs A/B/C + guías).
class FrameLineSettingsPanel extends StatelessWidget {
  final List<FrameLineConfig> configs;
  final FltSettingsTab activeTab;
  final ValueChanged<FltSettingsTab> onTabChanged;
  final ValueChanged<FrameLineConfig> onConfigChanged;
  final ComputedFrameLine? activeComputed;
  final LensIlluminationGuideConfig lensGuide;
  final ValueChanged<LensIlluminationGuideConfig> onLensGuideChanged;
  final FrameLeaderConfig frameLeader;
  final ValueChanged<FrameLeaderConfig> onFrameLeaderChanged;

  const FrameLineSettingsPanel({
    super.key,
    required this.configs,
    required this.activeTab,
    required this.onTabChanged,
    required this.onConfigChanged,
    this.activeComputed,
    required this.lensGuide,
    required this.onLensGuideChanged,
    required this.frameLeader,
    required this.onFrameLeaderChanged,
  });

  int get _frameLineIndex => switch (activeTab) {
        FltSettingsTab.frameLineA => 0,
        FltSettingsTab.frameLineB => 1,
        FltSettingsTab.frameLineC => 2,
        _ => 0,
      };

  bool get _isFrameLineTab =>
      activeTab == FltSettingsTab.frameLineA ||
      activeTab == FltSettingsTab.frameLineB ||
      activeTab == FltSettingsTab.frameLineC;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
          color: const Color(0xFF1565C0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Frame Line & Lens Illumination Settings',
                  style: AppTypography.caption(palette).copyWith(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: _resetActive,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white70,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Reset', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _tabChip(context, 'Frame Line A', FltSettingsTab.frameLineA, const Color(0xFFFFD600)),
              _tabChip(context, 'Frame Line B', FltSettingsTab.frameLineB, const Color(0xFF00E5FF)),
              _tabChip(context, 'Frame Line C', FltSettingsTab.frameLineC, const Color(0xFFFF5252)),
              _tabChip(context, 'Lens Illumination Guide', FltSettingsTab.lensIlluminationGuide, null),
              _tabChip(context, 'Frame Leader', FltSettingsTab.frameLeader, null),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        if (_isFrameLineTab)
          _buildFrameLineFields(context, palette, configs[_frameLineIndex.clamp(0, configs.length - 1)])
        else if (activeTab == FltSettingsTab.lensIlluminationGuide)
          _buildLensGuideFields(context, palette)
        else
          _buildFrameLeaderFields(context, palette),
      ],
    );
  }

  void _resetActive() {
    if (_isFrameLineTab) {
      final idx = _frameLineIndex;
      final defaults = FrameLineConfig.defaults();
      if (idx < defaults.length) {
        onConfigChanged(defaults[idx]);
      }
      return;
    }
    if (activeTab == FltSettingsTab.lensIlluminationGuide) {
      onLensGuideChanged(const LensIlluminationGuideConfig());
      return;
    }
    onFrameLeaderChanged(const FrameLeaderConfig());
  }

  Widget _tabChip(BuildContext context, String label, FltSettingsTab tab, Color? accent) {
    final selected = activeTab == tab;
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: selected ? Colors.black87 : null,
            fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        selected: selected,
        selectedColor: accent ?? Theme.of(context).colorScheme.primaryContainer,
        onSelected: (_) => onTabChanged(tab),
      ),
    );
  }

  Widget _buildFrameLineFields(BuildContext context, AppPalette palette, FrameLineConfig cfg) {
    return KeyedSubtree(
      key: ValueKey('${cfg.id}_${cfg.scalingPercent}_${cfg.offsetLeftPx}_${cfg.offsetTopPx}'),
      child: _buildFrameLineFieldsInner(context, palette, cfg),
    );
  }

  Widget _buildFrameLineFieldsInner(BuildContext context, AppPalette palette, FrameLineConfig cfg) {
    final presetId = cfg.aspectPreset.isCustom
        ? 'custom'
        : (kAspectRatioPresets
                .where((p) => p.ratio != null && cfg.effectiveAspectRatio != null)
                .where((p) => (p.ratio! - cfg.effectiveAspectRatio!).abs() < 0.02)
                .map((p) => p.id)
                .firstOrNull ??
            cfg.aspectPreset.id);

    final wPx = activeComputed?.widthPx;
    final hPx = activeComputed?.heightPx;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Aspect Ratio'),
          initialValue: presetId == 'custom' || kAspectRatioPresets.any((p) => p.id == presetId)
              ? presetId
              : 'custom',
          items: kAspectRatioPresets
              .map((p) => DropdownMenuItem(value: p.id, child: Text(p.label)))
              .toList(),
          onChanged: (id) async {
            if (id == null) return;
            if (id == 'custom') {
              final custom = await _promptCustomAspect(context, cfg.customAspectRatio);
              if (custom == null) return;
              onConfigChanged(cfg.copyWith(
                aspectPreset: const AspectRatioPreset(id: 'custom', label: 'Personalizado'),
                customAspectRatio: custom,
                formatName: 'Custom ${custom.toStringAsFixed(2)}:1',
              ));
              return;
            }
            final preset = kAspectRatioPresets.firstWhere((p) => p.id == id);
            onConfigChanged(cfg.copyWith(
              aspectPreset: preset,
              formatName: preset.label,
            ));
          },
        ),
        if (cfg.aspectPreset.isCustom && cfg.customAspectRatio != null)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Ratio: ${cfg.customAspectRatio!.toStringAsFixed(3)}:1',
              style: AppTypography.caption(palette),
            ),
            trailing: TextButton(
              onPressed: () async {
                final custom = await _promptCustomAspect(context, cfg.customAspectRatio);
                if (custom != null) {
                  onConfigChanged(cfg.copyWith(customAspectRatio: custom));
                }
              },
              child: const Text('Editar'),
            ),
          ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Aspect Lock'),
          value: cfg.aspectLock,
          onChanged: (v) => onConfigChanged(cfg.copyWith(aspectLock: v ?? true)),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Frame Line'),
          value: cfg.showFrameLine,
          onChanged: (v) => onConfigChanged(cfg.copyWith(showFrameLine: v ?? true)),
        ),
        Text('Scaling: ${cfg.scalingPercent.toStringAsFixed(0)}%',
            style: AppTypography.caption(palette)),
        Slider(
          value: cfg.scalingPercent.clamp(10, 100),
          min: 10,
          max: 100,
          divisions: 18,
          onChanged: (v) => onConfigChanged(cfg.copyWith(scalingPercent: v)),
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'W (px)',
                  filled: true,
                  fillColor: palette.surfaceElevated,
                ),
                controller: TextEditingController(text: wPx?.toString() ?? '—'),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'H (px)',
                  filled: true,
                  fillColor: palette.surfaceElevated,
                ),
                controller: TextEditingController(text: hPx?.toString() ?? '—'),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(labelText: 'Offset Left (px)'),
                keyboardType: TextInputType.number,
                initialValue: cfg.offsetLeftPx.round().toString(),
                onChanged: (v) {
                  final n = double.tryParse(v) ?? 0;
                  onConfigChanged(cfg.copyWith(offsetLeftPx: n));
                },
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextFormField(
                decoration: const InputDecoration(labelText: 'Offset Top (px)'),
                keyboardType: TextInputType.number,
                initialValue: cfg.offsetTopPx.round().toString(),
                onChanged: (v) {
                  final n = double.tryParse(v) ?? 0;
                  onConfigChanged(cfg.copyWith(offsetTopPx: n));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<FrameLineShading>(
          decoration: const InputDecoration(labelText: 'Shading'),
          initialValue: cfg.shading,
          items: const [
            DropdownMenuItem(value: FrameLineShading.none, child: Text('None')),
            DropdownMenuItem(
              value: FrameLineShading.outsideFrameLine,
              child: Text('Outside Frame Line'),
            ),
            DropdownMenuItem(
              value: FrameLineShading.outsideSensor,
              child: Text('Outside Sensor'),
            ),
          ],
          onChanged: (v) {
            if (v != null) onConfigChanged(cfg.copyWith(shading: v));
          },
        ),
        DropdownButtonFormField<FrameLineCenterMark>(
          decoration: const InputDecoration(labelText: 'Center Mark'),
          initialValue: cfg.centerMark,
          items: const [
            DropdownMenuItem(value: FrameLineCenterMark.none, child: Text('None')),
            DropdownMenuItem(value: FrameLineCenterMark.cross, child: Text('Cross')),
            DropdownMenuItem(value: FrameLineCenterMark.dot, child: Text('Dot')),
            DropdownMenuItem(value: FrameLineCenterMark.crossDot, child: Text('Cross + Dot')),
          ],
          onChanged: (v) {
            if (v != null) onConfigChanged(cfg.copyWith(centerMark: v));
          },
        ),
        DropdownButtonFormField<FrameLineAlignCenterTo>(
          decoration: const InputDecoration(labelText: 'Align Center to'),
          initialValue: cfg.alignCenterTo,
          items: [
            const DropdownMenuItem(value: FrameLineAlignCenterTo.none, child: Text('None')),
            if (cfg.id != 'A')
              const DropdownMenuItem(value: FrameLineAlignCenterTo.lineA, child: Text('A')),
            if (cfg.id != 'B')
              const DropdownMenuItem(value: FrameLineAlignCenterTo.lineB, child: Text('B')),
            if (cfg.id != 'C')
              const DropdownMenuItem(value: FrameLineAlignCenterTo.lineC, child: Text('C')),
          ],
          onChanged: (v) {
            if (v != null) onConfigChanged(cfg.copyWith(alignCenterTo: v));
          },
        ),
        DropdownButtonFormField<FrameLineStyle>(
          decoration: const InputDecoration(labelText: 'Style'),
          initialValue: cfg.style,
          items: const [
            DropdownMenuItem(value: FrameLineStyle.fullBox, child: Text('Full Box')),
            DropdownMenuItem(value: FrameLineStyle.corners, child: Text('Corners')),
            DropdownMenuItem(value: FrameLineStyle.crosshair, child: Text('Crosshair')),
          ],
          onChanged: (v) {
            if (v != null) onConfigChanged(cfg.copyWith(style: v));
          },
        ),
        if (cfg.style == FrameLineStyle.corners)
          DropdownButtonFormField<FrameLineStyleLength>(
            decoration: const InputDecoration(labelText: 'Style Length'),
            initialValue: cfg.styleLength,
            items: const [
              DropdownMenuItem(value: FrameLineStyleLength.regular, child: Text('Regular')),
              DropdownMenuItem(value: FrameLineStyleLength.short, child: Text('Short')),
            ],
            onChanged: (v) {
              if (v != null) onConfigChanged(cfg.copyWith(styleLength: v));
            },
          ),
        DropdownButtonFormField<double>(
          decoration: const InputDecoration(labelText: 'Line Width'),
          initialValue: cfg.lineWidth.clamp(1, 8),
          items: List.generate(
            8,
            (i) => DropdownMenuItem(value: (i + 1).toDouble(), child: Text('${i + 1}')),
          ),
          onChanged: (v) {
            if (v != null) onConfigChanged(cfg.copyWith(lineWidth: v));
          },
        ),
        TextFormField(
          decoration: InputDecoration(
            labelText: 'Format Name',
            helperText: cfg.formatName ?? cfg.aspectPreset.label,
            counterText: cfg.formatName != null
                ? 'Max. 32 caracteres (${32 - cfg.formatName!.length} restantes)'
                : null,
          ),
          maxLength: 32,
          initialValue: cfg.formatName,
          onChanged: (v) => onConfigChanged(cfg.copyWith(formatName: v)),
        ),
      ],
    );
  }

  Widget _buildLensGuideFields(BuildContext context, AppPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Guía de iluminación de lente en el preview',
          style: AppTypography.caption(palette),
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Image Circle'),
          value: lensGuide.showImageCircle,
          onChanged: (v) => onLensGuideChanged(lensGuide.copyWith(showImageCircle: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Vignette Outside Circle'),
          value: lensGuide.vignetteOutsideCircle,
          onChanged: (v) => onLensGuideChanged(lensGuide.copyWith(vignetteOutsideCircle: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Coverage Fill'),
          value: lensGuide.showCoverageFill,
          onChanged: (v) => onLensGuideChanged(lensGuide.copyWith(showCoverageFill: v)),
        ),
      ],
    );
  }

  Widget _buildFrameLeaderFields(BuildContext context, AppPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Frame Leader'),
          value: frameLeader.enabled,
          onChanged: (v) => onFrameLeaderChanged(frameLeader.copyWith(enabled: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show Safe Area'),
          value: frameLeader.showSafeArea,
          onChanged: frameLeader.enabled
              ? (v) => onFrameLeaderChanged(frameLeader.copyWith(showSafeArea: v))
              : null,
        ),
        Text('Leader aspect: ${frameLeader.aspectRatio.toStringAsFixed(2)}:1',
            style: AppTypography.caption(palette)),
        Slider(
          value: frameLeader.aspectRatio.clamp(1.33, 2.39),
          min: 1.33,
          max: 2.39,
          divisions: 20,
          onChanged: frameLeader.enabled
              ? (v) => onFrameLeaderChanged(frameLeader.copyWith(aspectRatio: v))
              : null,
        ),
      ],
    );
  }

  Future<double?> _promptCustomAspect(BuildContext context, double? current) async {
    final wCtrl = TextEditingController(text: current != null ? (current * 1000).round().toString() : '1660');
    final hCtrl = TextEditingController(text: '1000');
    return showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aspect ratio personalizado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Introduce ancho y alto (valores relativos, ej. 1660 × 1000 = 1.66:1)'),
            const SizedBox(height: 12),
            TextField(
              controller: wCtrl,
              decoration: const InputDecoration(labelText: 'Ancho'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
            TextField(
              controller: hCtrl,
              decoration: const InputDecoration(labelText: 'Alto'),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              final w = double.tryParse(wCtrl.text);
              final h = double.tryParse(hCtrl.text);
              if (w == null || h == null || h <= 0) {
                Navigator.pop(ctx);
                return;
              }
              Navigator.pop(ctx, w / h);
            },
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
