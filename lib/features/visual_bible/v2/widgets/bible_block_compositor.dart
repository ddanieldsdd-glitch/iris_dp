import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../shared/visual_bible/narrative_card_kind.dart';
import '../../bible_block_catalog.dart';
import '../../widgets/bible_dark_glass_panel.dart';
import '../../widgets/catalog/direction/direction_acts_widget.dart';
import '../../widgets/catalog/direction/direction_visual_strategy_widget.dart';
import '../../widgets/catalog/shared/bible_point_list_widget.dart';
import '../../widgets/catalog/shared/bible_references_widget.dart';
import '../../widgets/catalog/shared/bible_tagged_text_widget.dart';
import '../bible_block_schemas.dart';
import '../../widgets/bible_thirds_painter.dart';
import '../../widgets/color_palette_strip.dart';
import '../../widgets/moodboard_lightbox.dart';
import '../../widgets/narrative_deck/lighting_behavior_mosaic.dart';
import '../../widgets/narrative_deck/narrative_deck_block.dart';
import '../../visual_bible_model.dart';
import '../layout/bible_grid_layout.dart';
import '../model/bible_json_parse.dart';
import '../model/bible_block.dart';
import '../model/bible_block_layout.dart';
import '../model/bible_image_content.dart';
import '../theme/bible_theme.dart';
import 'universal_bible_image_input.dart';

/// Renderiza un [BibleBlock] según su [BibleBlockKind] y `subsectionKind`.
class BibleBlockRenderer extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final int projectId;
  final int? bibleId;
  final String? sectionId;
  final bool editing;
  final ValueChanged<BibleBlock>? onChanged;

  const BibleBlockRenderer({
    super.key,
    required this.block,
    required this.theme,
    required this.projectId,
    this.bibleId,
    this.sectionId,
    this.editing = false,
    this.onChanged,
  });

  String? get _subsectionKind => block.content['subsectionKind']?.toString();

  @override
  Widget build(BuildContext context) {
    final pad = block.style.padding ?? theme.spacing.m;
    final radius = block.style.radius ?? theme.shape.radius;
    final showCard = block.style.showCard ?? true;

    final catalog = _catalogWidgetFor(block, projectId: projectId);
    if (catalog != null) return catalog;

    Widget child = switch (_subsectionKind) {
      'textField' => _TextBlock(
        block: block,
        theme: theme,
        editing: editing,
        onChanged: onChanged,
      ),
      'moodboardRefs' => _MoodboardRefsBlock(
        block: block,
        theme: theme,
        projectId: projectId,
        editing: editing,
        onChanged: onChanged,
      ),
      'heroWithCaption' => _ImageBlock(
        block: block,
        theme: theme,
        projectId: projectId,
        editing: editing,
        onChanged: onChanged,
        showThirds: true,
      ),
      'telemetryPanel' => _TelemetryBlock(
        block: block,
        theme: theme,
        editing: editing,
        onChanged: onChanged,
      ),
      'cardDeck' => _CardDeckBlock(
        block: block,
        theme: theme,
        projectId: projectId,
        bibleId: bibleId,
        sectionId: sectionId,
        editing: editing,
        onChanged: onChanged,
      ),
      'paletteTarget' => _ColorPaletteBlock(
        block: block,
        theme: theme,
        editing: editing,
        onChanged: onChanged,
      ),
      'headerTags' => _ChipSelectBlock(
        block: block,
        theme: theme,
        editing: editing,
        onChanged: onChanged,
      ),
      'behaviorMosaic' => _BehaviorMosaicBlock(
        block: block,
        theme: theme,
        projectId: projectId,
        bibleId: bibleId,
        editing: editing,
        onChanged: onChanged,
      ),
      _ => switch (block.type) {
        BibleBlockKind.text => _TextBlock(
          block: block,
          theme: theme,
          editing: editing,
          onChanged: onChanged,
        ),
        BibleBlockKind.narrative => _NarrativeBlock(
          block: block,
          theme: theme,
          editing: editing,
          onChanged: onChanged,
        ),
        BibleBlockKind.heroImage => _ImageBlock(
          block: block,
          theme: theme,
          projectId: projectId,
          editing: editing,
          onChanged: onChanged,
        ),
        BibleBlockKind.moodboardRefs => _MoodboardRefsBlock(
          block: block,
          theme: theme,
          projectId: projectId,
          editing: editing,
          onChanged: onChanged,
        ),
        BibleBlockKind.chipSelect => _ChipSelectBlock(
          block: block,
          theme: theme,
          editing: editing,
          onChanged: onChanged,
        ),
        BibleBlockKind.colorPalette => _ColorPaletteBlock(
          block: block,
          theme: theme,
          editing: editing,
          onChanged: onChanged,
        ),
        BibleBlockKind.telemetry => _TelemetryBlock(
          block: block,
          theme: theme,
          editing: editing,
          onChanged: onChanged,
        ),
        BibleBlockKind.equipmentList => _EquipmentListBlock(
          block: block,
          theme: theme,
          editing: editing,
          onChanged: onChanged,
        ),
        BibleBlockKind.lightingDiagram => _LightingDiagramBlock(
          block: block,
          theme: theme,
          editing: editing,
          onChanged: onChanged,
        ),
        BibleBlockKind.specsTable => _SpecsTableBlock(
          block: block,
          theme: theme,
          editing: editing,
          onChanged: onChanged,
        ),
        BibleBlockKind.workflowPipeline => _WorkflowPipelineBlock(
          block: block,
          theme: theme,
          editing: editing,
          onChanged: onChanged,
        ),
        BibleBlockKind.dynamicBlocks => _DynamicBlocksBlock(
          block: block,
          theme: theme,
          projectId: projectId,
          bibleId: bibleId,
          sectionId: sectionId,
          editing: editing,
          onChanged: onChanged,
        ),
      },
    };

    final textColor = _parseColor(block.style.textColor);
    if (textColor != null) {
      child = DefaultTextStyle.merge(
        style: TextStyle(color: textColor),
        child: child,
      );
    }
    final opacity = block.style.opacity;
    if (opacity != null) {
      child = Opacity(opacity: opacity.clamp(0.0, 1.0), child: child);
    }

    if (!showCard) return Padding(padding: EdgeInsets.all(pad), child: child);

    return BibleDarkGlassPanel(
      padding: EdgeInsets.all(pad),
      borderRadius: radius,
      child: child,
    );
  }
}

