import 'dart:math' as math;

import '../light_beam.dart';

/// Suma de luces de colores en un punto.
///
/// La luz se suma en lineal, no en los valores de pantalla: un rojo y un
/// azul dan magenta, y un rojo sobre mucha luz blanca da un rosa pálido.
class LightMix {
  double _r = 0, _g = 0, _b = 0;

  /// Suma [amount] de una luz: de su color [rgb] o, sin él, del de [kelvin].
  void add(double amount, double kelvin, int? rgb) {
    final key = rgb ?? -(kelvin / 50).round();
    final c = _linear[key] ??= _linearOf(kelvin, rgb);
    _r += amount * c.$1;
    _g += amount * c.$2;
    _b += amount * c.$3;
  }

  /// La mezcla como color 0xRRGGBB, a todo su brillo: cuánta luz hay ya lo
  /// dicen los lux. `null` si no se ha sumado nada.
  int? get rgb {
    final top = math.max(_r, math.max(_g, _b));
    if (top <= 0) return null;
    return (_encode(_r / top) << 16) |
        (_encode(_g / top) << 8) |
        _encode(_b / top);
  }

  /// Lo más que baja un aparato con un color saturado.
  static const double minOutput = 0.1;

  /// Parte de la luz del blanco que queda con el color [rgb], de 0 a 1:
  /// sale de lo que pesa cada canal para el ojo (Rec. 709). Un azul puro
  /// se queda en una décima parte, unos tres stops y pico por debajo.
  static double relativeOutput(int rgb) {
    final c = _linearOf(0, rgb);
    return (0.2126 * c.$1 + 0.7152 * c.$2 + 0.0722 * c.$3).clamp(
      minOutput,
      1.0,
    );
  }

  static final _linear = <int, (double, double, double)>{};

  static (double, double, double) _linearOf(double kelvin, int? rgb) {
    final c = LightBeam.colorOf(kelvin <= 0 ? 5600 : kelvin, rgb);
    return (_decode(c.r), _decode(c.g), _decode(c.b));
  }

  static double _decode(double v) => v <= 0.04045
      ? v / 12.92
      : math.pow((v + 0.055) / 1.055, 2.4).toDouble();

  static int _encode(double v) {
    final s = v <= 0.0031308
        ? v * 12.92
        : 1.055 * math.pow(v, 1 / 2.4) - 0.055;
    return (s * 255).round().clamp(0, 255);
  }
}
