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

/// Papel de una luz de color en la escena: decide desde dónde ilumina la
/// esfera de muestra.
enum LightColorRole {
  key('Clave'),
  fill('Relleno'),
  back('Contra'),
  ambient('Ambiente'),
  practical('Práctico');

  const LightColorRole(this.label);
  final String label;

  static LightColorRole parse(Object? name) =>
      values.firstWhere((r) => r.name == name, orElse: () => key);
}

/// Una luz de color de la escena (un interior de fiesta, un neón…).
class LightColor {
  final String name;

  /// 0xRRGGBB.
  final int rgb;
  final LightColorRole role;

  /// De 0 a 1.
  final double intensity;

  const LightColor({
    required this.rgb,
    this.name = '',
    this.role = LightColorRole.key,
    this.intensity = 1,
  });

  int get red => (rgb >> 16) & 0xFF;
  int get green => (rgb >> 8) & 0xFF;
  int get blue => rgb & 0xFF;

  String get hex => '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';

  /// Tono (0–360) y saturación (0–1): con la intensidad, es como se
  /// programa un LED en modo HSI.
  (double hue, double saturation) get hueSaturation {
    final r = red / 255, g = green / 255, b = blue / 255;
    final max = [r, g, b].reduce((a, c) => a > c ? a : c);
    final min = [r, g, b].reduce((a, c) => a < c ? a : c);
    final delta = max - min;
    if (delta == 0) return (0, 0);
    double hue;
    if (max == r) {
      hue = 60 * (((g - b) / delta) % 6);
    } else if (max == g) {
      hue = 60 * ((b - r) / delta + 2);
    } else {
      hue = 60 * ((r - g) / delta + 4);
    }
    return (hue < 0 ? hue + 360 : hue, max == 0 ? 0 : delta / max);
  }

  String get hsiLabel {
    final (hue, saturation) = hueSaturation;
    return 'H ${hue.round()}° · S ${(saturation * 100).round()} % · '
        'I ${(intensity * 100).round()} %';
  }

  String get rgbLabel => 'R $red · G $green · B $blue';

  /// Color pleno de un tono y una saturación.
  static int fromHueSaturation(double hue, double saturation) {
    final h = (hue % 360) / 60;
    final c = saturation.clamp(0.0, 1.0);
    final x = c * (1 - ((h % 2) - 1).abs());
    final (r, g, b) = switch (h.floor()) {
      0 => (c, x, 0.0),
      1 => (x, c, 0.0),
      2 => (0.0, c, x),
      3 => (0.0, x, c),
      4 => (x, 0.0, c),
      _ => (c, 0.0, x),
    };
    final m = 1 - c;
    int v(double n) => ((n + m) * 255).round().clamp(0, 255);
    return (v(r) << 16) | (v(g) << 8) | v(b);
  }

  static int? parseHex(String text) {
    final clean = text.trim().replaceFirst('#', '');
    if (clean.length != 6) return null;
    return int.tryParse(clean, radix: 16);
  }

  LightColor copyWith({
    String? name,
    int? rgb,
    LightColorRole? role,
    double? intensity,
  }) => LightColor(
    name: name ?? this.name,
    rgb: rgb ?? this.rgb,
    role: role ?? this.role,
    intensity: intensity ?? this.intensity,
  );

  Map<String, dynamic> toJson() => {
    'rgb': hex,
    if (name.isNotEmpty) 'name': name,
    'role': role.name,
    'intensity': intensity,
  };

  static List<LightColor> listFrom(Object? raw) => [
    if (raw is List)
      for (final e in raw)
        if (e is Map && parseHex(e['rgb']?.toString() ?? '') != null)
          LightColor(
            rgb: parseHex(e['rgb'].toString())!,
            name: e['name']?.toString() ?? '',
            role: LightColorRole.parse(e['role']),
            intensity: ((e['intensity'] as num?)?.toDouble() ?? 1).clamp(
              0.0,
              1.0,
            ),
          ),
  ];
}

