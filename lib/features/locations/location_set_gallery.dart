import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/media_storage.dart';
import '../../core/utils/user_error.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_snackbar.dart';

class SetReferenceGallerySection extends ConsumerWidget {
  final int projectId;
  final int locationId;

  const SetReferenceGallerySection({
    super.key,
    required this.projectId,
    required this.locationId,
  });

  Future<void> _addImage(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;

    final db = ref.read(databaseProvider);
    final existing = await db.watchImagesForLocation(locationId).first;
    var sort = existing.length;

    try {
      for (final file in result.files) {
        if (file.path == null) continue;
        final stored = await MediaStorage.copyLocationImage(
          projectId: projectId,
          locationId: locationId,
          sourcePath: file.path!,
        );
        await db.insertLocationImage(LocationImagesCompanion.insert(
          locationId: locationId,
          imagePath: stored,
          sortOrder: Value(sort),
        ));
        sort++;
      }
    } catch (e) {
      if (context.mounted) {
        AppSnackBar.show(context, userFriendlyError(e));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Galería de referencias',
                  style: AppTypography.titleMedium(palette)),
            ),
            TextButton.icon(
              onPressed: () => _addImage(context, ref),
              icon: Icon(Icons.add_photo_alternate_outlined,
                  color: palette.accent, size: 18),
              label: Text('Añadir',
                  style: AppTypography.caption(palette)
                      .copyWith(color: palette.accent)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        StreamBuilder<List<LocationImage>>(
          stream: db.watchImagesForLocation(locationId),
          builder: (context, snap) {
            final images = snap.data ?? [];
            if (!snap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (images.isEmpty) {
              return AppCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Text(
                  'Sin imágenes. Añade referencias visuales de este set.',
                  style: AppTypography.bodyMedium(palette),
                  textAlign: TextAlign.center,
                ),
              );
            }

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1.2,
              ),
              itemCount: images.length,
              itemBuilder: (context, i) =>
                  _SetGalleryTile(image: images[i]),
            );
          },
        ),
      ],
    );
  }
}

class _SetGalleryTile extends ConsumerWidget {
  final LocationImage image;

  const _SetGalleryTile({required this.image});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final exists = File(image.imagePath).existsSync();

    return GestureDetector(
      onLongPress: () async {
        final db = ref.read(databaseProvider);
        await db.deleteLocationImage(image.id);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: palette.divider),
          ),
          child: exists
              ? Image.file(File(image.imagePath), fit: BoxFit.cover)
              : ColoredBox(
                  color: palette.surfaceOverlay,
                  child: Icon(Icons.broken_image_outlined,
                      color: palette.textTertiary),
                ),
        ),
      ),
    );
  }
}
