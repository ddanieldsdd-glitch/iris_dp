import 'package:flutter/widgets.dart';

import 'bible_widget_size.dart';

/// Elemento empaquetable: peso de grid + widget hijo.
class BibleWidgetLayoutItem {
  final String key;
  final int weight;
  final Widget child;

  const BibleWidgetLayoutItem({
    required this.key,
    required this.weight,
    required this.child,
  });

  factory BibleWidgetLayoutItem.fromSize({
    required String key,
    required BibleWidgetSize size,
    required Widget child,
  }) =>
      BibleWidgetLayoutItem(
        key: key,
        weight: size.gridWeight,
        child: child,
      );
}

/// Empaqueta widgets en filas responsive según peso S/M/L.
abstract final class BibleWidgetLayoutPacker {
  static const int gridColumns = 12;

  /// Ancho mínimo legible por unidad S (4/12 del ancho).
  static const double minReadableWidth = 260;

  /// Cuántas unidades de grid (máx. 12) caben en [maxWidth].
  static int effectiveColumns(double maxWidth) {
    if (maxWidth <= 0) return 1;
    final unitWidth = minReadableWidth * (gridColumns / 4);
    final cols = (maxWidth / unitWidth * gridColumns).floor();
    if (cols <= 4) return 1;
    if (cols <= 6) return 6;
    if (cols <= 8) return 8;
    return gridColumns;
  }

  /// Agrupa [items] en filas cuya suma de pesos no supera [effectiveCols].
  static List<List<BibleWidgetLayoutItem>> packRows(
    List<BibleWidgetLayoutItem> items,
    int effectiveCols,
  ) {
    if (items.isEmpty) return const [];
    if (effectiveCols <= 4) {
      return [for (final item in items) [item]];
    }

    final rows = <List<BibleWidgetLayoutItem>>[];
    var currentRow = <BibleWidgetLayoutItem>[];
    var currentWeight = 0;

    for (final item in items) {
      final w = item.weight.clamp(1, gridColumns);
      if (currentRow.isNotEmpty && currentWeight + w > effectiveCols) {
        rows.add(currentRow);
        currentRow = [];
        currentWeight = 0;
      }
      currentRow.add(item);
      currentWeight += w;
      if (currentWeight >= effectiveCols) {
        rows.add(currentRow);
        currentRow = [];
        currentWeight = 0;
      }
    }
    if (currentRow.isNotEmpty) rows.add(currentRow);
    return rows;
  }
}

/// Fila responsive: hijos con flex proporcional al peso S/M/L.
class BibleWidgetLayoutRow extends StatelessWidget {
  final List<BibleWidgetLayoutItem> items;
  final double gap;

  const BibleWidgetLayoutRow({
    super.key,
    required this.items,
    this.gap = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (items.length == 1) {
      return items.first.child;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          Expanded(
            flex: items[i].weight.clamp(1, BibleWidgetLayoutPacker.gridColumns),
            child: items[i].child,
          ),
          if (i < items.length - 1) SizedBox(width: gap),
        ],
      ],
    );
  }
}

/// Grid scrollable que empaqueta [items] según el ancho disponible.
class BibleWidgetLayoutGrid extends StatelessWidget {
  final List<BibleWidgetLayoutItem> items;
  final double rowGap;

  const BibleWidgetLayoutGrid({
    super.key,
    required this.items,
    this.rowGap = 16,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final effectiveCols = BibleWidgetLayoutPacker.effectiveColumns(
          constraints.maxWidth,
        );
        final rows = BibleWidgetLayoutPacker.packRows(items, effectiveCols);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: rowGap),
              BibleWidgetLayoutRow(items: rows[i]),
            ],
          ],
        );
      },
    );
  }
}