/// Una fuente de luz blanca (CCT) de la escena: su papel, su temperatura,
/// su tinte, cuánto da respecto a la clave y cómo es.
class CctSource {
  final LightColorRole role;
  final int kelvin;

  /// Unidades CC: positivo hacia verde, negativo hacia magenta.
  final double tint;

  /// Stops respecto a la clave (0 = la clave; −2 = dos stops menos).
  final double stops;

  /// Suave (difusa) o dura.
  final bool soft;

  /// Qué es: «Farola de sodio», «Skypanel S60»…
  final String name;

  /// Temperatura de partida del aparato, para calcular la gelatina.
  final int? nativeKelvin;

  const CctSource({
    required this.kelvin,
    this.role = LightColorRole.key,
    this.tint = 0,
    this.stops = 0,
    this.soft = false,
    this.name = '',
    this.nativeKelvin,
  });

  int get rgb => LightingMetrics.colorOf(kelvin, tint: tint);

  /// Luz relativa a la clave (1 = la clave).
  double get level => math.pow(2, stops).toDouble();

  /// La misma fuente como luz de color, para la esfera de muestra.
  LightColor get asLightColor => LightColor(
    rgb: rgb,
    name: name,
    role: role,
    intensity: level.clamp(0.05, 1.0),
  );

  /// Gelatina para llegar a [kelvin] desde [nativeKelvin].
  ColorRecipe? recipe(List<CorrectionGel> gels) => nativeKelvin == null
      ? null
      : LightingMetrics(
          kelvin: kelvin,
          tint: tint,
          sourceKelvin: nativeKelvin,
        ).recipe(gels);

  CctSource copyWith({
    LightColorRole? role,
    int? kelvin,
    double? tint,
    double? stops,
    bool? soft,
    String? name,
    int? nativeKelvin,
  }) => CctSource(
    role: role ?? this.role,
    kelvin: kelvin ?? this.kelvin,
    tint: tint ?? this.tint,
    stops: stops ?? this.stops,
    soft: soft ?? this.soft,
    name: name ?? this.name,
    nativeKelvin: nativeKelvin ?? this.nativeKelvin,
  );

  Map<String, dynamic> toJson() => {
    'role': role.name,
    'kelvin': kelvin,
    if (tint != 0) 'tint': tint,
    if (stops != 0) 'stops': stops,
    if (soft) 'soft': true,
    if (name.isNotEmpty) 'name': name,
    if (nativeKelvin != null) 'native': nativeKelvin,
  };

  static List<CctSource> listFrom(Object? raw) => [
    if (raw is List)
      for (final e in raw)
        if (e is Map && e['kelvin'] is num)
          CctSource(
            role: LightColorRole.parse(e['role']),
            kelvin: (e['kelvin'] as num).round().clamp(1000, 20000),
            tint: (e['tint'] as num?)?.toDouble() ?? 0,
            stops: (e['stops'] as num?)?.toDouble() ?? 0,
            soft: e['soft'] == true,
            name: e['name']?.toString() ?? '',
            nativeKelvin: (e['native'] as num?)?.round(),
          ),
  ];
}

/// Escenas de partida: rellenan las fuentes de golpe.
class LightingPreset {
  final String name;
  final bool hsi;
  final List<CctSource> sources;
  final List<LightColor> colors;
  final double? ratio;

  const LightingPreset({
    required this.name,
    this.hsi = false,
    this.sources = const [],
    this.colors = const [],
    this.ratio,
  });

  LightingMetrics applyTo(LightingMetrics base) => hsi
      ? base.copyWith(colorMode: true, colors: colors, ratio: ratio)
      : base.withSources(sources).copyWith(colorMode: false, ratio: ratio);
}

