import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../visual_bible_model.dart';

/// Selector de imagen representante entre stills del contenedor.
class CoverPickerFromMatched extends StatelessWidget {
  final List<MoodboardImageModel> images;
  final int? selectedImageId;
  final AppPalette palette;
  final ValueChanged<int> onSelected;

  const CoverPickerFromMatched({
    super.key,
    required this.images,
    required this.selectedImageId,
    required this.palette,
    required this.onSelected,
  });

  static Future<int?> show(
    BuildContext context, {
    required List<MoodboardImageModel> images,
    required int? selectedImageId,
    required AppPalette palette,
    required ValueChanged<int> onSelected,
  }) {
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: palette.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Elegir plano representante',
                style: AppTypography.bodyMedium(palette).copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Stills asociados a este contenedor',
                style: AppTypography.bodyMedium(palette).copyWith(
                  fontSize: 12,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              if (images.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No hay stills asociados. Define tags o añade imágenes.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium(palette).copyWith(
                      fontSize: 12,
                      color: palette.textTertiary,
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 200,
                  child: GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1.35,
                    ),
                    itemCount: images.length,
                    itemBuilder: (context, i) {
                      final img = images[i];
                      final selected = img.id == selectedImageId;
                      return GestureDetector(
                        onTap: () {
                          onSelected(img.id);
                          Navigator.pop(ctx, img.id);
                        },
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: selected
                                  ? palette.accent
                                  : Colors.white.withValues(alpha: 0.1),
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: File(img.imagePath).existsSync()
                                ? Image.file(
                                    File(img.imagePath),
                                    fit: BoxFit.cover,
                                  )
                                : ColoredBox(
                                    color: Colors.white.withValues(alpha: 0.04),
                                  ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
