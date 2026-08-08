import 'dart:convert';

/// Helpers para `lightingData` — Acto 1 global + Acto 2 `byPlan[setId]`.
abstract final class BibleLightingData {
  static const textureCardsKey = 'textureCards';
  static const legacyBehaviorCardsKey = 'behaviorCards';

  /// Migra datos legacy (monolito philosophy) al esquema Acto 1 / Acto 2.
  static Map<String, dynamic> migrate(Map<String, dynamic> raw) {
    final data = Map<String, dynamic>.from(raw);

    // Acto 1: visualIntent → narrativeStory
    if ((data['narrativeStory'] as String?)?.isEmpty != false) {
      final intent = data['visualIntent'] as String?;
      if (intent != null && intent.isNotEmpty) {
        data['narrativeStory'] = intent;
      }
    }

    // Acto 1: behaviorCards globales → textureCards
    if (!data.containsKey(textureCardsKey) &&
        data[legacyBehaviorCardsKey] is List) {
      data[textureCardsKey] = data[legacyBehaviorCardsKey];
    }

    // Acto 2: telemetría/fixtures en raíz → byPlan default si hay selectedPlanId
    final selectedId = data['selectedPlanId'];
    if (selectedId != null) {
      final byPlan = planMap(data);
      final key = '$selectedId';
      final plan = Map<String, dynamic>.from(byPlan[key] as Map? ?? {});
      _moveRootTelemetryToPlan(data, plan);
      byPlan[key] = plan;
      data['byPlan'] = byPlan;
    }

    return data;
  }

  static void _moveRootTelemetryToPlan(
    Map<String, dynamic> root,
    Map<String, dynamic> plan,
  ) {
    const telemetryKeys = [
      'colorTemp',
      'tint',
      'tintValue',
      'contrastRatio',
      'contrastNum',
      'blackLevelIre',
      'crushedBlacks',
      'activeFixtures',
      'fixtureTypes',
      'equipmentManifest',
    ];
    for (final k in telemetryKeys) {
      if (plan.containsKey(k)) continue;
      if (root.containsKey(k)) {
        plan[k] = root[k];
      }
    }
    if (!plan.containsKey(legacyBehaviorCardsKey) &&
        root[legacyBehaviorCardsKey] is List &&
        root[textureCardsKey] == null) {
      plan[legacyBehaviorCardsKey] = root[legacyBehaviorCardsKey];
    }
  }

  static Map<String, dynamic> planMap(Map<String, dynamic> data) {
    final raw = data['byPlan'];
    if (raw is! Map) return {};
    return raw.map((k, v) => MapEntry('$k', v));
  }

  static Map<String, dynamic> planFor(
    Map<String, dynamic> data,
    int? planId,
  ) {
    if (planId == null) return {};
    final byPlan = planMap(data);
    final raw = byPlan['$planId'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return {};
  }

  static Map<String, dynamic> mergePlan(
    Map<String, dynamic> data,
    int planId,
    Map<String, dynamic> patch,
  ) {
    final next = Map<String, dynamic>.from(data);
    final byPlan = planMap(next);
    final current = planFor(next, planId);
    byPlan['$planId'] = {...current, ...patch};
    next['byPlan'] = byPlan;
    next['selectedPlanId'] = planId;
    return next;
  }

  static List<Map<String, String>> textureCards(Map<String, dynamic> data) {
    final raw = data[textureCardsKey] ?? data[legacyBehaviorCardsKey];
    if (raw is! List) return [];
    return raw.map((e) {
      if (e is Map) {
        return {
          'title': e['title']?.toString() ?? '',
          'meta': e['meta']?.toString() ?? '',
          'tag': e['tag']?.toString() ?? '',
          'note': e['note']?.toString() ?? '',
        };
      }
      return {'title': e.toString(), 'meta': '', 'tag': '', 'note': ''};
    }).toList();
  }

  static List<Map<String, dynamic>> fixtureList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) {
      if (e is Map) return Map<String, dynamic>.from(e);
      return <String, dynamic>{'name': e.toString()};
    }).toList();
  }

  static Map<String, dynamic> telemetryForPlan(
    Map<String, dynamic> data,
    int? planId,
  ) {
    if (planId != null) {
      final plan = planFor(data, planId);
      if (plan.isNotEmpty) return plan;
    }
    return data;
  }

  static String encode(Map<String, dynamic> data) => jsonEncode(migrate(data));

  static Map<String, dynamic> decode(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map<String, dynamic>) return migrate(parsed);
    } catch (_) {}
    return {};
  }
}