Widget? _catalogWidgetFor(BibleBlock block, {required int projectId}) {
  final kind = block.content['subsectionKind']?.toString();
  final label = block.content['label']?.toString() ?? '';
  switch (kind) {
    case BibleBlockSchemas.narrativeIntent:
      return BibleTaggedTextWidget(
        title: label.isEmpty ? 'Intención narrativa' : label,
        text: block.content['text']?.toString() ?? '',
        tags: BibleBlockSchemas.parseTags(block.content['tags']),
      );
    case BibleBlockSchemas.tonePoints:
    case BibleBlockSchemas.transitions:
      return BiblePointListWidget(
        title: label.isEmpty
            ? (kind == BibleBlockSchemas.transitions
                  ? 'Lenguaje de transiciones'
                  : 'Tono y atmósfera')
            : label,
        icon: kind == BibleBlockSchemas.transitions
            ? Icons.animation
            : Icons.blur_on,
        points: BibleBlockSchemas.parsePointList(block.content['points']),
      );
    case BibleBlockSchemas.visualStrategy:
      return DirectionVisualStrategyWidget(pillars: _strategyPillars(block));
    case BibleBlockSchemas.acts:
      return DirectionActsWidget(acts: _directionActs(block));
    case BibleBlockSchemas.narrativeRefs:
      final items = _narrativeRefItems(block);
      return Builder(
        builder: (context) => BibleReferencesWidget(
          title: label.isEmpty ? 'Referencias de dirección' : label,
          mode: ReferencesWidgetMode.narrative,
          items: items,
          onOpenItem: (item) {
            final path = item.path;
            if (path == null || path.isEmpty) return;
            MoodboardLightbox.show(
              context: context,
              images: [
                MoodboardImageModel(
                  id: item.moodboardImageId ?? -1,
                  projectId: projectId,
                  imagePath: path,
                  source: 'bible_block',
                  caption: item.title,
                ),
              ],
              initialIndex: 0,
              metaById: const {},
              projectId: projectId,
              onAddToProject: (_) async {},
            );
          },
        ),
      );
    default:
      return null;
  }
}

List<DirectionStrategyPillar> _strategyPillars(BibleBlock block) {
  final extras = BibleBlockSchemas.parsePointList(block.content['extras']);
  final pillars = <DirectionStrategyPillar>[];
  if (block.content['pillars'] is List) {
    for (final item in block.content['pillars'] as List) {
      if (item is! Map) continue;
      final id = item['id']?.toString() ?? '';
      pillars.add(
        DirectionStrategyPillar(
          id: id,
          title: item['title']?.toString() ?? '',
          body: item['body']?.toString() ?? '',
          icon: switch (id) {
            'camera' => Icons.videocam_outlined,
            'blocking' => Icons.person_pin_outlined,
            'pov' => Icons.center_focus_strong,
            _ => Icons.auto_awesome_outlined,
          },
        ),
      );
    }
  }
  if (pillars.isEmpty) {
    pillars.addAll(const [
      DirectionStrategyPillar(
        id: 'camera',
        title: 'Cámara',
        icon: Icons.videocam_outlined,
      ),
      DirectionStrategyPillar(
        id: 'blocking',
        title: 'Blocking',
        icon: Icons.person_pin_outlined,
      ),
      DirectionStrategyPillar(
        id: 'pov',
        title: 'POV',
        icon: Icons.center_focus_strong,
      ),
    ]);
  }
  for (final extra in extras) {
    pillars.add(
      DirectionStrategyPillar(
        id: extra['title'] ?? 'extra',
        title: extra['title'] ?? 'Estrategia',
        body: extra['body'] ?? '',
      ),
    );
  }
  return pillars;
}

List<DirectionActItem> _directionActs(BibleBlock block) {
  final raw = block.content['acts'];
  if (raw is! List || raw.isEmpty) {
    return const [
      DirectionActItem(phase: 'ACTO I'),
      DirectionActItem(phase: 'ACTO II'),
      DirectionActItem(phase: 'ACTO III'),
    ];
  }
  return [
    for (final item in raw)
      if (item is Map)
        DirectionActItem(
          phase: item['phase']?.toString() ?? '',
          title: item['title']?.toString() ?? '',
          body: item['body']?.toString() ?? item['desc']?.toString() ?? '',
        ),
  ];
}

