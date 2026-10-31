import 'light/ambient.dart';

/// Qué es el entorno de un set (F6.21.1): un plató, donde solo alumbran los
/// focos; un interior, donde el sol y el cielo entran por los huecos; o un
/// exterior, con cielo, sol y terreno. Va en la planta del set y lo usan el
/// fotómetro, el 3D y Unreal.
enum SetEnvironmentKind {
  studio('Plató', 'Solo los focos: sin sol ni cielo'),
  interior('Interior', 'El sol y el cielo entran por puertas y ventanas'),
  exterior('Exterior', 'Cielo, sol y terreno');

  final String label;
  final String hint;
  const SetEnvironmentKind(this.label, this.hint);
}

/// El suelo de un exterior.
enum SetGround {
  grass('Hierba', 0x4f6b35),
  dirt('Tierra', 0x7a6248),
  asphalt('Asfalto', 0x3a3a3c),
  concrete('Hormigón', 0x9a968e);

  final String label;

  /// Color del suelo (0xRRGGBB), en el 3D y en Unreal.
  final int rgb;
  const SetGround(this.label, this.rgb);
}

class SetEnvironment {
  final SetEnvironmentKind kind;
  final SetGround ground;

  const SetEnvironment({
    this.kind = SetEnvironmentKind.interior,
    this.ground = SetGround.grass,
  });

  bool get isStudio => kind == SetEnvironmentKind.studio;
  bool get isExterior => kind == SetEnvironmentKind.exterior;

  /// El ambiente con el que se mide en este entorno: en un plató no hay sol
  /// ni cielo, aunque el esquema de luz sea de día.
  PlanAmbient effective(PlanAmbient ambient) =>
      isStudio ? ambient.copyWith(sunOn: false, skyOn: false) : ambient;

  Map<String, dynamic> toJson() => {'kind': kind.name, 'ground': ground.name};

  /// Para la escena del 3D y Unreal.
  Map<String, dynamic> toScene() => {
    'kind': kind.name,
    'ground': ground.name,
    'groundRgb': ground.rgb,
  };

  static SetEnvironment fromJson(Object? raw) {
    if (raw is! Map) return const SetEnvironment();
    T pick<T extends Enum>(List<T> values, Object? name, T or) =>
        values.where((v) => v.name == name).firstOrNull ?? or;
    return SetEnvironment(
      kind: pick(SetEnvironmentKind.values, raw['kind'], SetEnvironmentKind.interior),
      ground: pick(SetGround.values, raw['ground'], SetGround.grass),
    );
  }

  SetEnvironment copyWith({SetEnvironmentKind? kind, SetGround? ground}) =>
      SetEnvironment(kind: kind ?? this.kind, ground: ground ?? this.ground);

  @override
  bool operator ==(Object other) =>
      other is SetEnvironment && other.kind == kind && other.ground == ground;

  @override
  int get hashCode => Object.hash(kind, ground);
}
