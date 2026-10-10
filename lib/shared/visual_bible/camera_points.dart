import 'bible_cards.dart';
import 'bible_equipment.dart';
import 'bible_table.dart';
import 'bible_text_specs.dart';

/// Contenido de los puntos de Cámara y sensor, para la pantalla y el PDF.
///
/// Cada punto guarda su valor en `values[clave]`. Mientras no lo tenga, se
/// lee de donde estaba antes: el blob `cameraData` y las columnas de la
/// biblia. Nada de lo que devuelve es un ejemplo: lo que el usuario no
/// escribió sale vacío, salvo los datos de la ficha de la cámara elegida.
abstract final class CameraPoints {
  static const equipment = 'equipment';
  static const body = 'cameraBody';
  static const recording = 'recording';
  static const matrix = 'recordingMatrix';
  static const colorPipeline = 'colorPipeline';
  static const accessories = 'accessories';
  static const dataFlow = 'dataManagement';
  static const philosophy = 'philosophy';
  static const movements = 'movements';

  // Rótulos de los datos de fábrica; algunos se copian a columnas de la
  // biblia que leen otras pantallas.
  static const rowSensor = 'Sensor';
  static const rowMount = 'Montura';
  static const rowRange = 'Rango dinámico';
  static const rowNativeIso = 'ISO nativo';
  static const rowDualIso = 'ISO dual';
  static const rowMode = 'Modo de grabación';
  static const rowSensorUsed = 'Sensor usado';
  static const rowAspect = 'Relación de aspecto';
  static const rowModeFps = 'fps máximos del modo';
  static const rowLog = 'Curva log';
  static const rowWeight = 'Peso del cuerpo';
  static const rowResolution = 'Resolución de captura';
  static const rowCodec = 'Códec';
  static const rowBitDepth = 'Profundidad de bits';
  static const rowColorSpace = 'Espacio de color';
  static const rowFrameRate = 'Cadencia base';
  static const rowShutter = 'Obturador';
  static const rowSlowMo = 'Cámara lenta máx.';
  static const rowShowLut = 'LUT de rodaje';
  static const rowMovementStyle = 'Estilo de movimiento';

  static const matrixColumns = [
    'Formato',
    'Resolución',
    'Códec',
    'fps máx.',
    'GB/h',
  ];
  static const accessoryColumns = ['Grupo', 'Elemento', 'Detalle'];

  static String _text(Object? v) => v?.toString().trim() ?? '';

  static BibleTextSpecsValue _stored(
    Map<String, String> values,
    String key,
    BibleTextSpecsValue Function() legacy,
  ) => values.containsKey(key)
      ? BibleTextSpecsValue.decode(values[key])
      : legacy();

  /// Valor de la fila [label], o vacío.
  static String row(BibleTextSpecsValue value, String label) {
    for (final (name, text) in value.rows) {
      if (name.trim().toLowerCase() == label.toLowerCase()) return text.trim();
    }
    return '';
  }

  /// Las cámaras del proyecto. En biblias anteriores solo había una
  /// principal: sale como cámara A, tentativa.
  static List<BibleEquipmentItem> equipmentItems(
    Map<String, String> values, {
    int? legacyCameraId,
    String? legacyCameraName,
    Map<String, String> legacyFacts = const {},
  }) {
    if (values.containsKey(equipment)) {
      return BibleEquipmentItem.listFrom(values[equipment]);
    }
    final name = _text(legacyCameraName);
    return [
      if (name.isNotEmpty)
        BibleEquipmentItem(
          role: 'A',
          catalogId: legacyCameraId,
          name: name,
          facts: legacyFacts,
        ),
    ];
  }

  /// Ficha del cuerpo: lo escrito a mano manda; lo demás se completa en
  /// pantalla y en el PDF con [facts], los datos de la cámara A.
  static BibleTextSpecsValue bodyValue(
    Map<String, String> values,
    Map<String, dynamic> blob, {
    int? nativeIso,
  }) => _stored(
    values,
    body,
    () => BibleTextSpecsValue(
      text: _text(blob['isoNote']),
      rows: [
        (rowSensor, _text(blob['sensorLabel'])),
        (rowMount, _text(blob['mountLabel'])),
        (rowRange, _text(blob['dynamicRange'])),
        (rowNativeIso, nativeIso == null ? '' : '$nativeIso'),
        (rowDualIso, _text(blob['dualIso'])),
        (rowLog, ''),
        (rowWeight, ''),
      ],
    ),
  );

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

