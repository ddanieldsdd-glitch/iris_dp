import 'dart:convert';

import 'bible_table.dart';
import 'bible_text_specs.dart';

/// Contenido de los puntos de Textura, para la pantalla y el PDF.
///
/// Cada punto guarda su valor en `values[clave]`. Mientras no lo tenga, se
/// lee de donde estaba antes: el blob `textureData` y las columnas de la
/// biblia. Nada de lo que devuelve es un ejemplo: solo lo que el usuario
/// llegó a tocar en la pantalla antigua.
abstract final class TexturePoints {
  static const comparison = 'macroPreview';
  static const grain = 'filmGrain';
  static const diffusion = 'diffusion';
  static const noise = 'sensorNoise';

  static const rowEmulation = 'Emulación';
  static const rowHighlights = 'Altas luces';
  static const rowShadows = 'Sombras';

  static String _text(Object? v) => v?.toString().trim() ?? '';

  /// Datos de la pantalla antigua: iban juntos en `values['textureData']`.
  static Map<String, dynamic> blob(String? contentJson) {
    if (contentJson == null || contentJson.isEmpty) return {};
    try {
      final decoded = jsonDecode(contentJson);
      if (decoded is! Map) return {};
      final values = decoded['values'] ?? decoded['_values'];
      if (values is Map && values['textureData'] is String) {
        final parsed = jsonDecode(values['textureData'] as String);
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

  static String _percent(Object? v) =>
      v is num ? '${(v * 100).round()} %' : _text(v);

  static BibleTextSpecsValue grainValue(
    Map<String, String> values,
    Map<String, dynamic> blob, {
    String? grainLevel,
  }) {
    if (values.containsKey(grain)) {
      return BibleTextSpecsValue.decode(values[grain]);
    }
    // El grano apagado no se había decidido: sus números eran de partida.
    final on = blob['grainEnabled'] == true;
    final size = blob['grainSize'];
    return BibleTextSpecsValue(
      rows: [
        (
          rowEmulation,
          _text(blob['grainPreset']).isNotEmpty && on
              ? _text(blob['grainPreset'])
              : _text(grainLevel),
        ),
        ('Tamaño', on && size is num ? '${size.toStringAsFixed(1)} µm' : ''),
        ('Intensidad', on ? _percent(blob['grainIntensity']) : ''),
        ('Variación de color', on ? _percent(blob['grainColorVariation']) : ''),
      ],
    );
  }

  static List<BibleMeter> diffusionMeters(
    Map<String, String> values,
    Map<String, dynamic> blob, {
    String? diffusionNotes,
  }) {
    if (values.containsKey(diffusion)) {
      return BibleMeter.listFrom(values[diffusion]);
    }
    final on = blob['diffusionEnabled'] == true;
    if (!on) {
      return [
        if (_text(diffusionNotes).isNotEmpty)
          BibleMeter(label: _text(diffusionNotes), min: 0, max: 1),
      ];
    }
    final halation = blob['halationRadius'];
    return [
      BibleMeter(
        label: _text(blob['diffusionFilter']),
        value: _text(blob['diffusionDensity']),
        min: 0,
        max: 1,
      ),
      if (halation is num)
        BibleMeter(
          label: 'Halación',
          value: halation.toStringAsFixed(2),
          min: 0,
          max: 1,
        ),
    ];
  }

  /// «Filtro densidad» de la difusión, para la columna que leen Óptica y
  /// el resumen.
  static String diffusionSummary(List<BibleMeter> meters) => [
    for (final m in meters)
      if (m.label.trim().isNotEmpty && m.label != 'Halación')
        '${m.label.trim()} ${m.value.trim()}'.trim(),
  ].join(' · ');

  static BibleTextSpecsValue noiseValue(
    Map<String, String> values,
    Map<String, dynamic> blob, {
    String? highlightBehavior,
    String? shadowBehavior,
  }) => values.containsKey(noise)
      ? BibleTextSpecsValue.decode(values[noise])
      : BibleTextSpecsValue(
          text: _text(blob['noiseFloorDesc']),
          rows: [
            ('Ruido de color en sombras', _text(blob['shadowChromaNoise'])),
            ('Ruido de patrón fijo', _text(blob['fixedPatternNoise'])),
            ('Forzado', _text(blob['pushPullProcessing'])),
            (
              rowHighlights,
              _text(blob['highlightBehavior']).isNotEmpty
                  ? _text(blob['highlightBehavior'])
                  : _text(highlightBehavior),
            ),
            (
              rowShadows,
              _text(blob['shadowBehavior']).isNotEmpty
                  ? _text(blob['shadowBehavior'])
                  : _text(shadowBehavior),
            ),
          ],
        );
}
