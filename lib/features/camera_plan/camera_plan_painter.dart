import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light_symbols.dart';

/// Colores optimizados para renderizar sobre fondo blanco del canvas.
class _CanvasColors {
  static const background = Colors.white;
  static const grid = Color(0xFFE0E0E0);
  static const ink = Color(0xFF1A1A1A);
  static const inkSecondary = Color(0xFF555555);
  static const inkTertiary = Color(0xFF888888);
  static const accent = Color(0xFF007AFF);
}

class CameraPlanPainter extends CustomPainter {
  final List<PlanElement> elements;
  final PlanElement? selectedElement;
  final int? selectedPathIndex;
  final double scale;
  final Offset offset;
  final AppPalette palette;
  final ui.Image? backgroundImage;
  final Rect? backgroundRect;
  final double backgroundOpacity;

  CameraPlanPainter({
    required this.elements,
    required this.palette,
    this.selectedElement,
    this.selectedPathIndex,
    this.scale = 1.0,
    this.offset = Offset.zero,
    this.backgroundImage,
    this.backgroundRect,
    this.backgroundOpacity = 0.85,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawCanvasBackground(canvas, size);

    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    canvas.scale(scale);

    _drawBackgroundImage(canvas);
    _drawGrid(canvas, size);

    for (final el in elements.where((e) => e.type == ElementType.camera)) {
      final isSelected = el.id == selectedElement?.id;
      _drawCameraPath(
        canvas,
        el,
        highlightPathIndex: isSelected ? selectedPathIndex : null,
        showHandles: isSelected,
      );
    }

    for (final el in elements) {
      _drawElement(canvas, el, selected: el.id == selectedElement?.id);
    }

    canvas.restore();
  }

  void _drawCanvasBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = _CanvasColors.background,
    );
  }

  void _drawBackgroundImage(Canvas canvas) {
    final image = backgroundImage;
    final rect = backgroundRect;
    if (image == null || rect == null) return;

    final paint = Paint()..color = Colors.white.withValues(alpha: backgroundOpacity);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      paint,
    );
  }

  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _CanvasColors.grid
      ..strokeWidth = 0.5;
    const step = 40.0;
    final adjustedSize = Size(size.width / scale, size.height / scale);

    for (double x = 0; x < adjustedSize.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, adjustedSize.height), paint);
    }
    for (double y = 0; y < adjustedSize.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(adjustedSize.width, y), paint);
    }
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint) {
    const dashLength = 6.0;
    const gapLength = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = math.min(distance + dashLength, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashLength + gapLength;
      }
    }
  }

  static const pathPointHitRadius = 14.0;

  /// Índice del punto de trayectoria bajo [canvasPos], o null.
  static int? pathPointAt(
    PlanElement camera,
    Offset canvasPos, {
    double scale = 1,
  }) {
    if (camera.type != ElementType.camera || camera.pathPoints.isEmpty) {
      return null;
    }
    final r = pathPointHitRadius / scale;
    for (var i = camera.pathPoints.length - 1; i >= 0; i--) {
      if ((camera.pathPoints[i] - canvasPos).distance <= r) return i;
    }
    return null;
  }

  void _drawCameraPath(
    Canvas canvas,
    PlanElement camera, {
    int? highlightPathIndex,
    bool showHandles = false,
  }) {
    if (camera.pathPoints.isEmpty && !showHandles) return;

    final camColor = cameraColorForLetter(camera.cameraLetter);
    final pathPaint = Paint()
      ..color = camColor.withValues(alpha: 0.65)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (camera.pathPoints.isNotEmpty) {
      final allPoints = [camera.position, ...camera.pathPoints];
      final path = Path()..moveTo(allPoints[0].dx, allPoints[0].dy);
      for (final p in allPoints.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      _drawDashedPath(canvas, path, pathPaint);

      for (int i = 0; i < allPoints.length - 1; i++) {
        final a = allPoints[i];
        final b = allPoints[i + 1];
        final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
        final angle = math.atan2(b.dy - a.dy, b.dx - a.dx);
        _drawArrowHead(canvas, mid, angle, pathPaint);
      }
    }

    if (showHandles || camera.pathPoints.isNotEmpty) {
      _drawPathWaypoint(
        canvas,
        camera.position,
        label: '1',
        color: camColor,
        highlighted: false,
      );
    }

    for (int i = 0; i < camera.pathPoints.length; i++) {
      _drawPathWaypoint(
        canvas,
        camera.pathPoints[i],
        label: '${i + 2}',
        color: camColor,
        highlighted: highlightPathIndex == i,
      );
    }
  }

  void _drawPathWaypoint(
    Canvas canvas,
    Offset pt, {
    required String label,
    required Color color,
    required bool highlighted,
  }) {
    if (highlighted) {
      canvas.drawCircle(
        pt,
        12,
        Paint()
          ..color = _CanvasColors.accent.withValues(alpha: 0.35)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        pt,
        12,
        Paint()
          ..color = _CanvasColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.drawCircle(pt, 8, Paint()..color = color);
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pt.translate(-tp.width / 2, -tp.height / 2));
  }

  void _drawArrowHead(Canvas canvas, Offset tip, double angle, Paint paint) {
    const size = 7.0;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - size * math.cos(angle - 0.45),
        tip.dy - size * math.sin(angle - 0.45),
      )
      ..lineTo(
        tip.dx - size * math.cos(angle + 0.45),
        tip.dy - size * math.sin(angle + 0.45),
      )
      ..close();
    canvas.drawPath(path, paint..style = PaintingStyle.fill);
  }

  void _drawElement(Canvas canvas, PlanElement el, {bool selected = false}) {
    canvas.save();
    canvas.translate(el.position.dx, el.position.dy);
    canvas.rotate(el.rotation * math.pi / 180);

    switch (el.type) {
      case ElementType.camera:
        _drawCamera(canvas, el);
      case ElementType.actor:
        _drawActor(canvas, el);
      case ElementType.light:
        _drawLight(canvas, el);
      case ElementType.prop:
        _drawProp(canvas, el);
      case ElementType.wall:
        _drawArchitecture(canvas, el);
    }

    if (selected) {
      final handleColor = el.type == ElementType.camera
          ? cameraColorForLetter(el.cameraLetter)
          : _CanvasColors.accent;
      canvas.drawCircle(
        Offset.zero,
        30,
        Paint()
          ..color = handleColor.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      _drawRotationHandle(canvas, handleColor);
    }

    switch (el.type) {
      case ElementType.camera:
        final camColor = cameraColorForLetter(el.cameraLetter);
        final labelText =
            '${el.cameraLabel}\n${el.stabilization ?? ''} ${el.lens ?? ''}'.trim();
        if (labelText.isNotEmpty) {
          _drawLabelBelow(canvas, labelText, camColor, yOffset: 28);
        }
      case ElementType.light:
        _drawLightLabel(canvas, el);
      case ElementType.actor:
      case ElementType.prop:
      case ElementType.wall:
        if (el.label != null && el.label!.isNotEmpty) {
          _drawLabelBelow(canvas, el.displayLabel, _CanvasColors.inkSecondary);
        }
    }

    canvas.restore();
  }

  void _drawLabelBelow(
    Canvas canvas,
    String text,
    Color color, {
    double yOffset = 22,
    double maxWidth = 90,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, Offset(-tp.width / 2, yOffset));
  }

  void _drawLightLabel(Canvas canvas, PlanElement el) {
    final name = el.lightType?.label ?? el.label;
    if (name == null || name.isEmpty) return;
    _drawLabelBelow(
      canvas,
      name,
      LightSymbolColors.stroke,
      yOffset: 20,
      maxWidth: 72,
    );
  }

  void _drawRotationHandle(Canvas canvas, Color color) {
    const handleOffset = Offset(0, -36);
    canvas.drawLine(
      Offset.zero,
      handleOffset,
      Paint()
        ..color = color.withValues(alpha: 0.5)
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      handleOffset,
      7,
      Paint()..color = color,
    );
    canvas.drawCircle(
      handleOffset,
      7,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _drawCamera(Canvas canvas, PlanElement el) {
    final camColor = cameraColorForLetter(el.cameraLetter);
    final fovPaint = Paint()
      ..color = camColor.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawLine(const Offset(0, -14), const Offset(-28, -48), fovPaint);
    canvas.drawLine(const Offset(0, -14), const Offset(28, -48), fovPaint);

    canvas.drawCircle(
      Offset.zero,
      16,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      Offset.zero,
      16,
      Paint()
        ..color = camColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final body = Path()
      ..moveTo(0, -10)
      ..lineTo(-7, 6)
      ..lineTo(7, 6)
      ..close();
    canvas.drawPath(
      body,
      Paint()..color = camColor.withValues(alpha: 0.9),
    );

    final tp = TextPainter(
      text: TextSpan(
        text: el.cameraLetter,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
  }

  void _drawActor(Canvas canvas, PlanElement el) {
    final paint = Paint()..color = el.actorColor;
    canvas.drawCircle(Offset.zero, 16, paint);
    canvas.drawCircle(
      Offset.zero,
      16,
      Paint()
        ..color = _CanvasColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.drawLine(
      const Offset(0, -14),
      const Offset(0, 14),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.9)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    if (el.label != null && el.label!.isNotEmpty) {
      final initial = el.label![0].toUpperCase();
      final tp = TextPainter(
        text: TextSpan(
          text: initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
    }
  }

  void _drawLight(Canvas canvas, PlanElement el) {
    if (el.lightType != null) {
      LightSymbols.draw(canvas, el.lightType!);
    } else {
      canvas.drawCircle(
        Offset.zero,
        12,
        Paint()
          ..color = LightSymbolColors.stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = LightSymbolColors.strokeWidth,
      );
      canvas.drawCircle(Offset.zero, 6, Paint()..color = LightSymbolColors.fill);
    }
    if (el.lukaCompatible) {
      final badge = TextPainter(
        text: const TextSpan(
          text: 'LUKA',
          style: TextStyle(
            color: Color(0xFF007AFF),
            fontSize: 7,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      badge.paint(canvas, Offset(-badge.width / 2, 14));
    }
  }

  void _drawProp(Canvas canvas, PlanElement el) {
    final paint = Paint()
      ..color = _CanvasColors.inkSecondary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    switch (el.propType) {
      case PropType.table:
        canvas.drawRect(const Rect.fromLTWH(-16, -10, 32, 20), paint);
        for (final x in [-12.0, 12.0]) {
          canvas.drawLine(Offset(x, 10), Offset(x, 16), paint);
        }
      case PropType.chair:
        canvas.drawRect(const Rect.fromLTWH(-10, -2, 20, 14), paint);
        canvas.drawRect(const Rect.fromLTWH(-10, -14, 20, 12), paint);
      case PropType.sofa:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-18, -8, 36, 16),
            const Radius.circular(4),
          ),
          paint,
        );
        canvas.drawLine(const Offset(-18, -8), const Offset(-18, -14), paint);
        canvas.drawLine(const Offset(18, -8), const Offset(18, -14), paint);
      case PropType.bed:
        canvas.drawRect(const Rect.fromLTWH(-20, -8, 40, 16), paint);
        canvas.drawRect(const Rect.fromLTWH(-20, -8, 12, 16), paint..style = PaintingStyle.fill);
      case PropType.rectangle:
      case null:
        canvas.drawRect(const Rect.fromLTWH(-12, -12, 24, 24), paint);
    }
  }

  void _drawArchitecture(Canvas canvas, PlanElement el) {
    final wallPaint = Paint()
      ..color = _CanvasColors.ink
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    switch (el.architectureType) {
      case ArchitectureType.wall:
        canvas.drawLine(const Offset(-30, 0), const Offset(30, 0), wallPaint);
      case ArchitectureType.window:
        canvas.drawLine(const Offset(-30, 0), const Offset(30, 0), wallPaint);
        canvas.drawRect(
          const Rect.fromLTWH(-14, -8, 28, 16),
          Paint()
            ..color = const Color(0xFF87CEEB).withValues(alpha: 0.5)
            ..style = PaintingStyle.fill,
        );
        canvas.drawRect(
          const Rect.fromLTWH(-14, -8, 28, 16),
          Paint()
            ..color = _CanvasColors.inkSecondary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
        canvas.drawLine(const Offset(0, -8), const Offset(0, 8), wallPaint..strokeWidth = 1);
      case ArchitectureType.doorOpen:
        canvas.drawLine(const Offset(-30, 0), const Offset(30, 0), wallPaint);
        canvas.drawArc(
          const Rect.fromLTWH(-20, -20, 40, 40),
          math.pi,
          math.pi / 2,
          false,
          Paint()
            ..color = _CanvasColors.inkSecondary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        canvas.drawLine(const Offset(-20, 0), const Offset(-20, -20), wallPaint..strokeWidth = 2);
      case ArchitectureType.doorClosed:
        canvas.drawLine(const Offset(-30, 0), const Offset(30, 0), wallPaint);
        canvas.drawRect(
          const Rect.fromLTWH(-10, -18, 20, 18),
          Paint()
            ..color = const Color(0xFFD4A574)
            ..style = PaintingStyle.fill,
        );
        canvas.drawRect(
          const Rect.fromLTWH(-10, -18, 20, 18),
          Paint()
            ..color = _CanvasColors.inkSecondary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1,
        );
      case ArchitectureType.doubleDoor:
        canvas.drawLine(const Offset(-30, 0), const Offset(30, 0), wallPaint);
        for (final left in [-18.0, 2.0]) {
          canvas.drawRect(
            Rect.fromLTWH(left, -18, 16, 18),
            Paint()
              ..color = const Color(0xFFD4A574)
              ..style = PaintingStyle.fill,
          );
          canvas.drawRect(
            Rect.fromLTWH(left, -18, 16, 18),
            Paint()
              ..color = _CanvasColors.inkSecondary
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1,
          );
        }
      case ArchitectureType.opening:
        canvas.drawLine(const Offset(-30, 0), const Offset(-10, 0), wallPaint);
        canvas.drawLine(const Offset(10, 0), const Offset(30, 0), wallPaint);
        canvas.drawLine(
          const Offset(-10, 0),
          const Offset(10, 0),
          Paint()
            ..color = _CanvasColors.inkTertiary
            ..strokeWidth = 1
            ..strokeCap = StrokeCap.round,
        );
      case ArchitectureType.prisonBars:
        canvas.drawLine(const Offset(-30, 0), const Offset(30, 0), wallPaint);
        for (var x = -24.0; x <= 24; x += 8) {
          canvas.drawLine(
            Offset(x, -14),
            Offset(x, 14),
            Paint()
              ..color = _CanvasColors.inkSecondary
              ..strokeWidth = 2,
          );
        }
      case null:
        canvas.drawLine(const Offset(-30, 0), const Offset(30, 0), wallPaint);
    }
  }

  /// Posición mundial del asa de rotación para un elemento.
  static Offset rotationHandleWorld(PlanElement el) {
    const handleLocal = Offset(0, -36);
    final rad = el.rotation * math.pi / 180;
    return el.position +
        Offset(
          handleLocal.dx * math.cos(rad) - handleLocal.dy * math.sin(rad),
          handleLocal.dx * math.sin(rad) + handleLocal.dy * math.cos(rad),
        );
  }

  @override
  bool shouldRepaint(CameraPlanPainter old) =>
      old.elements != elements ||
      old.selectedElement?.id != selectedElement?.id ||
      old.selectedPathIndex != selectedPathIndex ||
      old.scale != scale ||
      old.offset != offset ||
      old.palette != palette ||
      old.backgroundImage != backgroundImage ||
      old.backgroundRect != backgroundRect ||
      old.backgroundOpacity != backgroundOpacity;
}
