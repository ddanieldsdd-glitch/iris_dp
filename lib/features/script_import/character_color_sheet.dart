import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/character_colors.dart';
import '../../core/utils/scene_color.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/scene_color_picker.dart';

/// Hoja para asignar color a un personaje del guion escaneado.
Future<String?> showCharacterColorSheet(
  BuildContext context, {
  required String characterName,
  required String? currentHex,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surfaceElevated,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => _CharacterColorSheet(
      characterName: characterName,
      initialHex: currentHex,
    ),
  );
}

class _CharacterColorSheet extends StatefulWidget {
  final String characterName;
  final String? initialHex;

  const _CharacterColorSheet({
    required this.characterName,
    required this.initialHex,
  });

  @override
  State<_CharacterColorSheet> createState() => _CharacterColorSheetState();
}

class _CharacterColorSheetState extends State<_CharacterColorSheet> {
  late String _pickedHex;

  @override
  void initState() {
    super.initState();
    _pickedHex = sceneColorForPicker(widget.initialHex);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final previewColor = characterDisplayColor(_pickedHex);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: previewColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    widget.characterName,
                    style: AppTypography.titleMedium(palette),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: palette.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Color del personaje en el guion escaneado',
              style: AppTypography.caption(palette),
            ),
            const SizedBox(height: AppSpacing.lg),
            SceneColorPicker(
              selectedHex: _pickedHex,
              onChanged: (hex) => setState(() => _pickedHex = hex),
              palette: palette,
              hint: 'Se aplicará a todas las apariciones de este personaje.',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppButton(
              label: 'Guardar color',
              icon: Icons.palette_outlined,
              onTap: () => Navigator.pop(context, _pickedHex),
            ),
          ],
        ),
      ),
    );
  }
}
