import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../bible_block_catalog.dart';
import '../model/bible_json_parse.dart';
import '../model/bible_block.dart';
import '../model/bible_block_layout.dart';
import '../model/bible_image_content.dart';
import '../theme/bible_theme.dart';
import 'universal_bible_image_input.dart';

/// Renderiza un [BibleBlock] según su [BibleBlockKind].
class BibleBlockRenderer extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;
  final int projectId;
  final bool editing;
  final ValueChanged<BibleBlock>? onChanged;

  const BibleBlockRenderer({
    super.key,
    required this.block,
    required this.theme,
    required this.projectId,
    this.editing = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pad = block.style.padding ?? theme.spacing.m;
    final radius = block.style.radius ?? theme.shape.radius;
    final showCard = block.style.showCard ?? true;

    Widget child = switch (block.type) {
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
      BibleBlockKind.heroImage || BibleBlockKind.moodboardRefs => _ImageBlock(
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
      BibleBlockKind.telemetry => _TelemetryBlock(block: block, theme: theme),
      BibleBlockKind.equipmentList => _EquipmentListBlock(
        block: block,
        theme: theme,
        editing: editing,
        onChanged: onChanged,
      ),
      BibleBlockKind.lightingDiagram => _LightingDiagramBlock(
        block: block,
        theme: theme,
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
      ),
    };

    if (!showCard) return Padding(padding: EdgeInsets.all(pad), child: child);

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color:
            _parseColor(block.style.backgroundColor) ??
            _parseColor(theme.colors.card) ??
            palette.surfaceElevated,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color:
              _parseColor(block.style.borderColor) ??
              _parseColor(theme.colors.border) ??
              palette.border,
          width: block.style.borderWidth ?? theme.shape.borderWidth,
        ),
      ),
      child: child,
    );
  }
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
              style: AppTypography.label(palette).copyWith(letterSpacing: 1.1),
            ),
          const SizedBox(height: 6),
          Text(
            text.isEmpty ? '—' : text,
            style: AppTypography.bodyMedium(
              palette,
            ).copyWith(fontSize: theme.typography.body),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) Text(label, style: AppTypography.label(palette)),
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

    return Container(
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      padding: const EdgeInsets.only(left: 12),
      child: editing
          ? TextFormField(
              initialValue: text,
              maxLines: 5,
              style: AppTypography.bodyMedium(
                palette,
              ).copyWith(fontSize: theme.typography.body, height: 1.45),
              decoration: InputDecoration(
                hintText:
                    block.content['hint']?.toString() ?? 'Intención narrativa…',
                border: InputBorder.none,
              ),
              onChanged: (v) => onChanged?.call(
                block.copyWith(content: {...block.content, 'text': v}),
              ),
            )
          : Text(
              text.isEmpty ? 'Sin intención narrativa' : '“$text”',
              style: AppTypography.bodyMedium(palette).copyWith(
                fontSize: theme.typography.body,
                fontStyle: FontStyle.italic,
                height: 1.45,
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
  final ValueChanged<BibleBlock>? onChanged;

  const _ImageBlock({
    required this.block,
    required this.theme,
    required this.projectId,
    required this.editing,
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(theme.shape.radius),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: file.existsSync()
            ? Image.file(file, fit: BoxFit.cover)
            : const ColoredBox(color: Colors.black26),
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
            label: Text(chip.toUpperCase()),
            selected: selected.contains(chip),
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

    return Wrap(
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
    );
  }
}

class _Swatch extends StatelessWidget {
  final String hex;
  final String name;
  final VoidCallback? onRemove;

  const _Swatch({required this.hex, required this.name, this.onRemove});

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
        Text(hex.toUpperCase(), style: AppTypography.label(context.palette)),
        if (name.isNotEmpty)
          Text(name, style: AppTypography.caption(context.palette)),
      ],
    );
  }
}

class _TelemetryBlock extends StatelessWidget {
  final BibleBlock block;
  final BibleTheme theme;

  const _TelemetryBlock({required this.block, required this.theme});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final metrics = (block.content['metrics'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (metrics.isEmpty) {
      metrics.addAll([
        {'label': 'Kelvin', 'value': block.content['kelvin'] ?? '—'},
        {'label': 'Ratio', 'value': block.content['ratio'] ?? '—'},
        {'label': 'IRE', 'value': block.content['ire'] ?? '—'},
      ]);
    }
    return Row(
      children: [
        for (final m in metrics)
          Expanded(
            child: Column(
              children: [
                Text(
                  m['value']?.toString() ?? '—',
                  style: AppTypography.titleMedium(palette).copyWith(
                    color: _parseColor(theme.colors.accent) ?? palette.accent,
                    fontSize: theme.typography.h2,
                  ),
                ),
                Text(
                  (m['label']?.toString() ?? '').toUpperCase(),
                  style: AppTypography.label(palette),
                ),
              ],
            ),
          ),
      ],
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

  const _LightingDiagramBlock({required this.block, required this.theme});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final nodes = (block.content['nodes'] as List? ?? const []).length;
    return Container(
      height: 140,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        border: Border.all(color: palette.border),
        borderRadius: BorderRadius.circular(8),
        color: palette.surfaceOverlay,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.grid_on_outlined, color: palette.accent),
          const SizedBox(height: 8),
          Text(
            nodes > 0
                ? 'Diagrama de iluminación ($nodes nodos)'
                : 'Diagrama de iluminación',
            style: AppTypography.bodyMedium(palette),
          ),
          Text(
            'Editar en sección Lighting o inspector',
            style: AppTypography.caption(palette),
          ),
        ],
      ),
    );
  }
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
      steps.addAll(['Preproduction', 'Camera prep', 'Shoot', 'DIT', 'Grade']);
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: palette.surfaceOverlay,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: palette.border),
              ),
              child: Text(steps[i], style: AppTypography.bodyMedium(palette)),
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

  const _DynamicBlocksBlock({required this.block, required this.theme});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final count = bibleJsonIntOr(block.content['count'], 0);
    return Text(
      count > 0
          ? '$count bloques dinámicos (color / exposure / lighting)'
          : 'Bloques dinámicos del proyecto',
      style: AppTypography.bodyMedium(palette),
    );
  }
}

/// Compositor de lista/grid de bloques (consumer principal: freeform / canvas).
class BibleBlockCompositor extends StatelessWidget {
  final List<BibleBlock> blocks;
  final BibleTheme theme;
  final int projectId;
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

    // Agrupar por filas smart (row).
    final byRow = <int, List<BibleBlock>>{};
    for (final b in blocks) {
      byRow.putIfAbsent(b.layout.row, () => []).add(b);
    }
    final rows = byRow.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final row in rows) ...[
          _SmartRow(
            blocks: byRow[row]!,
            theme: theme,
            projectId: projectId,
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
  final bool editing;
  final String? selectedBlockId;
  final ValueChanged<String>? onSelect;
  final ValueChanged<BibleBlock>? onBlockChanged;

  const _SmartRow({
    required this.blocks,
    required this.theme,
    required this.projectId,
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
  final bool editing;
  final bool selected;
  final ValueChanged<String>? onSelect;
  final ValueChanged<BibleBlock>? onBlockChanged;

  const _SelectableBlock({
    required this.block,
    required this.theme,
    required this.projectId,
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
          editing: editing,
          onChanged: onBlockChanged,
        ),
      ),
    );
  }
}
