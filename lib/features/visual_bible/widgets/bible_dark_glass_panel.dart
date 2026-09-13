import 'package:flutter/material.dart';

import '../../../shared/visual_bible/bible_widget_size.dart';
import 'bible_widget_renderer_registry.dart';

/// Panel oscuro tipo cristal usado en secciones legacy de la biblia.
///
/// Sustituye las copias privadas `_GlassPanel` de cada pantalla.
/// El padding se adapta al tamaño S/M/L activo en el grid.
class BibleDarkGlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double borderRadius;
  final bool? compact;

  const BibleDarkGlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.borderRadius = 8,
    this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact =
        compact ?? BibleWidgetSizeScope.of(context) == BibleWidgetSize.small;
    final resolvedPadding = padding ??
        EdgeInsets.all(isCompact ? 12 : 20);

    return Container(
      width: double.infinity,
      padding: resolvedPadding,
      decoration: BoxDecoration(
        color: const Color(0xB31A1A1C),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}
