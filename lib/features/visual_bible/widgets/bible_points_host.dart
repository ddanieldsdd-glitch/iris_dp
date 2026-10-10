import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/visual_bible/bible_point_extras.dart';
import '../../../shared/visual_bible/bible_section_fields.dart';
import 'bible_add_point.dart';
import 'bible_point_frame.dart';
import 'catalog/bible_widget_catalog.dart';

/// Una lista de puntos de la biblia que no es una pantalla: la de una
/// ficha (una idea de luz, la luz de un set, una referencia…).
///
/// Usa lo mismo que las pantallas —widgets del catálogo, menú «⋯»,
/// «Añadir punto», anchos— pero lee y guarda donde le digan.
class BiblePointsHost extends ConsumerWidget {
  final int projectId;
  final int bibleId;

  /// Pantalla a la que pertenecen las imágenes que se añadan.
  final String sectionId;
  final List<BibleSectionField> fields;
  final Map<String, String> values;

  /// Guarda la lista de puntos; [dropValues] son valores que ya sobran.
  final void Function(
    List<BibleSectionField> fields, {
    Set<String> dropValues,
  })
  onFieldsChanged;
  final void Function(String key, String? value) onValueChanged;

  /// Puntos que la ficha pinta a su manera en vez de con el catálogo.
  final Map<String, Widget> overrides;

  const BiblePointsHost({
    super.key,
    required this.projectId,
    required this.bibleId,
    required this.sectionId,
    required this.fields,
    required this.values,
    required this.onFieldsChanged,
    required this.onValueChanged,
    this.overrides = const {},
  });

  static const double _gap = AppSpacing.xl;
  static const double _rowBreakpoint = 1000;

  /// Pantalla sin puntos propios: al añadir solo se ofrecen los widgets.
  static const _addDialogSection = 'custom_card';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.read(databaseProvider);
    final points = <(BiblePointWidth, Widget)>[];
    for (final field in fields) {
      final point =
          overrides[field.key] ??
          BibleWidgetCatalog.build(
            context,
            BibleWidgetContext(
              projectId: projectId,
              bibleId: bibleId,
              sectionId: sectionId,
              field: field,
              value: values[field.key],
              onChanged: (value) => onValueChanged(field.key, value),
              db: db,
            ),
          );
      if (point == null) continue;
      final extras = BiblePointExtras.read(values, field.key);
      points.add((
        field.width,
        BiblePointFrame(
          key: ValueKey('host_point_${field.key}'),
          projectId: projectId,
          bibleId: bibleId,
          sectionId: sectionId,
          extras: extras,
          onExtrasChanged: (next) => onValueChanged(
            BiblePointExtras.keyFor(field.key),
            next.encode(),
          ),
          onDuplicate: values[field.key] == null
              ? null
              : () => _duplicate(field),
          onRemove: () => onFieldsChanged(
            [
              for (final f in fields)
                if (f.key != field.key) f,
            ],
            dropValues: {field.key, BiblePointExtras.keyFor(field.key)},
          ),
          width: field.width,
          onWidthChanged: (width) => onFieldsChanged([
            for (final f in fields)
              f.key == field.key ? f.copyWith(width: width) : f,
          ]),
          child: point,
        ),
      ));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= _rowBreakpoint;
        final rows = _rows(points, wide: wide);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: _gap),
              rows[i],
            ],
            const SizedBox(height: _gap),
            BibleAddPointTile(onTap: () => _add(context)),
          ],
        );
      },
    );
  }

  void _duplicate(BibleSectionField field) {
    final copy = BibleSectionField(
      key: BibleSectionFieldsConfig.newFieldKey(),
      label: '${field.label} (copia)',
      hint: field.hint,
      maxLines: field.maxLines,
      type: field.type,
      widget: field.widget,
      width: field.width,
    );
    final at = fields.indexWhere((f) => f.key == field.key);
    onFieldsChanged([...fields.take(at + 1), copy, ...fields.skip(at + 1)]);
    onValueChanged(copy.key, values[field.key]);
  }

  Future<void> _add(BuildContext context) async {
    final added = await showBibleAddPointDialog(
      context,
      sectionId: _addDialogSection,
      fields: fields,
    );
    if (added == null) return;
    onFieldsChanged([...fields, added.field]);
    if (added.initialValue != null) {
      onValueChanged(added.field.key, added.initialValue);
    }
  }

  /// Agrupa los puntos estrechos que van seguidos en filas de seis sextos.
  static List<Widget> _rows(
    List<(BiblePointWidth, Widget)> points, {
    required bool wide,
  }) {
    if (!wide) return [for (final (_, w) in points) w];
    final rows = <Widget>[];
    var row = <(BiblePointWidth, Widget)>[];
    var used = 0;
    void flush() {
      if (row.isEmpty) return;
      if (row.length == 1 && row.first.$1 == BiblePointWidth.full) {
        rows.add(row.first.$2);
      } else {
        rows.add(
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < row.length; i++) ...[
                if (i > 0) const SizedBox(width: _gap),
                Expanded(flex: row[i].$1.sixths, child: row[i].$2),
              ],
              if (used < 6) Spacer(flex: 6 - used),
            ],
          ),
        );
      }
      row = [];
      used = 0;
    }

    for (final point in points) {
      if (used + point.$1.sixths > 6) flush();
      row.add(point);
      used += point.$1.sixths;
      if (used == 6) flush();
    }
    flush();
    return rows;
  }
}
