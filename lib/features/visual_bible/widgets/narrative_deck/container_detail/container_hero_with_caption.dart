import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../core/utils/clipboard_image_reader.dart';
import '../../../visual_bible_model.dart';
import '../../bible_paste_zone.dart';
import '../../moodboard_drag.dart';
import 'cover_picker_from_matched.dart';

/// Cover del contenedor con pie de foto editable y altura acotada.
class ContainerHeroWithCaption extends StatelessWidget {
  final int projectId;
  final int bibleId;
  final NarrativeCardModel card;
  final AppPalette palette;
  final String? coverPath;
  final List<MoodboardImageModel> matchedImages;
  final TextEditingController captionController;
  final Future<void> Function(ClipboardImagePayload payload) onPasteCover;
  final Future<void> Function(MoodboardDragPayload payload)? onMoodboardDropped;
  final Future<void> Function(int imageId) onCoverSet;
  final VoidCallback onChanged;
  /// Altura máxima del plano (responsivo). Null = auto según ancho.
  final double? maxHeroHeight;

  const ContainerHeroWithCaption({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.card,
    required this.palette,
    required this.coverPath,
    required this.matchedImages,
    required this.captionController,
    required this.onPasteCover,
    this.onMoodboardDropped,
    required this.onCoverSet,
    required this.onChanged,
    this.maxHeroHeight,
  });

  Future<void> _pickCover(BuildContext context) async {
    await CoverPickerFromMatched.show(
      context,
      images: matchedImages,
      selectedImageId: card.coverMoodboardImageId,
      palette: palette,
      onSelected: onCoverSet,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCover = coverPath != null && File(coverPath!).existsSync();
    final maxH = maxHeroHeight ?? 260.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'PLANO REPRESENTANTE',
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 11,
                  letterSpacing: 1.1,
                  color: palette.textTertiary,
                ),
              ),
            ),
            if (matchedImages.isNotEmpty)
              TextButton.icon(
                onPressed: () => _pickCover(context),
                icon: const Icon(Icons.grid_view_rounded, size: 16),
                label: const Text('Elegir del pool'),
                style: TextButton.styleFrom(
                  foregroundColor: palette.accent,
                  textStyle: const TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        BibleTargetZone(
          hint: '⌘V o arrastra cover',
          minHeight: 160,
          onPaste: (payload) async {
            await onPasteCover(payload);
            onChanged();
          },
          onMoodboardDropped: onMoodboardDropped == null
              ? null
              : (drag) async {
                  await onMoodboardDropped!(drag);
                  onChanged();
                },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              // Scope 2.35 pero con techo de altura para no ocupar toda la pantalla.
              final naturalH = width / 2.35;
              final height = naturalH.clamp(160.0, maxH);
              return SizedBox(
                height: height,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: hasCover
                      ? Image.file(File(coverPath!), fit: BoxFit.cover)
                      : ColoredBox(
                          color: Colors.white.withValues(alpha: 0.04),
                          child: Center(
                            child: Text(
                              'Portada — ⌘V o elige del pool',
                              style: AppTypography.bodyMedium(palette).copyWith(
                                color: palette.textTertiary,
                              ),
                            ),
                          ),
                        ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'APUNTES DEL PLANO',
          style: AppTypography.mono(palette).copyWith(
            fontSize: 10,
            letterSpacing: 1,
            color: palette.textTertiary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: captionController,
          maxLines: 3,
          style: AppTypography.bodyMedium(palette).copyWith(
            fontSize: 14,
            height: 1.5,
            fontStyle: FontStyle.italic,
            color: palette.textSecondary,
          ),
          decoration: InputDecoration(
            hintText: 'Notas principales del plano elegido…',
            hintStyle: AppTypography.bodyMedium(palette).copyWith(
              fontSize: 14,
              color: palette.textTertiary,
            ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.03),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(6),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
      ],
    );
  }
}
