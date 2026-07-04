import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_card.dart';
import 'luka_export_preview.dart';

/// Panel de resumen del contenido del export Unreal / LUKA.
class LukaBridgePreviewPanel extends StatelessWidget {
  final LukaExportPreview preview;
  final bool loading;
  final double canvasScale;
  final bool projectWide;

  const LukaBridgePreviewPanel({
    super.key,
    required this.preview,
    required this.loading,
    required this.canvasScale,
    this.projectWide = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (loading) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: palette.accent,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              'Calculando contenido del export…',
              style: AppTypography.bodyMedium(palette),
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            projectWide ? 'Resumen del proyecto' : 'Contenido del export',
            style: AppTypography.titleMedium(palette),
          ),
          if (!projectWide && preview.setName != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${preview.siteName != null ? '${preview.siteName} · ' : ''}'
              'Set: ${preview.setName}',
              style: AppTypography.caption(palette),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _MetricChip(
                palette: palette,
                icon: Icons.movie_outlined,
                label: '${preview.shotCount} planos',
              ),
              _MetricChip(
                palette: palette,
                icon: Icons.videocam_outlined,
                label: '${preview.cameraCount} cámaras',
              ),
              _MetricChip(
                palette: palette,
                icon: Icons.wb_incandescent_outlined,
                label: '${preview.lightCount} focos',
              ),
              _MetricChip(
                palette: palette,
                icon: Icons.lightbulb_outline,
                label: '${preview.lukaLightCount} LUKA',
                accent: true,
              ),
              if (preview.fallbackLightCount > 0)
                _MetricChip(
                  palette: palette,
                  icon: Icons.light_mode_outlined,
                  label: '${preview.fallbackLightCount} fallback UE',
                ),
              _MetricChip(
                palette: palette,
                icon: Icons.person_outline,
                label: '${preview.actorCount} actores',
              ),
              _MetricChip(
                palette: palette,
                icon: Icons.chair_outlined,
                label: '${preview.propCount} props',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(
            palette: palette,
            label: 'Movimiento de cámara',
            value: preview.camerasWithMovement > 0
                ? '${preview.camerasWithMovement} con trayectoria · '
                    '${preview.totalPathPoints} puntos de path'
                : 'Sin trayectorias dibujadas',
          ),
          _InfoRow(
            palette: palette,
            label: 'Escala export',
            value: '1 px = ${canvasScale}m (${(canvasScale * 100).toStringAsFixed(0)} cm)',
          ),
          if (preview.scaleSource == 'scan')
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Escala tomada del scan de localización',
                style: AppTypography.caption(palette).copyWith(
                  color: palette.accent,
                ),
              ),
            ),
          _InfoRow(
            palette: palette,
            label: 'Scan 3D',
            value: preview.hasScan
                ? 'Sí${preview.scanSource != null ? ' (${_scanLabel(preview.scanSource!)})' : ''}'
                : 'No importado en el set',
          ),
          if (preview.hasTopDown)
            _InfoRow(
              palette: palette,
              label: 'Planta cenital',
              value: 'Incluida en metadatos del set',
            ),
          if (preview.shots.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text('Detalle por plano', style: AppTypography.label(palette)),
            const SizedBox(height: AppSpacing.sm),
            ...preview.shots.take(8).map(
                  (s) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            'P${s.number}',
                            style: AppTypography.mono(palette),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _shotLine(s),
                            style: AppTypography.caption(palette),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            if (preview.shots.length > 8)
              Text(
                '+ ${preview.shots.length - 8} planos más',
                style: AppTypography.caption(palette),
              ),
          ],
          if (preview.lightCount > 0) ...[
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: palette.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.accent.withValues(alpha: 0.25)),
              ),
              child: Text(
                'Cobertura LUKA: ${preview.lukaLightCount} de ${preview.lightCount} '
                'focos (${_pct(preview.lukaLightCount, preview.lightCount)}%) · '
                '${preview.fallbackLightCount} usarán luces Unreal de respaldo',
                style: AppTypography.caption(palette),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _scanLabel(String source) => switch (source) {
        'luma_ai' => 'Luma AI',
        'polycam' => 'Polycam',
        'cinetracer' => 'Cine Tracer',
        _ => source,
      };

  static String _pct(int part, int total) {
    if (total == 0) return '0';
    return ((part / total) * 100).round().toString();
  }

  static String _shotLine(LukaExportShotPreview s) {
    final parts = <String>[
      if (s.primaryCameraLabel != null) 'Cam ${s.primaryCameraLabel}',
      if (s.lensMm != null) '${s.lensMm}mm',
      if (s.movement != null && s.movement!.isNotEmpty) s.movement!,
      '${s.lights} focos (${s.lukaLights} LUKA)',
      if (s.hasPath) 'path: ${s.pathPoints} pts',
      'planta: ${_planSourceLabel(s.planSource)}',
    ];
    return parts.join(' · ');
  }

  static String _planSourceLabel(String source) => switch (source) {
        'shot' => 'plano',
        'set_template' => 'set',
        'site_template' => 'loc.',
        _ => source,
      };
}

class _MetricChip extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final String label;
  final bool accent;

  const _MetricChip({
    required this.palette,
    required this.icon,
    required this.label,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ? palette.accent : palette.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent
            ? palette.accent.withValues(alpha: 0.1)
            : palette.surfaceOverlay.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent ? palette.accent.withValues(alpha: 0.35) : palette.divider,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(label, style: AppTypography.caption(palette).copyWith(color: color)),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final AppPalette palette;
  final String label;
  final String value;

  const _InfoRow({
    required this.palette,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: AppTypography.caption(palette)),
          ),
          Expanded(
            child: Text(value, style: AppTypography.bodyMedium(palette)),
          ),
        ],
      ),
    );
  }
}
