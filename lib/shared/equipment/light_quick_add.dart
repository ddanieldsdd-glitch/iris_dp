import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import 'catalog_data_status.dart';
import 'light_kind.dart';

/// Cómo da el color una luz nueva.
enum LightColorMode {
  /// Una sola temperatura: un tungsteno, un HMI, un LED daylight.
  fixed('Temperatura fija', 5600, 5600),

  /// Bicolor, de cálido a frío.
  bicolor('Bicolor', 2700, 6500),

  /// RGB o RGBW: cualquier temperatura y además color.
  rgb('RGB', 2000, 10000);

  const LightColorMode(this.label, this.defaultMin, this.defaultMax);
  final String label;
  final int defaultMin;
  final int defaultMax;
}

/// Lo que se pide para dar de alta una luz que no está en el catálogo:
/// formato, marca y modelo, color y vatios. El formato ya dice cómo emite;
/// el resto queda «pendiente de configurar» hasta que el Excel de material
/// traiga su ficha.
class LightQuickAddDraft {
  final LightFormat format;

  /// `null` = la que suele llevar el formato.
  final LightTechnology? technology;
  final String brand;
  final String model;
  final LightColorMode color;

  /// Temperatura o rango, en kelvin. `null` = lo típico de [color]; con
  /// temperatura fija y una sola, la de [technology].
  final int? cctMin;
  final int? cctMax;
  final int watts;

  const LightQuickAddDraft({
    required this.format,
    required this.brand,
    required this.model,
    required this.watts,
    this.technology,
    this.color = LightColorMode.fixed,
    this.cctMin,
    this.cctMax,
  });

  LightKind get kind => LightKind(technology ?? format.usualTechnology, format);

  /// Rango de temperatura que se guarda.
  (int, int) get cctRange {
    if (color == LightColorMode.fixed) {
      final k =
          cctMin ??
          cctMax ??
          switch (kind.technology) {
            LightTechnology.tungsten => 3200,
            LightTechnology.fluorescent => 5600,
            _ => 5600,
          };
      return (k, k);
    }
    final low = cctMin ?? color.defaultMin;
    final high = cctMax ?? color.defaultMax;
    return low <= high ? (low, high) : (high, low);
  }

  /// Qué falta para poder guardarla.
  List<String> get problems => [
    if (brand.trim().isEmpty) 'Falta la marca',
    if (model.trim().isEmpty) 'Falta el modelo',
    if (watts <= 0) 'Faltan los vatios',
    if (cctRange.$1 < 1000 || cctRange.$2 > 20000)
      'La temperatura va de 1000 a 20 000 K',
  ];
}

class LightQuickAdd {
  LightQuickAdd._();

  /// Fuente con la que queda marcada una luz dada de alta a mano. Cuando el
  /// catálogo trae una ficha con su mismo identificador, la completa (ver
  /// `upsertCatalogLights`).
  static const sourceLabel = 'Alta rápida en IRIS · pendiente de configurar';

  /// Identificador con el que la buscará el Excel: el mismo criterio que
  /// las fichas del catálogo, `marca_modelo` en minúsculas.
  static String externalIdFor(String brand, String model) {
    const accents = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'é': 'e', 'è': 'e', 'ë': 'e', //
      'ê': 'e', 'í': 'i', 'ï': 'i', 'ó': 'o', 'ö': 'o', 'ô': 'o', 'ú': 'u',
      'ü': 'u', 'ñ': 'n', 'ç': 'c',
    };
    final text = '$brand $model'.toLowerCase().split('').map((c) {
      return accents[c] ?? c;
    }).join();
    return text
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  static bool isPending(Light light) =>
      light.isCustom && light.sourceLabel == sourceLabel;

  /// Lo que le falta a una luz para dejar de ser una estimación.
  static List<String> missing(Light light) => [
    if (light.beamAngleDeg == null || isPending(light)) 'ángulo de haz',
    if (light.photometryLux == null || light.photometryDistanceM == null)
      'fotometría (lux a una distancia)',
    if (light.cri == null) 'CRI',
  ];

  /// La fila nueva. El haz y el tamaño salen del formato; la fotometría se
  /// estimará con vatios y tecnología hasta que llegue la del fabricante.
  static LightsCompanion companion(LightQuickAddDraft draft) {
    final (low, high) = draft.cctRange;
    final format = draft.format;
    return LightsCompanion.insert(
      brand: draft.brand.trim(),
      model: draft.model.trim(),
      lightType: draft.kind.code,
      powerW: draft.watts,
      colorTempMin: low,
      colorTempMax: high,
      beamAngleDeg: Value(format.beamDeg),
      externalId: Value(externalIdFor(draft.brand, draft.model)),
      isCustom: const Value(true),
      notes: Value(
        'Alta rápida · ${draft.kind.label} · ${draft.color.label}. '
        'Haz y tamaño de su formato; fotometría estimada por vatios.',
      ),
      dataStatus: Value(CatalogDataStatus.pendiente.label),
      sourceLabel: const Value(sourceLabel),
    );
  }

  /// Da de alta la luz. Si el catálogo ya tiene una con la misma marca y
  /// modelo, devuelve esa y no crea otra.
  static Future<({Light light, bool created})> add(
    AppDatabase db,
    LightQuickAddDraft draft,
  ) async {
    final problems = draft.problems;
    if (problems.isNotEmpty) throw ArgumentError(problems.join('. '));
    final id = externalIdFor(draft.brand, draft.model);
    final existing = await db.getLightByExternalId(id);
    if (existing != null) return (light: existing, created: false);
    final rowId = await db.insertLight(companion(draft));
    return (light: (await db.getLightById(rowId))!, created: true);
  }
}
