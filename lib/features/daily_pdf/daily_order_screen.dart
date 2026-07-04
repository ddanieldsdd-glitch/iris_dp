import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/feature_coming_soon_card.dart';
import '../technical_script/technical_script_screen.dart';

/// Jornada de rodaje: PDF del día en set (planificado para fase de rodaje).
class DailyOrderScreen extends ConsumerWidget {
  final int projectId;
  final String projectName;

  const DailyOrderScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: palette.surface,
        title: Text(
          'Jornada de rodaje',
          style: AppTypography.titleMedium(palette),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.xl),
        children: [
          const FeatureComingSoonCard(
            icon: Icons.calendar_today_outlined,
            title: 'Orden del día en set',
            description:
                'Cuando estéis en rodaje, aquí podréis elegir qué planos se '
                'graban cada jornada, reordenarlos según el call sheet real '
                'y exportar un PDF para el equipo (cámara, script, eléctricos…).\n\n'
                'No es lo mismo que el guion técnico: ese documento incluye '
                'todo el proyecto; la jornada de rodaje es solo un día concreto.',
            plannedFeatures: [
              'Selección de planos por fecha de rodaje',
              'Reordenación drag-and-drop del día',
              'PDF call sheet listo para imprimir',
              'Portada con fecha, localización y notas',
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            'Mientras tanto',
            style: AppTypography.label(palette),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Usa el guion técnico para el desglose completo y exportar PDF '
            'de todas las escenas y planos de «$projectName».',
            style: AppTypography.bodyMedium(palette),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => TechnicalScriptScreen(projectId: projectId),
              ),
            ),
            icon: const Icon(Icons.table_rows_outlined),
            label: const Text('Abrir guion técnico'),
          ),
        ],
      ),
    );
  }
}
