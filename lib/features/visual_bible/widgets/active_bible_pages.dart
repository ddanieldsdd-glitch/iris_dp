import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../shared/visual_bible/bible_section_fields.dart';
import 'catalog/bible_widget_catalog.dart';

/// Una ficha abierta dentro de una pantalla de la biblia (una idea de luz,
/// una localización, una referencia): sus puntos y cómo cambiarlos. El
/// panel lateral la enseña mientras está a la vista.
class ActiveBiblePage {
  final String id;
  final String title;
  final List<BibleSectionField> fields;
  final void Function(List<BibleSectionField> fields, {Set<String> dropValues})
  onFieldsChanged;

  const ActiveBiblePage({
    required this.id,
    required this.title,
    required this.fields,
    required this.onFieldsChanged,
  });

  bool sameAs(ActiveBiblePage other) =>
      other.id == id &&
      other.title == title &&
      other.fields.length == fields.length &&
      [
        for (final (i, f) in fields.indexed)
          f.key == other.fields[i].key &&
              f.label == other.fields[i].label &&
              f.width == other.fields[i].width,
      ].every((same) => same);
}

class ActiveBiblePages extends StateNotifier<List<ActiveBiblePage>> {
  ActiveBiblePages() : super(const []);

  /// Pone o actualiza una ficha a la vista.
  void show(ActiveBiblePage page) {
    if (!mounted) return;
    final i = state.indexWhere((p) => p.id == page.id);
    if (i >= 0 && state[i].sameAs(page)) return;
    state = [
      for (final p in state)
        if (p.id != page.id) p,
      page,
    ];
  }

  void hide(String id) {
    // La app entera puede haberse cerrado antes (al salir de un test).
    if (!mounted || !state.any((p) => p.id == id)) return;
    state = [
      for (final p in state)
        if (p.id != id) p,
    ];
  }
}

/// Las fichas a la vista ahora, en el orden en que se abrieron.
final activeBiblePagesProvider =
    StateNotifierProvider<ActiveBiblePages, List<ActiveBiblePage>>(
      (ref) => ActiveBiblePages(),
    );

/// En el panel lateral: los widgets de las fichas abiertas, cada uno con
/// qué es y para cambiar su orden, su ancho o quitarlo.
class ActiveBiblePagesPanel extends ConsumerWidget {
  final List<ActiveBiblePage> pages;

  const ActiveBiblePagesPanel({super.key, required this.pages});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(
          'Estás dentro de una ficha: estos son sus widgets. Para añadir uno, '
          '«Añadir punto» al final de la ficha.',
          style: AppTypography.caption(palette),
        ),
        for (final page in pages) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'WIDGETS DE ESTA FICHA · ${page.title.toUpperCase()}',
            style: AppTypography.label(palette),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final (i, field) in page.fields.indexed)
            _FieldRow(page: page, index: i, field: field),
          if (page.fields.isEmpty)
            Text('Sin puntos.', style: AppTypography.caption(palette)),
        ],
      ],
    );
  }
}

class _FieldRow extends StatelessWidget {
  final ActiveBiblePage page;
  final int index;
  final BibleSectionField field;

  const _FieldRow({
    required this.page,
    required this.index,
    required this.field,
  });

  void _move(int delta) {
    final next = [...page.fields];
    final to = index + delta;
    if (to < 0 || to >= next.length) return;
    next.insert(to, next.removeAt(index));
    page.onFieldsChanged(next);
  }

  void _width(BiblePointWidth width) => page.onFieldsChanged([
    for (final f in page.fields)
      f.key == field.key ? f.copyWith(width: width) : f,
  ]);

  void _remove() => page.onFieldsChanged(
    [
      for (final f in page.fields)
        if (f.key != field.key) f,
    ],
    dropValues: {field.key},
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final entry = BibleWidgetCatalog.forField(field);
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 6, 2, 6),
      decoration: BoxDecoration(
        color: palette.background.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: [
          Icon(
            entry?.icon ?? Icons.widgets_outlined,
            size: 18,
            color: palette.accent,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  field.label,
                  style: AppTypography.bodyMedium(palette),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${entry?.label ?? 'Texto'} · ${field.width.label}',
                  style: AppTypography.caption(palette),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Opciones del widget',
            color: palette.surfaceElevated,
            icon: Icon(Icons.more_vert, size: 18, color: palette.textSecondary),
            onSelected: (action) => switch (action) {
              'up' => _move(-1),
              'down' => _move(1),
              'remove' => _remove(),
              _ => _width(BiblePointWidth.values.byName(action)),
            },
            itemBuilder: (_) => [
              if (index > 0)
                const PopupMenuItem(value: 'up', child: Text('Subir')),
              if (index < page.fields.length - 1)
                const PopupMenuItem(value: 'down', child: Text('Bajar')),
              const PopupMenuDivider(),
              for (final w in BiblePointWidth.values)
                CheckedPopupMenuItem(
                  value: w.name,
                  checked: field.width == w,
                  child: Text('Ancho: ${w.label.toLowerCase()}'),
                ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'remove',
                child: Text(
                  'Quitar de la ficha',
                  style: TextStyle(color: palette.error),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
