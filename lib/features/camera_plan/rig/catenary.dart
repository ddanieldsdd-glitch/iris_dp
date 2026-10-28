import 'dart:math' as math;

/// Curva de una cuerda (o del borde de una tela) que cuelga entre dos
/// amarres: la catenaria real, no una parábola.
///
/// Se mide sobre la cuerda recta que une los amarres: [dropAt] da cuánto
/// queda por debajo de esa recta en cada punto. Con amarres a distinta
/// altura se suma la recta, que es una aproximación muy buena para las
/// flechas de una tela de rodaje (menos de un 10 % de la luz).
class Catenary {
  /// Luz entre amarres, en metros.
  final double span;

  /// Flecha en el centro, en metros.
  final double sag;

  /// Parámetro de la catenaria (`a` en `a·cosh(x/a)`), en metros. Muy
  /// grande cuando la cuerda va tensa.
  final double a;

  const Catenary._(this.span, this.sag, this.a);

  static const double _taut = 1e7;

  /// Catenaria de una luz y una flecha dadas.
  factory Catenary.fromSag(double span, double sag) {
    if (span <= 0 || sag <= 1e-4) return Catenary._(span, 0, _taut);
    var lo = 1e-3, hi = 1e6;
    for (var i = 0; i < 90; i++) {
      final m = math.sqrt(lo * hi);
      final v = m * (_cosh(math.min(700, span / (2 * m))) - 1);
      if (v > sag) {
        lo = m;
      } else {
        hi = m;
      }
    }
    return Catenary._(span, sag, math.sqrt(lo * hi));
  }

  /// Catenaria de una luz y un largo de cuerda dados. Una cuerda más corta
  /// que la luz se toma tensa.
  factory Catenary.fromRope(double span, double rope) {
    if (span <= 0 || rope <= span + 1e-4) return Catenary._(span, 0, _taut);
    var lo = 0.0, hi = span * 3;
    for (var i = 0; i < 60; i++) {
      final mid = (lo + hi) / 2;
      if (Catenary.fromSag(span, mid).rope > rope) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return Catenary.fromSag(span, (lo + hi) / 2);
  }

  bool get isTaut => a >= _taut / 10;

  /// Lo que baja la cuerda respecto a la recta entre amarres a `t` (0–1)
  /// de la luz. Negativo hacia abajo; `-sag` en el centro.
  double dropAt(double t) {
    if (isTaut) return 0;
    final x = t * span - span / 2;
    return a * (_cosh(x / a) - _cosh(span / (2 * a)));
  }

  /// Largo de la cuerda entre amarres.
  double get rope => isTaut ? span : 2 * a * _sinh(span / (2 * a));

  /// Tensión horizontal (la misma en toda la cuerda) para un peso por
  /// metro de luz, en las mismas unidades que el peso (kg → kgf).
  double horizontalTension(double weightPerMeter) =>
      isTaut ? double.infinity : weightPerMeter * a;

  /// Tiro en cada amarre para un peso por metro de luz.
  double anchorTension(double weightPerMeter) =>
      isTaut ? double.infinity : weightPerMeter * a * _cosh(span / (2 * a));

  static double _cosh(double x) => (math.exp(x) + math.exp(-x)) / 2;
  static double _sinh(double x) => (math.exp(x) - math.exp(-x)) / 2;
}
