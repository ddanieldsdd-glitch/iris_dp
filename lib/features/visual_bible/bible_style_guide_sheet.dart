import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/app_snackbar.dart';
import 'moodboard_association.dart';
import 'moodboard_batch_actions.dart';
import 'visual_bible_model.dart';
import 'widgets/bible_navigation_scope.dart';

/// Destinos donde se pueden usar referencias del moodboard del proyecto.
enum ProjectReferenceTarget {
  bibleSection,
  shootDocument,
  technicalScript,
  location,
}

extension ProjectReferenceTargetX on ProjectReferenceTarget {
  String get label => switch (this) {
        ProjectReferenceTarget.bibleSection => 'Sección de la biblia',
        ProjectReferenceTarget.shootDocument => 'Documento de rodaje',
        ProjectReferenceTarget.technicalScript => 'Guion técnico / plano',
        ProjectReferenceTarget.location => 'Localización',
      };
}

/// Guía visual del proyecto: moodboard central para definir estilo y repartir refs.
class BibleStyleGuideSheet extends ConsumerWidget {
  final int projectId;
  final int? bibleId;

  const BibleStyleGuideSheet({
    super.key,
    required this.projectId,
    this.bibleId,
  });

  static Future<void> show(
    BuildContext context, {
    required int projectId,
    int? bibleId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.palette.surfaceElevated,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          child: BibleStyleGuideSheet(
            projectId: projectId,
            bibleId: bibleId,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.palette_outlined, color: palette.accent),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Guía visual del proyecto',
                  style: AppTypography.titleMedium(palette),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'La biblia es el centro de estilo: sube referencias al moodboard, '
            'asígnalas a secciones y úsalas en guion técnico, documentos de '
            'rodaje y localizaciones.',
            style: AppTypography.bodyMedium(palette),
          ),
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              BibleNavigationScope.openMoodboardForSection(
                context,
                BibleSectionId.moodboard,
              );
            },
            icon: const Icon(Icons.photo_library_outlined, size: 18),
            label: const Text('Abrir moodboard completo'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Referencias del proyecto', style: AppTypography.label(palette)),
          const SizedBox(height: AppSpacing.sm),
          StreamBuilder<List<MoodboardImage>>(
            stream: db.watchMoodboardImages(projectId),
            builder: (context, snap) {
              final images = snap.data ?? [];
              if (images.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                  child: Text(
                    'Aún no hay imágenes. Añade referencias en el moodboard '
                    '(⌘V para pegar).',
                    style: AppTypography.caption(palette),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.1,
                ),
                itemCount: images.length,
                itemBuilder: (context, i) {
                  final img = images[i];
                  final sections =
                      MoodboardAssociation.decodeSections(img.assignedSections);
                  return _ReferenceTile(
                    image: img,
                    sectionCount: sections.length,
                    palette: palette,
                    onTap: () => _showAssignSheet(context, ref, img),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showAssignSheet(
    BuildContext context,
    WidgetRef ref,
    MoodboardImage img,
  ) async {
    final palette = context.palette;
    final db = ref.read(databaseProvider);
    final current =
        MoodboardAssociation.decodeSections(img.assignedSections);

    final sectionIds = [
      BibleSectionId.direction,
      BibleSectionId.concept,
      BibleSectionId.lighting,
      BibleSectionId.colorImage,
      BibleSectionId.optics,
      BibleSectionId.exposure,
      BibleSectionId.camera,
      BibleSectionId.location,
      BibleSectionId.texture,
      BibleSectionId.format,
    ];

    final selected = {...current};

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: palette.surfaceElevated,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Asignar referencia', style: AppTypography.titleMedium(palette)),
                const SizedBox(height: AppSpacing.sm),
                if (File(img.imagePath).existsSync())
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(img.imagePath),
                      height: 120,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                Text('Secciones de la biblia', style: AppTypography.label(palette)),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final id in sectionIds)
                      FilterChip(
                        label: Text(BibleSectionId.label(id)),
                        selected: selected.contains(id),
                        onSelected: (on) {
                          setLocal(() {
                            if (on) {
                              selected.add(id);
                            } else {
                              selected.remove(id);
                            }
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'También disponible en: documentos de rodaje (bloque imagen), '
                  'guion técnico (referencia de plano) y localizaciones.',
                  style: AppTypography.caption(palette),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await Clipboard.setData(
                            ClipboardData(text: img.imagePath),
                          );
                          if (ctx.mounted) {
                            AppSnackBar.show(ctx, 'Ruta copiada al portapapeles');
                          }
                        },
                        child: const Text('Copiar ruta'),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          await MoodboardBatchActions.assignSections(
                            db: db,
                            images: [img],
                            sections: selected.toList(),
                          );
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            AppSnackBar.show(context, 'Referencia asignada');
                          }
                        },
                        child: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReferenceTile extends StatelessWidget {
  final MoodboardImage image;
  final int sectionCount;
  final AppPalette palette;
  final VoidCallback onTap;

  const _ReferenceTile({
    required this.image,
    required this.sectionCount,
    required this.palette,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(image.imagePath);
    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (file.existsSync())
              Image.file(file, fit: BoxFit.cover)
            else
              Container(color: palette.surfaceOverlay),
            if (sectionCount > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: palette.accent.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$sectionCount',
                    style: AppTypography.caption(palette).copyWith(
                      color: Colors.white,
                      fontSize: 10,
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

/// Selector reutilizable de imagen del moodboard (otras pantallas).
Future<MoodboardImage?> pickProjectReferenceImage({
  required BuildContext context,
  required AppDatabase db,
  required int projectId,
  String? title,
}) async {
  final images = await db.watchMoodboardImages(projectId).first;
  if (images.isEmpty) return null;
  if (!context.mounted) return null;

  return showModalBottomSheet<MoodboardImage>(
    context: context,
    backgroundColor: context.palette.surfaceElevated,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              title ?? 'Elegir referencia del moodboard',
              style: AppTypography.titleMedium(context.palette),
            ),
          ),
          SizedBox(
            height: 280,
            child: GridView.builder(
              padding: const EdgeInsets.all(AppSpacing.md),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: images.length,
              itemBuilder: (_, i) {
                final img = images[i];
                final file = File(img.imagePath);
                return InkWell(
                  onTap: () => Navigator.pop(ctx, img),
                  child: file.existsSync()
                      ? Image.file(file, fit: BoxFit.cover)
                      : const SizedBox.shrink(),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