const kLightingPresets = <LightingPreset>[
  LightingPreset(
    name: 'Noche de sodio',
    ratio: 8,
    sources: [
      CctSource(
        role: LightColorRole.key,
        kelvin: 2000,
        name: 'Farola de sodio',
      ),
      CctSource(
        role: LightColorRole.back,
        kelvin: 6500,
        stops: -2,
        name: 'Rebote frío',
      ),
    ],
  ),
  LightingPreset(
    name: 'Día nublado',
    ratio: 2,
    sources: [
      CctSource(
        role: LightColorRole.key,
        kelvin: 6500,
        soft: true,
        name: 'Cielo cubierto',
      ),
      CctSource(
        role: LightColorRole.fill,
        kelvin: 6500,
        stops: -1,
        soft: true,
        name: 'Rebote del suelo',
      ),
    ],
  ),
  LightingPreset(
    name: 'Fluorescente',
    ratio: 2,
    sources: [
      CctSource(
        role: LightColorRole.key,
        kelvin: 4000,
        tint: 12,
        soft: true,
        name: 'Tubos fluorescentes',
      ),
    ],
  ),
  LightingPreset(
    name: 'Interior tungsteno',
    ratio: 4,
    sources: [
      CctSource(
        role: LightColorRole.key,
        kelvin: 3200,
        name: 'Lámpara de mesa',
      ),
      CctSource(
        role: LightColorRole.fill,
        kelvin: 3200,
        stops: -2,
        soft: true,
        name: 'Rebote en pared',
      ),
      CctSource(
        role: LightColorRole.practical,
        kelvin: 2700,
        stops: -1,
        name: 'Prácticos',
      ),
    ],
  ),
  LightingPreset(
    name: 'Fiesta',
    hsi: true,
    ratio: 4,
    colors: [
      LightColor(rgb: 0xFF1FA2, name: 'Magenta', role: LightColorRole.key),
      LightColor(
        rgb: 0x19E3FF,
        name: 'Cian',
        role: LightColorRole.back,
        intensity: 0.7,
      ),
      LightColor(
        rgb: 0x8A2BFF,
        name: 'Violeta',
        role: LightColorRole.ambient,
        intensity: 0.4,
      ),
    ],
  ),
];

