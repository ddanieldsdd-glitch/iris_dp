import 'dart:convert';
import 'dart:math' as math;

/// Una opción de ratio de contraste clave:relleno.
class ContrastRatioOption {
  /// 4 = «4:1».
  final double ratio;

  /// Para qué se suele usar.
  final String use;

  const ContrastRatioOption(this.ratio, this.use);

  String get label =>
      '${ratio % 1 == 0 ? ratio.toStringAsFixed(0) : ratio.toString().replaceAll('.', ',')}:1';

  /// Diferencia entre clave y relleno, en stops.
  double get stops => math.log(ratio) / math.ln2;

  String get stopsLabel {
    final s = stops;
    if (s == 0) return 'sin diferencia';
    final text = s % 1 == 0
        ? s.toStringAsFixed(0)
        : s.toStringAsFixed(1).replaceAll('.', ',');
    return '$text ${s == 1 ? 'stop' : 'stops'}';
  }
}

/// Todas las opciones de ratio que ofrece la biblia, de plano a silueta.
const kContrastRatios = <ContrastRatioOption>[
  ContrastRatioOption(1, 'Plano'),
  ContrastRatioOption(1.5, 'Suave'),
  ContrastRatioOption(2, 'Natural'),
  ContrastRatioOption(3, 'Modelado'),
  ContrastRatioOption(4, 'Marcado'),
  ContrastRatioOption(6, 'Dramático'),
  ContrastRatioOption(8, 'Clave baja'),
  ContrastRatioOption(16, 'Noir'),
  ContrastRatioOption(32, 'Casi silueta'),
  ContrastRatioOption(64, 'Silueta'),
];

/// Una temperatura de color con nombre, para situarse en la escala.
class KelvinLandmark {
  final int kelvin;
  final String name;
  const KelvinLandmark(this.kelvin, this.name);
}

const kKelvinLandmarks = <KelvinLandmark>[
  KelvinLandmark(1900, 'Vela'),
  KelvinLandmark(2100, 'Sodio'),
  KelvinLandmark(2700, 'Bombilla'),
  KelvinLandmark(3200, 'Tungsteno'),
  KelvinLandmark(4000, 'Fluorescente'),
  KelvinLandmark(5600, 'Luz día'),
  KelvinLandmark(6500, 'Nublado'),
  KelvinLandmark(8000, 'Sombra'),
  KelvinLandmark(10000, 'Cielo azul'),
];

/// Fuentes de las que se suele partir para llegar a un color.
const kLightSources = <KelvinLandmark>[
  KelvinLandmark(3200, 'Tungsteno'),
  KelvinLandmark(5600, 'HMI / luz día'),
  KelvinLandmark(4000, 'Fluorescente'),
  KelvinLandmark(2100, 'Sodio de calle'),
];

/// Una gelatina de corrección: nombre, cuánto mueve el color (en mired) y
/// cuánta luz deja pasar.
class CorrectionGel {
  final String name;
  final double miredShift;
  final double transmission;
  const CorrectionGel(this.name, this.miredShift, this.transmission);
}

/// Lo que hace falta para llevar una fuente a un color.
class ColorRecipe {
  final int sourceKelvin;
  final int targetKelvin;

  /// Mired que hay que mover (positivo = calentar).
  final double miredShift;
  final List<CorrectionGel> gels;

  /// Temperatura que se consigue con esas gelatinas.
  final int resultKelvin;

  /// Luz que se pierde, en stops.
  final double stopsLost;

  /// Corrección de verde o magenta, o nulo si no hace falta.
  final String? tintGel;

  const ColorRecipe({
    required this.sourceKelvin,
    required this.targetKelvin,
    required this.miredShift,
    required this.gels,
    required this.resultKelvin,
    required this.stopsLost,
    this.tintGel,
  });

  bool get needsNothing => gels.isEmpty && tintGel == null;
}

