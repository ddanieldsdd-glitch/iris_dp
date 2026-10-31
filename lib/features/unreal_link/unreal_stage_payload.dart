import 'dart:convert';
import 'dart:math' as math;

/// El mundo (nivel de Unreal) de una planta: uno por set de rodaje, y otro
/// para el plano maestro de cada localización. Las escenas y los planos que
/// se ruedan en un set comparten su mundo.
class UnrealWorld {
  /// Estable aunque se renombre: `set12`, `site3`.
  final String key;
  final String name;

  /// Localización a la que pertenece: su carpeta en Unreal.
  final String? site;

  const UnrealWorld({required this.key, required this.name, this.site});

  Map<String, dynamic> toJson() => {'key': key, 'name': name, 'site': ?site};

  @override
  bool operator ==(Object other) =>
      other is UnrealWorld &&
      other.key == key &&
      other.name == name &&
      other.site == site;

  @override
  int get hashCode => Object.hash(key, name, site);
}

/// De la escena 3D de IRIS (`iris.scene3d`, [PlanScene3d]) a lo que aplica
/// IRIS Stage Link en Unreal (`tools/unreal/iris_stage`).
///
/// Todo se convierte aquí para que el lado de Unreal solo aplique:
/// - posiciones en centímetros con los ejes de Unreal (z arriba, mano
///   izquierda): la x igual, la y al revés que en la escena;
/// - rotadores `[pitch, yaw, roll]` en grados, con el eje del haz en +X;
/// - intensidad en candelas, como el motor de luz de IRIS; el sol en lux.
class UnrealStagePayload {
  UnrealStagePayload._();

  /// Versión del contrato con `iris_stage_link.py`.
  static const version = 1;

  /// A partir de este tamaño, una fuente es una luz rectangular (paneles,
  /// tubos, softbox); por debajo, un foco.
  static const double rectFromM = 0.25;

  /// Ángulo de cono máximo de un foco de Unreal (medio ángulo).
  static const double maxConeDeg = 80;

  static double _r(double v) => (v * 10).roundToDouble() / 10;

  /// Un punto de la escena (metros) en Unreal (cm).
  static List<double> loc(List p) => [
    _r((p[0] as num) * 100),
    _r(-(p[1] as num) * 100),
    _r((p.length > 2 ? p[2] as num : 0) * 100),
  ];

  /// El rotador de Unreal que apunta su +X hacia [d] (dirección en ejes de
  /// la escena).
  static List<double> rotToward(double dx, double dy, double dz) {
    final x = dx, y = -dy, z = dz;
    final yaw = math.atan2(y, x) * 180 / math.pi;
    final pitch = math.atan2(z, math.sqrt(x * x + y * y)) * 180 / math.pi;
    return [_r(pitch), _r(yaw), 0];
  }

  static Map<String, dynamic>? light(Map f) {
    final pos = f['pos'] as List?, aim = f['aim'] as List?;
    if (pos == null || aim == null) return null;
    double at(List p, int i) => (p[i] as num).toDouble();
    final dx = at(aim, 0) - at(pos, 0);
    final dy = at(aim, 1) - at(pos, 1);
    final dz = at(aim, 2) - at(pos, 2);
    final dist = math.sqrt(dx * dx + dy * dy + dz * dz);
    final src = f['source'] as Map?;
    final beam = ((src?['beamDeg'] ?? f['beamDeg'] ?? 60) as num).toDouble();
    final sizeM = ((src?['sizeM'] ?? 0.1) as num).toDouble();
    final kind = beam >= 359
        ? 'point'
        : sizeM >= rectFromM
        ? 'rect'
        : 'spot';
    // El haz (donde la intensidad cae a la mitad) queda a medio camino
    // entre el cono interior y el exterior.
    final half = beam / 2;
    final outer = math.min(half * 1.5, maxConeDeg);
    final inner = math.min(half * 0.5, outer - 1);
    final size = _r(sizeM * 100);
    return {
      'id': f['id'],
      'name': f['name'],
      'kind': kind,
      'loc': loc(pos),
      'rot': dist < 1e-6 ? [-90.0, 0.0, 0.0] : rotToward(dx, dy, dz),
      'cd': _r(((src?['cd'] ?? 0) as num).toDouble()),
      'cct': _r(((src?['cct'] ?? f['cct'] ?? 3200) as num).toDouble()),
      'on': f['on'] == true,
      if (kind == 'spot') ...{'outerDeg': _r(outer), 'innerDeg': _r(inner)},
      if (kind == 'rect') ...{'widthCm': size, 'heightCm': size},
      'sizeCm': size,
      // Hasta dónde llega en Unreal: de sobra para no cortar la luz.
      'reachCm': _r((dist * 400).clamp(2000.0, 10000.0)),
      'asset': ?f['asset'],
    };
  }

