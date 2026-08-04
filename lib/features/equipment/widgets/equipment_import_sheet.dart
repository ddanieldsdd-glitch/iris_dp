import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/app_button.dart';
import '../data/equipment_spreadsheet_models.dart';

class EquipmentImportSheet extends StatelessWidget {
  final EquipmentImportPreview preview;
  final VoidCallback onApply;
  final VoidCallback onCancel;
  final bool applying;

  const EquipmentImportSheet({
    super.key,
    required this.preview,
    required this.onApply,
    required this.onCancel,
    this.applying = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Importar lista de equipo',
              style: AppTypography.titleMedium(palette),
            ),
            const SizedBox(height: AppSpacing.md),
            if (preview.canApply && preview.totalChanges == 0)
              Text(
                'El archivo coincide con la lista actual. No hay cambios.',
                style: AppTypography.bodyMedium(palette),
              )
            else ...[
              _SummaryRow(
                palette: palette,
                label: 'Asignaciones nuevas',
                value: preview.assignmentsAdded,
              ),
              _SummaryRow(
                palette: palette,
                label: 'Asignaciones eliminadas',
                value: preview.assignmentsRemoved,
              ),
              _SummaryRow(
                palette: palette,
                label: 'Asignaciones actualizadas',
                value: preview.assignmentsUpdated,
              ),
              _SummaryRow(
                palette: palette,
                label: 'Custom creados',
                value: preview.customCreated,
              ),
              _SummaryRow(
                palette: palette,
                label: 'Custom actualizados',
                value: preview.customUpdated,
              ),
              _SummaryRow(
                palette: palette,
                label: 'Custom eliminados',
                value: preview.customDeleted,
              ),
            ],
            if (preview.warnings.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Advertencias',
                style: AppTypography.label(palette),
              ),
              const SizedBox(height: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 120),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: preview.warnings
                        .map(
                          (w) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $w',
                              style: AppTypography.caption(palette).copyWith(
                                color: palette.warning,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
            if (preview.errors.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Errores',
                style: AppTypography.label(palette),
              ),
              const SizedBox(height: AppSpacing.xs),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 160),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: preview.errors
                        .map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $e',
                              style: AppTypography.caption(palette).copyWith(
                                color: palette.error,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: applying ? null : onCancel,
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: AppButton(
                    label: applying ? 'Aplicando…' : 'Aplicar',
                    onTap: preview.canApply && !applying ? onApply : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final AppPalette palette;
  final String label;
  final int value;

  const _SummaryRow({
    required this.palette,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodyMedium(palette)),
          Text(
            '$value',
            style: AppTypography.bodyMedium(palette).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool?> showEquipmentImportSheet(
  BuildContext context, {
  required EquipmentImportPreview preview,
  required Future<void> Function() onApply,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      var applying = false;
      return StatefulBuilder(
        builder: (context, setState) {
          return EquipmentImportSheet(
            preview: preview,
            applying: applying,
            onCancel: () => Navigator.pop(ctx, false),
            onApply: () async {
              setState(() => applying = true);
              try {
                await onApply();
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Error al importar: $e')),
                  );
                  setState(() => applying = false);
                }
              }
            },
          );
        },
      );
    },
  );
}
