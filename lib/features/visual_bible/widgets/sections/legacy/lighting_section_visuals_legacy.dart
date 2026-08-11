// LEGACY — código visual de Iluminación (hero banner, mosaico,
// referencias por set) retirado al unificar con
// BibleSectionReferencesManager. Conservado para una futura pasada
// de rediseño estético. No se usa en producción actualmente.
// Fecha de retiro: 2026-08-11

// ignore_for_file: unused_element

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/app_database.dart';
import '../../../../../core/database/database_provider.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_typography.dart';
import '../../../../../shared/visual_bible/bible_section_ids.dart';
import '../../../bible_paste_helpers.dart';
import '../../../moodboard_helpers.dart';
import '../../../visual_bible_model.dart';
import '../../bible_moodboard_image_target.dart';

// ─── Hero ────────────────────────────────────────────────────────────────────

class _HeroBanner extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final String badge;
  final String title;
  final String subtitle;
  final AppPalette palette;
  final VoidCallback onEditBadge;
  final VoidCallback onEditTitle;

  const _HeroBanner({
    required this.projectId,
    required this.bibleId,
    required this.badge,
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.onEditBadge,
    required this.onEditTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: BibleMoodboardImageTarget(
        projectId: projectId,
        sectionId: BibleSectionId.lighting,
        bibleId: bibleId,
        hint: 'Clic aquí → ⌘V para pegar hero de iluminación',
        child: SizedBox(
          height: 280,
          child: Stack(
            fit: StackFit.expand,
            children: [
              StreamBuilder<List<MoodboardImage>>(
              stream: db.watchMoodboardImagesForSection(
                projectId,
                BibleSectionId.lighting,
              ),
              builder: (context, snap) {
                final imgs = snap.data ?? [];
                if (imgs.isNotEmpty &&
                    File(imgs.first.imagePath).existsSync()) {
                  return Opacity(
                    opacity: 0.55,
                    child: Image.file(
                      File(imgs.first.imagePath),
                      fit: BoxFit.cover,
                    ),
                  );
                }
                return ColoredBox(
                  color: palette.surfaceOverlay,
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () => MoodboardHelpers.addManualImages(
                        db: db,
                        projectId: projectId,
                        bibleId: bibleId,
                        category: MoodboardCategory.lighting,
                        assignedSections: [BibleSectionId.lighting],
                      ),
                      icon: Icon(
                        Icons.add_photo_alternate_outlined,
                        color: palette.accent,
                      ),
                      label: Text(
                        'Añadir imagen hero',
                        style: TextStyle(color: palette.accent),
                      ),
                    ),
                  ),
                );
              },
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    palette.background.withValues(alpha: 0.4),
                    palette.background,
                  ],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    palette.background,
                    palette.background.withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              left: 28,
              right: 28,
              bottom: 28,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: onEditBadge,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: palette.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: palette.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            badge.toUpperCase(),
                            style: AppTypography.mono(palette).copyWith(
                              fontSize: 11,
                              letterSpacing: 1.4,
                              color: palette.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: onEditTitle,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$title\n',
                            style: AppTypography.displayMedium(palette)
                                .copyWith(
                                  fontSize: 36,
                                  height: 1.15,
                                  letterSpacing: -0.8,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          TextSpan(
                            text: subtitle,
                            style: AppTypography.displayMedium(palette)
                                .copyWith(
                                  fontSize: 32,
                                  height: 1.2,
                                  letterSpacing: -0.6,
                                  color: palette.textTertiary,
                                  fontWeight: FontWeight.w400,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
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

// ─── Mosaic ──────────────────────────────────────────────────────────────────

class _AtmosphericMosaic extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final List<Map<String, String>> behaviors;
  final String contrastRatio;
  final int colorTemp;
  final String tintStr;
  final AppPalette palette;
  final void Function(int index) onEditCard;

  const _AtmosphericMosaic({
    required this.projectId,
    required this.bibleId,
    required this.behaviors,
    required this.contrastRatio,
    required this.colorTemp,
    required this.tintStr,
    required this.palette,
    required this.onEditCard,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);
    return StreamBuilder<List<MoodboardImage>>(
      stream: db.watchMoodboardImagesForSection(
        projectId,
        BibleSectionId.lighting,
      ),
      builder: (context, snap) {
        final imgs = snap.data ?? [];
        return LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 700;
            if (!wide) {
              return Column(
                children: [
                  for (var i = 0; i < math.min(3, behaviors.length); i++) ...[
                    if (i > 0) const SizedBox(height: 12),
                    _BehaviorCard(
                      title: behaviors[i]['title'] ?? '',
                      meta: behaviors[i]['meta'] ?? '',
                      tag: behaviors[i]['tag'] ?? '',
                      note: behaviors[i]['note'] ?? '',
                      imagePath: i < imgs.length ? imgs[i].imagePath : null,
                      tall: i == 0,
                      showTech: i == 0,
                      contrastRatio: contrastRatio,
                      palette: palette,
                      onTap: () => onEditCard(i),
                      onAddImage: () => MoodboardHelpers.addManualImages(
                        db: db,
                        projectId: projectId,
                        bibleId: bibleId,
                        category: MoodboardCategory.lighting,
                        assignedSections: [BibleSectionId.lighting],
                      ),
                    ),
                  ],
                ],
              );
            }
            return SizedBox(
              height: 320,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 8,
                    child: _BehaviorCard(
                      title: behaviors[0]['title'] ?? 'Visual Intent',
                      meta: behaviors[0]['meta'] ?? contrastRatio,
                      tag: behaviors[0]['tag'] ?? '',
                      note: behaviors[0]['note'] ?? '',
                      imagePath: imgs.isNotEmpty ? imgs.first.imagePath : null,
                      tall: true,
                      showTech: true,
                      contrastRatio: contrastRatio,
                      palette: palette,
                      onTap: () => onEditCard(0),
                      onAddImage: () => MoodboardHelpers.addManualImages(
                        db: db,
                        projectId: projectId,
                        bibleId: bibleId,
                        category: MoodboardCategory.lighting,
                        assignedSections: [BibleSectionId.lighting],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 4,
                    child: Column(
                      children: [
                        Expanded(
                          child: _BehaviorCard(
                            title: behaviors.length > 1
                                ? (behaviors[1]['title'] ?? 'Specular')
                                : 'Specular Analysis',
                            meta: behaviors.length > 1
                                ? (behaviors[1]['meta'] ?? '')
                                : '+2 STOPS',
                            tag: behaviors.length > 1
                                ? (behaviors[1]['tag'] ?? '')
                                : 'Metal',
                            note: '',
                            imagePath: imgs.length > 1
                                ? imgs[1].imagePath
                                : null,
                            tall: false,
                            showTech: false,
                            contrastRatio: contrastRatio,
                            palette: palette,
                            onTap: () =>
                                onEditCard(behaviors.length > 1 ? 1 : 0),
                            onAddImage: () => MoodboardHelpers.addManualImages(
                              db: db,
                              projectId: projectId,
                              bibleId: bibleId,
                              category: MoodboardCategory.lighting,
                        assignedSections: [BibleSectionId.lighting],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Expanded(
                          child: _BehaviorCard(
                            title: behaviors.length > 2
                                ? (behaviors[2]['title'] ?? 'Color Volume')
                                : 'Color Volume',
                            meta: behaviors.length > 2
                                ? (behaviors[2]['meta'] ?? '${colorTemp}K')
                                : '${colorTemp}K',
                            tag: behaviors.length > 2
                                ? (behaviors[2]['tag'] ?? tintStr)
                                : tintStr,
                            note: '',
                            imagePath: imgs.length > 2
                                ? imgs[2].imagePath
                                : null,
                            tall: false,
                            showTech: false,
                            contrastRatio: contrastRatio,
                            palette: palette,
                            onTap: () =>
                                onEditCard(behaviors.length > 2 ? 2 : 0),
                            onAddImage: () => MoodboardHelpers.addManualImages(
                              db: db,
                              projectId: projectId,
                              bibleId: bibleId,
                              category: MoodboardCategory.lighting,
                        assignedSections: [BibleSectionId.lighting],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _BehaviorCard extends StatelessWidget {
  final String title;
  final String meta;
  final String tag;
  final String note;
  final String? imagePath;
  final bool tall;
  final bool showTech;
  final String contrastRatio;
  final AppPalette palette;
  final VoidCallback onTap;
  final VoidCallback onAddImage;

  const _BehaviorCard({
    required this.title,
    required this.meta,
    required this.tag,
    required this.note,
    required this.imagePath,
    required this.tall,
    required this.showTech,
    required this.contrastRatio,
    required this.palette,
    required this.onTap,
    required this.onAddImage,
  });

  @override
  Widget build(BuildContext context) {
    final hasImg = imagePath != null && File(imagePath!).existsSync();
    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: BoxConstraints(minHeight: tall ? 280 : 140),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImg)
              Opacity(
                opacity: 0.8,
                child: Image.file(File(imagePath!), fit: BoxFit.cover),
              )
            else
              ColoredBox(
                color: palette.surfaceOverlay,
                child: Center(
                  child: IconButton(
                    onPressed: onAddImage,
                    icon: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: palette.accent,
                    ),
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xE60D0D0D)],
                ),
              ),
            ),
            if (showTech)
              Positioned(
                top: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _TechChip(label: 'LUMA ANALYSIS', palette: palette),
                    const SizedBox(height: 4),
                    _TechChip(label: 'RATIO $contrastRatio', palette: palette),
                  ],
                ),
              ),
            Positioned(
              left: 14,
              right: 14,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.toUpperCase(),
                    style: AppTypography.mono(palette).copyWith(
                      fontSize: 11,
                      letterSpacing: 1.3,
                      color: palette.accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (note.isNotEmpty)
                    Text(
                      note,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium(palette).copyWith(
                        fontSize: 13,
                        color: palette.textSecondary,
                        height: 1.4,
                      ),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meta,
                            style: AppTypography.mono(palette).copyWith(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        if (tag.isNotEmpty)
                          Text(
                            tag,
                            style: AppTypography.mono(palette).copyWith(
                              fontSize: 12,
                              color: palette.textTertiary,
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechChip extends StatelessWidget {
  final String label;
  final AppPalette palette;
  const _TechChip({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        border: Border.all(color: palette.accent.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: AppTypography.mono(
          palette,
        ).copyWith(fontSize: 10, color: palette.accent.withValues(alpha: 0.85)),
      ),
    );
  }
}

// ─── Referencias ─────────────────────────────────────────────────────────────

class _LightingReferencesBlock extends ConsumerWidget {
  final int projectId;
  final int bibleId;
  final AppPalette palette;
  final int? selectedPlanId;
  final List<String> planRefs;
  final Future<void> Function(List<String> paths) onPlanRefsChanged;

  const _LightingReferencesBlock({
    required this.projectId,
    required this.bibleId,
    required this.palette,
    required this.selectedPlanId,
    required this.planRefs,
    required this.onPlanRefsChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(databaseProvider);

    Future<void> pasteToPlan() async {
      if (selectedPlanId == null) return;
      await BiblePasteHelpers.pasteFromClipboard(
        onPayload: (payload) async {
          final path = await BiblePasteHelpers.savePayloadToProject(
            projectId: projectId,
            subfolder: 'lighting_refs',
            payload: payload,
          );
          if (path != null) {
            await onPlanRefsChanged([...planRefs, path]);
          }
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHead(
          icon: Icons.photo_library_outlined,
          label: selectedPlanId == null
              ? 'Referencias globales'
              : 'Referencias del set',
          palette: palette,
        ),
        const SizedBox(height: 12),
        if (selectedPlanId == null)
          StreamBuilder<List<MoodboardImage>>(
            stream: db.watchMoodboardImagesForSection(
              projectId,
              BibleSectionId.lighting,
            ),
            builder: (context, snap) {
              final imgs = snap.data ?? [];
              if (imgs.isEmpty) {
                return _GlassPanel(
                  child: Text(
                    'Pega imágenes en el hero o selecciona un set para refs por localización.',
                    style: AppTypography.bodyMedium(palette)
                        .copyWith(color: palette.textTertiary),
                  ),
                );
              }
              return SizedBox(
                height: 120,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: imgs.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final file = File(imgs[i].imagePath);
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: file.existsSync()
                          ? Image.file(file, width: 160, height: 120, fit: BoxFit.cover)
                          : const SizedBox(width: 160, height: 120),
                    );
                  },
                ),
              );
            },
          )
        else ...[
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: planRefs.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                if (i == planRefs.length) {
                  return BibleMoodboardImageTarget(
                    projectId: projectId,
                    sectionId: BibleSectionId.lighting,
                    bibleId: bibleId,
                    hint: '⌘V — ref del set',
                    child: InkWell(
                      onTap: pasteToPlan,
                      child: Container(
                        width: 160,
                        height: 120,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: palette.border,
                            style: BorderStyle.solid,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: palette.accent),
                            const SizedBox(height: 4),
                            Text('Pegar ref',
                                style: TextStyle(
                                    color: palette.accent, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                final file = File(planRefs[i]);
                return Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: file.existsSync()
                          ? Image.file(file,
                              width: 160, height: 120, fit: BoxFit.cover)
                          : const SizedBox(width: 160, height: 120),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          minimumSize: const Size(28, 28),
                          padding: EdgeInsets.zero,
                        ),
                        icon: const Icon(Icons.close, size: 16, color: Colors.white),
                        onPressed: () {
                          final next = [...planRefs]..removeAt(i);
                          onPlanRefsChanged(next);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => MoodboardHelpers.addManualImages(
              db: db,
              projectId: projectId,
              bibleId: bibleId,
              category: MoodboardCategory.lighting,
              assignedSections: [BibleSectionId.lighting],
            ),
            icon: Icon(Icons.folder_open, size: 16, color: palette.accent),
            label: Text('Elegir desde Finder',
                style: TextStyle(color: palette.accent, fontSize: 12)),
          ),
        ],
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _GlassPanel({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xB31A1A1C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}

class _SectionHead extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppPalette palette;
  final bool accent;

  const _SectionHead({
    required this.icon,
    required this.label,
    required this.palette,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: accent ? palette.accent : palette.textTertiary,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: accent
              ? AppTypography.mono(palette).copyWith(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: palette.accent,
                )
              : AppTypography.titleMedium(palette).copyWith(fontSize: 20),
        ),
      ],
    );
  }
}