/// Métricas de luz de la biblia: temperatura, tinte y contraste. Vale para
/// el proyecto entero, para una idea de luz o para una localización.
///
/// Todo es opcional: lo que no se ha decidido es nulo, no un valor de
/// partida.
class LightingMetrics {
  /// Temperatura de color buscada, en kelvin.
  final int? kelvin;

  /// Tinte en unidades CC: positivo hacia verde, negativo hacia magenta.
  final double? tint;

  /// Ratio clave:relleno (4 = 4:1).
  final double? ratio;

  /// Temperatura de la fuente de la que se parte.
  final int? sourceKelvin;

  const LightingMetrics({this.kelvin, this.tint, this.ratio, this.sourceKelvin});

  static const minKelvin = 1800;
  static const maxKelvin = 10000;
  static const maxTint = 30.0;

  bool get isEmpty => kelvin == null && tint == null && ratio == null;

  LightingMetrics copyWith({
    int? kelvin,
    double? tint,
    double? ratio,
    int? sourceKelvin,
  }) => LightingMetrics(
    kelvin: kelvin ?? this.kelvin,
    tint: tint ?? this.tint,
    ratio: ratio ?? this.ratio,
    sourceKelvin: sourceKelvin ?? this.sourceKelvin,
  );

  Map<String, dynamic> toJson() => {
    if (kelvin != null) 'kelvin': kelvin,
    if (tint != null) 'tint': tint,
    if (ratio != null) 'ratio': ratio,
    if (sourceKelvin != null) 'source': sourceKelvin,
  };