List<BibleReferenceItem> _narrativeRefItems(BibleBlock block) {
  final raw = block.content['images'] ?? block.content['items'];
  if (raw is! List) return const [];
  return [
    for (final item in raw)
      if (item is Map)
        BibleReferenceItem.fromJson(Map<String, dynamic>.from(item)),
  ];
}

Color? _parseColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var h = hex.replaceFirst('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length == 8) {
    final v = int.tryParse(h, radix: 16);
    if (v != null) return Color(v);
  }
  return null;
}

class _TextBlock extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final bool editing;
  final ValueChanged<BibleBlock>? onChanged;

  const _TextBlock({
    required this.block,
    required this.theme,
    required this.editing,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final label = block.content['label']?.toString() ?? '';
    final text = block.content['text']?.toString() ?? '';

    if (!editing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label.isNotEmpty)
            Text(
              label.toUpperCase(),
              style: AppTypography.mono(palette).copyWith(
                fontSize: theme.typography.label,
                letterSpacing: 1.4,
                color: palette.textTertiary,
              ),
            ),
          const SizedBox(height: 6),
          Text(
            text.isEmpty ? '—' : text,
            style: AppTypography.bodyMedium(
              palette,
            ).copyWith(fontSize: theme.typography.body, height: 1.45),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty)
          Text(
            label.toUpperCase(),
            style: AppTypography.mono(palette).copyWith(
              fontSize: theme.typography.label,
              letterSpacing: 1.4,
              color: palette.textTertiary,
            ),
          ),
        const SizedBox(height: 6),
        TextFormField(
          initialValue: text,
          maxLines: bibleJsonIntOr(block.content['maxLines'], 4),
          style: AppTypography.bodyMedium(palette),
          decoration: const InputDecoration(isDense: true),
          onChanged: (v) {
            onChanged?.call(
              block.copyWith(content: {...block.content, 'text': v}),
            );
          },
        ),
      ],
    );
  }
}

class _NarrativeBlock extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final bool editing;
  final ValueChanged<BibleBlock>? onChanged;

  const _NarrativeBlock({
    required this.block,
    required this.theme,
    required this.editing,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = block.content['text']?.toString() ?? '';
    final accent = _parseColor(theme.colors.accent) ?? palette.accent;

    final title = block.content['label']?.toString().trim();
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: palette.ambientBlue,
          border: Border.all(color: accent.withValues(alpha: 0.15), width: 0.5),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ColoredBox(color: accent, child: const SizedBox(width: 3)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.auto_stories_outlined,
                            color: accent,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            (title == null || title.isEmpty
                                    ? 'Intención narrativa'
                                    : title)
                                .toUpperCase(),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: accent,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (editing)
                        TextFormField(
                          initialValue: text,
                          maxLines: 5,
                          style: AppTypography.bodyMedium(palette).copyWith(
                            fontSize: theme.typography.body,
                            fontStyle: FontStyle.italic,
                            height: 1.45,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                block.content['hint']?.toString() ??
                                'Intención narrativa…',
                            border: InputBorder.none,
                          ),
                          onChanged: (v) => onChanged?.call(
                            block.copyWith(
                              content: {...block.content, 'text': v},
                            ),
                          ),
                        )
                      else
                        Text(
                          text.isEmpty ? 'Sin intención narrativa' : '“$text”',
                          style: AppTypography.bodyMedium(palette).copyWith(
                            fontSize: theme.typography.body,
                            fontStyle: FontStyle.italic,
                            height: 1.45,
                          ),
                        ),
                    ],
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

class _ImageBlock extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final int projectId;
  final bool editing;
  final bool showThirds;
  final ValueChanged<BibleBlock>? onChanged;

  const _ImageBlock({
    required this.block,
    required this.theme,
    required this.projectId,
    required this.editing,
    this.showThirds = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final image = BibleImageContent.fromJson(
      block.content['image'] is Map
          ? Map<String, dynamic>.from(block.content['image'] as Map)
          : block.content,
    );

    if (editing) {
      return SizedBox(
        height: 180,
        child: UniversalBibleImageInput(
          projectId: projectId,
          value: image.path == null ? null : image,
          onChanged: (img) => onChanged?.call(
            block.copyWith(content: {...block.content, 'image': img.toJson()}),
          ),
          onClear: () => onChanged?.call(
            block.copyWith(content: {...block.content}..remove('image')),
          ),
        ),
      );
    }

    final path = image.path;
    if (path == null || path.isEmpty) {
      return const SizedBox(
        height: 120,
        child: Center(child: Icon(Icons.image_outlined)),
      );
    }
    final file = File(path);
    final caption = image.caption ?? block.content['label']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(theme.shape.radius),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                file.existsSync()
                    ? Image.file(file, fit: BoxFit.cover)
                    : const ColoredBox(color: Colors.black26),
                if (showThirds)
                  CustomPaint(painter: BibleThirdsPainter(Colors.white)),
              ],
            ),
          ),
        ),
        if (caption != null && caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(caption, style: AppTypography.caption(context.palette)),
          ),
      ],
    );
  }
}