/// Colores de partida habituales en escenas de fiesta, club o neón.
const kPartyColors = <(String, int)>[
  ('Magenta', 0xFF1FA2),
  ('Rojo', 0xFF1E1E),
  ('Ámbar', 0xFF9A1F),
  ('Verde láser', 0x2BFF4E),
  ('Cian', 0x19E3FF),
  ('Azul profundo', 0x1F3BFF),
  ('Violeta', 0x8A2BFF),
];

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

  /// Luces de color de la escena. Con [colorMode], mandan sobre la
  /// temperatura: la escena se diseña con colores, no con kelvin.
  final List<LightColor> colors;
  final bool colorMode;

  /// Fuentes de luz blanca (CCT). La primera clave da [kelvin] y [tint].
  final List<CctSource> sources;

  const LightingMetrics({
    this.kelvin,
    this.tint,
    this.ratio,
    this.sourceKelvin,
    this.colors = const [],
    this.colorMode = false,
    this.sources = const [],
  });

  static const minKelvin = 1800;
  static const maxKelvin = 10000;
  static const maxTint = 30.0;

  bool get isEmpty =>
      kelvin == null &&
      tint == null &&
      ratio == null &&
      colors.isEmpty &&
      sources.isEmpty;

  /// Las fuentes CCT; sin ninguna puesta, la temperatura de siempre hace de
  /// clave (así no se pierde lo guardado antes de haber fuentes).
  List<CctSource> get cctSources => sources.isNotEmpty
      ? sources
      : [
          if (kelvin != null)
            CctSource(
              kelvin: kelvin!,
              tint: tint ?? 0,
              nativeKelvin: sourceKelvin,
            ),
        ];

  /// La clave de las fuentes CCT, si la hay.
  CctSource? get keySource {
    final list = cctSources;
    if (list.isEmpty) return null;
    return list.where((s) => s.role == LightColorRole.key).firstOrNull ??
        list.first;
  }

  /// Ratio que sale de la clave y el relleno (2 stops = 4:1).
  double? get derivedRatio {
    final key = keySource;
    final fill = cctSources
        .where((s) => s.role == LightColorRole.fill)
        .firstOrNull;
    if (key == null || fill == null) return null;
    return math.pow(2, key.stops - fill.stops).toDouble();
  }

  /// El ratio fijado o, si no, el que sale de las fuentes.
  double? get effectiveRatio => ratio ?? derivedRatio;

  /// Luces de la escena para la esfera de muestra: las de color en HSI, las
  /// fuentes en CCT.
  List<LightColor> get sceneLights =>
      colorMode ? colors : [for (final s in sources) s.asLightColor];

  /// Qué parte de la luz de la escena pone cada fuente (color, parte).
  List<(int rgb, double share)> get mix {
    final parts = colorMode
        ? [for (final c in colors) (c.rgb, c.intensity)]
        : [for (final s in cctSources) (s.rgb, s.level)];
    final total = parts.fold<double>(0, (a, p) => a + p.$2);
    if (total <= 0) return const [];
    return [for (final p in parts) (p.$1, p.$2 / total)];
  }

  /// Con estas fuentes; la clave fija también la temperatura y el tinte.
  LightingMetrics withSources(List<CctSource> next) {
    final key =
        next.where((s) => s.role == LightColorRole.key).firstOrNull ??
        next.firstOrNull;
    return LightingMetrics(
      kelvin: key?.kelvin ?? kelvin,
      tint: key?.tint ?? tint,
      ratio: ratio,
      sourceKelvin: sourceKelvin,
      colors: colors,
      colorMode: colorMode,
      sources: next,
    );
  }

  /// Se está diseñando con colores y hay alguno puesto.
  bool get usesColors => colorMode && colors.isNotEmpty;

  LightingMetrics copyWith({
    int? kelvin,
    double? tint,
    double? ratio,
    int? sourceKelvin,
    List<LightColor>? colors,
    bool? colorMode,
    List<CctSource>? sources,
  }) => LightingMetrics(
    kelvin: kelvin ?? this.kelvin,
    tint: tint ?? this.tint,
    ratio: ratio ?? this.ratio,
    sourceKelvin: sourceKelvin ?? this.sourceKelvin,
    colors: colors ?? this.colors,
    colorMode: colorMode ?? this.colorMode,
    sources: sources ?? this.sources,
  );

  /// Lo mismo, con uno de los valores quitado.
  LightingMetrics without({
    bool kelvin = false,
    bool tint = false,
    bool ratio = false,
  }) => LightingMetrics(
    kelvin: kelvin ? null : this.kelvin,
    tint: tint ? null : this.tint,
    ratio: ratio ? null : this.ratio,
    sourceKelvin: sourceKelvin,
    colors: colors,
    colorMode: colorMode,
    sources: sources,
  );

  Map<String, dynamic> toJson() => {
    if (kelvin != null) 'kelvin': kelvin,
    if (tint != null) 'tint': tint,
    if (ratio != null) 'ratio': ratio,
    if (sourceKelvin != null) 'source': sourceKelvin,
    if (colors.isNotEmpty) 'colors': [for (final c in colors) c.toJson()],
    if (colorMode) 'colorMode': true,
    if (sources.isNotEmpty) 'sources': [for (final s in sources) s.toJson()],
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
      colors: LightColor.listFrom(value['colors']),
      colorMode: value['colorMode'] == true,
      sources: CctSource.listFrom(value['sources']),
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
    final r = effectiveRatio;
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
      stopsLost: transmission >= 1 ? 0 : -math.log(transmission) / math.ln2,
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