  factory LightingMetrics.fromJson(Object? raw) {
    var value = raw;
    if (value is String && value.trim().isNotEmpty) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return const LightingMetrics();
      }
    }
    if (value is! Map) return const LightingMetrics();
    return LightingMetrics(
      kelvin: (value['kelvin'] as num?)?.round(),
      tint: (value['tint'] as num?)?.toDouble(),
      ratio: (value['ratio'] as num?)?.toDouble(),
      sourceKelvin: (value['source'] as num?)?.round(),
    );
  }

  String encode() => jsonEncode(toJson());

  /// Lo que la pantalla antigua guardaba suelto. Solo cuenta lo que el
  /// usuario llegó a tocar: sin clave no hay dato.
  factory LightingMetrics.fromLegacy(Map<String, dynamic> data) {
    final legacyTint = data['tintValue'];
    final contrast = data['contrastNum'];
    return LightingMetrics(
      kelvin:
          (data['colorTemp'] as num?)?.round() ??
          (data['targetKelvin'] as num?)?.round(),
      // Iba de −0,5 a 0,5; aquí, de −30 a 30.
      tint: legacyTint is num && legacyTint != 0 ? legacyTint * 60.0 : null,
      ratio: contrast is num ? contrast.toDouble() : null,
      sourceKelvin: (data['sourceKelvin'] as num?)?.round(),
    );
  }

  ContrastRatioOption? get ratioOption {
    final r = ratio;
    if (r == null) return null;
    return kContrastRatios.reduce(
      (a, b) => (b.ratio - r).abs() < (a.ratio - r).abs() ? b : a,
    );
  }

  String get tintLabel {
    final t = tint ?? 0;
    if (t.abs() < 0.5) return 'Neutro';
    return '${t.abs().round()} ${t > 0 ? 'verde' : 'magenta'}';
  }

  /// Color aproximado (0xRRGGBB) de una temperatura, con su tinte.
  static int colorOf(int kelvin, {double tint = 0}) {
    final t = kelvin.clamp(1000, 40000) / 100.0;
    double r, g, b;
    if (t <= 66) {
      r = 255;
      g = 99.4708025861 * math.log(t) - 161.1195681661;
      b = t <= 19 ? 0 : 138.5177312231 * math.log(t - 10) - 305.0447927307;
    } else {
      r = 329.698727446 * math.pow(t - 60, -0.1332047592);
      g = 288.1221695283 * math.pow(t - 60, -0.0755148492);
      b = 255;
    }
    // El tinte mueve el verde frente a rojo y azul.
    final shift = (tint / maxTint).clamp(-1.0, 1.0) * 0.22;
    g *= 1 + shift;
    r *= 1 - shift * 0.5;
    b *= 1 - shift * 0.5;
    int c(double v) => v.clamp(0, 255).round();
    return (c(r) << 16) | (c(g) << 8) | c(b);
  }

  int? get color => kelvin == null ? null : colorOf(kelvin!, tint: tint ?? 0);

  /// Cómo se ve esta luz con la cámara balanceada a [whiteBalance].
  String? lookAgainst(int? whiteBalance) {
    final k = kelvin;
    if (k == null || whiteBalance == null) return null;
    final diff = k - whiteBalance;
    if (diff.abs() < 150) return 'Neutra con la cámara a $whiteBalance K';
    final amount = diff.abs() > 1500
        ? 'muy '
        : diff.abs() > 600
        ? ''
        : 'algo ';
    // Una luz más fría que el balance se ve azulada; más cálida, anaranjada.
    return 'Con la cámara a $whiteBalance K se verá $amount'
        '${diff > 0 ? 'fría' : 'cálida'} '
        '(${diff > 0 ? '+' : '−'}${diff.abs()} K)';
  }

  /// Qué gelatinas llevan [sourceKelvin] a la temperatura buscada, entre
  /// [gels]. Prueba una gelatina sola y parejas, y se queda con lo que más
  /// se acerca; a igualdad, lo que menos luz quita.
  ColorRecipe? recipe(List<CorrectionGel> gels) {
    final target = kelvin;
    final source = sourceKelvin;
    if (target == null || source == null) return null;
    final needed = 1e6 / target - 1e6 / source;
    final tintGel = _tintGel(tint ?? 0);

    var best = const <CorrectionGel>[];
    var bestError = needed.abs();
    // Menos de 10 mired no se nota: no hace falta gelatina.
    if (needed.abs() >= 10) {
      final sameWay = [
        for (final g in gels)
          if (g.miredShift.sign == needed.sign) g,
      ];
      final candidates = <List<CorrectionGel>>[
        for (final g in sameWay) [g],
        for (var i = 0; i < sameWay.length; i++)
          for (var j = i; j < sameWay.length; j++) [sameWay[i], sameWay[j]],
      ];
      for (final combo in candidates) {
        final shift = combo.fold<double>(0, (a, g) => a + g.miredShift);
        final error = (shift - needed).abs();
        final better =
            error < bestError - 2 ||
            ((error - bestError).abs() <= 2 &&
                best.isNotEmpty &&
                _transmission(combo) > _transmission(best));
        if (better) {
          best = combo;
          bestError = error;
        }
      }
    }
    final shift = best.fold<double>(0, (a, g) => a + g.miredShift);
    final mired = 1e6 / source + shift;
    final transmission = _transmission(best);
    return ColorRecipe(
      sourceKelvin: source,
      targetKelvin: target,
      miredShift: needed,
      gels: best,
      resultKelvin: (1e6 / mired).round(),
      stopsLost: transmission >= 1
          ? 0
          : -math.log(transmission) / math.ln2,
      tintGel: tintGel,
    );
  }

  static double _transmission(List<CorrectionGel> gels) =>
      gels.fold<double>(1, (a, g) => a * g.transmission);

  /// Plusgreen y Minusgreen completos corrigen unas 30 unidades CC.
  static String? _tintGel(double tint) {
    final amount = tint.abs();
    if (amount < 3) return null;
    final fraction = amount >= 24
        ? ''
        : amount >= 12
        ? '½ '
        : amount >= 6
        ? '¼ '
        : '⅛ ';
    return '$fraction${tint > 0 ? 'Plusgreen' : 'Minusgreen'}';
  }
}
