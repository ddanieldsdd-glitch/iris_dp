/// Qué es una luz del catálogo: su formato (cómo emite) y su tecnología
/// (cuánta luz da cada vatio), por separado.
///
/// En la base y en `assets/catalog/lights.json` van juntos en `lightType`
/// como «<tecnología>_<formato>»: `led_fresnel`, `tungsten_fresnel`,
/// `hmi_open`… Es el vocabulario cerrado que escribe
/// `tools/build_catalog.py`. Los tipos antiguos o escritos a mano
/// («LED Panel», «LED point-source», «fresnel») se siguen entendiendo.
library;

/// Formato del aparato. Dice cómo emite: haz, tamaño de la superficie y si
/// alumbra en todas direcciones.
enum LightFormat {
  fresnel('fresnel', 'Fresnel', beamDeg: 30, sizeM: 0.2),
  panel('panel', 'Panel', beamDeg: 110, sizeM: 0.6),
  flex('flex', 'Panel flexible', beamDeg: 120, sizeM: 0.6),
  tube('tube', 'Tubo', beamDeg: 360, sizeM: 1.2),
  cob('cob', 'COB / puntual', beamDeg: 55, sizeM: 0.2),
  balloon('balloon', 'Globo', beamDeg: 360, sizeM: 1.2),
  practical('practical', 'Práctica', beamDeg: 360, sizeM: 0.1),
  open('open', 'PAR / abierta', beamDeg: 40, sizeM: 0.25),
  profile('profile', 'Recorte', beamDeg: 26, sizeM: 0.15);

  const LightFormat(
    this.code,
    this.label, {
    required this.beamDeg,
    required this.sizeM,
  });

  /// Lo que va detrás del guion bajo en `lightType`.
  final String code;
  final String label;

  /// Haz con el que sale si la ficha no trae el suyo. 360 = en todas
  /// direcciones. Un COB se da con su reflector estándar.
  final double beamDeg;

  /// Tamaño típico de la superficie que emite, en metros.
  final double sizeM;

  bool get isOmni => beamDeg >= 359;

  /// Tecnología con la que suele venir.
  LightTechnology get usualTechnology => switch (this) {
    LightFormat.fresnel ||
    LightFormat.open ||
    LightFormat.profile => LightTechnology.tungsten,
    LightFormat.practical => LightTechnology.tungsten,
    _ => LightTechnology.led,
  };
}

/// Tecnología de la lámpara. Los nombres coinciden con los de `LightTech`
/// del motor de luz.
enum LightTechnology {
  led('led', 'LED'),
  hmi('hmi', 'HMI'),
  tungsten('tungsten', 'Tungsteno'),
  fluorescent('fluorescent', 'Fluorescente');

  const LightTechnology(this.code, this.label);
  final String code;
  final String label;
}

class LightKind {
  final LightTechnology technology;
  final LightFormat format;

  const LightKind(this.technology, this.format);

  /// Como se guarda en `lightType`.
  String get code => '${technology.code}_${format.code}';

  /// «Fresnel LED», «Panel», «HMI abierta»…
  String get label => switch ((technology, format)) {
    (LightTechnology.hmi, LightFormat.open) => 'HMI abierta',
    (LightTechnology.hmi, LightFormat.fresnel) => 'Fresnel HMI',
    (LightTechnology.led, LightFormat.fresnel) => 'Fresnel LED',
    (LightTechnology.tungsten, LightFormat.fresnel) => 'Fresnel de tungsteno',
    (_, final f) => f.label,
  };

  /// Entiende el vocabulario cerrado y los tipos de antes, se escriban como
  /// se escriban. Mismo criterio que `light_kind` en `tools/build_catalog.py`.
  static LightKind parse(String? raw) {
    final t = (raw ?? '')
        .toLowerCase()
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .trim();
    for (final tech in LightTechnology.values) {
      for (final format in LightFormat.values) {
        if (t == '${tech.code} ${format.code}') return LightKind(tech, format);
      }
    }
    final words = t.split(RegExp(r'\s+')).toSet();
    bool any(List<String> options) => options.any(words.contains);
    LightTechnology? tech = words.contains('hmi')
        ? LightTechnology.hmi
        : words.contains('led')
        ? LightTechnology.led
        : any(['fluorescent', 'kino', 'flo'])
        ? LightTechnology.fluorescent
        : null;
    final LightFormat format;
    if (any(['balloon', 'globo'])) {
      format = LightFormat.balloon;
    } else if (any(['practical', 'practica', 'práctica'])) {
      format = LightFormat.practical;
    } else if (any(['flexible', 'flex'])) {
      format = LightFormat.flex;
    } else if (any(['tube', 'tubo', 'pixel', 'bar'])) {
      format = LightFormat.tube;
    } else if (words.contains('panel')) {
      format = LightFormat.panel;
    } else if (words.contains('fresnel')) {
      format = LightFormat.fresnel;
    } else if (any(['par', 'open', 'abierta'])) {
      format = LightFormat.open;
    } else if (any(['profile', 'ellipsoidal', 'recorte'])) {
      format = LightFormat.profile;
    } else if (tech == LightTechnology.led) {
      format = LightFormat.cob;
    } else {
      format = LightFormat.fresnel;
    }
    tech ??= switch (format) {
      LightFormat.tube => LightTechnology.fluorescent,
      LightFormat.panel ||
      LightFormat.flex ||
      LightFormat.balloon => LightTechnology.led,
      LightFormat.cob => LightTechnology.led,
      _ => LightTechnology.tungsten,
    };
    return LightKind(tech, format);
  }

  @override
  bool operator ==(Object other) =>
      other is LightKind &&
      other.technology == technology &&
      other.format == format;

  @override
  int get hashCode => Object.hash(technology, format);

  @override
  String toString() => code;
}
