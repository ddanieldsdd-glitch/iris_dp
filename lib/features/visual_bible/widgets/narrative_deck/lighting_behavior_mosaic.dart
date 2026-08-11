import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/database/database_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/visual_bible/bible_section_ids.dart';
import '../../../../shared/visual_bible/narrative_card_kind.dart';
import '../../moodboard_reference_meta.dart';
import '../../services/moodboard_lighting_link_service.dart';
import '../../visual_bible_model.dart';
import '../bible_navigation_scope.dart';
import 'narrative_card_detail.dart';

/// Mosaico de contenedores de comportamiento de luz definidos por el usuario.
///
/// Cada contenedor declara de qué quiere hablar y qué tags de moodboard
/// deben aparecer dentro (calidad, fuente, textura, look color).
class LightingBehaviorMosaicBlock extends ConsumerWidget {
  final int projectId;
  final int bibleId;

  const LightingBehaviorMosaicBlock({
    super.key,
    required this.projectId,
    required this.bibleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final db = ref.watch(databaseProvider);

    return StreamBuilder<List<VisualBibleNarrativeCard>>(
      stream: db.watchNarrativeCardsForSection(
        bibleId,
        BibleSectionId.lighting,
        kind: NarrativeCardKind.style,
      ),
      builder: (context, cardsSnap) {
        final containers = (cardsSnap.data ?? [])
            .map(NarrativeCardModel.fromRow)
            .toList();

        return StreamBuilder<List<MoodboardImage>>(
          stream: db.watchMoodboardImages(projectId),
          builder: (context, imgsSnap) {
            return FutureBuilder<Map<int, MoodboardReferenceMeta>>(
              future: MoodboardReferenceMetaStore.loadMany(
                db,
                (imgsSnap.data ?? []).map((r) => r.id),
              ),
              builder: (context, metaSnap) {
                final metaById = metaSnap.data ?? {};
                final pool = <MoodboardImageModel>[];
                for (final row in imgsSnap.data ?? []) {
                  final model = MoodboardImageModel.fromRow(row);
                  final meta = metaById[row.id] ?? model.meta;
                  if (MoodboardLightingLinkService.visibleInLightingPool(
                    image: model,
                    meta: meta,
                  )) {
                    pool.add(model.copyWith(meta: meta));
                  }
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _MosaicHeader(
                      palette: palette,
                      onAdd: () => _createContainer(context, ref),
                      onOpenMoodboard: () =>
                          BibleNavigationScope.openMoodboardForSection(
                        context,
                        BibleSectionId.lighting,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (containers.isEmpty)
                      _EmptyState(
                        palette: palette,
                        onAdd: () => _createContainer(context, ref),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final wide = constraints.maxWidth >= 900;
                          final mid = constraints.maxWidth >= 620;
                          final cross = wide
                              ? 3
                              : mid
                                  ? 2
                                  : 1;
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: containers.length,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: cross,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 0.95,
                            ),
                            itemBuilder: (context, i) {
                              final container = containers[i];
                              final matched = MoodboardLightingLinkService
                                  .imagesMatchingContainer(
                                pool: pool,
                                container: container,
                              );
                              return _ContainerTile(
                                container: container,
                                matched: matched,
                                palette: palette,
                                onOpen: () => NarrativeCardDetailPage.open(
                                  context,
                                  projectId: projectId,
                                  bibleId: bibleId,
                                  cardId: container.id,
                                ),
                                onConfigure: () => _editContainer(
                                  context,
                                  ref,
                                  container,
                                ),
                                onDelete: () =>
                                    db.deleteNarrativeCard(container.id),
                              );
                            },
                          );
                        },
                      ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _createContainer(BuildContext context, WidgetRef ref) async {
    final result = await showLightingBehaviorContainerSheet(context);
    if (result == null || !context.mounted) return;
    final db = ref.read(databaseProvider);
    final existing = await db
        .watchNarrativeCardsForSection(
          bibleId,
          BibleSectionId.lighting,
          kind: NarrativeCardKind.style,
        )
        .first;
    final nextOrder = existing.isEmpty
        ? 0
        : existing.map((c) => c.sortOrder).reduce((a, b) => a > b ? a : b) + 1;

    final meta = <String, dynamic>{
      if (result.filter.hasAny) 'tagFilters': result.filter.toMetaMap(),
    };
    // Legacy single-value sync for older link paths.
    if (result.filter.lightingLooks.isNotEmpty) {
      meta['lightingLook'] = result.filter.lightingLooks.first;
    }
    if (result.filter.lightSources.isNotEmpty) {
      meta['lightSource'] = result.filter.lightSources.first;
    }
    if (result.filter.lightTextures.isNotEmpty) {
      meta['lightTexture'] = result.filter.lightTextures.first;
    }
    if (result.filter.colorMoods.isNotEmpty) {
      meta['colorMood'] = result.filter.colorMoods.first;
    }

    final id = await db.insertNarrativeCard(
      VisualBibleNarrativeCardsCompanion.insert(
        bibleId: bibleId,
        sectionId: BibleSectionId.lighting,
        kind: NarrativeCardKind.style,
        title: result.title,
        body: Value(result.body.trim().isEmpty ? null : result.body.trim()),
        metaJson: Value(meta.isEmpty ? null : jsonEncode(meta)),
        sortOrder: Value(nextOrder),
      ),
    );

    await MoodboardLightingLinkService.linkAllTaggedImages(
      db: db,
      projectId: projectId,
      bibleId: bibleId,
    );

    if (!context.mounted) return;
    await NarrativeCardDetailPage.open(
      context,
      projectId: projectId,
      bibleId: bibleId,
      cardId: id,
    );
  }

  Future<void> _editContainer(
    BuildContext context,
    WidgetRef ref,
    NarrativeCardModel container,
  ) async {
    final result = await showLightingBehaviorContainerSheet(
      context,
      initialTitle: container.title,
      initialBody: container.body ?? '',
      initialFilter: LightingBehaviorTagFilter.fromCard(container),
    );
    if (result == null) return;
    final db = ref.read(databaseProvider);
    final row = await db.getNarrativeCard(container.id);
    if (row == null) return;

    final meta = Map<String, dynamic>.from(container.meta);
    if (result.filter.hasAny) {
      meta['tagFilters'] = result.filter.toMetaMap();
    } else {
      meta.remove('tagFilters');
    }
    meta.remove('lightingLook');
    meta.remove('lightSource');
    meta.remove('lightTexture');
    meta.remove('colorMood');
    if (result.filter.lightingLooks.isNotEmpty) {
      meta['lightingLook'] = result.filter.lightingLooks.first;
    }
    if (result.filter.lightSources.isNotEmpty) {
      meta['lightSource'] = result.filter.lightSources.first;
    }
    if (result.filter.lightTextures.isNotEmpty) {
      meta['lightTexture'] = result.filter.lightTextures.first;
    }
    if (result.filter.colorMoods.isNotEmpty) {
      meta['colorMood'] = result.filter.colorMoods.first;
    }

    await db.updateNarrativeCard(
      row.copyWith(
        title: result.title,
        body: Value(result.body.trim().isEmpty ? null : result.body.trim()),
        metaJson: Value(meta.isEmpty ? null : jsonEncode(meta)),
      ),
    );
    await MoodboardLightingLinkService.linkAllTaggedImages(
      db: db,
      projectId: projectId,
      bibleId: bibleId,
    );
  }
}

class _MosaicHeader extends StatelessWidget {
  final AppPalette palette;
  final VoidCallback onAdd;
  final VoidCallback onOpenMoodboard;

  const _MosaicHeader({
    required this.palette,
    required this.onAdd,
    required this.onOpenMoodboard,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COMPORTAMIENTO DE LA LUZ',
                style: AppTypography.mono(palette).copyWith(
                  fontSize: 12,
                  letterSpacing: 1.4,
                  color: palette.textTertiary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Crea contenedores (cover + tags). Al entrar verás todas las '
                'imágenes asociadas a ese apartado.',
                style: AppTypography.bodyMedium(palette).copyWith(
                  fontSize: 13,
                  color: palette.textSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onOpenMoodboard,
          child: Text(
            'Moodboard',
            style: TextStyle(color: palette.accent, fontSize: 12),
          ),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: Icon(Icons.add, color: palette.accent, size: 18),
          label: Text(
            'Añadir contenedor',
            style: TextStyle(color: palette.accent),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppPalette palette;
  final VoidCallback onAdd;

  const _EmptyState({required this.palette, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xB31A1A1C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            'Sin contenedores todavía',
            style: AppTypography.bodyMedium(palette).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Ejemplos: Contraste y volumen, Temperatura y sensación, '
            'Textura óptica… Define los tags que quieres tratar en cada uno.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(palette).copyWith(
              fontSize: 13,
              color: palette.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Crear primer contenedor'),
          ),
        ],
      ),
    );
  }
}

class _ContainerTile extends StatelessWidget {
  final NarrativeCardModel container;
  final List<MoodboardImageModel> matched;
  final AppPalette palette;
  final VoidCallback onOpen;
  final VoidCallback onConfigure;
  final VoidCallback onDelete;

  const _ContainerTile({
    required this.container,
    required this.matched,
    required this.palette,
    required this.onOpen,
    required this.onConfigure,
    required this.onDelete,
  });

  String? get _coverPath {
    final coverId = container.coverMoodboardImageId;
    if (coverId != null) {
      for (final img in matched) {
        if (img.id == coverId) return img.imagePath;
      }
    }
    if (matched.isNotEmpty) return matched.first.imagePath;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final filter = LightingBehaviorTagFilter.fromCard(container);
    final path = _coverPath;
    final tags = filter.allSelectedLabels;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: const Color(0xB31A1A1C),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(8),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (path != null && File(path).existsSync())
                        Image.file(File(path), fit: BoxFit.cover)
                      else
                        ColoredBox(
                          color: Colors.white.withValues(alpha: 0.04),
                          child: Center(
                            child: Icon(
                              Icons.wb_twilight_outlined,
                              color: palette.textTertiary,
                              size: 36,
                            ),
                          ),
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.65),
                            ],
                          ),
                        ),
                      ),
                      Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${matched.length} still${matched.length == 1 ? '' : 's'}',
                            style: AppTypography.mono(palette).copyWith(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                      if (tags.isNotEmpty)
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final t in tags.take(3))
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.accent.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(3),
                                    border: Border.all(
                                      color: palette.accent.withValues(alpha: 0.45),
                                    ),
                                  ),
                                  child: Text(
                                    t.toUpperCase(),
                                    style: AppTypography.mono(palette).copyWith(
                                      fontSize: 9,
                                      color: palette.accent,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        container.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium(palette).copyWith(
                          fontWeight: FontWeight.w700,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Configurar tags',
                      visualDensity: VisualDensity.compact,
                      onPressed: onConfigure,
                      icon: Icon(
                        Icons.tune,
                        size: 18,
                        color: palette.textTertiary,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Eliminar',
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                      icon: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: palette.textTertiary,
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

class LightingBehaviorContainerResult {
  final String title;
  final String body;
  final LightingBehaviorTagFilter filter;

  const LightingBehaviorContainerResult({
    required this.title,
    required this.body,
    required this.filter,
  });
}

Future<LightingBehaviorContainerResult?> showLightingBehaviorContainerSheet(
  BuildContext context, {
  String? initialTitle,
  String? initialBody,
  LightingBehaviorTagFilter? initialFilter,
}) {
  return showModalBottomSheet<LightingBehaviorContainerResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.palette.surfaceElevated,
    builder: (ctx) => _ContainerEditorSheet(
      initialTitle: initialTitle ?? '',
      initialBody: initialBody ?? '',
      initialFilter: initialFilter ?? const LightingBehaviorTagFilter(),
    ),
  );
}

class _ContainerEditorSheet extends StatefulWidget {
  final String initialTitle;
  final String initialBody;
  final LightingBehaviorTagFilter initialFilter;

  const _ContainerEditorSheet({
    required this.initialTitle,
    required this.initialBody,
    required this.initialFilter,
  });

  @override
  State<_ContainerEditorSheet> createState() => _ContainerEditorSheetState();
}

class _ContainerEditorSheetState extends State<_ContainerEditorSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _bodyCtrl;
  late Set<String> _looks;
  late Set<String> _sources;
  late Set<String> _textures;
  late Set<String> _moods;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _bodyCtrl = TextEditingController(text: widget.initialBody);
    _looks = {...widget.initialFilter.lightingLooks};
    _sources = {...widget.initialFilter.lightSources};
    _textures = {...widget.initialFilter.lightTextures};
    _moods = {...widget.initialFilter.colorMoods};
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _toggle(Set<String> set, String value) {
    setState(() {
      if (set.contains(value)) {
        set.remove(value);
      } else {
        set.add(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initialTitle.isEmpty
                  ? 'Nuevo contenedor'
                  : 'Editar contenedor',
              style: AppTypography.titleMedium(palette),
            ),
            const SizedBox(height: 6),
            Text(
              'Define de qué vas a hablar y qué tags del moodboard deben '
              'aparecer dentro de este apartado.',
              style: AppTypography.bodyMedium(palette).copyWith(
                fontSize: 13,
                color: palette.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Título del contenedor',
                hintText: 'Contraste y volumen / Temperatura y sensación…',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bodyCtrl,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'De qué vas a hablar',
                hintText:
                    'Cómo tratamos el fall-off, la especularidad, la temperatura…',
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'TAGS QUE QUIERES QUE APAREZCAN',
              style: AppTypography.mono(palette).copyWith(
                fontSize: 11,
                letterSpacing: 1.2,
                color: palette.textTertiary,
              ),
            ),
            const SizedBox(height: 12),
            _TagFamilyPicker(
              label: 'Calidad de luz',
              options: kMoodboardLightingLooks,
              selected: _looks,
              palette: palette,
              onToggle: (v) => _toggle(_looks, v),
            ),
            const SizedBox(height: 12),
            _TagFamilyPicker(
              label: 'Fuente de luz',
              options: kMoodboardLightSources,
              selected: _sources,
              palette: palette,
              onToggle: (v) => _toggle(_sources, v),
            ),
            const SizedBox(height: 12),
            _TagFamilyPicker(
              label: 'Textura de luz',
              options: kMoodboardLightTextures,
              selected: _textures,
              palette: palette,
              onToggle: (v) => _toggle(_textures, v),
            ),
            const SizedBox(height: 12),
            _TagFamilyPicker(
              label: 'Look color',
              options: kMoodboardColorMoods,
              selected: _moods,
              palette: palette,
              onToggle: (v) => _toggle(_moods, v),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                final title = _titleCtrl.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(
                  context,
                  LightingBehaviorContainerResult(
                    title: title,
                    body: _bodyCtrl.text,
                    filter: LightingBehaviorTagFilter(
                      lightingLooks: _looks.toList()..sort(),
                      lightSources: _sources.toList()..sort(),
                      lightTextures: _textures.toList()..sort(),
                      colorMoods: _moods.toList()..sort(),
                    ),
                  ),
                );
              },
              child: Text(
                widget.initialTitle.isEmpty ? 'Crear contenedor' : 'Guardar',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagFamilyPicker extends StatelessWidget {
  final String label;
  final List<String> options;
  final Set<String> selected;
  final AppPalette palette;
  final ValueChanged<String> onToggle;

  const _TagFamilyPicker({
    required this.label,
    required this.options,
    required this.selected,
    required this.palette,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodyMedium(palette).copyWith(
            fontSize: 12,
            color: palette.textSecondary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final opt in options)
              FilterChip(
                label: Text(opt, style: const TextStyle(fontSize: 12)),
                selected: selected.contains(opt),
                onSelected: (_) => onToggle(opt),
                selectedColor: palette.accent.withValues(alpha: 0.25),
                checkmarkColor: palette.accent,
                side: BorderSide(
                  color: selected.contains(opt)
                      ? palette.accent
                      : Colors.white.withValues(alpha: 0.12),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
