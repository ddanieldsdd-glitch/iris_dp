import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import '../utils/color_edit_scope.dart';
import '../utils/scene_color.dart';
import 'scene_color_picker.dart';

class ColorScopePromptResult {
  final String colorHex;
  final ColorEditScope scope;

  const ColorScopePromptResult({
    required this.colorHex,
    required this.scope,
  });
}

/// Pregunta alcance y color al personalizar un set por primera vez.
Future<ColorScopePromptResult?> showSetColorCustomizationDialog(
  BuildContext context, {
  required AppPalette palette,
  required String setName,
  required String locationSiteName,
  required String initialHex,
  required int scenesInSet,
  required int setsInSite,
}) {
  return showDialog<ColorScopePromptResult>(
    context: context,
    builder: (dialogContext) => _SetColorCustomizationDialog(
      palette: palette,
      setName: setName,
      locationSiteName: locationSiteName,
      initialHex: initialHex,
      scenesInSet: scenesInSet,
      setsInSite: setsInSite,
    ),
  );
}

class _SetColorCustomizationDialog extends StatefulWidget {
  final AppPalette palette;
  final String setName;
  final String locationSiteName;
  final String initialHex;
  final int scenesInSet;
  final int setsInSite;

  const _SetColorCustomizationDialog({
    required this.palette,
    required this.setName,
    required this.locationSiteName,
    required this.initialHex,
    required this.scenesInSet,
    required this.setsInSite,
  });

  @override
  State<_SetColorCustomizationDialog> createState() =>
      _SetColorCustomizationDialogState();
}

class _SetColorCustomizationDialogState
    extends State<_SetColorCustomizationDialog> {
  late String _pickedHex;
  late ColorEditScope _scope;

  @override
  void initState() {
    super.initState();
    _pickedHex = widget.initialHex;
    _scope = widget.setsInSite > 1 ? ColorEditScope.set : ColorEditScope.set;
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;

    return AlertDialog(
      backgroundColor: palette.surfaceElevated,
      title: Text(
        'Color del set «${widget.setName}»',
        style: AppTypography.titleMedium(palette),
      ),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Este set pertenece a la localización «${widget.locationSiteName}». '
                'Elige el color y dónde aplicarlo.',
                style: AppTypography.bodyMedium(palette),
              ),
              const SizedBox(height: AppSpacing.md),
              Text('Aplicar a', style: AppTypography.label(palette)),
              const SizedBox(height: AppSpacing.sm),
              SegmentedButton<ColorEditScope>(
                segments: ColorEditScope.values
                    .map(
                      (s) => ButtonSegment(
                        value: s,
                        label: Text(s.shortLabel),
                      ),
                    )
                    .toList(),
                selected: {_scope},
                onSelectionChanged: (selected) =>
                    setState(() => _scope = selected.first),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _scope.hint(
                  scenesInSet: widget.scenesInSet,
                  setsInSite: widget.setsInSite,
                ),
                style: AppTypography.caption(palette),
              ),
              const SizedBox(height: AppSpacing.md),
              SceneColorPicker(
                palette: palette,
                selectedHex: _pickedHex,
                onChanged: (hex) => setState(() => _pickedHex = hex),
                hint: _scope == ColorEditScope.location
                    ? 'Color base de la localización.'
                    : 'Color del set.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancelar', style: AppTypography.bodyMedium(palette)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            ColorScopePromptResult(
              colorHex: sceneColorForPicker(_pickedHex),
              scope: _scope,
            ),
          ),
          child: Text(
            'Aplicar',
            style: AppTypography.bodyMedium(palette)
                .copyWith(color: palette.accent),
          ),
        ),
      ],
    );
  }
}
