import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light/exposure.dart';
import 'light/light_scene.dart';
import 'light/meter.dart';
import 'light/plan_light.dart';
import 'light_beam.dart';
import 'light_symbols.dart';
import 'light/modifiers.dart';
import 'light/surfaces.dart';
import 'plan_opening.dart';
import 'plan_segment.dart';

/// Colores del lienzo: fondo oscuro, como en un plató a oscuras, para que
/// los haces de luz se lean.
class _CanvasColors {
  static const background = Color(0xFF0C0C0F);
  static const grid = Color(0xFF1E1E24);
  static const ink = Color(0xFFE4E4EA);
  static const inkSecondary = Color(0xFFA9A9B4);
  static const inkTertiary = Color(0xFF74747F);
  static const accent = Color(0xFF4DA3FF);
  static const body = Color(0xFF1A1A20);
}

/// Zona de un set sobre el plano maestro de la localización.
class PlanZone {
  final Rect rect;
  final Color color;
  final String label;

  /// La del set que se está viendo.
  final bool active;

  const PlanZone({
    required this.rect,
    required this.color,
    required this.label,
    this.active = false,
  });
}

class CameraPlanPainter extends CustomPainter {
  final List<PlanElement> elements;

  /// Capas de fondo: se ven atenuadas.
  final List<PlanElement> inheritedElements;
  final double inheritedOpacity;
  final bool showGrid;

  /// Zonas de los sets sobre el plano maestro.
  final List<PlanZone> zones;

  /// Otros elementos seleccionados a la vez (selección múltiple).
  final Set<PlanElement> alsoSelected;

  /// Tramo que se está dibujando.
  final ({Offset from, Offset to, String kind})? segmentPreview;

  /// Medida en curso.
  final ({Offset from, Offset to})? measure;

  /// Zona con asas en las esquinas, mientras se ajusta.
  final Rect? zoneHandles;

  /// Ajustes de cámara con los que se lee la luz en diafragmas. `null` =
  /// sin lecturas: ni fotómetros, ni actores, ni mapa.
  final ExposureSettings? exposure;

  /// Diafragma de trabajo, para decir cuánto sobra o falta.
  final double targetStop;

  /// Enseña bajo cada actor el diafragma que le llega.
  final bool showReadings;

  /// Mapa de exposición en falso color, en lugar de los haces.
  final bool exposureMap;

  /// Metros por unidad del lienzo; con él se rotulan longitudes y se pinta
  /// la barra de escala. `null` = sin rótulos de medida.
  final double? metersPerUnit;
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
    this.inheritedElements = const [],
    this.inheritedOpacity = 0.55,
    this.showGrid = true,
    this.zones = const [],
    this.alsoSelected = const {},
    this.segmentPreview,
    this.measure,
    this.zoneHandles,
    this.metersPerUnit,
    this.exposure,
    this.targetStop = CameraExposure.defaultStop,
    this.showReadings = false,
    this.exposureMap = false,
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
    if (showGrid) _drawGrid(canvas, size);
    for (final zone in zones) {
      _drawZone(canvas, zone);
    }

