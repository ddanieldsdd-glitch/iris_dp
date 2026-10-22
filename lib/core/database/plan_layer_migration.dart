import 'dart:convert';

import 'package:drift/drift.dart';

import 'app_database.dart';

/// Pasa las plantas al modelo por capas (schemaVersion 42).
///
/// - Las luces que vivían en cada plano pasan a esquemas de luz compartidos
///   por set: los planos con la misma luz quedan bajo el mismo esquema.
/// - Las paredes y props copiados del set al plano se quitan del plano; el
///   plano los ve por referencia.
/// - Los diagramas de luz de la biblia pasan a esquemas en estado «boceto».
///   La ficha de la biblia conserva su diagrama y apunta al esquema.
///
/// Es idempotente: se puede ejecutar varias veces.
class PlanLayerMigration {
  final AppDatabase db;

  PlanLayerMigration(this.db);

  /// El lienzo del diagrama de la biblia es unas tres veces menor que el de
  /// la planta (1600 × 1200).
  static const double bibleDiagramScale = 3;
  static const double bibleDiagramOffsetX = 200;
  static const double bibleDiagramOffsetY = 150;

  static const _baseTypes = {'wall', 'prop'};

  Future<void> run() async {
    await db.transaction(() async {
      await _migrateBibleDiagrams();
      await _migrateShotLights();
    });
  }

  // ── Biblia ────────────────────────────────────────────────────────────────

  Future<void> _migrateBibleDiagrams() async {
    final setups = await (db.select(
      db.lightingSetups,
    )..where((s) => s.planSetupId.isNull())).get();

    for (final setup in setups) {
      final elements = bibleDiagramToPlanElements(setup.diagramJson);
      if (elements.isEmpty) continue;
      final bible = await (db.select(
        db.visualBibles,
      )..where((b) => b.id.equals(setup.bibleId))).getSingleOrNull();
      if (bible == null) continue;

      final id = await db.insertLightSetup(
        LightSetupsCompanion.insert(
          projectId: bible.projectId,
          locationSiteId: Value(setup.locationSiteId),
          locationBasePlanId: Value(setup.locationBasePlanId),
          name: setup.setupName,
          status: const Value('boceto'),
          origin: const Value('biblia'),
          planJson: Value(encodePlan(elements)),
          sortOrder: Value(setup.sortOrder),
        ),
      );
      await (db.update(db.lightingSetups)..where((s) => s.id.equals(setup.id)))
          .write(LightingSetupsCompanion(planSetupId: Value(id)));
    }
  }

