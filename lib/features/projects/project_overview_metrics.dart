import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'project_overview.dart';

/// Barras de progreso compactas del resumen de proyecto.
class ProjectOverviewMetrics extends StatelessWidget {
  final ProjectOverview overview;

  const ProjectOverviewMetrics({super.key, required this.overview});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final metrics = overview.metricsForPalette(
      accent: palette.accent,
      success: palette.success,
      warning: palette.warning,
      info: const Color(0xFF64D2FF),
      secondary: palette.textSecondary,
    );

    return Column(
      children: metrics.map((metric) {
        final displayValue = metric.label == 'Biblia'
            ? '${metric.value}%'
            : '${metric.value}';
        return Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(
            children: [
              Icon(metric.icon, size: 12, color: metric.color),
              const SizedBox(width: 6),
              SizedBox(
                width: 58,
                child: Text(
                  metric.label,
                  style: AppTypography.caption(palette).copyWith(
                    color: palette.textSecondary,
                    fontSize: 10,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: metric.progress,
                    minHeight: 5,
                    backgroundColor: palette.border.withValues(alpha: 0.5),
                    color: metric.hasContent
                        ? metric.color
                        : palette.textTertiary.withValues(alpha: 0.35),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 28,
                child: Text(
                  displayValue,
                  textAlign: TextAlign.right,
                  style: AppTypography.caption(palette).copyWith(
                    fontSize: 10,
                    color: metric.hasContent
                        ? palette.textPrimary
                        : palette.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

/// Chip de fase del proyecto con indicador de actividad.
class ProjectStateChip extends StatelessWidget {
  final ProjectOverview overview;
  final String status;

  const ProjectStateChip({
    super.key,
    required this.overview,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final statusColor = switch (status) {
      'preproduction' => palette.warning,
      'shooting' => palette.success,
      'post' => palette.textTertiary,
      _ => palette.textTertiary,
    };
    final fill = (overview.totalScore / 80).clamp(0.0, 1.0);

    return Row(
      children: [
        SizedBox(
          width: 28,
          height: 28,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: fill == 0 ? null : fill,
                strokeWidth: 3,
                backgroundColor: palette.border,
                color: statusColor,
              ),
              Icon(Icons.insights_outlined, size: 12, color: statusColor),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                overview.stateLabel,
                style: AppTypography.caption(palette).copyWith(
                  color: palette.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                _statusLabel(status),
                style: AppTypography.caption(palette).copyWith(
                  color: statusColor,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _statusLabel(String status) => switch (status) {
        'preproduction' => 'Preproducción',
        'shooting' => 'Rodaje',
        'post' => 'Postproducción',
        _ => 'Sin fase',
      };
}
