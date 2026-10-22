import 'dart:convert';

import 'bible_table.dart';
import 'bible_text_specs.dart';

/// Contenido de los puntos de Workflow, para la pantalla y el PDF.
///
/// Cada punto guarda su valor en `values[clave]`. Mientras no lo tenga, se
/// lee del blob `workflowData` y de las columnas de la biblia. La tabla de
/// pasos nace con los nombres de los pasos y el resto en blanco: no trae
/// programas ni formatos de ejemplo.
abstract final class WorkflowPoints {
  static const steps = 'workflowSettings';
  static const team = 'dataTeam';
  static const delivery = 'delivery';

  static const stepColumns = ['Paso', 'Programa', 'Formato', 'Soporte'];
  static const stepNames = ['Cámara', 'Copias', 'Diarios', 'Color', 'Entrega'];

  static const rowColorSpace = 'Espacio de color de entrega';
  static const rowResolution = 'Resolución de entrega';
  static const rowCodec = 'Códec de rodaje';
  static const rowFrameRate = 'Cadencia';
  static const rowPipeline = 'Flujo';

  static String _text(Object? v) => v?.toString().trim() ?? '';

  static Map<String, dynamic> blob(Map<String, String> values) {
    final raw = values['workflowData'];
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return {};
  }

  static String row(BibleTextSpecsValue value, String label) {
    for (final (name, text) in value.rows) {
      if (name.trim().toLowerCase() == label.toLowerCase()) return text.trim();
    }
    return '';
  }

  static BibleTableValue stepsValue(Map<String, String> values) =>
      values.containsKey(steps)
      ? BibleTableValue.decode(values[steps])
      : BibleTableValue(
          columns: stepColumns,
          rows: [
            for (final name in stepNames) [name, '', '', ''],
          ],
        );

  /// La tabla tiene algo más que los nombres de los pasos.
  static bool stepsFilled(BibleTableValue table) => table.rows.any(
    (row) => row.skip(1).any((cell) => cell.trim().isNotEmpty),
  );

  static BibleTextSpecsValue teamValue(Map<String, String> values) {
    if (values.containsKey(team)) {
      return BibleTextSpecsValue.decode(values[team]);
    }
    final old = blob(values);
    return BibleTextSpecsValue(
      text: _text(old['technicalNote']),
      rows: [
        ('DIT', _text(old['ditName'])),
        ('Auxiliar de datos', _text(old['wranglerName'])),
      ],
    );
  }

  static BibleTextSpecsValue deliveryValue(
    Map<String, String> values, {
    String? deliveryColorSpace,
    String? resolutionNotes,
    String? workflowPipeline,
  }) => values.containsKey(delivery)
      ? BibleTextSpecsValue.decode(values[delivery])
      : BibleTextSpecsValue(
          rows: [
            (rowPipeline, _text(workflowPipeline)),
            (rowCodec, ''),
            (rowFrameRate, ''),
            (rowResolution, _text(resolutionNotes)),
            (rowColorSpace, _text(deliveryColorSpace)),
          ],
        );

  /// Lo que viene de Cámara mientras aquí no se escriba otra cosa.
  static Map<String, String> fromCamera({String? codec, String? frameRate}) => {
    if (_text(codec).isNotEmpty) rowCodec: _text(codec),
    if (_text(frameRate).isNotEmpty) rowFrameRate: _text(frameRate),
  };

  /// [value] con las filas vacías completadas con [facts].
  static BibleTextSpecsValue withFacts(
    BibleTextSpecsValue value,
    Map<String, String> facts,
  ) => value.copyWith(
    rows: [
      for (final (label, text) in value.rows)
        (label, text.trim().isNotEmpty ? text : (facts[label] ?? '')),
    ],
  );
}
