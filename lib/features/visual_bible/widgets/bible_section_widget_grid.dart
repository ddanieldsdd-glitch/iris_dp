import 'package:flutter/material.dart';

import '../../../../shared/visual_bible/bible_section_fields.dart';
import '../../../../shared/visual_bible/bible_widget_layout_packer.dart';
import '../../../../shared/visual_bible/bible_widget_size.dart';
import 'bible_widget_renderer_registry.dart';

/// Construye el grid responsive de widgets para [BibleSectionScaffold].
class BibleSectionWidgetGrid extends StatelessWidget {
  final String sectionId;
  final int projectId;
  final int bibleId;
  final List<BibleSectionField> fields;
  final Map<String, Widget> fieldWidgets;
  final Widget? Function(BuildContext context, BibleSectionField field)?
      fallbackBuilder;
  final double rowGap;

  const BibleSectionWidgetGrid({
    super.key,
    required this.sectionId,
    required this.projectId,
    required this.bibleId,
    required this.fields,
    required this.fieldWidgets,
    this.fallbackBuilder,
    this.rowGap = 16,
  });

  @override
  Widget build(BuildContext context) {
    final items = <BibleWidgetLayoutItem>[];

    for (final field in fields) {
      final widget = _buildField(context, field);
      if (widget == null) continue;
      items.add(
        BibleWidgetLayoutItem.fromSize(
          key: field.key,
          size: field.size,
          child: BibleWidgetSizeScope(
            size: field.size,
            child: widget,
          ),
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();
    return BibleWidgetLayoutGrid(items: items, rowGap: rowGap);
  }

  Widget? _buildField(BuildContext context, BibleSectionField field) {
    final renderCtx = BibleWidgetRenderContext(
      sectionId: sectionId,
      projectId: projectId,
      bibleId: bibleId,
      field: field,
      size: field.size,
    );
    final fromRegistry = BibleWidgetRendererRegistry.tryBuild(renderCtx);
    if (fromRegistry != null) return fromRegistry;

    return fieldWidgets[field.key] ?? fallbackBuilder?.call(context, field);
  }
}
