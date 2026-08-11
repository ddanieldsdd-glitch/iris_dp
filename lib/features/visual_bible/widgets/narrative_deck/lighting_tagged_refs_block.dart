import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/visual_bible/bible_section_ids.dart';
import '../../moodboard_reference_meta.dart';
import '../../services/moodboard_lighting_link_service.dart';
import '../../visual_bible_model.dart';
import '../bible_navigation_scope.dart';
import '../moodboard_lightbox.dart';

/// Explorador de stills del moodboard filtrados por etiquetas de luz.
class LightingTaggedRefsBlock extends ConsumerStatefulWidget {
  final int projectId;
  final int bibleId;

  const LightingTaggedRefsBlock({
    super.key,
    required this.projectId,
    required this.bibleId,
  });

  @override
  ConsumerState<LightingTaggedRefsBlock> createState() =>
      _LightingTaggedRefsBlockState();
}

class _LightingTaggedRefsBlockState extends ConsumerState<LightingTaggedRefsBlock> {
  String? _lightingLook;
  String? _lightSource;
  String? _lightTexture;
  String? _colorMood;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<MoodboardImage>>(
      stream: db.watchMoodboardImages(widget.projectId),
      builder: (context, snap) {
        return FutureBuilder<Map<int, MoodboardReferenceMeta>>(
          future: _loadMeta(db, snap.data ?? []),
          builder: (context, metaSnap) {
            final metaById = metaSnap.data ?? {};
            final pool = <MoodboardImageModel>[];
            for (final row in snap.data ?? []) {
              final model = MoodboardImageModel.fromRow(row);
              final meta = metaById[row.id] ?? model.meta;
              if (MoodboardLightingLinkService.visibleInLightingPool(
                image: model,
                meta: meta,
              )) {
                pool.add(model.copyWith(meta: meta));
              }
            }

            final filtered = pool.where((img) {
              return MoodboardLightingLinkService.matchesFilter(
                meta: img.meta,
                lightingLook: _lightingLook,
                lightSource: _lightSource,
                lightTexture: _lightTexture,
                colorMood: _colorMood,
              );
            }).toList();

            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xB31A1A1C),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'EXPLORAR POR ETIQUETAS',
                          style: AppTypography.mono(palette).copyWith(
                            fontSize: 11,
                            letterSpacing: 1.2,
                            color: palette.textTertiary,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _autoLinkAll(db, palette),
                        child: Text(
                          'Vincular a cartas',
                          style: TextStyle(color: palette.accent, fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () => BibleNavigationScope.openMoodboardForSection(
                          context,
                          BibleSectionId.lighting,
                        ),
                        child: Text(
                          'Moodboard',
                          style: TextStyle(color: palette.accent, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Filtra stills del moodboard por calidad, fuente, textura y look color. '
                    'Las etiquetas vinculan imágenes con las cartas de comportamiento.',
                    style: AppTypography.bodyMedium(palette).copyWith(
                      fontSize: 12,
                      color: palette.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TagRow(
                    label: 'Calidad de luz',
                    options: kMoodboardLightingLooks,
                    selected: _lightingLook,
                    images: pool,
                    valueOf: (m) => m.meta.lightingLook,
                    palette: palette,
                    onSelected: (v) => setState(() => _lightingLook = v),
                  ),
                  const SizedBox(height: 8),
                  _TagRow(
                    label: 'Fuente de luz',
                    options: kMoodboardLightSources,
                    selected: _lightSource,
                    images: pool,
                    valueOf: (m) => m.meta.lightSource,
                    palette: palette,
                    onSelected: (v) => setState(() => _lightSource = v),
                  ),
                  const SizedBox(height: 8),
                  _TagRow(
                    label: 'Textura de luz',
                    options: kMoodboardLightTextures,
                    selected: _lightTexture,
                    images: pool,
                    valueOf: (m) => m.meta.lightTexture,
                    palette: palette,
                    onSelected: (v) => setState(() => _lightTexture = v),
                  ),
                  const SizedBox(height: 8),
                  _TagRow(
                    label: 'Look color',
                    options: kMoodboardColorMoods,
                    selected: _colorMood,
                    images: pool,
                    valueOf: (m) => m.meta.colorMood,
                    palette: palette,
                    onSelected: (v) => setState(() => _colorMood = v),
                  ),
                  if (_hasActiveFilter) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () => setState(() {
                          _lightingLook = null;
                          _lightSource = null;
                          _lightTexture = null;
                          _colorMood = null;
                        }),
                        child: Text(
                          'Limpiar filtros',
                          style: TextStyle(
                            color: palette.textTertiary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  if (filtered.isEmpty)
                    Text(
                      pool.isEmpty
                          ? 'Etiqueta stills en el moodboard (calidad, fuente, textura, look color) '
                              'y asígnalos a Iluminación.'
                          : 'Ningún still coincide con estos filtros.',
                      style: AppTypography.bodyMedium(palette).copyWith(
                        color: palette.textTertiary,
                        fontSize: 12,
                      ),
                    )
                  else
                    SizedBox(
                      height: 108,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final img = filtered[i];
                          return _Thumb(
                            image: img,
                            onTap: () => _openLightbox(
                              context,
                              filtered,
                              i,
                              metaById,
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
      },
    );
  }

  bool get _hasActiveFilter =>
      _lightingLook != null ||
      _lightSource != null ||
      _lightTexture != null ||
      _colorMood != null;

  Future<Map<int, MoodboardReferenceMeta>> _loadMeta(
    AppDatabase db,
    List<MoodboardImage> rows,
  ) {
    if (rows.isEmpty) return Future.value({});
    return MoodboardReferenceMetaStore.loadMany(db, rows.map((r) => r.id));
  }

  Future<void> _autoLinkAll(AppDatabase db, AppPalette palette) async {
    final n = await MoodboardLightingLinkService.linkAllTaggedImages(
      db: db,
      projectId: widget.projectId,
      bibleId: widget.bibleId,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n > 0
              ? 'Vinculadas $n asociaciones imagen ↔ carta'
              : 'Sin coincidencias. Define etiquetas en cartas de estilo y en el moodboard.',
        ),
      ),
    );
  }

  Future<void> _openLightbox(
    BuildContext context,
    List<MoodboardImageModel> images,
    int index,
    Map<int, MoodboardReferenceMeta> metaById,
  ) {
    return MoodboardLightbox.show(
      context: context,
      images: images,
      initialIndex: index,
      metaById: metaById,
      bibleId: widget.bibleId,
      projectId: widget.projectId,
      onAddToProject: (_) async {},
      onMetaSaved: (imageId, meta) async {
        await MoodboardLightingLinkService.linkImageToMatchingCards(
          db: ref.read(databaseProvider),
          bibleId: widget.bibleId,
          imageId: imageId,
          meta: meta,
        );
      },
    );
  }
}

class _TagRow extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? selected;
  final List<MoodboardImageModel> images;
  final String? Function(MoodboardImageModel) valueOf;
  final AppPalette palette;
  final ValueChanged<String?> onSelected;

  const _TagRow({
    required this.label,
    required this.options,
    required this.selected,
    required this.images,
    required this.valueOf,
    required this.palette,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.mono(palette).copyWith(
            fontSize: 10,
            letterSpacing: 1,
            color: palette.textTertiary,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final opt in options)
              _countChip(opt),
          ],
        ),
      ],
    );
  }

  Widget _countChip(String opt) {
    final count = images.where((img) {
      final v = valueOf(img);
      return v != null && v.toLowerCase() == opt.toLowerCase();
    }).length;
    if (count == 0) return const SizedBox.shrink();

    final isSelected = selected?.toLowerCase() == opt.toLowerCase();
    return FilterChip(
      label: Text('$opt ($count)'),
      selected: isSelected,
      onSelected: (v) => onSelected(v ? opt : null),
      selectedColor: palette.accent.withValues(alpha: 0.2),
      checkmarkColor: palette.accent,
      labelStyle: TextStyle(
        fontSize: 11,
        color: isSelected ? palette.accent : palette.textSecondary,
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final MoodboardImageModel image;
  final VoidCallback onTap;

  const _Thumb({required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final path = image.imagePath;
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 144,
          height: 108,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (File(path).existsSync())
                Image.file(File(path), fit: BoxFit.cover)
              else
                const ColoredBox(color: Color(0xFF2C2C2E)),
              if (image.meta.hasAnyLightingTag)
                Positioned(
                  left: 4,
                  bottom: 4,
                  right: 4,
                  child: Text(
                    image.meta.lightingTagSummary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

extension on MoodboardReferenceMeta {
  bool get hasAnyLightingTag =>
      (lightingLook?.trim().isNotEmpty == true) ||
      (lightSource?.trim().isNotEmpty == true) ||
      (lightTexture?.trim().isNotEmpty == true) ||
      (colorMood?.trim().isNotEmpty == true);

  String get lightingTagSummary {
    final parts = [
      if (lightingLook?.trim().isNotEmpty == true) lightingLook,
      if (lightSource?.trim().isNotEmpty == true) lightSource,
      if (lightTexture?.trim().isNotEmpty == true) lightTexture,
      if (colorMood?.trim().isNotEmpty == true) colorMood,
    ].whereType<String>();
    return parts.join(' · ');
  }
}