  /// La dirección (ejes de la escena) del +X de un rotador de Unreal: lo
  /// contrario de [rotToward].
  static ({double x, double y, double z}) dirOf(List rot) {
    final p = (rot[0] as num) * math.pi / 180;
    final yw = (rot[1] as num) * math.pi / 180;
    return (
      x: math.cos(p) * math.cos(yw),
      y: -math.cos(p) * math.sin(yw),
      z: math.sin(p),
    );
  }

  /// Una cámara de la planta como CineCamera: a la altura del objetivo,
  /// mirando en horizontal hacia donde mira en planta, con la focal que da
  /// su campo en su sensor.
  static Map<String, dynamic>? camera(Map c) {
    final at = c['at'] as List?, dir = c['dir'] as List?;
    if (at == null || dir == null) return null;
    final z = ((c['z0'] ?? 0) as num) + ((c['z'] ?? 1.5) as num);
    final sensor = ((c['sensorMm'] ?? 24.89) as num).toDouble();
    final hfov = ((c['hfovDeg'] ?? 40) as num).toDouble() * math.pi / 180;
    return {
      'id': c['id'],
      'name': c['name'],
      'loc': loc([at[0], at[1], z]),
      'rot': rotToward(
        (dir[0] as num).toDouble(),
        (dir[1] as num).toDouble(),
        0,
      ),
      'focalMm': _r(sensor / (2 * math.tan(hfov / 2))),
      'sensorMm': _r(sensor),
      'asset': ?c['asset'],
    };
  }

  /// Una pieza de atrezzo: su asset de Unreal si lo tiene o, si no, un
  /// bloque con sus medidas. Gira como en planta.
  static Map<String, dynamic>? prop(Map p) {
    final at = p['at'] as List?;
    if (at == null) return null;
    final rad = ((p['yawDeg'] ?? 0) as num) * math.pi / 180;
    final size = _r(((p['sizeM'] ?? 0.5) as num) * 100);
    return {
      'id': p['id'],
      'name': p['name'],
      'type': p['type'],
      'loc': loc([at[0], at[1], p['z0'] ?? 0]),
      'rot': rotToward(math.sin(rad), math.cos(rad), 0),
      'sizeCm': [size, size, _r(((p['heightM'] ?? 0.8) as num) * 100)],
      'asset': ?p['asset'],
    };
  }

  /// Otra pieza con asset de Unreal (pared, actor, grip, rigging): el asset
  /// en su sitio y con su giro. Sin asset no va a Unreal.
  static Map<String, dynamic>? asset(Map a) {
    final at = a['at'] as List?;
    if (at == null || a['asset'] == null) return null;
    final rad = ((a['yawDeg'] ?? 0) as num) * math.pi / 180;
    return {
      'id': a['id'],
      'name': a['name'],
      'loc': loc([at[0], at[1], a['z0'] ?? 0]),
      'rot': rotToward(math.sin(rad), math.cos(rad), 0),
      'lengthCm': ?(a['lengthM'] == null ? null : _r((a['lengthM'] as num) * 100)),
      'asset': a['asset'],
    };
  }

  /// Carpetas de este equipo donde están los escaneos de la planta: Unreal,
  /// en el mismo PC, los importa de ahí. Las pone la vista 3D del proyecto.
  static List<String> scanFolders = const [];

