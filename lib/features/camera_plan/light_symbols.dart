import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'camera_plan_constants.dart';

/// Paleta de símbolos de luces — convención Shot Designer (verde oscuro + relleno claro).
class LightSymbolColors {
  static const stroke = Color(0xFF1B5E20);
  static const fill = Color(0xFFC8E6C9);
  static const strokeWidth = 1.8;
}

/// Dibuja un fixture cenital centrado en (0,0). Escala 1.0 ≈ icono en el mapa.
class LightSymbolPainter extends CustomPainter {
  final LightType type;
  final double scale;

  const LightSymbolPainter({required this.type, this.scale = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    LightSymbols.draw(canvas, type);
    canvas.restore();
  }

  @override
  bool shouldRepaint(LightSymbolPainter old) =>
      old.type != type || old.scale != scale;
}

class LightSymbols {
  LightSymbols._();

  static Paint _stroke([double width = LightSymbolColors.strokeWidth]) =>
      Paint()
        ..color = LightSymbolColors.stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

  static Paint _fill() => Paint()
    ..color = LightSymbolColors.fill
    ..style = PaintingStyle.fill;

  static void draw(Canvas canvas, LightType type) {
    switch (type) {
      case LightType.sun:
        _sun(canvas);
      case LightType.fresnelSmall:
        _fresnel(canvas, w: 10, h: 14, barn: 5);
      case LightType.fresnelMedium:
        _fresnel(canvas, w: 12, h: 18, barn: 6);
      case LightType.fresnelLarge:
        _fresnel(canvas, w: 16, h: 24, barn: 8);
      case LightType.flo4Tubes:
        _flo(canvas, tubes: 4, w: 28, h: 8);
      case LightType.flo2Tubes:
        _flo(canvas, tubes: 2, w: 22, h: 10);
      case LightType.floSingle:
        _floSingle(canvas);
      case LightType.lightPanel:
        _lightPanel(canvas);
      case LightType.led:
        _ledHex(canvas);
      case LightType.led1x1:
        _led1x1(canvas);
      case LightType.openFace:
        _openFace(canvas);
      case LightType.ellipsoidal:
        _ellipsoidal(canvas);
      case LightType.par:
        _par(canvas);
      case LightType.scoop:
        _scoop(canvas);
      case LightType.cyc:
        _cyc(canvas);
      case LightType.softbox:
        _softbox(canvas);
      case LightType.practical:
        _practical(canvas);
      case LightType.bounce:
        _bounce(canvas);
      case LightType.flag:
        _flag(canvas);
      case LightType.octagon:
        _octagon(canvas);
      case LightType.cutter:
        _cutter(canvas);
      case LightType.gel:
        _gel(canvas);
      case LightType.cStand:
        _cStand(canvas);
      case LightType.generator:
        _generator(canvas);
      case LightType.chimera:
        _chimera(canvas);
      case LightType.hmi:
        _hmi(canvas);
    }
  }

  static void _sun(Canvas canvas) {
    canvas.drawCircle(Offset.zero, 6, _fill());
    canvas.drawCircle(Offset.zero, 6, _stroke());
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      canvas.drawLine(
        Offset(math.cos(a) * 9, math.sin(a) * 9),
        Offset(math.cos(a) * 14, math.sin(a) * 14),
        _stroke(1.5),
      );
    }
  }

  static void _fresnel(Canvas canvas, {required double w, required double h, required double barn}) {
    final r = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    canvas.drawRect(r, _fill());
    canvas.drawRect(r, _stroke());
    canvas.drawLine(Offset(-w / 2 - barn, -h / 2), Offset(-w / 2, -h / 2), _stroke());
    canvas.drawLine(Offset(-w / 2 - barn, h / 2), Offset(-w / 2, h / 2), _stroke());
    canvas.drawLine(Offset(w / 2, -h / 2), Offset(w / 2 + barn, -h / 2), _stroke());
    canvas.drawLine(Offset(w / 2, h / 2), Offset(w / 2 + barn, h / 2), _stroke());
  }

