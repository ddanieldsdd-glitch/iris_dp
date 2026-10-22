import 'dart:convert';

import 'bible_palette.dart';
import 'bible_table.dart';
import 'bible_text_specs.dart';

/// Contenido de los puntos de Color e imagen, para la pantalla y el PDF.
///
/// «LUT» y «Temperatura base» guardan su valor en `values[clave]` y, hasta
/// entonces, se leen del blob `colorData` y de las columnas de la biblia.
/// Las paletas por bloque siguen en su tabla (`VisualBibleColorBlocks`),
/// que también leen el moodboard, el resumen y la planta.
abstract final class ColorPoints {
  static const lut = 'lut';
  static const baseTemp = 'baseTemp';
  static const blocks = 'blocks';

  static const rowWorkingLut = 'LUT de trabajo';
  static const rowShowLut = 'LUT de rodaje';

  static String _text(Object? v) => v?.toString().trim() ?? '';

  /// Datos de la pantalla antigua: iban juntos en `values['colorData']`.
  static Map<String, dynamic> blob(String? contentJson) {
    if (contentJson == null || contentJson.isEmpty) return {};
    try {
      final decoded = jsonDecode(contentJson);
      if (decoded is! Map) return {};
      final values = decoded['values'] ?? decoded['_values'];
      if (values is Map && values['colorData'] is String) {
        final parsed = jsonDecode(values['colorData'] as String);
        if (parsed is Map<String, dynamic>) return parsed;
      }
    } catch (_) {}
    return {};
  }

  static String row(BibleTextSpecsValue value, String label) {
    for (final (name, text) in value.rows) {
      if (name.trim().toLowerCase() == label.toLowerCase()) return text.trim();
    }
    return '';
  }

  static String _tags(Object? raw) => [
    if (raw is List)
      for (final t in raw)
        if (_text(t).isNotEmpty) _text(t),
  ].join(', ');

  static BibleTextSpecsValue lutValue(
    Map<String, String> values,
    Map<String, dynamic> blob, {
    String? workingLut,
    String? showLut,
  }) => values.containsKey(lut)
      ? BibleTextSpecsValue.decode(values[lut])
      : BibleTextSpecsValue(
          rows: [
            (rowWorkingLut, _text(workingLut)),
            ('Carácter del LUT de trabajo', _tags(blob['workingLutTags'])),
            (rowShowLut, _text(showLut)),
            ('Carácter del LUT de rodaje', _tags(blob['creativeLutTags'])),
          ],
        );

  /// Temperatura base en kelvin. Antes se tomaba del primer bloque de
  /// color si la pantalla no tenía la suya.
  static List<BibleMeter> baseTempMeters(
    Map<String, String> values,
    Map<String, dynamic> blob, {
    int? firstBlockKelvin,
  }) {
    if (values.containsKey(baseTemp)) {
      return BibleMeter.listFrom(values[baseTemp]);
    }
    final kelvin = (blob['kelvin'] as num?)?.round() ?? firstBlockKelvin;
    return [
      BibleMeter(
        label: _text(blob['kelvinLabel']).isNotEmpty
            ? _text(blob['kelvinLabel'])
            : 'Temperatura base',
        value: kelvin == null ? '' : '$kelvin K',
        min: 2000,
        max: 10000,
      ),
    ];
  }

  /// Colores de un bloque: en la base son «Nombre|#RRGGBB» o «#RRGGBB».
  /// [names] son los nombres que la pantalla antigua guardaba aparte.
  static List<BiblePaletteColor> swatches(
    List<String> stored, {
    Map<String, String> names = const {},
  }) => [
    for (final raw in stored)
      if (raw.trim().isNotEmpty)
        () {
          final parts = raw.split('|');
          var hex = parts.last.trim().toUpperCase();
          if (!hex.startsWith('#')) hex = '#$hex';
          final name = parts.length > 1 ? parts.first.trim() : '';
          return BiblePaletteColor(
            hex: hex,
            name: name.isNotEmpty ? name : (names[hex] ?? ''),
          );
        }(),
  ];

  static List<String> storeSwatches(List<BiblePaletteColor> colors) => [
    for (final c in colors)
      c.name.trim().isEmpty ? c.hex : '${c.name.trim()}|${c.hex}',
  ];

  static Map<String, String> swatchNames(Map<String, dynamic> blob) => {
    if (blob['swatchNames'] is Map)
      for (final e in (blob['swatchNames'] as Map).entries)
        e.key.toString().toUpperCase(): e.value.toString(),
  };
}
