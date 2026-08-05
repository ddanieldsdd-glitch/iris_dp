import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import 'script_parser.dart';
import 'script_screenplay_layout.dart';

enum ScriptContextAction {
  copy,
  markAsCharacter,
  editCharacterColor,
  removeCharacterMark,
  addOrEditScene,
  addCharacterToScene,
  markAsSlugline,
  editLineText,
}

/// Datos de una línea del guion escaneado para el menú contextual.
class ScriptLineContext {
  final String lineText;
  final int? charStartIndex;
  final ScreenplayLineKind? lineKind;
  final RawSlugline? slugline;
  final String? characterName;
  final bool isManualCharacter;

  const ScriptLineContext({
    required this.lineText,
    this.charStartIndex,
    this.lineKind,
    this.slugline,
    this.characterName,
    this.isManualCharacter = false,
  });

  ScriptLineContext copyWithCharacterName(String name) => ScriptLineContext(
        lineText: name,
        charStartIndex: charStartIndex,
        lineKind: lineKind,
        slugline: slugline,
        characterName: name,
        isManualCharacter: isManualCharacter,
      );
}

Future<ScriptContextAction?> showScriptContextMenu(
  BuildContext context, {
  required Offset globalPosition,
  required ScriptLineContext line,
}) {
  final palette = context.palette;
  final items = <PopupMenuEntry<ScriptContextAction>>[];

  items.add(
    PopupMenuItem(
      value: ScriptContextAction.copy,
      child: _MenuRow(
        icon: Icons.copy_outlined,
        label: 'Copiar texto',
        palette: palette,
      ),
    ),
  );

  if (line.slugline != null) {
    items.add(
      PopupMenuItem(
        value: ScriptContextAction.addOrEditScene,
        child: _MenuRow(
          icon: Icons.movie_filter_outlined,
          label: 'Añadir / editar escena',
          palette: palette,
        ),
      ),
    );
  } else if (line.characterName != null) {
    items.addAll([
      PopupMenuItem(
        value: ScriptContextAction.editCharacterColor,
        child: _MenuRow(
          icon: Icons.palette_outlined,
          label: 'Cambiar color de personaje',
          palette: palette,
        ),
      ),
      PopupMenuItem(
        value: ScriptContextAction.addCharacterToScene,
        child: _MenuRow(
          icon: Icons.group_add_outlined,
          label: 'Añadir a escena cercana',
          palette: palette,
        ),
      ),
      if (line.isManualCharacter)
        PopupMenuItem(
          value: ScriptContextAction.removeCharacterMark,
          child: _MenuRow(
            icon: Icons.person_off_outlined,
            label: 'Quitar marca de personaje',
            palette: palette,
          ),
        ),
    ]);
  } else {
    items.addAll([
      PopupMenuItem(
        value: ScriptContextAction.markAsCharacter,
        child: _MenuRow(
          icon: Icons.person_add_outlined,
          label: 'Marcar como personaje',
          palette: palette,
        ),
      ),
      PopupMenuItem(
        value: ScriptContextAction.markAsSlugline,
        child: _MenuRow(
          icon: Icons.location_on_outlined,
          label: 'Marcar como escena (slugline)',
          palette: palette,
        ),
      ),
      PopupMenuItem(
        value: ScriptContextAction.editLineText,
        child: _MenuRow(
          icon: Icons.edit_outlined,
          label: 'Editar línea',
          palette: palette,
        ),
      ),
    ]);
  }

  return showMenu<ScriptContextAction>(
    context: context,
    position: RelativeRect.fromLTRB(
      globalPosition.dx,
      globalPosition.dy,
      globalPosition.dx + 1,
      globalPosition.dy + 1,
    ),
    color: palette.surfaceElevated,
    items: items,
  );
}

Future<void> handleScriptContextCopy(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppPalette palette;

  const _MenuRow({
    required this.icon,
    required this.label,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: palette.textSecondary),
        const SizedBox(width: 12),
        Expanded(
          child: Text(label, style: AppTypography.bodyMedium(palette)),
        ),
      ],
    );
  }
}
