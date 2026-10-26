import 'dart:convert';
import 'dart:math' as math;

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

  /// La escena entera para Unreal.
  static Map<String, dynamic> build(Map<String, dynamic> scene) {
    final sunNow = sun(scene['sun'] as Map?);
    return {
      'v': version,
      'lights': [
        for (final f in (scene['fixtures'] as List? ?? const []).cast<Map>())
          ?light(f),
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
    if (before == null) return {...now, 'full': true};
    Map<String, String> byId(Map<String, dynamic> p) => {
      for (final l in (p['lights'] as List).cast<Map>())
        '${l['id']}': jsonEncode(l),
    };
    final old = byId(before), cur = byId(now);
    final upsert = [
      for (final l in (now['lights'] as List).cast<Map>())
        if (old['${l['id']}'] != cur['${l['id']}']) l,
    ];
    final remove = [
      for (final id in old.keys)
        if (!cur.containsKey(id)) id,
    ];
    final sunChanged =
        jsonEncode(before['sun']) != jsonEncode(now['sun']) ||
        jsonEncode(before['sky']) != jsonEncode(now['sky']);
    if (upsert.isEmpty && remove.isEmpty && !sunChanged) return null;
    return {
      'v': version,
      'lights': upsert,
      if (remove.isNotEmpty) 'remove': remove,
      if (sunChanged) ...{'sun': now['sun'], 'sky': now['sky']},
    };
  }
}
