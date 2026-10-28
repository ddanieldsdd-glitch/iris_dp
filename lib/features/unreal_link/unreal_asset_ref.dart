import '../camera_plan/camera_plan_element_model.dart';

/// De dónde viene un asset de Unreal, por su carpeta.
enum UnrealAssetSource {
  fab('Fab'),
  megascans('Megascans'),
  project('Proyecto'),
  engine('Unreal');

  final String label;
  const UnrealAssetSource(this.label);

  static UnrealAssetSource ofPath(String path) {
    final p = path.toLowerCase();
    if (p.startsWith('/game/fab/')) return fab;
    if (p.startsWith('/game/megascans/') || p.startsWith('/game/quixel/')) {
      return megascans;
    }
    if (p.startsWith('/engine/')) return engine;
    return project;
  }

  static UnrealAssetSource byName(String? name) => values.firstWhere(
    (s) => s.name == name,
    orElse: () => project,
  );
}

/// Qué clase de asset: una malla, un Blueprint o un personaje (malla con
/// esqueleto o MetaHuman).
enum UnrealAssetKind {
  mesh,
  blueprint,
  skeletal,
  metahuman;

  static UnrealAssetKind byName(String? name) => values.firstWhere(
    (k) => k.name == name,
    orElse: () => mesh,
  );
}

/// El asset de Unreal que hace de un elemento de la planta en Unreal
/// (F6.20 B1): cualquier tipo de elemento puede tener uno.
///
/// Se guarda en `props['unreal']`. Al leer se aceptan también los dos
/// campos de antes: `props['unrealAsset']` (ruta del atrezzo, F6.19) y
/// `externalMapping.unrealMeshPath` si no es uno de los cubos y cilindros
/// que se ponían solos. Al guardar se escribe el nuevo y también
/// `unrealAsset`, para que una versión anterior de IRIS lo conserve.
///
/// **Licencia:** IRIS guarda la ruta, las medidas y las miniaturas que
/// renderiza Unreal; el modelo nunca sale de Unreal.
class UnrealAssetRef {
  static const key = 'unreal';
  static const legacyKey = 'unrealAsset';

  /// Ruta del objeto: `/Game/Fab/Sofa/SM_Sofa.SM_Sofa`.
  final String path;
  final String name;
  final UnrealAssetKind kind;
  final UnrealAssetSource source;

  /// Ancho, fondo y alto, en centímetros, si se conocen.
  final List<double>? sizeCm;

  /// Miniaturas que renderiza Unreal (B3): claves de [UnrealThumbStore]
  /// de la cenital (con transparencia) y de la 3/4.
  final String? thumbTop;
  final String? thumb34;

  /// Lo que cubre de lado la cenital, en centímetros, centrada en el punto
  /// de apoyo de la pieza: con ella se dibuja a escala en la planta.
  final double? topSpanCm;

  const UnrealAssetRef({
    required this.path,
    required this.name,
    this.kind = UnrealAssetKind.mesh,
    this.source = UnrealAssetSource.project,
    this.sizeCm,
    this.thumbTop,
    this.thumb34,
    this.topSpanCm,
  });

  /// Un asset nuevo a partir de su ruta: nombre y origen salen de ella.
  factory UnrealAssetRef.fromPath(
    String path, {
    UnrealAssetKind kind = UnrealAssetKind.mesh,
    List<double>? sizeCm,
  }) => UnrealAssetRef(
    path: path,
    name: nameOfPath(path),
    kind: kind,
    source: UnrealAssetSource.ofPath(path),
    sizeCm: sizeCm,
  );

  /// `/Game/Fab/Sofa/SM_Sofa.SM_Sofa` → `SM_Sofa`.
  static String nameOfPath(String path) =>
      path.split('/').last.split('.').first;

  Map<String, dynamic> toJson() => {
    'path': path,
    'name': name,
    'kind': kind.name,
    'source': source.name,
    'sizeCm': ?sizeCm,
    'thumbTop': ?thumbTop,
    'thumb34': ?thumb34,
    'topSpanCm': ?topSpanCm,
  };

  static UnrealAssetRef? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['path'];
    if (path is! String || path.isEmpty) return null;
    final size = raw['sizeCm'];
    return UnrealAssetRef(
      path: path,
      name: raw['name'] as String? ?? nameOfPath(path),
      kind: UnrealAssetKind.byName(raw['kind'] as String?),
      source: raw['source'] is String
          ? UnrealAssetSource.byName(raw['source'] as String)
          : UnrealAssetSource.ofPath(path),
      sizeCm: size is List && size.length == 3
          ? [for (final v in size) (v as num).toDouble()]
          : null,
      thumbTop: raw['thumbTop'] as String?,
      thumb34: raw['thumb34'] as String?,
      topSpanCm: (raw['topSpanCm'] as num?)?.toDouble(),
    );
  }

  /// El asset del elemento, del campo nuevo o de los de antes.
  static UnrealAssetRef? of(PlanElement el) {
    if (fromJson(el.props[key]) case final ref?) return ref;
    final legacy = el.props[legacyKey];
    if (legacy is String && legacy.isNotEmpty) {
      return UnrealAssetRef.fromPath(legacy);
    }
    final mapped = el.externalMapping.unrealMeshPath;
    if (mapped != null &&
        mapped.isNotEmpty &&
        !mapped.startsWith('/Engine/BasicShapes/')) {
      return UnrealAssetRef.fromPath(mapped);
    }
    return null;
  }

  static bool has(PlanElement el) => of(el) != null;

  /// Pone (o quita, con `null`) el asset del elemento.
  static void set(PlanElement el, UnrealAssetRef? ref) {
    if (ref == null) {
      el.props
        ..remove(key)
        ..remove(legacyKey);
      return;
    }
    el.props[key] = ref.toJson();
    el.props[legacyKey] = ref.path;
  }

  /// Lo que va a Unreal: qué cargar y cómo colocarlo.
  Map<String, dynamic> toPayload() => {'path': path, 'kind': kind.name};

  UnrealAssetRef copyWith({
    String? thumbTop,
    String? thumb34,
    double? topSpanCm,
  }) => UnrealAssetRef(
    path: path,
    name: name,
    kind: kind,
    source: source,
    sizeCm: sizeCm,
    thumbTop: thumbTop ?? this.thumbTop,
    thumb34: thumb34 ?? this.thumb34,
    topSpanCm: topSpanCm ?? this.topSpanCm,
  );
}
