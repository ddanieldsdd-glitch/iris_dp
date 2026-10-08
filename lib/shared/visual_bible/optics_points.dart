import 'dart:convert';

import 'bible_cards.dart';
import 'bible_equipment.dart';
import 'bible_table.dart';
import 'bible_text_specs.dart';

/// Contenido de los puntos de Óptica, para la pantalla y el PDF.
///
/// Cada punto guarda su valor en `values[clave]`. Mientras no lo tenga, se
/// lee de donde estaba antes: `VisualBibles.opticsConfigJson` y las
/// columnas de la biblia. Nada de lo que devuelve es un ejemplo.
abstract final class OpticsPoints {
  static const kit = 'lensKit';
  static const philosophy = 'opticSettings';
  static const character = 'character';
  static const focals = 'focalTable';
  static const filtration = 'filtration';
  static const maintenance = 'maintenance';

  static const factType = 'Tipo';
  static const factSqueeze = 'Factor anamórfico';
  static const factAspect = 'Relación de aspecto';
  static const typeAnamorphic = 'Anamórfica';
  static const typeSpherical = 'Esférica';

  static const rowTStop = 'T de trabajo';
  static const rowSqueeze = factSqueeze;

  static const focalColumns = [
    'Focal',
    'T',
    'Distancia mínima',
    'Distorsión',
    'Uso',
  ];
  static const maintenanceColumns = ['Fecha', 'Revisión', 'Notas'];

  static String _text(Object? v) => v?.toString().trim() ?? '';