  static void _flo(Canvas canvas, {required int tubes, required double w, required double h}) {
    final r = Rect.fromCenter(center: Offset.zero, width: w, height: h);
    canvas.drawRect(r, _fill());
    canvas.drawRect(r, _stroke());
    final gap = w / (tubes + 1);
    for (var i = 1; i <= tubes; i++) {
      final x = -w / 2 + gap * i;
      canvas.drawLine(Offset(x, -h / 2 + 1), Offset(x, h / 2 - 1), _stroke(1.2));
    }
    canvas.drawLine(Offset(-w / 2 - 4, -h / 2 + 2), Offset(-w / 2, -h / 2 + 2), _stroke());
    canvas.drawLine(Offset(-w / 2 - 4, h / 2 - 2), Offset(-w / 2, h / 2 - 2), _stroke());
  }

  static void _floSingle(Canvas canvas) {
    final r = Rect.fromCenter(center: Offset.zero, width: 26, height: 5);
    canvas.drawRect(r, _fill());
    canvas.drawRect(r, _stroke());
  }

  static void _lightPanel(Canvas canvas) {
    final r = Rect.fromCenter(center: Offset.zero, width: 22, height: 12);
    canvas.drawRect(r, _fill());
    canvas.drawRect(r, _stroke(2.5));
  }

  static void _ledHex(Canvas canvas) {
    final path = Path()
      ..moveTo(0, -12)
      ..lineTo(10, -6)
      ..lineTo(10, 6)
      ..lineTo(0, 12)
      ..lineTo(-10, 6)
      ..lineTo(-10, -6)
      ..close();
    canvas.drawPath(path, _fill());
    canvas.drawPath(path, _stroke());
    canvas.drawLine(const Offset(-10, 0), const Offset(10, 0), _stroke(1.2));
  }

  static void _led1x1(Canvas canvas) {
    final path = Path()
      ..moveTo(-8, -4)
      ..lineTo(8, -4)
      ..lineTo(12, 4)
      ..lineTo(-4, 4)
      ..close();
    canvas.drawPath(path, _fill());
    canvas.drawPath(path, _stroke());
    canvas.drawLine(const Offset(-8, -4), const Offset(-4, 4), _stroke(1.2));
    canvas.drawLine(const Offset(8, -4), const Offset(12, 4), _stroke(1.2));
  }

  static void _openFace(Canvas canvas) {
    final path = Path()
      ..moveTo(-10, 8)
      ..lineTo(-14, -2)
      ..lineTo(-6, -2)
      ..lineTo(-6, -8)
      ..lineTo(6, -8)
      ..lineTo(6, -2)
      ..lineTo(14, -2)
      ..lineTo(10, 8)
      ..close();
    canvas.drawPath(path, _fill());
    canvas.drawPath(path, _stroke());
  }

  static void _ellipsoidal(Canvas canvas) {
    final path = Path()
      ..moveTo(-16, 2)
      ..lineTo(-10, 2)
      ..quadraticBezierTo(-6, 2, -4, -4)
      ..quadraticBezierTo(0, -10, 6, -4)
      ..quadraticBezierTo(10, 0, 16, 4)
      ..lineTo(16, 8)
      ..lineTo(-16, 8)
      ..close();
    canvas.drawPath(path, _fill());
    canvas.drawPath(path, _stroke());
    canvas.drawRect(
      const Rect.fromLTWH(-16, 2, 6, 6),
      _stroke(1.2),
    );
  }

  static void _par(Canvas canvas) {
    final path = Path()
      ..moveTo(-8, -10)
      ..lineTo(8, -10)
      ..quadraticBezierTo(10, 0, 8, 10)
      ..lineTo(-8, 10)
      ..quadraticBezierTo(-10, 0, -8, -10)
      ..close();
    canvas.drawPath(path, _fill());
    canvas.drawPath(path, _stroke());
  }

  static void _scoop(Canvas canvas) {
    final path = Path()
      ..moveTo(-6, 10)
      ..lineTo(-14, -4)
      ..lineTo(14, -4)
      ..lineTo(6, 10)
      ..close();
    canvas.drawPath(path, _fill());
    canvas.drawPath(path, _stroke());
    canvas.drawLine(const Offset(-14, -4), const Offset(-18, -8), _stroke());
    canvas.drawLine(const Offset(14, -4), const Offset(18, -8), _stroke());
  }

  static void _cyc(Canvas canvas) {
    final path = Path()
      ..moveTo(-18, 6)
      ..quadraticBezierTo(-18, -8, 0, -10)
      ..quadraticBezierTo(18, -8, 18, 6)
      ..close();
    canvas.drawPath(path, _fill());
    canvas.drawPath(path, _stroke());
  }

