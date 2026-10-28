import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_layout.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_button.dart';

/// Cabecera de la lista de proyectos.
///
/// En iPad y escritorio: título, iconos de estado y los dos botones con
/// texto. En el iPhone (IP.1.3) no caben: los dos botones pasan a un único
/// «+» con menú y los márgenes se estrechan.
class ProjectsHeader extends StatelessWidget {
  /// Ajustes, sincronización y cuenta: van igual en todos los tamaños.
  final List<Widget> statusActions;
  final VoidCallback onNewProject;
  final VoidCallback onNewGroup;

  const ProjectsHeader({
    super.key,
    required this.statusActions,
    required this.onNewProject,
    required this.onNewGroup,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final compact = AppLayout.isCompact(context);
    final gutter = AppLayout.gutter(context, regular: AppSpacing.xl);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        gutter,
        compact ? AppSpacing.md : AppSpacing.xl,
        gutter,
        compact ? AppSpacing.md : AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'IRIS',
                  style: compact
                      ? AppTypography.titleLarge(palette)
                      : AppTypography.displayMedium(palette),
                ),
                Text('Proyectos', style: AppTypography.bodyMedium(palette)),
              ],
            ),
          ),
          ...statusActions,
          if (compact)
            PopupMenuButton<VoidCallback>(
              tooltip: 'Nuevo',
              icon: Icon(Icons.add_circle, color: palette.accent, size: 30),
              color: palette.surfaceElevated,
              onSelected: (action) => action(),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: onNewProject,
                  child: const ListTile(
                    leading: Icon(Icons.add),
                    title: Text('Nuevo proyecto'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                PopupMenuItem(
                  value: onNewGroup,
                  child: const ListTile(
                    leading: Icon(Icons.create_new_folder_outlined),
                    title: Text('Nuevo grupo'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            )
          else ...[
            const SizedBox(width: AppSpacing.sm),
            AppButton(
              label: 'Nuevo grupo',
              icon: Icons.create_new_folder_outlined,
              variant: AppButtonVariant.secondary,
              onTap: onNewGroup,
            ),
            const SizedBox(width: AppSpacing.md),
            AppButton(
              label: 'Nuevo proyecto',
              icon: Icons.add,
              onTap: onNewProject,
            ),
          ],
        ],
      ),
    );
  }
}