class _MoodboardRefsBlock extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final int projectId;
  final bool editing;
  final ValueChanged<BibleBlock>? onChanged;

  const _MoodboardRefsBlock({
    required this.block,
    required this.theme,
    required this.projectId,
    required this.editing,
    this.onChanged,
  });

  List<Map<String, dynamic>> _images() {
    final candidates =
        block.content['images'] ?? block.content['items'] ?? const [];
    if (candidates is! List) return const [];
    final out = <Map<String, dynamic>>[];
    for (final candidate in candidates) {
      if (candidate is String && candidate.trim().isNotEmpty) {
        out.add({'path': candidate});
      } else if (candidate is Map) {
        out.add(Map<String, dynamic>.from(candidate));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final images = _images();
    final title = block.content['title']?.toString().trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null && title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(title, style: AppTypography.label(palette)),
          ),
        if (images.isEmpty && !editing)
          SizedBox(
            height: 88,
            child: Center(
              child: Text(
                'Sin referencias',
                style: AppTypography.caption(palette),
              ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var i = 0; i < images.length; i++)
                _MoodboardTile(
                  image: images[i],
                  theme: theme,
                  onOpen: () => _openLightbox(context, images, i),
                  onRemove: editing
                      ? () {
                          final next = List<Map<String, dynamic>>.from(images)
                            ..removeAt(i);
                          onChanged?.call(
                            block.copyWith(
                              content: {...block.content, 'images': next},
                            ),
                          );
                        }
                      : null,
                ),
            ],
          ),
        if (editing) ...[
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: UniversalBibleImageInput(
              projectId: projectId,
              value: null,
              onChanged: (img) {
                final path = img.path;
                if (path == null || path.isEmpty) return;
                onChanged?.call(
                  block.copyWith(
                    content: {
                      ...block.content,
                      'images': [
                        ...images,
                        {
                          'path': path,
                          if (img.caption != null) 'caption': img.caption,
                        },
                      ],
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _openLightbox(
    BuildContext context,
    List<Map<String, dynamic>> images,
    int index,
  ) async {
    final models = <MoodboardImageModel>[];
    for (var i = 0; i < images.length; i++) {
      final path = BibleImageContent.fromJson(images[i]).path;
      if (path == null || path.isEmpty) continue;
      models.add(
        MoodboardImageModel(
          id: -(i + 1),
          projectId: projectId,
          imagePath: path,
          source: 'bible_block',
          caption: images[i]['caption']?.toString(),
        ),
      );
    }
    if (models.isEmpty) return;
    final start = index.clamp(0, models.length - 1);
    await MoodboardLightbox.show(
      context: context,
      images: models,
      initialIndex: start,
      metaById: const {},
      projectId: projectId,
      onAddToProject: (_) async {},
    );
  }
}

class _MoodboardTile extends StatelessWidget {
  final Map<String, dynamic> image;
  final BibleTheme theme;
  final VoidCallback? onOpen;
  final VoidCallback? onRemove;

  const _MoodboardTile({
    required this.image,
    required this.theme,
    this.onOpen,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final path = BibleImageContent.fromJson(image).path;
    final caption = image['caption']?.toString();
    final file = path == null || path.isEmpty ? null : File(path);
    return SizedBox(
      width: 120,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              GestureDetector(
                onTap: onOpen,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(theme.shape.radius),
                  child: SizedBox(
                    width: 120,
                    height: 80,
                    child: file != null && file.existsSync()
                        ? Image.file(file, fit: BoxFit.cover)
                        : ColoredBox(
                            color: Colors.black26,
                            child: Icon(
                              Icons.image_outlined,
                              color: context.palette.textTertiary,
                            ),
                          ),
                  ),
                ),
              ),
              if (onRemove != null)
                Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 16,
                      color: Colors.white,
                    ),
                    onPressed: onRemove,
                  ),
                ),
            ],
          ),
          if (caption != null && caption.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                caption,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(context.palette),
              ),
            ),
        ],
      ),
    );
  }
}

class _ChipSelectBlock extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final bool editing;
  final ValueChanged<BibleBlock>? onChanged;

  const _ChipSelectBlock({
    required this.block,
    required this.theme,
    required this.editing,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final chips = (block.content['chips'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    final selected = (block.content['selected'] as List? ?? const [])
        .map((e) => e.toString())
        .toSet();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final chip in chips)
          FilterChip(
            label: Text(
              chip.toUpperCase(),
              style: AppTypography.mono(palette).copyWith(fontSize: 10),
            ),
            selected: selected.contains(chip),
            selectedColor: palette.accent.withValues(alpha: 0.18),
            side: BorderSide(
              color: selected.contains(chip) ? palette.accent : palette.border,
            ),
            onSelected: editing
                ? (v) {
                    final next = Set<String>.from(selected);
                    if (v) {
                      next.add(chip);
                    } else {
                      next.remove(chip);
                    }
                    onChanged?.call(
                      block.copyWith(
                        content: {...block.content, 'selected': next.toList()},
                      ),
                    );
                  }
                : null,
          ),
        if (editing)
          ActionChip(
            avatar: const Icon(Icons.add, size: 16),
            label: const Text('Añadir'),
            onPressed: () async {
              final controller = TextEditingController();
              final name = await showDialog<String>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Nuevo tag'),
                  content: TextField(controller: controller, autofocus: true),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () =>
                          Navigator.pop(ctx, controller.text.trim()),
                      child: const Text('Añadir'),
                    ),
                  ],
                ),
              );
              if (name == null || name.isEmpty) return;
              onChanged?.call(
                block.copyWith(
                  content: {
                    ...block.content,
                    'chips': [...chips, name],
                  },
                ),
              );
            },
          ),
        if (chips.isEmpty)
          Text('Sin tags', style: AppTypography.caption(palette)),
      ],
    );
  }
}

