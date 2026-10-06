import 'dart:io';

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_point_extras.dart';
import '../../../shared/visual_bible/bible_section_fields.dart';
import 'bible_point_images.dart';
import 'bible_point_panel.dart';

/// Cabecera común de las pantallas de la biblia: el título en grande sobre
/// la imagen que el usuario elija para representar la pantalla.
class BibleScreenHero extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final String title;
  final String kicker;
  final int? imageId;

  /// Guarda la imagen elegida (`null` la quita). Sin él, la cabecera no se
  /// puede cambiar.
  final ValueChanged<int?>? onChanged;

  const BibleScreenHero({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.title,
    this.kicker = 'Biblia de fotografía',
    this.imageId,
    this.onChanged,
  });

  static const double height = 220;

  Future<void> _pick(BuildContext context) async {
    final picked = await showMoodboardImagePicker(
      context,
      projectId: projectId,
      bibleId: bibleId,
      sectionId: sectionId,
      selected: [if (imageId != null) imageId!],
      single: true,
    );
    if (picked != null) onChanged!(picked.isEmpty ? null : picked.first);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = imageId;
    if (id == null) return _band(context, null);
    return StreamBuilder<List<MoodboardImage>>(
      stream: ref.watch(databaseProvider).watchMoodboardImages(projectId),
      builder: (context, snap) {
        String? path;
        for (final image in snap.data ?? const <MoodboardImage>[]) {
          if (image.id == id) path = image.imagePath;
        }
        return _band(context, path);
      },
    );
  }

  Widget _band(BuildContext context, String? path) {
    final palette = context.palette;
    final file = path == null ? null : File(path);
    final hasImage = file != null && file.existsSync();
    final label = BiblePointPanel.labelStyle(palette);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xl),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(BiblePointPanel.radius),
        child: SizedBox(
          height: hasImage ? height : 132,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage) ...[
                Image.file(file, fit: BoxFit.cover),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.82),
                      ],
                    ),
                  ),
                ),
              ] else
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: palette.surfaceElevated.withValues(alpha: 0.45),
                    border: Border(
                      bottom: BorderSide(color: palette.borderBright),
                    ),
                  ),
                ),
              Positioned(
                left: AppSpacing.lg,
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      kicker.toUpperCase(),
                      style: label.copyWith(
                        color: hasImage ? Colors.white70 : palette.accent,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.displayMedium(palette).copyWith(
                        fontSize: 40,
                        height: 1.05,
                        letterSpacing: -0.8,
                        color: hasImage ? Colors.white : palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onChanged != null)
                Positioned(
                  top: AppSpacing.sm,
                  right: AppSpacing.sm,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _HeroButton(
                        icon: Icons.image_outlined,
                        label: hasImage ? 'Cambiar imagen' : 'Elegir imagen',
                        onTap: () => _pick(context),
                      ),
                      if (hasImage) ...[
                        const SizedBox(width: AppSpacing.sm),
                        _HeroButton(
                          icon: Icons.close,
                          label: 'Quitar imagen',
                          iconOnly: true,
                          onTap: () => onChanged!(null),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool iconOnly;
  final VoidCallback onTap;

  const _HeroButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: label,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: Colors.white70),
                if (!iconOnly) ...[
                  const SizedBox(width: 6),
                  Text(
                    label.toUpperCase(),
                    style: BiblePointPanel.labelStyle(
                      palette,
                    ).copyWith(color: Colors.white70),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// [BibleScreenHero] de una pantalla que no lleva el armazón común: lee y
/// guarda la imagen directamente en la definición de la sección.
class BibleSectionHero extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final String sectionId;
  final String title;

  const BibleSectionHero({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    if (bibleId <= 0) {
      return BibleScreenHero(
        projectId: projectId,
        bibleId: bibleId,
        sectionId: sectionId,
        title: title,
      );
    }
    return StreamBuilder<BibleSectionDefinition?>(
      stream:
          (db.select(db.bibleSectionDefinitions)..where(
                (d) => d.bibleId.equals(bibleId) & d.id.equals(sectionId),
              ))
              .watchSingleOrNull(),
      builder: (context, snap) => BibleScreenHero(
        projectId: projectId,
        bibleId: bibleId,
        sectionId: sectionId,
        title: title,
        imageId: BibleScreenHeroValue.read(
          BibleSectionFieldsConfig.parseValues(snap.data?.contentJson),
        ),
        onChanged: snap.data == null
            ? null
            : (id) => db.saveBibleSectionFieldValue(
                bibleId,
                sectionId,
                BibleScreenHeroValue.key,
                BibleScreenHeroValue.encode(id),
              ),
      ),
    );
  }
}
