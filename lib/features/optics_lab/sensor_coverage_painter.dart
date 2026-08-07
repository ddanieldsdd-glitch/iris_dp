import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'optics_calculator.dart';
import 'sensor_mode_utils.dart';

/// Visualizador de cobertura sensor / círculo de imagen estilo ARRI FLT.
class SensorCoveragePainter extends CustomPainter {
  final OpticsResult result;
  final SensorModeContext? context;
  final String? sensorModeName;
  final double tStop;
  final bool showFovCone;

  SensorCoveragePainter({
    required this.result,
    this.context,
    this.sensorModeName,
    this.tStop = 2.8,
    this.showFovCone = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 24.0;
    final area = Rect.fromLTWH(pad, pad, size.width - pad * 2, size.height - pad * 2);

    final fullW = context?.fullWidthMm ?? result.fullSensorWidthMm ?? result.sensorWidthMm;
    final fullH = context?.fullHeightMm ?? result.fullSensorHeightMm ?? result.sensorHeightMm;
    final maxDim = math.max(fullW, fullH);
    final scale = math.min(area.width, area.height) / (maxDim * 1.35);

    final cx = area.center.dx;
    final cy = area.center.dy;

    final chipW = fullW * scale;
    final chipH = fullH * scale;
    final chipRect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: chipW,
      height: chipH,
    );

    final modeNorm = context?.modeRectOnChipNorm;
    final Rect modeRect;
    if (modeNorm != null) {
      modeRect = Rect.fromLTWH(
        chipRect.left + modeNorm.left * chipW,
        chipRect.top + modeNorm.top * chipH,
        modeNorm.width * chipW,
        modeNorm.height * chipH,
      );
    } else {
      modeRect = chipRect;
    }

    final gateW = result.activeWidthMm * scale;
    final gateH = result.activeHeightMm * scale;
    final gateRect = Rect.fromCenter(
      center: modeRect.center,
      width: gateW,
      height: gateH,
    );

    final circleR = (result.imageCircleMm / 2) * scale;

    canvas.drawRect(area, Paint()..color = const Color(0xFF1A1A1E));

    // Círculo de imagen
    canvas.drawCircle(
      Offset(cx, cy),
      circleR,
      Paint()
        ..color = const Color(0x224A90D9)
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      Offset(cx, cy),
      circleR,
      Paint()
        ..color = const Color(0xFF4A90D9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // Chip completo (open gate)
    canvas.drawRect(
      chipRect,
      Paint()
        ..color = const Color(0xFF252528)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      chipRect,
      Paint()
        ..color = const Color(0xFF888890)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Áreas inactivas del chip (crop visual)
    if (modeRect != chipRect) {
      _dimOutside(canvas, chipRect, modeRect);
    }

    // Modo activo
    canvas.drawRect(
      modeRect,
      Paint()
        ..color = const Color(0xFF2C2C30)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      modeRect,
      Paint()
        ..color = const Color(0xFF6E6E73)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Gate AR
    canvas.drawRect(
      gateRect,
      Paint()
        ..color = const Color(0x3300C853)
        ..style = PaintingStyle.fill,
    );
    canvas.drawRect(
      gateRect,
      Paint()
        ..color = const Color(0xFF00C853)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    if (result.portholingWarning) {
      canvas.drawRect(
        modeRect,
        Paint()
          ..color = const Color(0x44FF5252)
          ..style = PaintingStyle.fill,
      );
    } else if (!result.coversSensor) {
      canvas.drawRect(
        gateRect,
        Paint()
          ..color = const Color(0x44FF9800)
          ..style = PaintingStyle.fill,
      );
    }

    if (showFovCone) {
      final opticalCenter = Offset(cx, cy + modeRect.height * 0.28);
      final halfHfovRad = result.hFovDeg * math.pi / 180 / 2;
      final coneLen = circleR * 0.85;
      final leftAngle = -math.pi / 2 - halfHfovRad;
      final rightAngle = -math.pi / 2 + halfHfovRad;
      final conePaint = Paint()
        ..color = const Color(0x66FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      canvas.drawLine(
        opticalCenter,
        Offset(
          opticalCenter.dx + coneLen * math.cos(leftAngle),
          opticalCenter.dy + coneLen * math.sin(leftAngle),
        ),
        conePaint,
      );
      canvas.drawLine(
        opticalCenter,
        Offset(
          opticalCenter.dx + coneLen * math.cos(rightAngle),
          opticalCenter.dy + coneLen * math.sin(rightAngle),
        ),
        conePaint,
      );
      canvas.drawCircle(
        opticalCenter,
        3,
        Paint()..color = const Color(0xAAFFFFFF),
      );
    }

    final labelStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.85),
      fontSize: 10,
    );
    _drawLabel(canvas, 'Chip ${fullW.toStringAsFixed(1)}×${fullH.toStringAsFixed(1)} mm',
        chipRect.topLeft + const Offset(4, -14), labelStyle);
    _drawLabel(canvas, 'Modo activo', modeRect.topLeft + const Offset(4, -2), labelStyle);
    _drawLabel(canvas, 'Gate AR', gateRect.topRight + const Offset(-48, -14), labelStyle);
    _drawLabel(
      canvas,
      'Circle ${result.imageCircleMm.toStringAsFixed(1)} mm',
      Offset(cx - 55, cy + circleR + 6),
      labelStyle,
    );
    if (context != null) {
      _drawLabel(canvas, context!.cropLabel, const Offset(pad, pad - 4),
          labelStyle.copyWith(fontWeight: FontWeight.w600));
    } else if (sensorModeName != null) {
      _drawLabel(canvas, sensorModeName!, const Offset(pad, pad - 4),
          labelStyle.copyWith(fontWeight: FontWeight.w600));
    }
    if (result.recordingResolutionLabel != null) {
      _drawLabel(canvas, 'Rec. ${result.recordingResolutionLabel}', Offset(pad, area.bottom + 4),
          labelStyle);
    }
    _drawLabel(
      canvas,
      'HFOV ${result.hFovDeg.toStringAsFixed(1)}° · T${tStop.toStringAsFixed(1)} · '
          'CoC ${result.cocMm.toStringAsFixed(3)} mm',
      Offset(pad, area.bottom + (result.recordingResolutionLabel != null ? 16 : 4)),
      labelStyle,
    );
  }

  void _dimOutside(Canvas canvas, Rect outer, Rect inner) {
    final path = Path()
      ..addRect(outer)
      ..addRect(inner)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(path, Paint()..color = const Color(0xAA000000));
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, TextStyle style) {
    final builder = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    builder.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant SensorCoveragePainter oldDelegate) =>
      oldDelegate.result != result ||
      oldDelegate.context != context ||
      oldDelegate.sensorModeName != sensorModeName ||
      oldDelegate.tStop != tStop ||
      oldDelegate.showFovCone != showFovCone;
}