class _ColorPaletteBlock extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final bool editing;
  final ValueChanged<BibleBlock>? onChanged;

  const _ColorPaletteBlock({
    required this.block,
    required this.theme,
    required this.editing,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = (block.content['colors'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    final swatchColors = colors
        .map((c) => _parseColor(c['hex']?.toString()) ?? Colors.grey)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (swatchColors.isNotEmpty)
          ColorPaletteStrip(colors: swatchColors, height: 22),
        if (swatchColors.isNotEmpty) const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < colors.length; i++)
              _Swatch(
                hex: colors[i]['hex']?.toString() ?? '#888888',
                name: colors[i]['name']?.toString() ?? '',
                onRemove: editing
                    ? () {
                        final next = List<Map<String, dynamic>>.from(colors)
                          ..removeAt(i);
                        onChanged?.call(
                          block.copyWith(
                            content: {...block.content, 'colors': next},
                          ),
                        );
                      }
                    : null,
                onChanged: editing
                    ? (nextColor) {
                        final next = List<Map<String, dynamic>>.from(colors);
                        next[i] = {...next[i], ...nextColor};
                        onChanged?.call(
                          block.copyWith(
                            content: {...block.content, 'colors': next},
                          ),
                        );
                      }
                    : null,
              ),
            if (editing)
              ActionChip(
                label: const Text('+ Color'),
                onPressed: () {
                  final next = [
                    ...colors,
                    {'hex': '#2997FF', 'name': 'ACCENT'},
                  ];
                  onChanged?.call(
                    block.copyWith(content: {...block.content, 'colors': next}),
                  );
                },
              ),
          ],
        ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  final String hex;
  final String name;
  final VoidCallback? onRemove;
  final ValueChanged<Map<String, String>>? onChanged;

  const _Swatch({
    required this.hex,
    required this.name,
    this.onRemove,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(hex) ?? Colors.grey;
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            if (onRemove != null)
              Positioned(
                right: 0,
                top: 0,
                child: InkWell(
                  onTap: onRemove,
                  child: const Icon(Icons.close, size: 14, color: Colors.white),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        if (onChanged != null) ...[
          SizedBox(
            width: 88,
            child: TextFormField(
              initialValue: hex,
              style: AppTypography.label(context.palette),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: '#HEX',
              ),
              onChanged: (v) => onChanged!({'hex': v, 'name': name}),
            ),
          ),
          SizedBox(
            width: 88,
            child: TextFormField(
              initialValue: name,
              style: AppTypography.caption(context.palette),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Nombre',
              ),
              onChanged: (v) => onChanged!({'hex': hex, 'name': v}),
            ),
          ),
        ] else ...[
          Text(hex.toUpperCase(), style: AppTypography.label(context.palette)),
          if (name.isNotEmpty)
            Text(name, style: AppTypography.caption(context.palette)),
        ],
      ],
    );
  }
}

class _TelemetryBlock extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final bool editing;
  final ValueChanged<BibleBlock>? onChanged;

  const _TelemetryBlock({
    required this.block,
    required this.theme,
    this.editing = false,
    this.onChanged,
  });

  List<Map<String, dynamic>> _metrics() {
    final metrics = (block.content['metrics'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (metrics.isEmpty) {
      return [
        {'label': 'Kelvin', 'value': block.content['kelvin'] ?? '—'},
        {'label': 'Ratio', 'value': block.content['ratio'] ?? '—'},
        {'label': 'IRE', 'value': block.content['ire'] ?? '—'},
      ];
    }
    return metrics;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final metrics = _metrics();
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < metrics.length; i++)
              Expanded(
                child: Column(
                  children: [
                    if (editing)
                      TextFormField(
                        initialValue: metrics[i]['value']?.toString() ?? '',
                        textAlign: TextAlign.center,
                        style: AppTypography.titleMedium(palette).copyWith(
                          color:
                              _parseColor(theme.colors.accent) ??
                              palette.accent,
                          fontSize: theme.typography.h2,
                        ),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                        ),
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(metrics);
                          next[i] = {...next[i], 'value': v};
                          onChanged?.call(
                            block.copyWith(
                              content: {...block.content, 'metrics': next},
                            ),
                          );
                        },
                      )
                    else
                      Text(
                        metrics[i]['value']?.toString() ?? '—',
                        style: AppTypography.titleMedium(palette).copyWith(
                          color:
                              _parseColor(theme.colors.accent) ??
                              palette.accent,
                          fontSize: theme.typography.h2,
                        ),
                      ),
                    if (editing)
                      TextFormField(
                        initialValue: metrics[i]['label']?.toString() ?? '',
                        textAlign: TextAlign.center,
                        style: AppTypography.label(palette),
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                        ),
                        onChanged: (v) {
                          final next = List<Map<String, dynamic>>.from(metrics);
                          next[i] = {...next[i], 'label': v};
                          onChanged?.call(
                            block.copyWith(
                              content: {...block.content, 'metrics': next},
                            ),
                          );
                        },
                      )
                    else
                      Text(
                        (metrics[i]['label']?.toString() ?? '').toUpperCase(),
                        style: AppTypography.label(palette),
                      ),
                  ],
                ),
              ),
          ],
        ),
        if (editing)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                onChanged?.call(
                  block.copyWith(
                    content: {
                      ...block.content,
                      'metrics': [
                        ...metrics,
                        {'label': 'Métrica', 'value': '—'},
                      ],
                    },
                  ),
                );
              },
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Añadir métrica'),
            ),
          ),
      ],
    );
  }
}

