import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../moodboard_palette_extractor.dart';
import '../../bible_section_shared_widgets.dart';
import '../../color_palette_strip.dart';

/// Tamaño del visor de paleta del plano representante.
enum PaletteTargetSize { small, medium, large }

/// Visor de paleta del cover.
///
/// - [PaletteTargetSize.small]: solo tira (compacta).
/// - [PaletteTargetSize.medium]/[PaletteTargetSize.large]: solo swatches+hex
///   (desarrollada), sin tira duplicada.
class PaletteTargetViewer extends StatelessWidget {
  final List<Color> colors;
  final PaletteTargetSize size;
  final AppPalette palette;
  final bool hideTitle;

  const PaletteTargetViewer({
    super.key,
    required this.colors,
    this.size = PaletteTargetSize.medium,
    required this.palette,
    this.hideTitle = false,
  });

  double get _stripHeight => switch (size) {
        PaletteTargetSize.small => 18,
        PaletteTargetSize.medium => 22,
        PaletteTargetSize.large => 28,
      };

  double get _swatchSize => switch (size) {
        PaletteTargetSize.small => 40,
        PaletteTargetSize.medium => 48,
        PaletteTargetSize.large => 64,
      };

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) {
      return Text(
        'Sin paleta extraída del plano representante.',
        style: AppTypography.bodyMedium(palette).copyWith(
          fontSize: 12,
          color: palette.textTertiary,
        ),
      );
    }

    final compact = size == PaletteTargetSize.small;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideTitle) ...[
          Text(
            'PALETA DEL PLANO',
            style: AppTypography.mono(palette).copyWith(
              fontSize: 11,
              letterSpacing: 1.1,
              color: palette.textTertiary,
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (compact)
          ColorPaletteStrip(colors: colors, height: _stripHeight)
        else
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < colors.length; i++)
                SizedBox(
                  width: _swatchSize + 8,
                  child: BibleColorSwatch(
                    color: colors[i],
                    name: 'Color ${i + 1}',
                    hex: MoodboardPaletteExtractor.toHex(colors[i]),
                    large: size == PaletteTargetSize.large,
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Carga la paleta del cover (meta o extracción) y la persiste si hace falta.
class PaletteTargetViewerAsync extends StatefulWidget {
  final String imagePath;
  final List<String> paletteHex;
  final PaletteTargetSize size;
  final AppPalette palette;
  final Future<void> Function(List<String> hex)? onPalettePersisted;
  final bool hideTitle;

  const PaletteTargetViewerAsync({
    super.key,
    required this.imagePath,
    required this.paletteHex,
    this.size = PaletteTargetSize.medium,
    required this.palette,
    this.onPalettePersisted,
    this.hideTitle = false,
  });

  @override
  State<PaletteTargetViewerAsync> createState() =>
      _PaletteTargetViewerAsyncState();
}

class _PaletteTargetViewerAsyncState extends State<PaletteTargetViewerAsync> {
  List<Color>? _colors;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(PaletteTargetViewerAsync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath ||
        oldWidget.paletteHex != widget.paletteHex) {
      _colors = null;
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final fromMeta = widget.paletteHex
        .map(MoodboardPaletteExtractor.fromHex)
        .whereType<Color>()
        .toList();
    if (fromMeta.isNotEmpty) {
      if (mounted) {
        setState(() {
          _colors = fromMeta;
          _loading = false;
        });
      }
      return;
    }

    final extracted = await MoodboardPaletteExtractor.fromFile(widget.imagePath);
    if (!mounted) return;
    final hex = extracted.map(MoodboardPaletteExtractor.toHex).toList();
    if (hex.isNotEmpty) {
      await widget.onPalettePersisted?.call(hex);
    }
    setState(() {
      _colors = extracted;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return SizedBox(
        height: widget.size == PaletteTargetSize.small ? 24 : 48,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return PaletteTargetViewer(
      colors: _colors ?? const [],
      size: widget.size,
      palette: widget.palette,
      hideTitle: widget.hideTitle,
    );
  }
}