  static void _softbox(Canvas canvas) {
    final path = Path()
      ..moveTo(-8, 12)
      ..quadraticBezierTo(-18, 0, -8, -14)
      ..quadraticBezierTo(0, -18, 8, -14)
      ..quadraticBezierTo(18, 0, 8, 12)
      ..close();
    canvas.drawPath(path, _fill());
    canvas.drawPath(path, _stroke());
  }

  static void _chimera(Canvas canvas) {
    final path = Path()
      ..moveTo(-6, 10)
      ..lineTo(-12, -2)
      ..lineTo(12, -2)
      ..lineTo(6, 10)
      ..close();
    canvas.drawPath(path, _fill());
    canvas.drawPath(path, _stroke());
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, -6), width: 8, height: 6),
      _stroke(1.2),
    );
  }

  static void _practical(Canvas canvas) {
    final shade = Path()
      ..moveTo(-8, -4)
      ..lineTo(8, -4)
      ..lineTo(6, -12)
      ..lineTo(-6, -12)
      ..close();
    canvas.drawPath(shade, _fill());
    canvas.drawPath(shade, _stroke());
    canvas.drawLine(const Offset(0, -4), const Offset(0, 4), _stroke());
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 6), width: 10, height: 4),
      _fill(),
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, 6), width: 10, height: 4),
      _stroke(),
    );
  }

  static void _bounce(Canvas canvas) {
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, 4), width: 18, height: 3),
      _fill(),
    );
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(0, 4), width: 18, height: 3),
      _stroke(),
    );
    canvas.drawLine(const Offset(0, 4), const Offset(0, -10), _stroke());
    canvas.drawLine(const Offset(-6, -10), const Offset(6, -10), _stroke());
    canvas.drawLine(const Offset(-6, -10), const Offset(-8, -14), _stroke());
    canvas.drawLine(const Offset(6, -10), const Offset(8, -14), _stroke());
  }

  static void _flag(Canvas canvas) {
    canvas.drawCircle(Offset.zero, 8, _fill());
    canvas.drawCircle(Offset.zero, 8, _stroke());
    canvas.drawLine(const Offset(0, 8), const Offset(0, 16), _stroke());
  }

  static void _octagon(Canvas canvas) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4;
      final p = Offset(math.cos(a) * 12, math.sin(a) * 12);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    path.close();
    canvas.drawPath(path, _fill());
    canvas.drawPath(path, _stroke());
    canvas.drawLine(const Offset(0, -12), const Offset(0, -18), _stroke());
  }

  static void _cutter(Canvas canvas) {
    final path = Path()
      ..moveTo(-20, 4)
      ..lineTo(20, 4)
      ..lineTo(14, -4)
      ..lineTo(-14, -4)
      ..close();
    canvas.drawPath(path, _fill());
    canvas.drawPath(path, _stroke());
  }

  static void _gel(Canvas canvas) {
    canvas.drawLine(const Offset(-14, 10), const Offset(14, -10), _stroke(2.5));
  }

  static void _cStand(Canvas canvas) {
    canvas.drawLine(const Offset(0, 14), const Offset(0, -6), _stroke());
    canvas.drawLine(const Offset(-8, 14), const Offset(8, 14), _stroke());
    canvas.drawCircle(const Offset(0, -8), 5, _fill());
    canvas.drawCircle(const Offset(0, -8), 5, _stroke());
  }

  static void _generator(Canvas canvas) {
    final r = Rect.fromCenter(center: Offset.zero, width: 18, height: 14);
    canvas.drawRect(r, _fill());
    canvas.drawRect(r, _stroke());
    canvas.drawLine(const Offset(-4, -3), const Offset(4, -3), _stroke(1.2));
    canvas.drawLine(const Offset(-4, 3), const Offset(4, 3), _stroke(1.2));
  }

  static void _hmi(Canvas canvas) {
    _sun(canvas);
    final r = Rect.fromCenter(center: const Offset(0, 14), width: 14, height: 8);
    canvas.drawRect(r, _fill());
    canvas.drawRect(r, _stroke());
  }
}

/// Vista previa del símbolo para grids del menú «Añadir».
class LightSymbolPreview extends StatelessWidget {
  final LightType type;
  final double size;

  const LightSymbolPreview({super.key, required this.type, this.size = 44});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: LightSymbolPainter(
          type: type,
          scale: size / 48,
        ),
      ),
    );
  }
}