    if (inheritedElements.isNotEmpty) {
      canvas.saveLayer(
        null,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: inheritedOpacity),
      );
      for (final el in _paintOrder(inheritedElements)) {
        _drawElement(canvas, el);
      }
      canvas.restore();
    }

    // La planta vista por la luz: aparatos, rebotes, telas y paredes de
    // todas las capas, con lo que las tapa.
    final scene = LightScene.from([
      ...inheritedElements,
      ...elements,
    ], metersPerUnit: metersPerUnit ?? defaultMetersPerUnit);
    _scene = scene;
    final dimmed = {...inheritedElements};
    if (exposureMap && exposure != null) {
      _drawExposureMap(canvas, size, scene);
    }
    // Los haces van debajo de todo lo demás. Con el mapa de exposición no
    // se pintan: el mapa ya dice cuánta luz hay en cada sitio.
    for (final light in exposureMap ? const <SceneLight>[] : scene.lights) {
      _drawBeam(
        canvas,
        scene,
        light,
        strength: dimmed.contains(light.fixture?.element)
            ? inheritedOpacity
            : 1,
      );
    }

    for (final el in elements.where((e) => e.type == ElementType.camera)) {
      final isSelected = el.id == selectedElement?.id;
      _drawCameraPath(
        canvas,
        el,
        highlightPathIndex: isSelected ? selectedPathIndex : null,
        showHandles: isSelected,
      );
    }

    final ordered = _paintOrder(elements);
    for (final el in ordered) {
      _drawElement(
        canvas,
        el,
        selected: el.id == selectedElement?.id,
        ringed: alsoSelected.contains(el),
      );
    }

    _drawOverlays(canvas);
    canvas.restore();

    if (metersPerUnit != null) _drawScaleBar(canvas, size);
    if (exposureMap && exposure != null) _drawExposureLegend(canvas, size);
  }

  /// La planta vista por la luz, calculada una vez por pintado.
  LightScene? _scene;

  /// Lectura de fotómetro en un punto, con los ajustes de la cámara.
  MeterReading? _readingAt(Offset point) {
    final scene = _scene;
    final settings = exposure;
    if (scene == null || settings == null) return null;
    return MeterReading.at(
      scene,
      point,
      exposure: settings,
      targetStop: targetStop,
    );
  }

  /// Mapa de exposición: cada celda, del color de los stops que le sobran
  /// o le faltan respecto al diafragma de trabajo.
  void _drawExposureMap(Canvas canvas, Size size, LightScene scene) {
    final settings = exposure!;
    const cellPx = 26.0;
    final cell = cellPx / scale;
    final left = -offset.dx / scale;
    final top = -offset.dy / scale;
    final cols = (size.width / cellPx).ceil();
    final rows = (size.height / cellPx).ceil();
    final paint = Paint();
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final rect = Rect.fromLTWH(
          left + col * cell,
          top + row * cell,
          cell,
          cell,
        );
        final lux = scene.luxAt(rect.center);
        if (lux < 0.5) continue;
        final stops = stopsBetweenApertures(settings.stopFor(lux), targetStop);
        paint.color = exposureColor(stops).withValues(alpha: 0.55);
        canvas.drawRect(rect, paint);
      }
    }
  }

  void _drawExposureLegend(Canvas canvas, Size size) {
    const steps = [-4.0, -3.0, -2.0, -1.0, 0.0, 1.0, 2.0, 3.0, 4.0];
    const w = 26.0;
    final origin = Offset(size.width - steps.length * w - 16, size.height - 46);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx - 8, origin.dy - 20, steps.length * w + 16, 58),
        const Radius.circular(8),
      ),
      Paint()..color = _CanvasColors.background.withValues(alpha: 0.85),
    );
    void text(String value, Offset at, {bool bold = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(
            color: _CanvasColors.inkSecondary,
            fontSize: 10,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at);
    }

    text(
      'Stops respecto a ${formatStop(targetStop)}',
      origin + const Offset(0, -16),
      bold: true,
    );
    for (var i = 0; i < steps.length; i++) {
      canvas.drawRect(
        Rect.fromLTWH(origin.dx + i * w, origin.dy, w - 1.5, 10),
        Paint()..color = exposureColor(steps[i]),
      );
      text(
        steps[i] == 0 ? '0' : formatStopDifference(steps[i]),
        origin + Offset(i * w + 4, 14),
      );
    }
  }

  /// Calles y relieve debajo, luego las paredes y encima todo lo demás:
  /// así una puerta o una ventana puede abrir su hueco en la pared.
  static List<PlanElement> _paintOrder(List<PlanElement> elements) {
    bool isWall(PlanElement e) =>
        PlanSegment.isSegment(e) && PlanSegment.kind(e) == PlanSegment.kindWall;
    return [
      ...elements.where((e) => PlanSegment.isSegment(e) && !isWall(e)),
      ...elements.where(isWall),
      ...elements.where((e) => !PlanSegment.isSegment(e)),
    ];
  }

  /// Tramo en curso, medida y asas de la zona.
  void _drawOverlays(Canvas canvas) {
    final preview = segmentPreview;
    if (preview != null) {
      final ghost = PlanSegment.create(
        start: preview.from,
        end: preview.to,
        kind: preview.kind,
      );
      canvas.saveLayer(null, Paint()..color = const Color(0x99FFFFFF));
      _drawSegment(canvas, ghost, selected: false);
      canvas.restore();
      _drawLengthLabel(
        canvas,
        (preview.from + preview.to) / 2,
        (preview.to - preview.from).distance,
      );
    }

    final m = measure;
    if (m != null) {
      final paint = Paint()
        ..color = _CanvasColors.accent
        ..strokeWidth = 1.5 / scale;
      canvas.drawLine(m.from, m.to, paint);
      for (final p in [m.from, m.to]) {
        canvas.drawCircle(p, 4 / scale, Paint()..color = _CanvasColors.accent);
      }
      _drawLengthLabel(
        canvas,
        (m.from + m.to) / 2,
        (m.to - m.from).distance,
        color: _CanvasColors.accent,
      );
    }

    final zone = zoneHandles;
    if (zone != null) {
      for (final corner in [
        zone.topLeft,
        zone.topRight,
        zone.bottomRight,
        zone.bottomLeft,
      ]) {
        canvas.drawCircle(corner, 7 / scale, Paint()..color = Colors.white);
        canvas.drawCircle(
          corner,
          7 / scale,
          Paint()
            ..color = _CanvasColors.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2 / scale,
        );
      }
    }
  }

  void _drawLengthLabel(
    Canvas canvas,
    Offset at,
    double units, {
    Color color = _CanvasColors.ink,
  }) {
    final mpu = metersPerUnit;
    if (mpu == null || units < 1) return;
    final tp = TextPainter(
      text: TextSpan(
        text: formatMeters(units, mpu),
        style: TextStyle(
          color: color,
          fontSize: 12 / scale,
          fontWeight: FontWeight.w600,
          backgroundColor: _CanvasColors.background.withValues(alpha: 0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at + Offset(-tp.width / 2, -tp.height - 6 / scale));
  }

  /// Barra de escala, abajo a la izquierda, con una longitud redonda.
  void _drawScaleBar(Canvas canvas, Size size) {
    final mpu = metersPerUnit!;
    const candidates = [0.5, 1.0, 2.0, 5.0, 10.0, 20.0, 50.0, 100.0];
    var meters = candidates.last;
    for (final c in candidates) {
      if (c / mpu * scale >= 70) {
        meters = c;
        break;
      }
    }
    final width = meters / mpu * scale;
    final origin = Offset(16, size.height - 18);
    final paint = Paint()
      ..color = _CanvasColors.inkSecondary
      ..strokeWidth = 1.5;
    canvas.drawLine(origin, origin + Offset(width, 0), paint);
    canvas.drawLine(origin + const Offset(0, -5), origin, paint);
    canvas.drawLine(
      origin + Offset(width, -5),
      origin + Offset(width, 0),
      paint,
    );
    final label = meters < 1
        ? '${(meters * 100).round()} cm'
        : '${meters.round()} m';
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: _CanvasColors.inkSecondary, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, origin + const Offset(4, -18));
  }

  /// Pared, calle o relieve dibujados punto a punto.
  void _drawSegment(Canvas canvas, PlanElement el, {required bool selected}) {
    final path = PlanSegment.path(el);
    switch (PlanSegment.kind(el)) {
      case PlanSegment.kindStreet:
        canvas.drawPath(
          path,
          Paint()
            ..color = const Color(0xFF3A3A44)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 64
            ..strokeCap = StrokeCap.butt,
        );
        _drawDashedPath(
          canvas,
          path,
          Paint()
            ..color = _CanvasColors.inkTertiary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      case PlanSegment.kindRelief:
        _drawDashedPath(
          canvas,
          path,
          Paint()
            ..color = const Color(0xFFB08968)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      default:
        canvas.drawPath(
          path,
          Paint()
            ..color = _CanvasColors.ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 6
            ..strokeCap = StrokeCap.round,
        );
    }

    if (!selected) return;
    canvas.drawPath(
      path,
      Paint()
        ..color = _CanvasColors.accent.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 / scale,
    );
    void handle(Offset at, {bool hollow = false}) {
      canvas.drawCircle(
        at,
        6 / scale,
        Paint()
          ..color = hollow ? _CanvasColors.background : _CanvasColors.accent,
      );
      canvas.drawCircle(
        at,
        6 / scale,
        Paint()
          ..color = hollow ? _CanvasColors.accent : Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 / scale,
      );
    }

    handle(PlanSegment.start(el));
    handle(PlanSegment.end(el));
    handle(PlanSegment.midpoint(el), hollow: true);
    _drawLengthLabel(canvas, PlanSegment.midpoint(el), PlanSegment.length(el));
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

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: backgroundOpacity);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      rect,
      paint,
    );
  }

  /// Rejilla que cubre siempre la parte visible, se desplace lo que se
  /// desplace el lienzo.
  void _drawGrid(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _CanvasColors.grid
      ..strokeWidth = 0.5 / scale;
    const step = 40.0;
    final left = -offset.dx / scale;
    final top = -offset.dy / scale;
    final right = left + size.width / scale;
    final bottom = top + size.height / scale;

    for (var x = (left / step).floor() * step; x <= right; x += step) {
      canvas.drawLine(Offset(x, top), Offset(x, bottom), paint);
    }
    for (var y = (top / step).floor() * step; y <= bottom; y += step) {
      canvas.drawLine(Offset(left, y), Offset(right, y), paint);
    }
  }

  void _drawZone(Canvas canvas, PlanZone zone) {
    final fill = Paint()
      ..color = zone.color.withValues(alpha: zone.active ? 0.10 : 0.05);
    canvas.drawRect(zone.rect, fill);
    final stroke = Paint()
      ..color = zone.color.withValues(alpha: zone.active ? 1 : 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = (zone.active ? 2.5 : 1.5) / scale;
    _drawDashedPath(canvas, Path()..addRect(zone.rect), stroke);

    final tp = TextPainter(
      text: TextSpan(
        text: zone.label,
        style: TextStyle(
          color: zone.color,
          fontSize: 13 / scale,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, zone.rect.topLeft + Offset(6 / scale, 4 / scale));
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

  void _drawElement(
    Canvas canvas,
    PlanElement el, {
    bool selected = false,
    bool ringed = false,
  }) {
    if (PlanSegment.isSegment(el)) {
      _drawSegment(canvas, el, selected: selected || ringed);
      return;
    }
    if (ringed && !selected) {
      canvas.drawCircle(
        el.position,
        30,
        Paint()
          ..color = _CanvasColors.accent.withValues(alpha: 0.6)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
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
        if (PlanOpening.isOpening(el)) {
          _drawOpening(canvas, el);
        } else {
          _drawArchitecture(canvas, el);
        }
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

    canvas.restore();

    // Los rótulos no giran con el elemento: siempre se leen del derecho.
    canvas.save();
    canvas.translate(el.position.dx, el.position.dy);
    switch (el.type) {
      case ElementType.camera:
        final camColor = cameraColorForLetter(el.cameraLetter);
        final labelText =
            '${el.cameraLabel}\n${el.stabilization ?? ''} ${el.lens ?? ''}'
                .trim();
        if (labelText.isNotEmpty) {
          _drawLabelBelow(canvas, labelText, camColor, yOffset: 28);
        }
      case ElementType.light:
        _drawLightLabel(canvas, el);
      case ElementType.actor:
        // Con lecturas, el actor enseña el diafragma que le llega.
        final reading = showReadings ? _readingAt(el.position) : null;
        final name = el.label?.isNotEmpty == true ? el.displayLabel : null;
        final text = [
          ?name,
          if (reading != null && reading.lux > 0.5)
            '${formatStop(reading.stop)} '
                '(${formatStopDifference(reading.stopsOverTarget)})',
        ].join('\n');
        if (text.isNotEmpty) {
          _drawLabelBelow(
            canvas,
            text,
            _CanvasColors.inkSecondary,
            maxWidth: 110,
          );
        }
      case ElementType.prop:
        if (el.propType == PropType.meter) {
          final reading = _readingAt(el.position);
          _drawLabelBelow(
            canvas,
            reading == null
                ? 'Fotómetro'
                : reading.lux < 0.05
                ? 'sin luz'
                : '${reading.shortLabel}\n'
                      '${formatStopDifference(reading.stopsOverTarget)} stops',
            _CanvasColors.accent,
            yOffset: 16,
            maxWidth: 130,
          );
        } else if (el.label != null && el.label!.isNotEmpty) {
          _drawLabelBelow(canvas, el.displayLabel, _CanvasColors.inkSecondary);
        }
      case ElementType.wall:
        // Puertas y ventanas se entienden solas: sin rótulo.
        if (PlanOpening.isOpening(el)) break;
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
    final base =
        (el.props['name'] as String?) ?? el.lightType?.label ?? el.label;
    if (base == null || base.isEmpty) return;
    final beam = LightBeam.of(el);
    final light = PlanLight.of(el);
    final filters = light == null
        ? ''
        : light.modifiers.map((m) => m.name).join(' + ');
    final name = beam == null || light == null
        ? base
        : beam.off
        ? '$base\napagada'
        : [
            base,
            if (filters.isNotEmpty) filters,
            '${(light.source.cct / 50).round() * 50}K · '
                '${beam.intensity.round()}%',
          ].join('\n');
    _drawLabelBelow(
      canvas,
      name,
      _CanvasColors.inkSecondary,
      yOffset: 20,
      maxWidth: 110,
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
    canvas.drawCircle(handleOffset, 7, Paint()..color = color);
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
    // Cono de visión según la focal y el sensor.
    final fov =
        cameraFovDegrees(
          el.lens,
          sensorWidthMm:
              (el.props['sensorWidthMm'] as num?)?.toDouble() ?? 24.89,
        ) ??
        40;
    final half = fov.clamp(4, 170) * math.pi / 360;
    const reach = 260.0;
    final left = Offset(-math.sin(half) * reach, -math.cos(half) * reach);
    final right = Offset(math.sin(half) * reach, -math.cos(half) * reach);
    final cone = Path()
      ..moveTo(0, 0)
      ..lineTo(left.dx, left.dy)
      ..arcToPoint(right, radius: const Radius.circular(reach))
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = ui.Gradient.radial(Offset.zero, reach, [
          camColor.withValues(alpha: 0.16),
          camColor.withValues(alpha: 0),
        ]),
    );
    final fovPaint = Paint()
      ..color = camColor.withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    _drawDashedPath(
      canvas,
      Path()
        ..moveTo(0, 0)
        ..lineTo(left.dx, left.dy),
      fovPaint,
    );
    _drawDashedPath(
      canvas,
      Path()
        ..moveTo(0, 0)
        ..lineTo(right.dx, right.dy),
      fovPaint,
    );

    canvas.drawCircle(Offset.zero, 16, Paint()..color = _CanvasColors.body);
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
    canvas.drawPath(body, Paint()..color = camColor.withValues(alpha: 0.9));

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

  /// Lux por debajo de los cuales el haz deja de dibujarse.
  static const double _beamFloorLux = 20;

  /// Haz de una fuente, calculado: llega hasta donde la luz baja de
  /// [_beamFloorLux], se apaga con el cuadrado de la distancia y se corta en
  /// lo que encuentra. Vale igual para un aparato que para lo que devuelve
  /// un rebote, una tela o una pared.
  void _drawBeam(
    Canvas canvas,
    LightScene scene,
    SceneLight light, {
    double strength = 1,
  }) {
    final source = light.source;
    if (source.candela <= 0) return;
    final mpu = scene.metersPerUnit;
    final reachM = source.distanceFor(_beamFloorLux).clamp(0.0, 60.0);
    if (reachM < 0.15) return;
    final reach = reachM / mpu;
    final color = LightBeam.colorForCct(source.cct);

    // Brillo según los stops que quedan por encima del suelo del haz.
    double alphaAt(double fraction) {
      final lux = source.illuminance(math.max(reachM * fraction, 0.05));
      final stops =
          math.log(math.max(lux, _beamFloorLux) / _beamFloorLux) / math.ln2;
      return math.pow((stops / 16).clamp(0.0, 1.0), 1.7).toDouble() *
          0.5 *
          strength;
    }

    const fractions = [0.0, 0.05, 0.12, 0.25, 0.5, 1.0];
    Paint glow(double amount) => Paint()
      ..blendMode = BlendMode.plus
      ..shader = ui.Gradient.radial(Offset.zero, reach, [
        for (final f in fractions) color.withValues(alpha: alphaAt(f) * amount),
      ], fractions);

    canvas.save();
    // Las paredes, las personas y el grip cortan el haz; las ventanas y las
    // puertas abiertas lo dejan pasar.
    if (scene.blockers.isNotEmpty) {
      canvas.clipPath(
        scene.visibleArea(light.position, reach, ignore: light.surface),
      );
    }
    canvas.translate(light.position.dx, light.position.dy);
    canvas.rotate(math.atan2(light.aim.dx, -light.aim.dy));

    Path wedge(double degrees) {
      final sweep = math.min(degrees, 340) * math.pi / 180;
      return Path()
        ..moveTo(0, 0)
        ..arcTo(
          Rect.fromCircle(center: Offset.zero, radius: reach),
          -math.pi / 2 - sweep / 2,
          sweep,
          false,
        )
        ..close();
    }

    if (light.frontOnly) {
      // Una superficie devuelve la luz por todo su frente, más en su eje.
      canvas.drawPath(wedge(178), glow(0.35));
      canvas.drawPath(wedge(math.min(source.beamDeg, 178)), glow(0.65));
    } else if (source.isOmni) {
      canvas.drawCircle(Offset.zero, reach, glow(1));
    } else {
      // El haz, hasta donde queda la mitad de la luz, y el derrame, más
      // ancho y más tenue.
      canvas.drawPath(wedge(source.beamDeg * 1.7), glow(0.3));
      canvas.drawPath(wedge(source.beamDeg), glow(0.7));
    }
    canvas.restore();
  }

  /// Puerta, ventana o abertura: abre su hueco en la pared y dibuja lo que
  /// hay en él. Se pinta en coordenadas del elemento (ya trasladado y
  /// girado): la pared va a lo largo del eje x.
  void _drawOpening(Canvas canvas, PlanElement el) {
    final half = PlanOpening.width(el) / 2;
    // El hueco: se borra la pared que haya debajo.
    canvas.drawRect(
      Rect.fromLTRB(-half, -5, half, 5),
      Paint()..color = _CanvasColors.background,
    );
    final jamb = Paint()
      ..color = _CanvasColors.ink
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-half, -5), Offset(-half, 5), jamb);
    canvas.drawLine(Offset(half, -5), Offset(half, 5), jamb);

    if (PlanOpening.isWindow(el)) {
      final glass = Rect.fromLTRB(-half, -3, half, 3);
      canvas.drawRect(
        glass,
        Paint()..color = const Color(0xFF7EC8F0).withValues(alpha: 0.35),
      );
      canvas.drawRect(
        glass,
        Paint()
          ..color = _CanvasColors.ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      // Cortina o difusión puesta en la ventana.
      if ((el.props[PlanLight.modifiersKey] as List? ?? const []).isNotEmpty) {
        _drawDashedPath(
          canvas,
          Path()
            ..moveTo(-half, 8)
            ..lineTo(half, 8),
          Paint()
            ..color = Colors.white.withValues(alpha: 0.8)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      return;
    }

    if (PlanOpening.isDoor(el)) {
      // Las hojas están en coordenadas del plano: se pasan a las de la
      // puerta deshaciendo su giro.
      final rad = -el.rotation * math.pi / 180;
      Offset local(Offset world) {
        final d = world - el.position;
        return Offset(
          d.dx * math.cos(rad) - d.dy * math.sin(rad),
          d.dx * math.sin(rad) + d.dy * math.cos(rad),
        );
      }

      final leaf = Paint()
        ..color = _CanvasColors.ink
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final swing = Paint()
        ..color = _CanvasColors.inkTertiary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      for (final (hinge, tip) in PlanOpening.leaves(el)) {
        final h = local(hinge);
        final t = local(tip);
        canvas.drawLine(h, t, leaf);
        // Recorrido de la hoja, del cierre a donde está.
        final length = (t - h).distance;
        final closed = Offset(h.dx < 0 ? h.dx + length : h.dx - length, 0);
        if ((closed - t).distance > 2) {
          final from = math.atan2(closed.dy - h.dy, closed.dx - h.dx);
          var sweep = math.atan2(t.dy - h.dy, t.dx - h.dx) - from;
          if (sweep > math.pi) sweep -= 2 * math.pi;
          if (sweep < -math.pi) sweep += 2 * math.pi;
          _drawDashedPath(
            canvas,
            Path()
              ..addArc(Rect.fromCircle(center: h, radius: length), from, sweep),
            swing,
          );
        }
      }
      return;
    }

    if (el.architectureType == ArchitectureType.prisonBars) {
      for (var x = -half + 6; x < half; x += 8) {
        canvas.drawLine(
          Offset(x, -6),
          Offset(x, 6),
          Paint()
            ..color = _CanvasColors.inkSecondary
            ..strokeWidth = 2,
        );
      }
    }
  }

  /// Negro, cortador, rebote, tela, red o gelatina: una barra con su largo
  /// real, a lo largo del eje x del elemento.
  void _drawGrip(Canvas canvas, PlanElement el) {
    final half = LightScene.lengthOf(el) / 2;
    final a = Offset(-half, 0);
    final b = Offset(half, 0);
    Paint line(Color color, double width) => Paint()
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.stroke;

    switch (el.lightType) {
      case LightType.flag || LightType.cutter:
        final width = el.lightType == LightType.flag ? 7.0 : 4.0;
        canvas.drawLine(a, b, line(_CanvasColors.inkSecondary, width + 2));
        canvas.drawLine(a, b, line(const Color(0xFF050506), width));
      case LightType.bounce:
        final material = SurfaceMaterial.byId(
          el.props[LightScene.materialKey] as String?,
          kBounceMaterials,
        );
        final tint = LightBeam.colorForCct(
          1e6 / (1e6 / 5600 + material.miredShift),
        );
        canvas.drawLine(a, b, line(tint, 6));
        canvas.drawLine(
          a + const Offset(0, 4),
          b + const Offset(0, 4),
          line(_CanvasColors.inkTertiary, 2),
        );
      case LightType.diffusionFrame:
        canvas.drawLine(a, b, line(Colors.white.withValues(alpha: 0.55), 7));
        for (var x = -half + 4; x < half; x += 7) {
          canvas.drawLine(
            Offset(x - 2, 4),
            Offset(x + 2, -4),
            line(_CanvasColors.background.withValues(alpha: 0.7), 1),
          );
        }
      case LightType.net:
        _drawDashedPath(
          canvas,
          Path()
            ..moveTo(a.dx, 0)
            ..lineTo(b.dx, 0),
          line(_CanvasColors.inkSecondary, 5),
        );
      case LightType.gel:
        final gel = LightModifier.byId(
          ((el.props[PlanLight.modifiersKey] as List?)?.firstOrNull)
              ?.toString(),
        );
        final warm = (gel?.miredShift ?? 81) >= 0;
        canvas.drawLine(
          a,
          b,
          line(
            (warm ? const Color(0xFFFF9E3D) : const Color(0xFF5AA9FF))
                .withValues(alpha: 0.75),
            6,
          ),
        );
      default:
        break;
    }
    // Los pies del marco.
    for (final end in [a, b]) {
      canvas.drawCircle(end, 3, Paint()..color = _CanvasColors.inkSecondary);
    }
  }

  /// ¿Se dibuja como una barra de grip con su largo real?
  static bool _isGripBar(PlanElement el) => switch (el.lightType) {
    LightType.flag ||
    LightType.cutter ||
    LightType.bounce ||
    LightType.diffusionFrame ||
    LightType.net ||
    LightType.gel => true,
    _ => false,
  };

  void _drawLight(Canvas canvas, PlanElement el) {
    if (_isGripBar(el)) {
      _drawGrip(canvas, el);
      return;
    }
    final beam = LightBeam.of(el);
    final lit = beam != null && !beam.off;
    final stroke = lit
        ? Color.lerp(LightSymbolColors.darkStroke, beam.color, 0.35)!
        : beam != null
        ? _CanvasColors.inkTertiary
        : LightSymbolColors.darkStroke;
    if (el.lightType != null) {
      LightSymbols.draw(
        canvas,
        el.lightType!,
        stroke: stroke,
        fill: LightSymbolColors.darkFill,
      );
    } else {
      canvas.drawCircle(
        Offset.zero,
        12,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = LightSymbolColors.strokeWidth,
      );
      canvas.drawCircle(
        Offset.zero,
        6,
        Paint()..color = LightSymbolColors.darkFill,
      );
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
        canvas.drawRect(
          const Rect.fromLTWH(-20, -8, 12, 16),
          paint..style = PaintingStyle.fill,
        );
      case PropType.meter:
        // Fotómetro: la semiesfera blanca sobre su cuerpo.
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-5, -2, 10, 14),
            const Radius.circular(3),
          ),
          Paint()..color = _CanvasColors.body,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(-5, -2, 10, 14),
            const Radius.circular(3),
          ),
          paint..color = _CanvasColors.accent,
        );
        canvas.drawCircle(
          const Offset(0, -5),
          6,
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(
          const Offset(0, -5),
          6,
          Paint()
            ..color = _CanvasColors.accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      case PropType.tree:
        canvas.drawCircle(
          Offset.zero,
          22,
          Paint()..color = const Color(0xFF2E7D32).withValues(alpha: 0.35),
        );
        canvas.drawCircle(
          Offset.zero,
          22,
          paint..color = const Color(0xFF66BB6A),
        );
        canvas.drawCircle(
          Offset.zero,
          3,
          Paint()..color = const Color(0xFF8D6E63),
        );
      case PropType.rock:
        final rock = Path()
          ..moveTo(-16, 6)
          ..lineTo(-8, -10)
          ..lineTo(6, -12)
          ..lineTo(16, 0)
          ..lineTo(10, 10)
          ..lineTo(-10, 12)
          ..close();
        canvas.drawPath(
          rock,
          Paint()..color = const Color(0xFF6B6B76).withValues(alpha: 0.5),
        );
        canvas.drawPath(rock, paint);
      case PropType.vehicle:
        final body = RRect.fromRectAndRadius(
          const Rect.fromLTWH(-18, -38, 36, 76),
          const Radius.circular(8),
        );
        canvas.drawRRect(body, paint);
        canvas.drawRect(const Rect.fromLTWH(-14, -20, 28, 12), paint);
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
        canvas.drawLine(
          const Offset(0, -8),
          const Offset(0, 8),
          wallPaint..strokeWidth = 1,
        );
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
        canvas.drawLine(
          const Offset(-20, 0),
          const Offset(-20, -20),
          wallPaint..strokeWidth = 2,
        );
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
      old.inheritedElements != inheritedElements ||
      old.inheritedOpacity != inheritedOpacity ||
      old.showGrid != showGrid ||
      old.zones != zones ||
      old.alsoSelected != alsoSelected ||
      old.segmentPreview != segmentPreview ||
      old.measure != measure ||
      old.zoneHandles != zoneHandles ||
      old.metersPerUnit != metersPerUnit ||
      old.exposure != exposure ||
      old.targetStop != targetStop ||
      old.showReadings != showReadings ||
      old.exposureMap != exposureMap ||
      old.selectedElement?.id != selectedElement?.id ||
      old.selectedPathIndex != selectedPathIndex ||
      old.scale != scale ||
      old.offset != offset ||
      old.palette != palette ||
      old.backgroundImage != backgroundImage ||
      old.backgroundRect != backgroundRect ||
      old.backgroundOpacity != backgroundOpacity;
}
