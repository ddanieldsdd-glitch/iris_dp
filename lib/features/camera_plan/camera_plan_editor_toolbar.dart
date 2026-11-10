// Avisos, capas y barra inferior del editor de planta.
part of 'camera_plan_editor.dart';

/// Franja de aviso con una acción.
class _Notice extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  const _Notice({
    required this.palette,
    required this.icon,
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: palette.accent.withValues(alpha: 0.12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: palette.accent, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: AppTypography.bodyMedium(palette)),
            ),
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: AppTypography.label(
                  palette,
                ).copyWith(color: palette.accent),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pastilla de una capa: ojo para ocultarla y, si procede, un desplegable.
class _LayerChip extends StatelessWidget {
  final AppPalette palette;
  final String label;
  final Color color;
  final bool visible;
  final VoidCallback onToggle;
  final VoidCallback? onMenu;

  const _LayerChip({
    required this.palette,
    required this.label,
    required this.color,
    required this.visible,
    required this.onToggle,
    this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final ink = visible ? palette.textPrimary : palette.textTertiary;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: color.withValues(alpha: visible ? 0.16 : 0.05),
        borderRadius: BorderRadius.circular(999),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                child: Tooltip(
                  message: visible ? 'Ocultar capa' : 'Mostrar capa',
                  child: Icon(
                    visible
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 16,
                    color: visible ? color : palette.textTertiary,
                  ),
                ),
              ),
            ),
            InkWell(
              onTap: onMenu ?? onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(2, 6, 10, 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: AppTypography.label(palette).copyWith(color: ink),
                    ),
                    if (onMenu != null)
                      Icon(Icons.arrow_drop_down, size: 18, color: ink),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomToolbar extends StatelessWidget {
  final AppPalette palette;
  final VoidCallback onAdd;
  final VoidCallback onSave;

  const _BottomToolbar({
    required this.palette,
    required this.onAdd,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _ToolbarButton(
            palette: palette,
            icon: Icons.add_circle,
            label: 'Añadir',
            highlighted: true,
            onTap: onAdd,
          ),
          _ToolbarButton(
            palette: palette,
            icon: Icons.save_outlined,
            label: 'Guardar',
            onTap: onSave,
          ),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  const _ToolbarButton({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = highlighted ? palette.accent : palette.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTypography.caption(
                palette,
              ).copyWith(color: color, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
