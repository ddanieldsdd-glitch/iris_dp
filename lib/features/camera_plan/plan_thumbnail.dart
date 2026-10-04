import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'camera_plan_element_model.dart';
import 'camera_plan_painter.dart';

/// Miniatura de una planta, pintada con el mismo painter del editor y
/// encuadrada a lo que contiene.
class PlanThumbnail extends StatelessWidget {
  final List<PlanElement> elements;
  final List<PlanElement> inherited;
  final IconData emptyIcon;

  /// Zona del plano que se encuadra. Sin ella, se encuadra todo.
  final Rect? focus;

  /// Zonas de los sets, para el plano maestro.
  final List<PlanZone> zones;

  /// Fuerza con la que se ve lo heredado.
  final double inheritedOpacity;

  const PlanThumbnail({
    super.key,
    required this.elements,
    this.inherited = const [],
    this.emptyIcon = Icons.grid_on_outlined,
    this.focus,
    this.zones = const [],
    this.inheritedOpacity = 0.55,
  });

  /// Margen alrededor de los elementos, en unidades del lienzo.
  static const double _margin = 90;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final all = [...inherited, ...elements];

    if (all.isEmpty && zones.isEmpty) {
      return ColoredBox(
        color: palette.surfaceOverlay.withValues(alpha: 0.5),
        child: Center(child: Icon(emptyIcon, color: palette.textTertiary)),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        var bounds =
            focus ??
            (all.isNotEmpty
                ? Rect.fromCircle(center: all.first.position, radius: 1)
                : zones.first.rect);
        for (final el in focus == null ? all : const <PlanElement>[]) {
          bounds = bounds.expandToInclude(
            Rect.fromCircle(center: el.position, radius: 1),
          );
          for (final p in el.pathPoints) {
            bounds = bounds.expandToInclude(
              Rect.fromCircle(center: p, radius: 1),
            );
          }
        }
        if (focus == null) {
          for (final zone in zones) {
            bounds = bounds.expandToInclude(zone.rect);
          }
        }
        bounds = bounds.inflate(focus == null ? _margin : 30);
        final scale = math.min(
          1.0,
          math.min(size.width / bounds.width, size.height / bounds.height),
        );
        final offset = size.center(Offset.zero) - bounds.center * scale;

        return ClipRect(
          child: CustomPaint(
            size: size,
            painter: CameraPlanPainter(
              elements: elements,
              inheritedElements: inherited,
              inheritedOpacity: inheritedOpacity,
              showGrid: false,
              zones: zones,
              palette: palette,
              scale: scale,
              offset: offset,
            ),
          ),
        );
      },
    );
  }
}
