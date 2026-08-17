import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../bible_block_catalog.dart';
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
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Modo', style: AppTypography.bodyMedium(palette)),
            subtitle: Text(block.layout.mode, style: AppTypography.caption(palette)),
          ),
        ],
        _InspectorSection.style => [
          Text('STYLE', style: AppTypography.label(palette)),
          _SliderRow(
            label: 'Radius',
            value: block.style.radius ?? theme.shape.radius,
            min: 0,
            max: 24,
            onChanged: (v) =>
                onChanged(block.copyWith(style: block.style.copyWith(radius: v))),
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
