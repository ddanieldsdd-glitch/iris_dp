import 'package:flutter/widgets.dart';

import '../../../shared/visual_bible/bible_section_fields.dart';
import '../../../shared/visual_bible/bible_subsection_kind_catalog.dart';
import '../../../shared/visual_bible/bible_widget_size.dart';

/// Expone el tamaño S/M/L activo a widgets hijos del grid.
class BibleWidgetSizeScope extends InheritedWidget {
  final BibleWidgetSize size;

  const BibleWidgetSizeScope({
    super.key,
    required this.size,
    required super.child,
  });

  static BibleWidgetSize of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<BibleWidgetSizeScope>();
    return scope?.size ?? BibleWidgetSize.large;
  }

  static BibleWidgetSize? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<BibleWidgetSizeScope>()
        ?.size;
  }

  @override
  bool updateShouldNotify(BibleWidgetSizeScope oldWidget) =>
      oldWidget.size != size;
}

/// Contexto de renderizado para el registry de widgets Stitch.
class BibleWidgetRenderContext {
  final String sectionId;
  final int projectId;
  final int bibleId;
  final BibleSectionField field;
  final BibleWidgetSize size;

  const BibleWidgetRenderContext({
    required this.sectionId,
    required this.projectId,
    required this.bibleId,
    required this.field,
    required this.size,
  });
}

typedef BibleWidgetRenderer = Widget Function(BibleWidgetRenderContext ctx);

/// Registry de renderers por sección y kind. Las pantallas registran bindings
/// específicos; kinds genéricos usan el fallback del scaffold.
abstract final class BibleWidgetRendererRegistry {
  static final Map<String, Map<BibleSubsectionKindId, BibleWidgetRenderer>>
      _sectionRenderers = {};
  static final Map<String, Map<String, BibleWidgetRenderer>> _bindingRenderers =
      {};

  static void registerKind(
    String sectionId,
    BibleSubsectionKindId kind,
    BibleWidgetRenderer renderer,
  ) {
    _sectionRenderers.putIfAbsent(sectionId, () => {})[kind] = renderer;
  }

  static void registerBinding(
    String sectionId,
    String bindingKey,
    BibleWidgetRenderer renderer,
  ) {
    _bindingRenderers.putIfAbsent(sectionId, () => {})[bindingKey] = renderer;
  }

  static void clearSection(String sectionId) {
    _sectionRenderers.remove(sectionId);
    _bindingRenderers.remove(sectionId);
  }

  static Widget? tryBuild(BibleWidgetRenderContext ctx) {
    final binding = ctx.field.binding ?? ctx.field.key;
    final byBinding = _bindingRenderers[ctx.sectionId]?[binding];
    if (byBinding != null) {
      return byBinding(ctx);
    }
    final byKind =
        _sectionRenderers[ctx.sectionId]?[ctx.field.resolvedKind(ctx.sectionId)];
    return byKind?.call(ctx);
  }
}