  /// Convierte el diagrama simplificado de la biblia en elementos de planta.
  static List<Map<String, dynamic>> bibleDiagramToPlanElements(String json) {
    List<dynamic> raw;
    try {
      raw = jsonDecode(json) as List<dynamic>;
    } catch (_) {
      return const [];
    }
    final out = <Map<String, dynamic>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final type = item['type']?.toString() ?? 'light';
      final x = (item['x'] as num?)?.toDouble() ?? 100;
      final y = (item['y'] as num?)?.toDouble() ?? 100;
      final base = <String, dynamic>{
        'x': x * bibleDiagramScale + bibleDiagramOffsetX,
        'y': y * bibleDiagramScale + bibleDiagramOffsetY,
        'rotation': (item['rotation'] as num?)?.toDouble() ?? 0,
        'cameraLetter': 'A',
        'cameraNumber': 1,
        'pathPoints': const <dynamic>[],
      };
      final label = item['label']?.toString();
      switch (type) {
        case 'camera':
          out.add({...base, 'type': 'camera'});
        case 'subject':
          out.add({...base, 'type': 'actor', 'label': label ?? 'Sujeto'});
        default:
          out.add({
            ...base,
            'type': 'light',
            'lightType': switch (type) {
              'fill' => 'softbox',
              'practical' => 'practical',
              _ => 'fresnel_medium',
            },
            'props': {
              'role': type,
              if (label != null && label.isNotEmpty) 'name': label,
            },
          });
      }
    }
    return out;
  }

  // ── Planos ────────────────────────────────────────────────────────────────

  Future<void> _migrateShotLights() async {
    final scenes = await db.select(db.scenes).get();
    final lettersByOwner = <String, int>{};
    final setupBySignature = <String, int>{};

    for (final scene in scenes) {
      final set = scene.locationId != null
          ? await db.getLocationById(scene.locationId!)
          : null;
      final siteId = scene.locationSiteId ?? set?.siteId;
      final site = siteId != null ? await db.getSiteById(siteId) : null;

      final base = [
        ...decodeElements(site?.floorPlanJson),
        ...decodeElements(set?.floorPlanJson),
      ].where((e) => _baseTypes.contains(e['type'])).toList();

      final ownerKey = set != null
          ? 'set:${set.id}'
          : site != null
          ? 'site:${site.id}'
          : 'scene:${scene.id}';

      final shots = await db.getShotsForScene(scene.id);
      for (final shot in shots) {
        final rows = await db.getCameraPlanElementsForShot(shot.id);
        if (rows.isEmpty) continue;

        for (final row in rows) {
          if (_baseTypes.contains(row.type) && _matchesBase(row, base)) {
            await db.deleteCameraPlanElement(row.id);
          }
        }

        if (shot.lightSetupId != null) continue;
        final lights = rows.where((r) => r.type == 'light').toList();
        if (lights.isEmpty) continue;

        final signature = '$ownerKey#${_signature(lights)}';
        var setupId = setupBySignature[signature];
        if (setupId == null) {
          final index = lettersByOwner.update(
            ownerKey,
            (n) => n + 1,
            ifAbsent: () => 0,
          );
          final letter = _letter(index);
          setupId = await db.insertLightSetup(
            LightSetupsCompanion.insert(
              projectId: scene.projectId,
              locationSiteId: Value(set == null ? site?.id : null),
              locationBasePlanId: Value(set?.id),
              name: set == null && site == null
                  ? 'Escena ${scene.label} · Setup $letter'
                  : 'Setup $letter',
              status: const Value('en_desarrollo'),
              origin: const Value('planta'),
              planJson: Value(encodePlan(lights.map(_rowToElement).toList())),
              sortOrder: Value(index),
            ),
          );
          setupBySignature[signature] = setupId;
        }

        await db.assignLightSetupToShot(shot.id, setupId);
        for (final light in lights) {
          await db.deleteCameraPlanElement(light.id);
        }
      }
    }
  }

  static String _letter(int index) {
    const letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    if (index < letters.length) return letters[index];
    return '${index + 1}';
  }

  static bool _matchesBase(
    CameraPlanElement row,
    List<Map<String, dynamic>> base,
  ) {
    for (final e in base) {
      if (e['type'] != row.type) continue;
      if ((e['label'] as String?) != row.label) continue;
      final x = (e['x'] as num?)?.toDouble() ?? 0;
      final y = (e['y'] as num?)?.toDouble() ?? 0;
      final r = (e['rotation'] as num?)?.toDouble() ?? 0;
      if ((x - row.x).abs() < 0.5 &&
          (y - row.y).abs() < 0.5 &&
          (r - row.rotation).abs() < 0.5) {
        return true;
      }
    }
    return false;
  }

  static String _signature(List<CameraPlanElement> lights) {
    final parts =
        lights
            .map(
              (l) =>
                  '${l.lightType}|${l.x.round()}|${l.y.round()}|'
                  '${l.rotation.round()}|${l.label ?? ''}',
            )
            .toList()
          ..sort();
    return parts.join(';');
  }

  static Map<String, dynamic> _rowToElement(CameraPlanElement row) {
    Object? mapping;
    Object? props;
    try {
      mapping = row.externalMappingJson != null
          ? jsonDecode(row.externalMappingJson!)
          : null;
      props = row.propsJson != null ? jsonDecode(row.propsJson!) : null;
    } catch (_) {}
    return {
      'type': row.type,
      'x': row.x,
      'y': row.y,
      'rotation': row.rotation,
      'label': row.label,
      'cameraLetter': row.cameraLetter,
      'cameraNumber': row.cameraNumber,
      'lightType': row.lightType,
      'lukaCompatible': row.lukaCompatible,
      'lukaFixtureId': row.lukaFixtureId,
      'externalMapping': ?mapping,
      'props': ?props,
      'pathPoints': const <dynamic>[],
    };
  }

  static String encodePlan(List<Map<String, dynamic>> elements) =>
      jsonEncode({'version': 2, 'elements': elements});

  static List<Map<String, dynamic>> decodeElements(String? json) {
    if (json == null || json.isEmpty) return const [];
    try {
      final data = jsonDecode(json) as Map<String, dynamic>;
      return (data['elements'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
