import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../moodboard_palette_extractor.dart';
import '../../../visual_bible_model.dart';
import '../../color_palette_strip.dart';

/// Densidad de información en tiles de still del contenedor.
enum AnnotatedStillSize { small, medium, large }

/// Tile de still: a mayor tamaño, más metadatos visibles.
///
/// - small: solo imagen
/// - medium: tags de luz
/// - large: tags + apuntes + tira de paleta si hay
class AnnotatedStillTile extends StatelessWidget {
  final MoodboardImageModel image;
  final AppPalette palette;
  final AnnotatedStillSize size;
  final VoidCallback? onTap;

  const AnnotatedStillTile({
    super.key,
    required this.image,
    required this.palette,
    this.size = AnnotatedStillSize.medium,
    this.onTap,
  });

  List<String> _lightingTags(MoodboardReferenceMeta meta) {
    return [
      if (meta.lightingLook?.trim().isNotEmpty == true) meta.lightingLook!.trim(),
      if (meta.lightSource?.trim().isNotEmpty == true) meta.lightSource!.trim(),
      if (meta.lightTexture?.trim().isNotEmpty == true) meta.lightTexture!.trim(),
      if (meta.colorMood?.trim().isNotEmpty == true) meta.colorMood!.trim(),
    ];
  }

  String? _notes(MoodboardReferenceMeta meta) {
    final notes = meta.technicalNotes?.trim();
    if (notes != null && notes.isNotEmpty) return notes;
    final caption = image.caption?.trim();
    if (caption != null && caption.isNotEmpty) return caption;
    return null;
  }

  int get _maxTags => switch (size) {
        AnnotatedStillSize.small => 0,
        AnnotatedStillSize.medium => 3,
        AnnotatedStillSize.large => 6,
      };

  int get _notesLines => switch (size) {
        AnnotatedStillSize.small => 0,
        AnnotatedStillSize.medium => 1,
        AnnotatedStillSize.large => 3,
      };

  bool get _showPalette => size == AnnotatedStillSize.large;

  @override
  Widget build(BuildContext context) {
    final meta = image.meta;
    final tags = _lightingTags(meta).take(_maxTags).toList();
    final notes = _notesLines > 0 ? _notes(meta) : null;
    final hasFile = File(image.imagePath).existsSync();
    final showOverlay = tags.isNotEmpty || notes != null || _showPalette;

    final paletteColors = meta.paletteHex
        .map(MoodboardPaletteExtractor.fromHex)
        .whereType<Color>()
        .toList();

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasFile)
              Image.file(File(image.imagePath), fit: BoxFit.cover)
            else
              ColoredBox(color: Colors.white.withValues(alpha: 0.04)),
            if (showOverlay)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.82),
                      ],
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      10,
                      size == AnnotatedStillSize.large ? 36 : 24,
                      10,
                      10,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_showPalette && paletteColors.isNotEmpty) ...[
                          ColorPaletteStrip(
                            colors: paletteColors,
                            height: 10,
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (tags.isNotEmpty)
                          Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final tag in tags)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: palette.accent
                                          .withValues(alpha: 0.45),
                                    ),
                                  ),
                                  child: Text(
                                    tag.toUpperCase(),
                                    style:
                                        AppTypography.mono(palette).copyWith(
                                      fontSize: 9,
                                      letterSpacing: 0.6,
                                      color: palette.accent,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        if (notes != null) ...[
                          if (tags.isNotEmpty) const SizedBox(height: 6),
                          Text(
                            notes,
                            maxLines: _notesLines,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMedium(palette).copyWith(
                              fontSize: size == AnnotatedStillSize.large
                                  ? 12
                                  : 11,
                              height: 1.3,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