  static BibleTextSpecsValue recordingValue(
    Map<String, String> values,
    Map<String, dynamic> blob, {
    String? captureResolution,
    String? codec,
    String? colorScience,
    String? frameRate,
  }) => _stored(
    values,
    recording,
    () => BibleTextSpecsValue(
      rows: [
        (rowMode, ''),
        (rowResolution, _text(captureResolution)),
        (rowCodec, _text(codec)),
        (rowBitDepth, _text(blob['bitDepth'])),
        (
          rowColorSpace,
          _text(blob['colorSpace']).isNotEmpty
              ? _text(blob['colorSpace'])
              : _text(colorScience),
        ),
        (rowFrameRate, _text(frameRate)),
        (rowShutter, _text(blob['shutterAngle'])),
        (rowSlowMo, _text(blob['slowMoMax'])),
      ],
    ),
  );

  /// [value] con las filas de [changes] puestas: las que existen se
  /// sobrescriben en su sitio y las que no, se añaden al principio.
  static BibleTextSpecsValue withRows(
    BibleTextSpecsValue value,
    Map<String, String> changes,
  ) {
    final pending = {...changes};
    final rows = [
      for (final (label, text) in value.rows)
        (label, pending.remove(label) ?? text),
    ];
    return value.copyWith(
      rows: [
        for (final e in pending.entries) (e.key, e.value),
        ...rows,
      ],
    );
  }

  static BibleTableValue matrixValue(Map<String, String> values) =>
      values.containsKey(matrix)
      ? BibleTableValue.decode(values[matrix])
      : const BibleTableValue(columns: matrixColumns);

  static BibleTextSpecsValue colorPipelineValue(
    Map<String, String> values,
    Map<String, dynamic> blob, {
    String? showLut,
  }) => _stored(
    values,
    colorPipeline,
    () => BibleTextSpecsValue(
      rows: [
        (rowLog, ''),
        ('Gamma de monitorado', ''),
        ('Flujo de color', _text(blob['pipeline'])),
        ('Gamut', _text(blob['gamut'])),
        (
          rowShowLut,
          _text(blob['showLut']).isNotEmpty
              ? _text(blob['showLut'])
              : _text(showLut),
        ),
        ('Transformación de entrada', _text(blob['idt'])),
        ('Vista en set', _text(blob['setPreview'])),
        ('Suelo de ruido', _text(blob['noiseFloor'])),
      ],
    ),
  );

  /// Filtros, soportes e imprescindibles, en una sola tabla.
  static BibleTableValue accessoriesValue(
    Map<String, String> values,
    Map<String, dynamic> blob,
  ) {
    if (values.containsKey(accessories)) {
      return BibleTableValue.decode(values[accessories]);
    }
    List<List<String>> group(String name, Object? raw) => [
      if (raw is List)
        for (final e in raw)
          if (e is Map &&
              (_text(e['label']).isNotEmpty || _text(e['value']).isNotEmpty))
            [name, _text(e['label']), _text(e['value'])],
    ];
    return BibleTableValue(
      columns: accessoryColumns,
      rows: [
        ...group('Filtros', blob['filters']),
        ...group('Soportes de grabación', blob['media']),
        ...group('Imprescindibles', blob['essentials']),
      ],
    );
  }

  static List<BibleCard> dataFlowCards(
    Map<String, String> values,
    Map<String, dynamic> blob, {
    String? workflowPipeline,
  }) {
    if (values.containsKey(dataFlow)) {
      return BibleCard.listFrom(values[dataFlow]);
    }
    final flow = _text(blob['ditFlow']).isNotEmpty
        ? _text(blob['ditFlow'])
        : _text(workflowPipeline);
    final backups = [
      if (blob['backups'] is List)
        for (final b in blob['backups'] as List)
          if (_text(b).isNotEmpty) _text(b),
    ];
    String join(String a, String b) =>
        [a, b].where((e) => e.isNotEmpty).join('\n');
    return [
      BibleCard(
        title: 'Flujo en set',
        body: join(flow, _text(blob['ditFlowNote'])),
      ),
      BibleCard(
        title: 'Transferencia',
        body: join(_text(blob['transferProto']), _text(blob['transferNote'])),
      ),
      BibleCard(title: 'Copias', body: backups.join('\n')),
    ].where((card) => card.body.isNotEmpty).toList();
  }

  static BibleTextSpecsValue philosophyValue(
    Map<String, String> values, {
    String? philosophy,
    String? movementStyle,
  }) => _stored(
    values,
    CameraPoints.philosophy,
    () => BibleTextSpecsValue(
      text: _text(philosophy),
      rows: [(rowMovementStyle, _text(movementStyle))],
    ),
  );

  static List<BibleCard> movementCards(
    Map<String, String> values,
    List<Map<String, String>> legacy,
  ) {
    if (values.containsKey(movements)) {
      return BibleCard.listFrom(values[movements]);
    }
    return [
      for (final m in legacy)
        BibleCard(
          title: _text(m['movement']),
          body: [
            _text(m['narrative']),
            _text(m['reference']),
          ].where((e) => e.isNotEmpty).join('\n'),
        ),
    ].where((card) => !card.isEmpty).toList();
  }
}
