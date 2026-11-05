import 'dart:convert';

import 'camera_plan_element_model.dart';
import 'floor_plan_json.dart';
import 'light_overrides.dart';

/// Cambios de entorno que hace un set sobre el de su localización.
///
/// El entorno es de la localización y lo ven todos sus sets. Un set puede,
/// sin tocarlo, cambiar un elemento solo para él, añadir uno propio o quitar
/// uno (una pared que en este set no está). Se guardan por identificador
/// (`props['uid']`) en `LightSetups.envOverridesJson`:
///
/// ```json
/// {"<uid>": {…elemento…}, "<uid2>": {"hidden": true}}
/// ```
///
/// Un uid que está en el entorno lo sustituye; uno que no está se añade, y
/// `{"hidden": true}` lo quita.
class EnvOverrides {
  EnvOverrides._();

  static const hiddenKey = 'hidden';

  /// Los cambios guardados: uid → elemento, o nulo si está quitado.
  static Map<String, PlanElement?> decode(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final raw = jsonDecode(json) as Map<String, dynamic>;
      final result = <String, PlanElement?>{};
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is Map && value[hiddenKey] == true) {
          result[entry.key] = null;
          continue;
        }
        final list = FloorPlanJson.decode(
          jsonEncode({
            'version': FloorPlanJson.version,
            'elements': [value],
          }),
        );
        if (list.isNotEmpty) {
          result[entry.key] = list.single
            ..props[LightOverrides.uidKey] = entry.key;
        }
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  static String? encode(Map<String, PlanElement?> overrides) {
    if (overrides.isEmpty) return null;
    return jsonEncode({
      for (final entry in overrides.entries)
        entry.key: switch (entry.value) {
          null => const {hiddenKey: true},
          final el =>
            (jsonDecode(FloorPlanJson.encode([el]))
                    as Map<String, dynamic>)['elements']
                .single,
        },
    });
  }

  /// El entorno ([environment] de la localización y [set], el de su zona)
  /// tal como lo ve el set: cada cambio sustituye en su capa, lo quitado
  /// desaparece y lo nuevo va al final de [set], lo propio del set.
  static ({List<PlanElement> environment, List<PlanElement> set}) apply({
    required List<PlanElement> environment,
    required List<PlanElement> set,
    String? json,
  }) {
    final overrides = decode(json);
    if (overrides.isEmpty) return (environment: environment, set: set);
    final seen = <String>{};
    List<PlanElement> resolve(List<PlanElement> layer) => [
      for (final el in layer)
        if (LightOverrides.uidOf(el) case final uid?
            when overrides.containsKey(uid)) ...[
          if (seen.add(uid) && overrides[uid] != null) overrides[uid]!,
        ] else
          el,
    ];
    final env = resolve(environment);
    final own = resolve(set);
    return (
      environment: env,
      set: [
        ...own,
        for (final entry in overrides.entries)
          if (!seen.contains(entry.key) && entry.value != null) entry.value!,
      ],
    );
  }
}
