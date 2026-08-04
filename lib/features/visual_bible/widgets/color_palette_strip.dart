import 'dart:io';

import 'package:flutter/material.dart';

import '../services/color_extraction_service.dart';

/// Tira horizontal de colores extraídos de una imagen (estilo ShotDeck / Artemis).
class ColorPaletteStrip extends StatelessWidget {
  final List<Color> colors;
  final double height;

  const ColorPaletteStrip({
    super.key,
    required this.colors,
    this.height = 22,
  });

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) return const SizedBox.shrink();

    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 1),
      ),
      clipBehavior: Clip.hardEdge,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < colors.length; i++)
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors[i],
                  border: i > 0
                      ? Border(
                          left: BorderSide(
                            color: Colors.white.withValues(alpha: 0.85),
                            width: 1,
                          ),
                        )
                      : null,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Imagen de referencia con paleta generada debajo.
class ColorBlockReferenceCard extends StatelessWidget {
  final String imagePath;
  final List<Color>? palette;
  final VoidCallback? onRemove;
  final double imageHeight;

  const ColorBlockReferenceCard({
    super.key,
    required this.imagePath,
    this.palette,
    this.onRemove,
    this.imageHeight = 140,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(imagePath);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Stack(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              child: file.existsSync()
                  ? Image.file(
                      file,
                      width: double.infinity,
                      height: imageHeight,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      height: imageHeight,
                      color: Colors.black26,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
            ),
            if (onRemove != null)
              Positioned(
                top: 6,
                right: 6,
                child: IconButton(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black54,
                    padding: const EdgeInsets.all(4),
                    minimumSize: Size.zero,
                  ),
                  icon: const Icon(Icons.close, size: 16, color: Colors.white),
                  onPressed: onRemove,
                ),
              ),
          ],
        ),
        if (palette != null && palette!.isNotEmpty)
          ColorPaletteStrip(colors: palette!, height: 22),
      ],
    );
  }
}

/// Tarjeta que extrae la paleta de la imagen al mostrarse.
class ColorBlockReferenceCardAsync extends StatefulWidget {
  final String imagePath;
  final VoidCallback? onRemove;

  const ColorBlockReferenceCardAsync({
    super.key,
    required this.imagePath,
    this.onRemove,
  });

  @override
  State<ColorBlockReferenceCardAsync> createState() =>
      _ColorBlockReferenceCardAsyncState();
}

class _ColorBlockReferenceCardAsyncState
    extends State<ColorBlockReferenceCardAsync> {
  List<Color>? _palette;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(ColorBlockReferenceCardAsync oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _palette = null;
      _load();
    }
  }

  Future<void> _load() async {
    final result = await ColorExtractionService.extractFromFile(
      widget.imagePath,
      swatches: ColorExtractionService.blockPaletteSwatches,
    );
    if (!mounted) return;
    setState(() => _palette = result.palette);
  }

  @override
  Widget build(BuildContext context) {
    return ColorBlockReferenceCard(
      imagePath: widget.imagePath,
      palette: _palette,
      onRemove: widget.onRemove,
    );
  }
}
