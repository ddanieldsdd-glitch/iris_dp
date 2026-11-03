import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// Barra de la biblia en el iPhone: en vez del lateral fijo, el nombre de la
/// pantalla abierta abre el índice en una hoja, y el icono de ajustes abre
/// los ajustes de esa pantalla.
class BibleCompactSectionBar extends StatelessWidget {
  final String label;
  final VoidCallback onOpenSections;
  final VoidCallback? onOpenSettings;

  const BibleCompactSectionBar({
    super.key,
    required this.label,
    required this.onOpenSections,
    this.onOpenSettings,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Material(
      color: palette.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.border)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        height: 48,
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onOpenSections,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.menu, size: 20, color: palette.accent),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleMedium(palette),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        Icons.expand_more,
                        size: 20,
                        color: palette.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (onOpenSettings != null)
              IconButton(
                tooltip: 'Ajustes de pantalla',
                onPressed: onOpenSettings,
                icon: Icon(Icons.tune, color: palette.accent),
              ),
          ],
        ),
      ),
    );
  }
}