class _CardDeckBlock extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final int projectId;
  final int? bibleId;
  final String? sectionId;
  final bool editing;
  final ValueChanged<BibleBlock>? onChanged;

  const _CardDeckBlock({
    required this.block,
    required this.theme,
    required this.projectId,
    this.bibleId,
    this.sectionId,
    required this.editing,
    this.onChanged,
  });

  String get _kind {
    final key = block.content['fieldKey']?.toString();
    return switch (key) {
      'filmRefs' => NarrativeCardKind.filmRef,
      'locationLights' => NarrativeCardKind.locationLight,
      'acts' => 'act',
      _ => NarrativeCardKind.overview,
    };
  }

  @override
  Widget build(BuildContext context) {
    final id = bibleId;
    final section = sectionId ?? 'lighting';
    if (id != null && id > 0) {
      return NarrativeDeckBlock(
        projectId: projectId,
        bibleId: id,
        sectionId: section,
        kind: _kind,
        title: block.content['label']?.toString() ?? 'Deck',
        allowAdd: editing,
        allowDelete: editing,
      );
    }
    final nested = BibleGridLayout.nestedBlocks(block);
    if (nested.isNotEmpty) {
      return BibleBlockCompositor(
        blocks: nested,
        theme: theme,
        projectId: projectId,
        bibleId: bibleId,
        sectionId: sectionId,
        editing: editing,
        onBlockChanged: onChanged,
      );
    }
    return Text(
      block.content['label']?.toString() ?? 'Deck narrativo',
      style: AppTypography.bodyMedium(context.palette),
    );
  }
}

class _BehaviorMosaicBlock extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final int projectId;
  final int? bibleId;
  final bool editing;
  final ValueChanged<BibleBlock>? onChanged;

  const _BehaviorMosaicBlock({
    required this.block,
    required this.theme,
    required this.projectId,
    this.bibleId,
    required this.editing,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final id = bibleId;
    if (id != null && id > 0) {
      return LightingBehaviorMosaicBlock(projectId: projectId, bibleId: id);
    }
    return _ImageBlock(
      block: block,
      theme: theme,
      projectId: projectId,
      editing: editing,
      onChanged: onChanged,
    );
  }
}

