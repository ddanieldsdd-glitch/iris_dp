import 'dart:convert';

import 'bible_cards.dart';
import 'bible_table.dart';
import 'bible_text_specs.dart';

/// Un bloque de exposición tal como estaba guardado antes (tabla propia).
typedef LegacyExposureBlock = ({
  String name,
  String? intent,
  String? keyFill,
  String? highlights,
  String? shadows,
});

/// Contenido de los puntos de Exposición, para la pantalla y el PDF.
///
/// Cada punto guarda su valor en `values[clave]`. Mientras no lo tenga, se
/// lee de donde estaba antes: el blob `exposureData`, las columnas de la
/// biblia y la tabla de bloques. Nada de lo que devuelve es un ejemplo.
abstract final class ExposurePoints {
  static const global = 'globalExposure';
  static const chain = 'exposureChain';
  static const signal = 'signalLevels';
  static const blocks = 'blocks';
  static const byLocation = 'byLocation';

  static const rowIso = 'ISO de trabajo';
  static const rowTStop = 'T de trabajo';
  static const rowShutter = 'Obturador';
  static const rowNd = 'ND';
  static const rowHighlights = 'Altas luces';
  static const rowShadows = 'Sombras';

  static const blockColumns = [
    'Bloque',
    'Intención',
    'Clave:relleno',
    'Altas luces',
    'Sombras',
  ];
  static const locationColumns = [
    'Localización',
    'ISO',
    'T',
    'ND',
    'Obturador',
    'Planteamiento',
    'Altas luces',
    'Sombras',
    'Clave:relleno',
  ];

  static String _text(Object? v) => v?.toString().trim() ?? '';

  /// Datos de la pantalla antigua: iban juntos en `values['exposureData']`.
  static Map<String, dynamic> blob(String? contentJson) {
    if (contentJson == null || contentJson.isEmpty) return {};
    try {
      final decoded = jsonDecode(contentJson);
      if (decoded is! Map) return {};
      final values = decoded['values'] ?? decoded['_values'];
      if (values is Map && values['exposureData'] is String) {
        final parsed = jsonDecode(values['exposureData'] as String);
        if (parsed is Map<String, dynamic>) return parsed;
      }
    } catch (_) {}
    return {};
  }

  static List<String> intentTags(Map<String, dynamic> blob) => [
    if (blob['intentTags'] is List)
      for (final tag in blob['intentTags'] as List)
        if (_text(tag).isNotEmpty) _text(tag),
  ];

  /// Intención escrita en la pantalla antigua, si la biblia no tiene otra.
  static String narrative(Map<String, dynamic> blob, String? column) =>
      _text(column).isNotEmpty ? _text(column) : _text(blob['narrativeIntent']);

  static String row(BibleTextSpecsValue value, String label) {
    for (final (name, text) in value.rows) {
      if (name.trim().toLowerCase() == label.toLowerCase()) return text.trim();
    }
    return '';
  }

  static String _first(List<Object?> candidates) {
    for (final c in candidates) {
      if (_text(c).isNotEmpty) return _text(c);
    }
    return '';
  }

  static BibleTextSpecsValue globalValue(
    Map<String, String> values,
    Map<String, dynamic> blob, {
    String? defaultTStop,
    String? ndNotes,
    String? highlightBehavior,
    String? shadowBehavior,
  }) {
    if (values.containsKey(global)) {
      return BibleTextSpecsValue.decode(values[global]);
    }
    final shutter = _text(blob['shutterAngle']);
    return BibleTextSpecsValue(
      rows: [
        (rowIso, _first([blob['exposureIndex'], blob['baseIso']])),
        (rowTStop, _first([defaultTStop, blob['targetTStop']])),
        (
          rowShutter,
          shutter.isEmpty || shutter.contains('°') ? shutter : '$shutter°',
        ),
        (rowNd, _first([blob['ndFilter'], ndNotes])),
        (rowHighlights, _text(highlightBehavior)),
        (rowShadows, _text(shadowBehavior)),
      ],
    );
  }

  static List<BibleCard> chainCards(
    Map<String, String> values,
    Map<String, dynamic> blob,
  ) => values.containsKey(chain)
      ? BibleCard.listFrom(values[chain])
      : [
          BibleCard(
            title: 'Intensidad de la fuente',
            body: _text(blob['sourceIntensity']),
          ),
          BibleCard(
            title: 'Sensibilidad del sensor',
            body: _text(blob['sensorSensitivity']),
          ),
          BibleCard(
            title: 'Límite de la óptica',
            body: _text(blob['opticsLimit']),
          ),
        ];

  /// Dónde se colocan las altas y las sombras en la señal, en IRE.
  static List<BibleMeter> signalMeters(
    Map<String, String> values,
    Map<String, dynamic> blob,
  ) {
    if (values.containsKey(signal)) return BibleMeter.listFrom(values[signal]);
    String ire(Object? v) => _text(v).isEmpty ? '' : '${_text(v)} IRE';
    return [
      BibleMeter(
        label: 'Pico de altas luces',
        value: ire(blob['lumaPeak']),
        min: 0,
        max: 100,
      ),
      BibleMeter(
        label: 'Suelo de sombras',
        value: ire(blob['lumaCrush']),
        min: 0,
        max: 100,
      ),
    ];
  }

  static BibleTableValue blocksValue(
    Map<String, String> values,
    List<LegacyExposureBlock> legacy,
  ) => values.containsKey(blocks)
      ? BibleTableValue.decode(values[blocks])
      : BibleTableValue(
          columns: blockColumns,
          rows: [
            for (final b in legacy)
              [
                _text(b.name),
                _text(b.intent),
                _text(b.keyFill),
                _text(b.highlights),
                _text(b.shadows),
              ],
          ],
        );

  /// Exposición por localización. Antes se guardaba por identificador de
  /// set; [setNames] les pone nombre.
  static BibleTableValue byLocationValue(
    Map<String, String> values,
    Map<String, dynamic> blob, {
    Map<int, String> setNames = const {},
  }) {
    if (values.containsKey(byLocation)) {
      return BibleTableValue.decode(values[byLocation]);
    }
    final slots = blob['byLocation'];
    return BibleTableValue(
      columns: locationColumns,
      rows: [
        if (slots is Map)
          for (final entry in slots.entries)
            if (entry.value is Map)
              () {
                final slot = entry.value as Map;
                final id = int.tryParse(entry.key.toString());
                return [
                  setNames[id] ?? 'Set ${entry.key}',
                  _text(slot['iso']),
                  _text(slot['tStop']),
                  _text(slot['nd']),
                  _text(slot['shutter']),
                  _text(slot['approach']),
                  _text(slot['highlightStrategy']),
                  _text(slot['shadowStrategy']),
                  _text(slot['keyFill']),
                ];
              }(),
      ].where((row) => row.skip(1).any((c) => c.isNotEmpty)).toList(),
    );
  }

  /// [table] con una fila por cada localización de [names] que aún no esté.
  static BibleTableValue withLocations(
    BibleTableValue table,
    Iterable<String> names,
  ) {
    final have = {
      for (final row in table.rows)
        if (row.isNotEmpty) row.first.trim().toLowerCase(),
    };
    return BibleTableValue(
      columns: table.columns,
      rows: [
        ...table.rows,
        for (final name in names)
          if (have.add(name.trim().toLowerCase()))
            [name, ...List.filled(table.columns.length - 1, '')],
      ],
    );
  }
}
