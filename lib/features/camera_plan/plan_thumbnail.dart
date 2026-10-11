import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/annotations/annotation_canvas.dart';
import '../../shared/annotations/annotation_document.dart';
import 'camera_plan_element_model.dart';
import 'camera_plan_painter.dart';
import 'plan_segment.dart';

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

  /// Recorridos de planos secuencia, de zona a zona: se dibujan con
  /// flechas encima.
  final List<List<Offset>> routes;

  /// Lo dibujado a mano encima (bocetos).
  final List<AnnotationDocument> drawings;

  const PlanThumbnail({
    super.key,
    required this.elements,
    this.inherited = const [],
    this.emptyIcon = Icons.grid_on_outlined,
    this.focus,
    this.zones = const [],
    this.inheritedOpacity = 0.55,
    this.routes = const [],
    this.drawings = const [],
  });

  /// Margen alrededor de los elementos, en unidades del lienzo.
  static const double _margin = 90;

  /// Tamaño de la hoja de dibujo a mano, en unidades del lienzo (el del
  /// editor).
  static const drawingSheet = Size(1600, 1200);

  /// Lo que ocupan los trazos y notas de [drawings] en el lienzo.
  static Rect? drawingBounds(List<AnnotationDocument> drawings) {
    Rect? bounds;
    void include(Rect rect) =>
        bounds = bounds == null ? rect : bounds!.expandToInclude(rect);
    for (final drawing in drawings) {
      for (final stroke in drawing.strokes) {
        for (final p in stroke.points) {
          include(
            Rect.fromCircle(
              center: Offset(
                p.x * drawingSheet.width,
                p.y * drawingSheet.height,
              ),
              radius: 1,
            ),
          );
        }
      }
      for (final note in drawing.notes) {
        include(
          Rect.fromLTWH(
            note.x * drawingSheet.width,
            note.y * drawingSheet.height,
            note.width * drawingSheet.width,
            note.height * drawingSheet.height,
          ),
        );
      }
    }
    return bounds;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final all = [...inherited, ...elements];

    final drawn = drawingBounds(drawings);

    if (all.isEmpty && zones.isEmpty && drawn == null) {
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
                : zones.isNotEmpty
                ? zones.first.rect
                : drawn!);
        for (final el in focus == null ? all : const <PlanElement>[]) {
          bounds = bounds.expandToInclude(
            Rect.fromCircle(center: el.position, radius: 1),
          );
          if (PlanSegment.isSegment(el)) {
            bounds = bounds.expandToInclude(
              Rect.fromCircle(center: PlanSegment.end(el), radius: 1),
            );
          }
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
        // Lo dibujado a mano entra siempre en el encuadre, aunque se salga
        // de la zona del set.
        if (drawn != null) bounds = bounds.expandToInclude(drawn);
        bounds = bounds.inflate(focus == null ? _margin : 30);
        final scale = math.min(
          1.0,
          math.min(size.width / bounds.width, size.height / bounds.height),
        );
        final offset = size.center(Offset.zero) - bounds.center * scale;

        final plan = CustomPaint(
          size: size,
          foregroundPainter: routes.isEmpty
              ? null
              : _RoutePainter(
                  routes: routes,
                  scale: scale,
                  offset: offset,
                  color: palette.accent,
                ),
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
        );
        if (drawn == null) return ClipRect(child: plan);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              plan,
              for (final drawing in drawings)
                CustomPaint(
                  size: size,
                  painter: AnnotationPainter(
                    document: drawing,
                    viewport: AnnotationViewport(
                      documentSize: drawingSheet,
                      offset: offset,
                      scale: scale,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// El recorrido de un plano secuencia sobre el plano maestro.
class _RoutePainter extends CustomPainter {
  final List<List<Offset>> routes;
  final double scale;
  final Offset offset;
  final Color color;

  const _RoutePainter({
    required this.routes,
    required this.scale,
    required this.offset,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    final fill = Paint()..color = color;
    for (final route in routes) {
      final points = [for (final p in route) offset + p * scale];
      for (var i = 0; i < points.length - 1; i++) {
        final a = points[i];
        final b = points[i + 1];
        final span = b - a;
        if (span.distance < 4) continue;
        final dir = span / span.distance;
        final normal = Offset(-dir.dy, dir.dx);
        // Sin llegar al centro de la zona, para que se vea la punta.
        final tip = b - dir * 10;
        canvas.drawLine(a + dir * 10, tip, line);
        canvas.drawPath(
          Path()
            ..moveTo(tip.dx + dir.dx * 8, tip.dy + dir.dy * 8)
            ..lineTo(tip.dx + normal.dx * 5, tip.dy + normal.dy * 5)
            ..lineTo(tip.dx - normal.dx * 5, tip.dy - normal.dy * 5)
            ..close(),
          fill,
        );
      }
      for (final (i, p) in points.indexed) {
        canvas.drawCircle(p, 8, fill);
        final tp = TextPainter(
          text: TextSpan(
            text: '${i + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
      }
    }
  }

  @override
  bool shouldRepaint(_RoutePainter old) =>
      old.routes != routes || old.scale != scale || old.offset != offset;
}