class _EquipmentListBlock extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final bool editing;
  final ValueChanged<BibleBlock>? onChanged;

  const _EquipmentListBlock({
    required this.block,
    required this.theme,
    required this.editing,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final items = (block.content['items'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 16,
                  color: palette.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(item, style: AppTypography.bodyMedium(palette)),
                ),
                if (editing)
                  IconButton(
                    icon: const Icon(Icons.close, size: 16),
                    onPressed: () {
                      final next = items.where((e) => e != item).toList();
                      onChanged?.call(
                        block.copyWith(
                          content: {...block.content, 'items': next},
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        if (editing)
          TextButton.icon(
            onPressed: () {
              onChanged?.call(
                block.copyWith(
                  content: {
                    ...block.content,
                    'items': [...items, 'Nuevo fixture'],
                  },
                ),
              );
            },
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Añadir equipo'),
          ),
      ],
    );
  }
}

class _LightingDiagramBlock extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final bool editing;
  final ValueChanged<BibleBlock>? onChanged;

  const _LightingDiagramBlock({
    required this.block,
    required this.theme,
    this.editing = false,
    this.onChanged,
  });

  List<Map<String, dynamic>> _nodes() {
    var nodes = block.content['nodes'];
    if (nodes is String) {
      try {
        nodes = jsonDecode(nodes);
      } catch (_) {
        nodes = const [];
      }
    }
    return (nodes as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final nodes = _nodes();
    final label = block.content['label']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(label, style: AppTypography.label(palette)),
          ),
        if (block.content['imagePath']?.toString().isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: Image.file(
                File(block.content['imagePath'].toString()),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => ColoredBox(
                  color: palette.surfaceOverlay,
                  child: Center(
                    child: Text(
                      'Imagen de referencia no disponible',
                      style: AppTypography.caption(palette),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Container(
          height: 180,
          decoration: BoxDecoration(
            border: Border.all(color: palette.border),
            borderRadius: BorderRadius.circular(8),
            color: palette.surfaceOverlay,
          ),
          child: CustomPaint(
            painter: _LightingPlanPainter(nodes: nodes, palette: palette),
            child: nodes.isEmpty
                ? Center(
                    child: Text(
                      'Planta de luz vacía',
                      style: AppTypography.caption(palette),
                    ),
                  )
                : null,
          ),
        ),
        if (block.content['text']?.toString().isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              block.content['text'].toString(),
              style: AppTypography.caption(palette),
            ),
          ),
        if (editing)
          TextFormField(
            initialValue: block.content['label']?.toString() ?? '',
            decoration: const InputDecoration(
              isDense: true,
              labelText: 'Nombre del setup',
            ),
            onChanged: (v) => onChanged?.call(
              block.copyWith(content: {...block.content, 'label': v}),
            ),
          ),
      ],
    );
  }
}

class _LightingPlanPainter extends CustomPainter {
  final List<Map<String, dynamic>> nodes;
  final AppPalette palette;

  _LightingPlanPainter({required this.nodes, required this.palette});

  @override
  void paint(Canvas canvas, Size size) {
    for (final element in nodes) {
      final x = ((element['x'] as num?)?.toDouble() ?? 150) / 600;
      final y = ((element['y'] as num?)?.toDouble() ?? 150) / 400;
      final type = element['type']?.toString() ?? 'light';
      final color = switch (type) {
        'camera' => Colors.blue,
        'subject' => palette.textPrimary,
        'key' => Colors.amber,
        'fill' => Colors.lightBlue,
        'rim' => Colors.orange,
        _ => palette.textTertiary,
      };
      canvas.drawCircle(
        Offset(
          x.clamp(0.03, 0.97) * size.width,
          y.clamp(0.03, 0.97) * size.height,
        ),
        7,
        Paint()..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _LightingPlanPainter oldDelegate) =>
      oldDelegate.nodes != nodes;
}

class _SpecsTableBlock extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final bool editing;
  final ValueChanged<BibleBlock>? onChanged;

  const _SpecsTableBlock({
    required this.block,
    required this.theme,
    required this.editing,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final rows = (block.content['rows'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    final columns = (block.content['columns'] as List? ?? ['label', 'value'])
        .map((e) => e.toString())
        .toList();

    if (rows.isEmpty) {
      rows.addAll([
        {'label': 'Sensor', 'value': '—'},
        {'label': 'ISO', 'value': '—'},
        {'label': 'Codec', 'value': '—'},
      ]);
    }

    return Table(
      columnWidths: {
        for (var i = 0; i < columns.length; i++) i: const FlexColumnWidth(),
      },
      children: [
        TableRow(
          children: [
            for (final c in columns)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  c.toUpperCase(),
                  style: AppTypography.label(palette),
                ),
              ),
          ],
        ),
        for (var r = 0; r < rows.length; r++)
          TableRow(
            children: [
              for (final c in columns)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: editing
                      ? TextFormField(
                          initialValue: rows[r][c]?.toString() ?? '',
                          style: AppTypography.bodyMedium(palette),
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                          ),
                          onChanged: (v) {
                            final next = List<Map<String, dynamic>>.from(rows);
                            next[r] = {...next[r], c: v};
                            onChanged?.call(
                              block.copyWith(
                                content: {...block.content, 'rows': next},
                              ),
                            );
                          },
                        )
                      : Text(
                          rows[r][c]?.toString() ?? '—',
                          style: AppTypography.bodyMedium(palette),
                        ),
                ),
            ],
          ),
      ],
    );
  }
}

class _WorkflowPipelineBlock extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final bool editing;
  final ValueChanged<BibleBlock>? onChanged;

  const _WorkflowPipelineBlock({
    required this.block,
    required this.theme,
    required this.editing,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final steps = (block.content['steps'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    if (steps.isEmpty) {
      steps.addAll(kBibleWorkflowDefaultSteps);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            InputChip(
              label: Text(steps[i], style: AppTypography.bodyMedium(palette)),
              onDeleted: editing
                  ? () {
                      final next = List<String>.from(steps)..removeAt(i);
                      onChanged?.call(
                        block.copyWith(
                          content: {...block.content, 'steps': next},
                        ),
                      );
                    }
                  : null,
            ),
            if (i < steps.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.arrow_forward,
                  size: 16,
                  color: palette.textTertiary,
                ),
              ),
          ],
          if (editing)
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {
                onChanged?.call(
                  block.copyWith(
                    content: {
                      ...block.content,
                      'steps': [...steps, 'Nuevo paso'],
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DynamicBlocksBlock extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final int projectId;
  final int? bibleId;
  final String? sectionId;
  final bool editing;
  final ValueChanged<BibleBlock>? onChanged;

  const _DynamicBlocksBlock({
    required this.block,
    required this.theme,
    required this.projectId,
    this.bibleId,
    this.sectionId,
    this.editing = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final nested = BibleGridLayout.nestedBlocks(block);
    if (nested.isEmpty) {
      final palette = context.palette;
      final count = bibleJsonIntOr(block.content['count'], 0);
      return Text(
        count > 0
            ? '$count bloques dinámicos (color / exposure / lighting)'
            : 'Bloques dinámicos del proyecto',
        style: AppTypography.bodyMedium(palette),
      );
    }
    return BibleBlockCompositor(
      blocks: nested,
      theme: theme,
      projectId: projectId,
      bibleId: bibleId,
      sectionId: sectionId,
      editing: editing,
      onBlockChanged: onChanged == null
          ? null
          : (child) {
              final next = nested
                  .map((b) => b.id == child.id ? child : b)
                  .map((b) => b.toJson())
                  .toList();
              onChanged!(
                block.copyWith(content: {...block.content, 'blocks': next}),
              );
            },
    );
  }
}

/// Compositor de lista/grid de bloques (consumer principal: freeform / canvas).
class BibleBlockCompositor extends StatelessWidget {
  final List<BibleBlock> blocks;
  final BibleTheme theme;
  final int projectId;
  final int? bibleId;
  final String? sectionId;
  final bool editing;
  final String? selectedBlockId;
  final ValueChanged<String>? onSelect;
  final ValueChanged<BibleBlock>? onBlockChanged;
  final double freeformAspectRatio;

  const BibleBlockCompositor({
    super.key,
    required this.blocks,
    required this.theme,
    required this.projectId,
    this.bibleId,
    this.sectionId,
    this.editing = false,
    this.selectedBlockId,
    this.onSelect,
    this.onBlockChanged,
    this.freeformAspectRatio = 1 / 1.4142,
  });

  @override
  Widget build(BuildContext context) {
    if (blocks.isEmpty) {
      return const SizedBox.shrink();
    }
    if (blocks.any((block) => block.layout.mode == 'freeform')) {
      return AspectRatio(
        aspectRatio: freeformAspectRatio,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              clipBehavior: Clip.none,
              children: [
                for (final block in blocks)
                  Positioned(
                    left:
                        (block.layout.x ??
                            block.layout.col / BibleBlockLayout.gridColumns) *
                        constraints.maxWidth,
                    top:
                        (block.layout.y ?? block.layout.row * 0.12) *
                        constraints.maxHeight,
                    width:
                        (block.layout.width ??
                            block.layout.colSpan /
                                BibleBlockLayout.gridColumns) *
                        constraints.maxWidth,
                    height:
                        (block.layout.height ??
                            (block.layout.rowSpan * 0.12).clamp(0.08, 1.0)) *
                        constraints.maxHeight,
                    child: _SelectableBlock(
                      block: block,
                      theme: theme,
                      projectId: projectId,
                      bibleId: bibleId,
                      sectionId: sectionId,
                      editing: editing,
                      selected: selectedBlockId == block.id,
                      onSelect: onSelect,
                      onBlockChanged: onBlockChanged,
                    ),
                  ),
              ],
            );
          },
        ),
      );
    }

    // Agrupar por filas smart (row) — misma lógica que el PDF.
    final rows = BibleGridLayout.rows(blocks);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows) ...[
          _SmartRow(
            blocks: row,
            theme: theme,
            projectId: projectId,
            bibleId: bibleId,
            sectionId: sectionId,
            editing: editing,
            selectedBlockId: selectedBlockId,
            onSelect: onSelect,
            onBlockChanged: onBlockChanged,
          ),
          SizedBox(height: theme.spacing.m),
        ],
      ],
    );
  }
}

class _SmartRow extends StatelessWidget {
  final List<BibleBlock> blocks;
  final BibleTheme theme;
  final int projectId;
  final int? bibleId;
  final String? sectionId;
  final bool editing;
  final String? selectedBlockId;
  final ValueChanged<String>? onSelect;
  final ValueChanged<BibleBlock>? onBlockChanged;

  const _SmartRow({
    required this.blocks,
    required this.theme,
    required this.projectId,
    this.bibleId,
    this.sectionId,
    required this.editing,
    this.selectedBlockId,
    this.onSelect,
    this.onBlockChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<BibleBlock>.from(blocks)
      ..sort((a, b) => a.layout.col.compareTo(b.layout.col));

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalSpan = sorted.fold<int>(
          0,
          (sum, b) => sum + b.layout.colSpan.clamp(1, 12),
        );
        final useFlex = totalSpan <= 12 && sorted.length > 1;

        if (!useFlex) {
          return Column(
            children: [
              for (final b in sorted)
                _SelectableBlock(
                  block: b,
                  theme: theme,
                  projectId: projectId,
                  bibleId: bibleId,
                  sectionId: sectionId,
                  editing: editing,
                  selected: selectedBlockId == b.id,
                  onSelect: onSelect,
                  onBlockChanged: onBlockChanged,
                ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final b in sorted) ...[
              Expanded(
                flex: b.layout.colSpan.clamp(1, 12),
                child: _SelectableBlock(
                  block: b,
                  theme: theme,
                  projectId: projectId,
                  bibleId: bibleId,
                  sectionId: sectionId,
                  editing: editing,
                  selected: selectedBlockId == b.id,
                  onSelect: onSelect,
                  onBlockChanged: onBlockChanged,
                ),
              ),
              if (b != sorted.last) SizedBox(width: theme.spacing.s),
            ],
          ],
        );
      },
    );
  }
}

class _SelectableBlock extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final int projectId;
  final int? bibleId;
  final String? sectionId;
  final bool editing;
  final bool selected;
  final ValueChanged<String>? onSelect;
  final ValueChanged<BibleBlock>? onBlockChanged;

  const _SelectableBlock({
    required this.block,
    required this.theme,
    required this.projectId,
    this.bibleId,
    this.sectionId,
    required this.editing,
    required this.selected,
    this.onSelect,
    this.onBlockChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return GestureDetector(
      onTap: () => onSelect?.call(block.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(theme.shape.radius + 2),
          border: selected && editing
              ? Border.all(color: palette.accent, width: 2)
              : null,
        ),
        child: BibleBlockRenderer(
          block: block,
          theme: theme,
          projectId: projectId,
          bibleId: bibleId,
          sectionId: sectionId,
          editing: editing,
          onChanged: onBlockChanged,
        ),
      ),
    );
  }
}