  /// Un escaneo de la planta (glb, gltf u obj): su archivo, en su sitio, con
  /// su giro y su escala. Las nubes de puntos (ply) no van a Unreal.
  static Map<String, dynamic>? scan(Map s) {
    final at = s['at'] as List?;
    final format = s['format'] as String? ?? 'glb';
    if (at == null || s['file'] == null || format == 'ply') return null;
    // En la escena gira -yaw sobre la vertical (en el sentido de la planta,
    // con y hacia abajo); Unreal invierte la y, así que allí es +yaw. El
    // importador de glTF de Unreal ya pasa de Y arriba a Z arriba (cambia
    // y por z), así que no hace falta otro giro de base.
    final yaw = ((s['yawDeg'] ?? 0) as num).toDouble();
    return {
      'id': s['id'],
      'name': s['name'],
      'file': s['file'],
      'loc': loc([at[0], at[1], s['z0'] ?? 0]),
      'rot': [0.0, _r(yaw), 0.0],
      'scale': ((s['scale'] ?? 1) as num).toDouble(),
    };
  }

  /// El sol: la escena da hacia dónde está; la luz va al revés.
  static Map<String, dynamic>? sun(Map? s) {
    final d = s?['dir'] as List?;
    if (s == null || d == null) return null;
    return {
      'rot': rotToward(
        -(d[0] as num).toDouble(),
        -(d[1] as num).toDouble(),
        -(d[2] as num).toDouble(),
      ),
      'lux': _r(((s['lux'] ?? 0) as num).toDouble()),
      'cct': _r(((s['cct'] ?? 5400) as num).toDouble()),
    };
  }

  /// Las listas de piezas que se comparan una a una.
  static const kinds = ['lights', 'cameras', 'props', 'assets', 'scans'];

  /// La escena entera para Unreal, en el mundo (nivel) [world].
  static Map<String, dynamic> build(
    Map<String, dynamic> scene, {
    UnrealWorld? world,
  }) {
    final sunNow = sun(scene['sun'] as Map?);
    return {
      'v': version,
      'world': ?world?.toJson(),
      'props': [
        for (final p in (scene['props'] as List? ?? const []).cast<Map>())
          ?prop(p),
      ],
      'assets': [
        for (final a in (scene['assets'] as List? ?? const []).cast<Map>())
          ?asset(a),
      ],
      'scans': [
        for (final s in (scene['scans'] as List? ?? const []).cast<Map>())
          ?scan(s),
      ],
      if (scanFolders.isNotEmpty) 'scanFolders': scanFolders,
      'lights': [
        for (final f in (scene['fixtures'] as List? ?? const []).cast<Map>())
          ?light(f),
      ],
      'cameras': [
        for (final c in (scene['cameras'] as List? ?? const []).cast<Map>())
          ?camera(c),
      ],
      'sun': sunNow,
      // De día, cielo físico (SkyAtmosphere y SkyLight) con el sol.
      'sky': sunNow == null ? null : {'scale': 1.0},
    };
  }

  /// Lo que hay que mandar para pasar de [before] a [now]: la escena entera
  /// si no hay nada antes, solo lo cambiado si lo hay, o `null` si no ha
  /// cambiado nada.
  static Map<String, dynamic>? diff(
    Map<String, dynamic>? before,
    Map<String, dynamic> now,
  ) {
    // Otro mundo (otro set): se manda entero y Unreal cambia de nivel.
    if (before == null ||
        jsonEncode(before['world']) != jsonEncode(now['world'])) {
      return {...now, 'full': true};
    }
    final out = <String, dynamic>{
      'v': version,
      'scanFolders': ?now['scanFolders'],
    };
    final remove = <String>[];
    for (final kind in kinds) {
      Map<String, String> byId(Map<String, dynamic> p) => {
        for (final l in (p[kind] as List? ?? const []).cast<Map>())
          '${l['id']}': jsonEncode(l),
      };
      final old = byId(before), cur = byId(now);
      out[kind] = [
        for (final l in (now[kind] as List? ?? const []).cast<Map>())
          if (old['${l['id']}'] != cur['${l['id']}']) l,
      ];
      remove.addAll([
        for (final id in old.keys)
          if (!cur.containsKey(id)) id,
      ]);
    }
    final sunChanged =
        jsonEncode(before['sun']) != jsonEncode(now['sun']) ||
        jsonEncode(before['sky']) != jsonEncode(now['sky']);
    if (kinds.every((k) => (out[k] as List).isEmpty) &&
        remove.isEmpty &&
        !sunChanged) {
      return null;
    }
    return {
      ...out,
      if (remove.isNotEmpty) 'remove': remove,
      if (sunChanged) ...{'sun': now['sun'], 'sky': now['sky']},
    };
  }
}
