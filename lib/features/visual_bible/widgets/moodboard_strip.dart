import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../visual_bible_model.dart';
import 'moodboard_drag.dart';

/// Tira horizontal de imágenes del moodboard filtradas por sección o set.
class MoodboardStrip extends ConsumerWidget {
  final int projectId;
  final String? sectionId;
  final String? locationName;
  final int? locationBasePlanId;
  final String? title;
  final bool showTitle;
  final bool showCaptions;
  final bool draggable;

  const MoodboardStrip({
    super.key,
    required this.projectId,
    this.sectionId,
    this.locationName,
    this.locationBasePlanId,
    this.title,
    this.showTitle = true,
    this.showCaptions = false,
    this.draggable = false,
  }) : assert(
          (sectionId != null) ^ (locationName != null),
          'Indica sectionId o locationName',
        );

  const MoodboardStrip.forSection({
    super.key,
    required this.projectId,
    required String this.sectionId,
    this.title,
    this.showTitle = true,
    this.showCaptions = false,
    this.draggable = false,
  })  : locationName = null,
        locationBasePlanId = null;

  const MoodboardStrip.forLocation({
    super.key,
    required this.projectId,
    required String this.locationName,
    this.locationBasePlanId,
    this.title,
    this.showTitle = true,
    this.showCaptions = false,
    this.draggable = false,
  })  : sectionId = null;

  static const _thumbW = 120.0;
  static const _thumbH = 80.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);
    final stream = locationName != null
        ? db.watchMoodboardImagesForLocation(
            projectId,
            locationName!,
            locationBasePlanId: locationBasePlanId,
          )
        : db.watchMoodboardImagesForSection(projectId, sectionId!);

    return StreamBuilder(
      stream: stream,
      builder: (context, snap) {
        final images = snap.data ?? [];
        if (images.isEmpty) {
          return Text(
            'Sin referencias aún. Pega aquí con ⌘V o asigna imágenes en el moodboard.',
            style: AppTypography.caption(palette).copyWith(
              color: palette.textTertiary,
            ),
          );
        }

        final stripHeight = showCaptions ? _thumbH + 28 : _thumbH;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle)
              Text(
                title ??
                    (locationName != null
                        ? 'Refs del moodboard · $locationName'
                        : 'Referencias del moodboard'),
                style: AppTypography.label(palette).copyWith(
                  color: palette.textTertiary,
                ),
              ),
            if (showTitle) const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: stripHeight,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final model = MoodboardImageModel.fromRow(images[i]);
                  final file = File(model.imagePath);
                  final caption = model.caption?.trim();
                  final hasCaption =
                      showCaptions && caption != null && caption.isNotEmpty;

                  final thumb = ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: file.existsSync()
                        ? Image.file(
                            file,
                            width: _thumbW,
                            height: _thumbH,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: _thumbW,
                            height: _thumbH,
                            color: palette.surfaceOverlay,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: palette.textTertiary,
                            ),
                          ),
                  );

                  Widget item = thumb;
                  if (draggable) {
                    item = MoodboardDraggableThumb(
                      payload: MoodboardDragPayload(
                        imagePath: model.imagePath,
                        moodboardImageId: model.id,
                        caption: model.caption,
                        filmReference: model.filmReference,
                      ),
                      width: _thumbW,
                      height: _thumbH,
                    );
                  }

                  if (!hasCaption) {
                    return SizedBox(
                      width: _thumbW,
                      height: stripHeight,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: item,
                      ),
                    );
                  }

                  return SizedBox(
                    width: _thumbW,
                    height: stripHeight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: _thumbW, height: _thumbH, child: item),
                        const SizedBox(height: 4),
                        SizedBox(
                          height: 20,
                          child: Text(
                            caption,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption(palette).copyWith(
                              fontSize: 11,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
