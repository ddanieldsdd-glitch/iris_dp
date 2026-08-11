import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import 'palette_target_viewer.dart';

/// Panel de paleta del contenedor con toggle compacta / desarrollada.
///
/// Compacta = tira. Desarrollada = swatches + hex (sin duplicar la tira).
class ContainerPalettePanel extends StatefulWidget {
  final String? imagePath;
  final List<String> paletteHex;
  final AppPalette palette;
  final Future<void> Function(List<String> hex)? onPalettePersisted;
  final bool initiallyExpanded;

  const ContainerPalettePanel({
    super.key,
    required this.imagePath,
    required this.paletteHex,
    required this.palette,
    this.onPalettePersisted,
    this.initiallyExpanded = false,
  });

  @override
  State<ContainerPalettePanel> createState() => _ContainerPalettePanelState();
}

class _ContainerPalettePanelState extends State<ContainerPalettePanel> {
  late bool _developed;

  @override
  void initState() {
    super.initState();
    _developed = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final palette = widget.palette;
    final path = widget.imagePath;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'PALETA DEL PLANO',
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  color: palette.textTertiary,
                ),
              ),
            ),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: false,
                  label: Text('Compacta', style: TextStyle(fontSize: 10)),
                ),
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Desarrollada', style: TextStyle(fontSize: 10)),
                ),
              ],
              selected: {_developed},
              onSelectionChanged: path == null
                  ? null
                  : (set) {
                      setState(() => _developed = set.first);
                    },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return palette.accent;
                  }
                  return palette.textTertiary;
                }),
              ),
              showSelectedIcon: false,
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (path == null)
          Text(
            'Elige un plano representante para ver su paleta.',
            style: AppTypography.bodyMedium(palette).copyWith(
              fontSize: 12,
              color: palette.textTertiary,
            ),
          )
        else
          PaletteTargetViewerAsync(
            key: ValueKey('palette_${_developed}_$path'),
            imagePath: path,
            paletteHex: widget.paletteHex,
            size: _developed
                ? PaletteTargetSize.large
                : PaletteTargetSize.small,
            palette: palette,
            onPalettePersisted: widget.onPalettePersisted,
            hideTitle: true,
          ),
      ],
    );
  }
}