  static Map<String, dynamic> config(String? opticsConfigJson) {
    if (opticsConfigJson == null || opticsConfigJson.isEmpty) return {};
    try {
      final decoded = jsonDecode(opticsConfigJson);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  static List<Map> _maps(Object? raw) => [
    if (raw is List)
      for (final e in raw)
        if (e is Map) e,
  ];

  /// «2x Squeeze», «1,8», 2.0 → 2.0. Nulo si no hay número.
  static double? squeezeOf(Object? raw) {
    if (raw is num) return raw.toDouble();
    final match = RegExp(r'\d+(?:[.,]\d+)?').firstMatch(_text(raw));
    if (match == null) return null;
    return double.tryParse(match.group(0)!.replaceAll(',', '.'));
  }

  static String _squeezeLabel(double squeeze) =>
      '${squeeze.toStringAsFixed(squeeze % 1 == 0 ? 0 : 2)}x';

  /// Los juegos de lentes. En biblias anteriores había un juego principal
  /// y, aparte, «lens sets» por cámara: salen todos, tentativos.
  static List<BibleEquipmentItem> kitItems(
    Map<String, String> values,
    Map<String, dynamic> config, {
    int? legacyLensId,
    String? legacyLensName,
    Map<String, String> legacyFacts = const {},
  }) {
    if (values.containsKey(kit)) {
      return BibleEquipmentItem.listFrom(values[kit]);
    }
    final mainName = _text(config['primarySetName']).isNotEmpty
        ? _text(config['primarySetName'])
        : _text(legacyLensName);
    return [
      if (mainName.isNotEmpty)
        BibleEquipmentItem(
          role: 'A',
          catalogId: legacyLensId,
          name: mainName,
          facts: legacyFacts,
        ),
      for (final set in _maps(config['lensSets']))
        BibleEquipmentItem(
          role: _text(set['name']),
          name: set['isAnamorphic'] == true ? typeAnamorphic : typeSpherical,
          facts: {
            factType: set['isAnamorphic'] == true
                ? typeAnamorphic
                : typeSpherical,
            if (squeezeOf(set['squeezeRatio']) != null)
              factSqueeze: _squeezeLabel(squeezeOf(set['squeezeRatio'])!),
            if (_text(set['aspectRatio']).isNotEmpty)
              factAspect: _text(set['aspectRatio']),
          },
        ),
    ];
  }

  /// Los juegos tal como los lee Formato (`BibleOpticsContext`).
  static List<Map<String, dynamic>> lensSetsFor(
    List<BibleEquipmentItem> items,
  ) => [
    for (final item in items)
      if (!item.isEmpty)
        () {
          final squeeze = squeezeOf(item.facts[factSqueeze]) ?? 1.0;
          final anamorphic =
              item.facts[factType] == typeAnamorphic || squeeze > 1.05;
          return <String, dynamic>{
            'name': item.role.isNotEmpty ? item.role : item.name,
            'isAnamorphic': anamorphic,
            'squeezeRatio': anamorphic && squeeze <= 1.05 ? 2.0 : squeeze,
            if ((item.facts[factAspect] ?? '').isNotEmpty)
              'aspectRatio': item.facts[factAspect],
          };
        }(),
  ];

  static BibleTextSpecsValue philosophyValue(
    Map<String, String> values,
    Map<String, dynamic> config, {
    String? lensPhilosophy,
  }) => values.containsKey(philosophy)
      ? BibleTextSpecsValue.decode(values[philosophy])
      : BibleTextSpecsValue(
          text: _text(lensPhilosophy),
          rows: [
            (rowTStop, _text(config['tStop'])),
            (rowSqueeze, _text(config['squeeze'])),
          ],
        );

  static List<BibleCard> characterCards(
    Map<String, String> values,
    Map<String, dynamic> config,
  ) => values.containsKey(character)
      ? BibleCard.listFrom(values[character])
      : [
          BibleCard(
            title: 'Bokeh',
            body: _text(config['bokehCharacteristic']),
          ),
          BibleCard(title: 'Flares', body: _text(config['flareBehavior'])),
        ];

  static BibleTableValue focalsValue(
    Map<String, String> values,
    Map<String, dynamic> config, {
    List<int> legacyFocals = const [],
  }) {
    if (values.containsKey(focals)) {
      return BibleTableValue.decode(values[focals]);
    }
    final specs = _maps(config['anamorphicSpecs']);
    return BibleTableValue(
      columns: focalColumns,
      rows: specs.isNotEmpty
          ? [
              for (final s in specs)
                [
                  _text(s['focalLength']),
                  _text(s['tStop']),
                  _text(s['cfd']) == '—' ? '' : _text(s['cfd']),
                  _text(s['distortion']) == '—' ? '' : _text(s['distortion']),
                  '',
                ],
            ]
          : [
              for (final focal in legacyFocals) ['$focal mm', '', '', '', ''],
            ],
    );
  }

  /// Focales de la tabla como números, para las columnas de la biblia.
  static List<int> focalNumbers(BibleTableValue table) => [
    for (final row in table.filledRows)
      if (row.isNotEmpty &&
          RegExp(r'\d+').firstMatch(row.first) != null)
        int.parse(RegExp(r'\d+').firstMatch(row.first)!.group(0)!),
  ];

  static List<BibleMeter> filtrationMeters(
    Map<String, String> values,
    Map<String, dynamic> config, {
    String? filtrationNotes,
  }) {
    if (values.containsKey(filtration)) {
      return BibleMeter.listFrom(values[filtration]);
    }
    final stack = _maps(config['filtrationStack']);
    return [
      for (final f in stack)
        BibleMeter(
          label: _text(f['name']),
          value: _text(f['density']),
          note: _text(f['justification']),
          // Las densidades de difusión van de 1/16 a 1.
          min: 0,
          max: 1,
        ),
      if (stack.isEmpty && _text(filtrationNotes).isNotEmpty)
        BibleMeter(label: 'Filtraje', note: _text(filtrationNotes)),
    ].where((m) => !m.isEmpty || m.note.isNotEmpty).toList();
  }

  static BibleTableValue maintenanceValue(
    Map<String, String> values,
    Map<String, dynamic> config,
  ) => values.containsKey(maintenance)
      ? BibleTableValue.decode(values[maintenance])
      : BibleTableValue(
          columns: maintenanceColumns,
          rows: [
            for (final entry in _maps(config['maintenanceLog']))
              [
                _text(entry['date']),
                _text(entry['title']),
                _text(entry['description'] ?? entry['body']),
              ],
          ],
        );
}
