import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../bible_block_catalog.dart';
import '../bible_block_schemas.dart';
import '../model/bible_block.dart';
import '../model/bible_page.dart';
import '../theme/bible_theme.dart';
import '../widgets/bible_block_compositor.dart';
import '../widgets/universal_bible_image_input.dart';
import '../model/bible_image_content.dart';

/// Inspector contextual derecho (página o bloque seleccionado).
class BibleBlockInspector extends StatelessWidget {
  final BiblePage? page;
  final String? selectedBlockId;
  final BibleTheme theme;
  final int projectId;
  final ValueChanged<BibleBlock> onBlockChanged;
  final VoidCallback? onDelete;

  const BibleBlockInspector({
    super.key,
    required this.page,
    required this.selectedBlockId,
    required this.theme,
    required this.projectId,
    required this.onBlockChanged,
    this.onDelete,
  });

  BibleBlock? get _block {
    if (page == null || selectedBlockId == null) return null;
    for (final b in page!.blocks) {
      if (b.id == selectedBlockId) return b;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final block = _block;

    return DefaultTabController(
      length: block == null ? 1 : 4,
      child: Container(
        decoration: BoxDecoration(
          color: palette.surfaceElevated,
          border: Border(left: BorderSide(color: palette.border)),
        ),
        child: Semantics(
          namesRoute: true,
          label: 'Inspector de bloque',
          child: block == null
              ? _PageInspector(page: page, palette: palette)
              : Column(
                  children: [
                    TabBar(
                      isScrollable: true,
                      tabs: const [
                        Tab(text: 'Content'),
                        Tab(text: 'Layout'),
                        Tab(text: 'Style'),
                        Tab(text: 'Advanced'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        children: [
                          _BlockInspectorBody(
                            block: block,
                            theme: theme,
                            projectId: projectId,
                            palette: palette,
                            onChanged: onBlockChanged,
                            onDelete: onDelete,
                            section: _InspectorSection.content,
                          ),
                          _BlockInspectorBody(
                            block: block,
                            theme: theme,
                            projectId: projectId,
                            palette: palette,
                            onChanged: onBlockChanged,
                            onDelete: onDelete,
                            section: _InspectorSection.layout,
                          ),
                          _BlockInspectorBody(
                            block: block,
                            theme: theme,
                            projectId: projectId,
                            palette: palette,
                            onChanged: onBlockChanged,
                            onDelete: onDelete,
                            section: _InspectorSection.style,
                          ),
                          _BlockInspectorBody(
                            block: block,
                            theme: theme,
                            projectId: projectId,
                            palette: palette,
                            onChanged: onBlockChanged,
                            onDelete: onDelete,
                            section: _InspectorSection.advanced,
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

enum _InspectorSection { content, layout, style, advanced }

class _PageInspector extends StatelessWidget {
  final BiblePage? page;
  final AppPalette palette;

  const _PageInspector({required this.page, required this.palette});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('AJUSTES DE PÁGINA', style: AppTypography.label(palette)),
        const SizedBox(height: 12),
        Text(
          page?.label ?? 'Sin selección',
          style: AppTypography.titleMedium(palette),
        ),
        const SizedBox(height: 8),
        Text(
          page == null
              ? 'Selecciona una página o un bloque.'
              : '${page!.blocks.length} bloques',
          style: AppTypography.bodyMedium(palette),
        ),
      ],
    );
  }
}

class _BlockInspectorBody extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final int projectId;
  final AppPalette palette;
  final ValueChanged<BibleBlock> onChanged;
  final VoidCallback? onDelete;
  final _InspectorSection section;

  const _BlockInspectorBody({
    required this.block,
    required this.theme,
    required this.projectId,
    required this.palette,
    required this.onChanged,
    this.onDelete,
    this.section = _InspectorSection.content,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: switch (section) {
        _InspectorSection.layout => [
          Text('LAYOUT', style: AppTypography.label(palette)),
          const SizedBox(height: 8),
          _SliderRow(
            label: 'Width (cols)',
            value: block.layout.colSpan.toDouble(),
            min: 1,
            max: 12,
            onChanged: (v) => onChanged(
              block.copyWith(layout: block.layout.copyWith(colSpan: v.round())),
            ),
          ),
          _SliderRow(
            label: 'Col',
            value: block.layout.col.toDouble(),
            min: 0,
            max: 11,
            onChanged: (v) => onChanged(
              block.copyWith(layout: block.layout.copyWith(col: v.round())),
            ),
          ),
          _SliderRow(
            label: 'Row',
            value: block.layout.row.toDouble(),
            min: 0,
            max: 40,
            onChanged: (v) => onChanged(
              block.copyWith(layout: block.layout.copyWith(row: v.round())),
            ),
          ),
          Text('Modo', style: AppTypography.bodyMedium(palette)),
          Text(block.layout.mode, style: AppTypography.caption(palette)),
        ],
        _InspectorSection.style => [
          Text('STYLE', style: AppTypography.label(palette)),
          _SliderRow(
            label: 'Radius',
            value: block.style.radius ?? theme.shape.radius,
            min: 0,
            max: 24,
            onChanged: (v) => onChanged(
              block.copyWith(style: block.style.copyWith(radius: v)),
            ),
          ),
          _SliderRow(
            label: 'Padding',
            value: block.style.padding ?? theme.spacing.m,
            min: 0,
            max: 32,
            onChanged: (v) => onChanged(
              block.copyWith(style: block.style.copyWith(padding: v)),
            ),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Card', style: AppTypography.bodyMedium(palette)),
            value: block.style.showCard ?? true,
            onChanged: (v) => onChanged(
              block.copyWith(style: block.style.copyWith(showCard: v)),
            ),
          ),
        ],
        _InspectorSection.advanced => [
          Text('ADVANCED', style: AppTypography.label(palette)),
          Text('Tipo', style: AppTypography.caption(palette)),
          DropdownButton<BibleBlockKind>(
            isExpanded: true,
            value: block.type,
            items: [
              for (final k in BibleBlockCatalog.pickerKinds)
                DropdownMenuItem(value: k, child: Text(k.label)),
            ],
            onChanged: (k) {
              if (k == null) return;
              onChanged(block.copyWith(type: k));
            },
          ),
          if (onDelete != null) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('Eliminar bloque'),
            ),
          ],
        ],
        _ => [
          Text(
            block.type.label.toUpperCase(),
            style: AppTypography.label(palette),
          ),
          if (block.type == BibleBlockKind.heroImage) ...[
            const SizedBox(height: 16),
            Text('IMAGE', style: AppTypography.label(palette)),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: UniversalBibleImageInput(
                projectId: projectId,
                value: BibleImageContent.fromJson(
                  block.content['image'] is Map
                      ? Map<String, dynamic>.from(block.content['image'] as Map)
                      : null,
                ),
                onChanged: (img) => onChanged(
                  block.copyWith(
                    content: {...block.content, 'image': img.toJson()},
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Text('CONTENT', style: AppTypography.label(palette)),
          const SizedBox(height: 8),
          ..._subsectionEditors(),
          BibleBlockRenderer(
            block: block,
            theme: theme,
            projectId: projectId,
            editing: true,
            onChanged: onChanged,
          ),
        ],
      },
    );
  }

  List<Widget> _subsectionEditors() {
    final kind = block.content['subsectionKind']?.toString();
    return switch (kind) {
      BibleBlockSchemas.narrativeIntent => _tagsEditor(),
      BibleBlockSchemas.tonePoints ||
      BibleBlockSchemas.transitions => _pointsEditor(),
      BibleBlockSchemas.visualStrategy => _pillarsEditor(),
      BibleBlockSchemas.acts => _actsEditor(),
      BibleBlockSchemas.narrativeRefs => _refsMetaEditor(),
      _ => const [],
    };
  }

  List<Widget> _tagsEditor() {
    final tags = BibleBlockSchemas.parseTags(block.content['tags']);
    return [
      TextFormField(
        initialValue: block.content['text']?.toString() ?? '',
        maxLines: 5,
        decoration: const InputDecoration(labelText: 'Intención'),
        onChanged: (v) =>
            onChanged(block.copyWith(content: {...block.content, 'text': v})),
      ),
      const SizedBox(height: 8),
      TextFormField(
        initialValue: tags.join(', '),
        decoration: const InputDecoration(
          labelText: 'Tags (separados por coma)',
        ),
        onChanged: (v) {
          final next = [
            for (final part in v.split(','))
              if (part.trim().isNotEmpty) part.trim(),
          ];
          onChanged(block.copyWith(content: {...block.content, 'tags': next}));
        },
      ),
      const SizedBox(height: 12),
    ];
  }

  List<Widget> _pointsEditor() {
    final points = BibleBlockSchemas.parsePointList(block.content['points']);
    return [
      for (var i = 0; i < points.length; i++) ...[
        TextFormField(
          initialValue: points[i]['title'] ?? '',
          decoration: InputDecoration(labelText: 'Punto ${i + 1} · título'),
          onChanged: (v) => _replacePoint(points, i, title: v),
        ),
        TextFormField(
          initialValue: points[i]['body'] ?? '',
          decoration: InputDecoration(labelText: 'Punto ${i + 1} · cuerpo'),
          maxLines: 3,
          onChanged: (v) => _replacePoint(points, i, body: v),
        ),
        const SizedBox(height: 8),
      ],
      TextButton.icon(
        onPressed: () => onChanged(
          block.copyWith(
            content: {
              ...block.content,
              'points': [
                ...points,
                {'title': '', 'body': ''},
              ],
            },
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Añadir punto'),
      ),
      const SizedBox(height: 12),
    ];
  }

  void _replacePoint(
    List<Map<String, String>> points,
    int index, {
    String? title,
    String? body,
  }) {
    final next = [for (final p in points) Map<String, String>.from(p)];
    next[index] = {
      'title': title ?? next[index]['title'] ?? '',
      'body': body ?? next[index]['body'] ?? '',
    };
    onChanged(block.copyWith(content: {...block.content, 'points': next}));
  }

  List<Widget> _pillarsEditor() {
    final pillars = _pillarMaps();
    return [
      for (var i = 0; i < pillars.length; i++) ...[
        TextFormField(
          initialValue: pillars[i]['title'] ?? '',
          decoration: InputDecoration(labelText: 'Pilar ${i + 1} · título'),
          onChanged: (v) => _replacePillar(pillars, i, title: v),
        ),
        TextFormField(
          initialValue: pillars[i]['body'] ?? '',
          decoration: InputDecoration(labelText: 'Pilar ${i + 1} · cuerpo'),
          maxLines: 3,
          onChanged: (v) => _replacePillar(pillars, i, body: v),
        ),
        const SizedBox(height: 8),
      ],
      const SizedBox(height: 4),
    ];
  }

  List<Map<String, String>> _pillarMaps() {
    final raw = block.content['pillars'];
    if (raw is List && raw.isNotEmpty) {
      return [
        for (final item in raw)
          if (item is Map)
            {
              'id': item['id']?.toString() ?? '',
              'title': item['title']?.toString() ?? '',
              'body': item['body']?.toString() ?? '',
            },
      ];
    }
    return [
      {'id': 'camera', 'title': 'Cámara', 'body': ''},
      {'id': 'blocking', 'title': 'Blocking', 'body': ''},
      {'id': 'pov', 'title': 'POV', 'body': ''},
    ];
  }

  void _replacePillar(
    List<Map<String, String>> pillars,
    int index, {
    String? title,
    String? body,
  }) {
    final next = [for (final p in pillars) Map<String, String>.from(p)];
    next[index] = {
      'id': next[index]['id'] ?? '',
      'title': title ?? next[index]['title'] ?? '',
      'body': body ?? next[index]['body'] ?? '',
    };
    onChanged(block.copyWith(content: {...block.content, 'pillars': next}));
  }

  List<Widget> _actsEditor() {
    final acts = _actMaps();
    return [
      for (var i = 0; i < acts.length; i++) ...[
        TextFormField(
          initialValue: acts[i]['phase'] ?? '',
          decoration: InputDecoration(labelText: 'Acto ${i + 1} · fase'),
          onChanged: (v) => _replaceAct(acts, i, phase: v),
        ),
        TextFormField(
          initialValue: acts[i]['title'] ?? '',
          decoration: InputDecoration(labelText: 'Acto ${i + 1} · título'),
          onChanged: (v) => _replaceAct(acts, i, title: v),
        ),
        TextFormField(
          initialValue: acts[i]['body'] ?? '',
          maxLines: 3,
          decoration: InputDecoration(labelText: 'Acto ${i + 1} · cuerpo'),
          onChanged: (v) => _replaceAct(acts, i, body: v),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }

  List<Map<String, String>> _actMaps() {
    final raw = block.content['acts'];
    if (raw is! List || raw.isEmpty) {
      return [
        {'phase': 'ACTO I', 'title': '', 'body': ''},
        {'phase': 'ACTO II', 'title': '', 'body': ''},
        {'phase': 'ACTO III', 'title': '', 'body': ''},
      ];
    }
    return [
      for (final item in raw)
        if (item is Map)
          {
            'phase': item['phase']?.toString() ?? '',
            'title': item['title']?.toString() ?? '',
            'body': item['body']?.toString() ?? '',
          },
    ];
  }

  void _replaceAct(
    List<Map<String, String>> acts,
    int index, {
    String? phase,
    String? title,
    String? body,
  }) {
    final next = [for (final a in acts) Map<String, String>.from(a)];
    next[index] = {
      'phase': phase ?? next[index]['phase'] ?? '',
      'title': title ?? next[index]['title'] ?? '',
      'body': body ?? next[index]['body'] ?? '',
    };
    onChanged(block.copyWith(content: {...block.content, 'acts': next}));
  }

  List<Widget> _refsMetaEditor() {
    final images = _refMaps();
    return [
      for (var i = 0; i < images.length; i++) ...[
        Text('Referencia ${i + 1}', style: AppTypography.label(palette)),
        TextFormField(
          initialValue: images[i]['title'] ?? '',
          decoration: const InputDecoration(labelText: 'Título narrativo'),
          onChanged: (v) => _replaceRef(images, i, title: v),
        ),
        TextFormField(
          initialValue: images[i]['body'] ?? '',
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Idea narrativa'),
          onChanged: (v) => _replaceRef(images, i, body: v),
        ),
        TextFormField(
          initialValue: images[i]['refLabel'] ?? '',
          decoration: const InputDecoration(labelText: 'Etiqueta (película)'),
          onChanged: (v) => _replaceRef(images, i, refLabel: v),
        ),
        TextFormField(
          initialValue: images[i]['specs'] ?? '',
          decoration: const InputDecoration(
            labelText: 'Specs (LENS=35mm, APERTURE=T5.6)',
          ),
          onChanged: (v) => _replaceRef(images, i, specs: v),
        ),
        const SizedBox(height: 8),
      ],
      if (images.isEmpty)
        Text(
          'Añade stills en el bloque; aquí editas la ficha narrativa.',
          style: AppTypography.caption(palette),
        ),
      const SizedBox(height: 12),
    ];
  }

  List<Map<String, String>> _refMaps() {
    final raw = block.content['images'] ?? block.content['items'];
    if (raw is! List) return const [];
    return [
      for (final item in raw)
        if (item is Map)
          {
            'path': item['path']?.toString() ?? '',
            'moodboardImageId': '${item['moodboardImageId'] ?? ''}',
            'title': item['title']?.toString() ?? '',
            'body': item['body']?.toString() ?? '',
            'refLabel': item['refLabel']?.toString() ?? '',
            'specs': _specsToLine(item['specs']),
          },
    ];
  }

  String _specsToLine(Object? raw) {
    if (raw is! List) return '';
    return [
      for (final spec in raw)
        if (spec is Map && (spec['label']?.toString().isNotEmpty ?? false))
          '${spec['label']}=${spec['value'] ?? ''}',
    ].join(', ');
  }

  List<Map<String, String>> _specsFromLine(String raw) {
    return [
      for (final part in raw.split(','))
        if (part.contains('='))
          {
            'label': part.split('=').first.trim(),
            'value': part.split('=').sublist(1).join('=').trim(),
          },
    ];
  }

  void _replaceRef(
    List<Map<String, String>> images,
    int index, {
    String? title,
    String? body,
    String? refLabel,
    String? specs,
  }) {
    final current = images[index];
    final nextItem = <String, dynamic>{
      if (current['path']!.isNotEmpty) 'path': current['path'],
      if (current['moodboardImageId']!.isNotEmpty)
        'moodboardImageId': int.tryParse(current['moodboardImageId']!),
      'title': title ?? current['title'] ?? '',
      'body': body ?? current['body'] ?? '',
      'refLabel': refLabel ?? current['refLabel'] ?? '',
      'specs': _specsFromLine(specs ?? current['specs'] ?? ''),
    };
    final raw = block.content['images'] ?? block.content['items'];
    final list = [
      if (raw is List)
        for (final item in raw)
          item is Map ? Map<String, dynamic>.from(item) : item,
    ];
    if (index < list.length) list[index] = nextItem;
    onChanged(block.copyWith(content: {...block.content, 'images': list}));
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(label, style: AppTypography.caption(palette)),
        ),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        Text(value.round().toString(), style: AppTypography.mono(palette)),
      ],
    );
  }
}
