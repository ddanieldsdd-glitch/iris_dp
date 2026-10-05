import 'dart:convert';
import 'dart:math' as math;

import 'camera_plan_element_model.dart';
import 'floor_plan_json.dart';

/// Ajustes de luz propios de un plano sobre el esquema que comparte.
///
/// El esquema es de todos los planos que lo usan; un plano puede, sin
/// romperlo, apagar una luz, bajarla o mover una bandera solo para él. Cada
/// elemento del esquema lleva un identificador estable (`props['uid']`) y
/// el plano guarda, por identificador, cómo queda ese elemento en él
/// (`Shots.lightOverridesJson`).
class LightOverrides {
  LightOverrides._();

  static const uidKey = 'uid';
  static final _random = math.Random();

  /// Da identificador a los elementos que aún no lo tienen.
  static void ensureUids(Iterable<PlanElement> elements) {
    for (final el in elements) {
      if (el.props[uidKey] is! String) {
        el.props[uidKey] =
            '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}'
            '${_random.nextInt(1 << 20).toRadixString(36)}';
      }
    }
  }

  static String? uidOf(PlanElement el) => el.props[uidKey] as String?;

  /// Los ajustes guardados en un plano: identificador → elemento.
  static Map<String, PlanElement> decode(String? json) {
    if (json == null || json.isEmpty) return {};
    try {
      final raw = jsonDecode(json) as Map<String, dynamic>;
      final result = <String, PlanElement>{};
      for (final entry in raw.entries) {
        final list = FloorPlanJson.decode(
          jsonEncode({
            'version': FloorPlanJson.version,
            'elements': [entry.value],
          }),
        );
        if (list.isNotEmpty) result[entry.key] = list.single;
      }
      return result;
    } catch (_) {
      return {};
    }
  }

  static String? encode(Map<String, PlanElement> overrides) {
    if (overrides.isEmpty) return null;
    return jsonEncode({
      for (final entry in overrides.entries)
        entry.key:
            (jsonDecode(FloorPlanJson.encode([entry.value]))
                    as Map<String, dynamic>)['elements']
                .single,
    });
  }

  /// Los elementos del esquema tal como se ven en el plano: los que tienen
  /// ajuste se sustituyen por él y quedan marcados (`shotOverride`).
  static List<PlanElement> apply(List<PlanElement> setup, String? json) {
    final overrides = decode(json);
    if (overrides.isEmpty) return setup;
    return [
      for (final el in setup)
        if (overrides[uidOf(el)] case final own?)
          own
            ..props[uidKey] = uidOf(el)
            ..shotOverride = true
        else
          el,
    ];
  }

  /// Copia independiente de un elemento.
  static PlanElement clone(PlanElement el) =>
      FloorPlanJson.decode(FloorPlanJson.encode([el])).single;
}
