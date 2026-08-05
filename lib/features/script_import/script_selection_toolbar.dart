import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'script_context_menu.dart';
import 'script_screenplay_layout.dart';

/// Contexto de una selección de texto en el guion escaneado.
class ScriptTextSelection {
  final String selectedText;
  final String lineText;
  final int? charStartIndex;
  final int? charEndIndex;
  final ScreenplayLineKind? lineKind;

  const ScriptTextSelection({
    required this.selectedText,
    required this.lineText,
    this.charStartIndex,
    this.charEndIndex,
    this.lineKind,
  });

  ScriptLineContext toLineContext() => ScriptLineContext(
        lineText: lineText,
        charStartIndex: charStartIndex,
        lineKind: lineKind,
      );
}

/// Barra flotante de acciones sobre texto seleccionado.
class ScriptSelectionToolbar extends StatelessWidget {
  final ScriptTextSelection selection;
  final List<String> existingCharacters;
  final ValueChanged<ScriptContextAction> onAction;
  final ValueChanged<String>? onAssignExistingCharacter;
  final VoidCallback onDismiss;

  const ScriptSelectionToolbar({
    super.key,
    required this.selection,
    required this.existingCharacters,
    required this.onAction,
    this.onAssignExistingCharacter,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = selection.selectedText.trim();

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      color: palette.surfaceElevated,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                child: Text(
                  text.length > 48 ? '${text.substring(0, 48)}…' : text,
                  style: AppTypography.caption(palette),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionChip(
                    palette: palette,
                    icon: Icons.copy_outlined,
                    label: 'Copiar',
                    onTap: () => onAction(ScriptContextAction.copy),
                  ),
                  _ActionChip(
                    palette: palette,
                    icon: Icons.person_add_outlined,
                    label: 'Nuevo personaje',
                    onTap: () => onAction(ScriptContextAction.markAsCharacter),
                  ),
                  if (existingCharacters.isNotEmpty)
                    _ActionChip(
                      palette: palette,
                      icon: Icons.person_search_outlined,
                      label: 'Personaje existente',
                      onTap: () => _pickExistingCharacter(context),
                    ),
                  _ActionChip(
                    palette: palette,
                    icon: Icons.group_add_outlined,
                    label: 'A escena',
                    onTap: () =>
                        onAction(ScriptContextAction.addCharacterToScene),
                  ),
                  _ActionChip(
                    palette: palette,
                    icon: Icons.location_on_outlined,
                    label: 'Nueva escena',
                    onTap: () => onAction(ScriptContextAction.markAsSlugline),
                  ),
                  _ActionChip(
                    palette: palette,
                    icon: Icons.close,
                    label: 'Cerrar',
                    onTap: onDismiss,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickExistingCharacter(BuildContext context) async {
    final palette = context.palette;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: palette.surfaceElevated,
      builder: (ctx) {
        final sorted = [...existingCharacters]..sort();
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  'Asignar a personaje existente',
                  style: AppTypography.titleMedium(palette),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  itemBuilder: (_, i) {
                    final name = sorted[i];
                    return ListTile(
                      leading: Icon(Icons.person_outline,
                          color: palette.accent, size: 20),
                      title: Text(name, style: AppTypography.bodyMedium(palette)),
                      onTap: () => Navigator.pop(ctx, name),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null) {
      onAssignExistingCharacter?.call(picked);
    }
  }
}

class _ActionChip extends StatelessWidget {
  final AppPalette palette;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionChip({
    required this.palette,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ActionChip(
        avatar: Icon(icon, size: 16, color: palette.accent),
        label: Text(label, style: AppTypography.caption(palette)),
        backgroundColor: palette.surface,
        side: BorderSide(color: palette.divider),
        onPressed: onTap,
      ),
    );
  }
}

/// Muestra la barra de selección como overlay anclado arriba del visor.
OverlayEntry showScriptSelectionOverlay({
  required BuildContext context,
  required LayerLink layerLink,
  required ScriptSelectionToolbar toolbar,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      width: 420,
      child: CompositedTransformFollower(
        link: layerLink,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topCenter,
        followerAnchor: Alignment.bottomCenter,
        offset: const Offset(0, -8),
        child: toolbar,
      ),
    ),
  );
  overlay.insert(entry);
  return entry;
}
