import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../../core/database/app_database.dart';
import 'catalog_importer.dart';
import 'catalog_models.dart';

/// Hojas del Excel de catálogo técnico (v1.1+ / v1.7).
abstract final class CatalogExcelSheetNames {
  static const cameras = 'Cámaras';
  static const cameraModes = 'Modos_Cámara';
}

/// Resultado de importar cámaras + modos desde Excel de catálogo.
class CatalogExcelImportResult {
  final int camerasParsed;
  final int modesParsed;
  final int camerasUpserted;
  final int camerasSkippedCustom;
  final List<String> errors;
  final List<String> warnings;

  const CatalogExcelImportResult({
    required this.camerasParsed,
    required this.modesParsed,
    required this.camerasUpserted,
    required this.camerasSkippedCustom,
    this.errors = const [],
    this.warnings = const [],
  });

  bool get ok => errors.isEmpty;
}

/// Importador de catálogo oficial desde Excel (Cámaras + Modos_Cámara).
///
/// Camino separado del roundtrip de proyecto (`EquipmentSpreadsheetService`):
/// aquí sí se actualizan filas `isCustom=false`. Nunca sobrescribe custom.
///
/// Precedencia de modos: Excel sustituye `sensorModesJson` de esas cámaras
/// (convive con JSON embebido: el import Excel gana al aplicarse después).
/// No persiste `estado_dato` / auditoría / fuentes.
abstract final class CatalogExcelImporter {
  CatalogExcelImporter._();

  /// Parsea bytes `.xlsx` a entradas de catálogo (sin escribir DB).
  static ({
    List<CatalogCameraEntry> cameras,
    int modesParsed,
    List<String> errors,
    List<String> warnings,
  }) parseCamerasWorkbook(Uint8List bytes) {
    final errors = <String>[];
    final warnings = <String>[];
    late final Excel excel;
    try {
      excel = Excel.decodeBytes(bytes);
    } catch (e) {
      return (
        cameras: const [],
        modesParsed: 0,
        errors: ['No se pudo leer el Excel: $e'],
        warnings: const [],
      );
    }

    final cameraSheet = _findSheet(excel, CatalogExcelSheetNames.cameras);
    if (cameraSheet == null) {
      errors.add('Falta la pestaña "${CatalogExcelSheetNames.cameras}"');
      return (
        cameras: const [],
        modesParsed: 0,
        errors: errors,
        warnings: warnings,
      );
    }

    final modesSheet = _findSheet(excel, CatalogExcelSheetNames.cameraModes);
    final modesByCamera = <String, List<Map<String, dynamic>>>{};
    var modesParsed = 0;
    if (modesSheet != null) {
      final parsedModes = _parseModesSheet(modesSheet, errors, warnings);
      modesParsed = parsedModes.modeCount;
      modesByCamera.addAll(parsedModes.byCamera);
    } else {
      warnings.add(
        'Sin pestaña "${CatalogExcelSheetNames.cameraModes}": '
        'se importan cámaras sin modos estructurados',
      );
    }

    final cameras = _parseCamerasSheet(
      cameraSheet,
      modesByCamera: modesByCamera,
      errors: errors,
      warnings: warnings,
    );

    return (
      cameras: cameras,
      modesParsed: modesParsed,
      errors: errors,
      warnings: warnings,
    );
  }

  /// Parsea e importa cámaras oficiales a Drift desde bytes Excel.
  static Future<CatalogExcelImportResult> importCameras(
    AppDatabase db,
    Uint8List bytes,
  ) async {
    final parsed = parseCamerasWorkbook(bytes);
    if (parsed.cameras.isEmpty && parsed.errors.isNotEmpty) {
      return CatalogExcelImportResult(
        camerasParsed: 0,
        modesParsed: parsed.modesParsed,
        camerasUpserted: 0,
        camerasSkippedCustom: 0,
        errors: parsed.errors,
        warnings: parsed.warnings,
      );
    }

    final stats = await upsertCatalogCameras(db, parsed.cameras);
    return CatalogExcelImportResult(
      camerasParsed: parsed.cameras.length,
      modesParsed: parsed.modesParsed,
      camerasUpserted: stats.upserted,
      camerasSkippedCustom: stats.skippedCustom,
      errors: parsed.errors,
      warnings: parsed.warnings,
    );
  }

  /// Importa cámaras desde JSON ya normalizado (p. ej. export del Excel v1.7).
  ///
  /// Preferible cuando el `.xlsx` original no es legible por el paquete `excel`
  /// (libros ricos de Numbers/Excel). Shape: lista de [CatalogCameraEntry].
  static Future<CatalogExcelImportResult> importCamerasFromJson(
    AppDatabase db,
    String jsonStr,
  ) async {
    late final List<CatalogCameraEntry> cameras;
    try {
      cameras = parseCameraCatalog(jsonStr);
    } catch (e) {
      return CatalogExcelImportResult(
        camerasParsed: 0,
        modesParsed: 0,
        camerasUpserted: 0,
        camerasSkippedCustom: 0,
        errors: ['JSON de catálogo inválido: $e'],
      );
    }
    final modesParsed =
        cameras.fold<int>(0, (sum, c) => sum + c.sensorModes.length);
    final stats = await upsertCatalogCameras(db, cameras);
    return CatalogExcelImportResult(
      camerasParsed: cameras.length,
      modesParsed: modesParsed,
      camerasUpserted: stats.upserted,
      camerasSkippedCustom: stats.skippedCustom,
    );
  }

  /// Importa ópticas desde JSON normalizado (`CatalogLensEntry`).
  static Future<CatalogExcelImportResult> importLensesFromJson(
    AppDatabase db,
    String jsonStr,
  ) async {
    late final List<CatalogLensEntry> lenses;
    try {
      lenses = parseLensCatalog(jsonStr);
    } catch (e) {
      return CatalogExcelImportResult(
        camerasParsed: 0,
        modesParsed: 0,
        camerasUpserted: 0,
        camerasSkippedCustom: 0,
        errors: ['JSON de ópticas inválido: $e'],
      );
    }
    final stats = await upsertCatalogLenses(db, lenses);
    return CatalogExcelImportResult(
      camerasParsed: lenses.length,
      modesParsed: 0,
      camerasUpserted: stats.upserted,
      camerasSkippedCustom: stats.skippedCustom,
    );
  }

  /// Importa luces desde JSON normalizado (`CatalogLightEntry`).
  static Future<CatalogExcelImportResult> importLightsFromJson(
    AppDatabase db,
    String jsonStr,
  ) async {
    late final List<CatalogLightEntry> lights;
    try {
      lights = parseLightCatalog(jsonStr);
    } catch (e) {
      return CatalogExcelImportResult(
        camerasParsed: 0,
        modesParsed: 0,
        camerasUpserted: 0,
        camerasSkippedCustom: 0,
        errors: ['JSON de luces inválido: $e'],
      );
    }
    final stats = await upsertCatalogLights(db, lights);
    return CatalogExcelImportResult(
      camerasParsed: lights.length,
      modesParsed: 0,
      camerasUpserted: stats.upserted,
      camerasSkippedCustom: stats.skippedCustom,
    );
  }

  static Sheet? _findSheet(Excel excel, String name) {
    for (final key in excel.tables.keys) {
      if (key.trim().toLowerCase() == name.trim().toLowerCase()) {
        return excel.tables[key];
      }
    }
    return null;
  }

  static List<CatalogCameraEntry> _parseCamerasSheet(
    Sheet sheet, {
    required Map<String, List<Map<String, dynamic>>> modesByCamera,
    required List<String> errors,
    required List<String> warnings,
  }) {
    final header = _headerMap(sheet);
    final byId = <String, CatalogCameraEntry>{};

    for (var r = 1; r < sheet.rows.length; r++) {
      if (_rowIsEmpty(sheet, r)) continue;
      final rowLabel = '${CatalogExcelSheetNames.cameras} fila ${r + 1}';

      final externalId = _cellString(sheet, r, header, 'external_id')?.trim();
      if (externalId == null || externalId.isEmpty) {
        errors.add('$rowLabel: falta external_id');
        continue;
      }

      final action =
          _cellString(sheet, r, header, 'accion')?.toLowerCase().trim() ??
              'mantener';
      if (action == 'eliminar') {
        warnings.add('$rowLabel ($externalId): accion=eliminar ignorada '
            '(import de catálogo no borra filas)');
        continue;
      }

      final isCustom = _cellBool(sheet, r, header, 'es_custom');
      if (isCustom) {
        warnings.add(
          '$rowLabel ($externalId): es_custom=true omitida del catálogo oficial',
        );
        continue;
      }

      final brand = _cellString(sheet, r, header, 'marca')?.trim();
      final model = _cellString(sheet, r, header, 'modelo')?.trim();
      final width = _cellDouble(sheet, r, header, 'sensor_ancho_mm');
      final height = _cellDouble(sheet, r, header, 'sensor_alto_mm');
      if (brand == null ||
          brand.isEmpty ||
          model == null ||
          model.isEmpty ||
          width == null ||
          height == null) {
        errors.add('$rowLabel: faltan marca/modelo/sensor_mm');
        continue;
      }

      final nativeIso = _cellInt(sheet, r, header, 'iso_base') ??
          _cellInt(sheet, r, header, 'iso_base_1');
      final modes = List<Map<String, dynamic>>.from(
        modesByCamera[externalId] ?? const [],
      );

      byId[externalId] = CatalogCameraEntry(
        externalId: externalId,
        brand: brand,
        model: model,
        sensorWidthMm: width,
        sensorHeightMm: height,
        mountType: _cellString(sheet, r, header, 'mount')?.trim(),
        sensorModes: modes,
        dynamicRangeStops:
            _cellDouble(sheet, r, header, 'rango_dinamico_stops'),
        colorScience: _cellString(sheet, r, header, 'tipo_sensor')?.trim(),
        nativeIso: nativeIso,
        manufacturerUrl:
            _cellString(sheet, r, header, 'fuente_datos')?.trim(),
        vintage: _cellBool(sheet, r, header, 'vintage'),
        lukaCompatible: _cellBool(sheet, r, header, 'luka_compatible'),
      );
    }

    return byId.values.toList();
  }

  static ({
    Map<String, List<Map<String, dynamic>>> byCamera,
    int modeCount,
  }) _parseModesSheet(
    Sheet sheet,
    List<String> errors,
    List<String> warnings,
  ) {
    final header = _headerMap(sheet);
    final byCamera = <String, List<Map<String, dynamic>>>{};
    var modeCount = 0;

    for (var r = 1; r < sheet.rows.length; r++) {
      if (_rowIsEmpty(sheet, r)) continue;
      final rowLabel = '${CatalogExcelSheetNames.cameraModes} fila ${r + 1}';

      final cameraId =
          _cellString(sheet, r, header, 'camera_external_id')?.trim();
      final modeName = _cellString(sheet, r, header, 'modo_sensor')?.trim();
      final gateW = _cellDouble(sheet, r, header, 'gate_ancho_mm');
      final gateH = _cellDouble(sheet, r, header, 'gate_alto_mm');

      if (cameraId == null || cameraId.isEmpty) {
        errors.add('$rowLabel: falta camera_external_id');
        continue;
      }
      if (modeName == null ||
          modeName.isEmpty ||
          gateW == null ||
          gateH == null) {
        errors.add('$rowLabel: faltan modo_sensor / gate_mm');
        continue;
      }

      final cropX = _cellDouble(sheet, r, header, 'crop_x') ?? 1.0;
      final cropY = _cellDouble(sheet, r, header, 'crop_y');
      final resX = _cellInt(sheet, r, header, 'res_x');
      final resY = _cellInt(sheet, r, header, 'res_y');
      final aspect = _cellString(sheet, r, header, 'aspect_ratio')?.trim();
      final codec = _cellString(sheet, r, header, 'codec')?.trim();
      final fpsMax = _cellDouble(sheet, r, header, 'fps_max');

      final mode = <String, dynamic>{
        'name': modeName,
        'widthMm': gateW,
        'heightMm': gateH,
        'cropFactor': cropX,
        if (cropY != null) 'cropY': cropY,
        if (resX != null) 'maxWidthPx': resX,
        if (resY != null) 'maxHeightPx': resY,
        if (aspect != null && aspect.isNotEmpty) 'aspectRatio': aspect,
        if (codec != null && codec.isNotEmpty) 'codec': codec,
        if (fpsMax != null) 'fpsMax': fpsMax,
      };

      byCamera.putIfAbsent(cameraId, () => []).add(mode);
      modeCount++;
    }

    if (byCamera.isEmpty && modeCount == 0) {
      warnings.add(
        '${CatalogExcelSheetNames.cameraModes}: sin filas de modos válidas',
      );
    }

    return (byCamera: byCamera, modeCount: modeCount);
  }

  static Map<String, int> _headerMap(Sheet sheet) {
    final map = <String, int>{};
    if (sheet.rows.isEmpty) return map;
    final row = sheet.rows.first;
    for (var c = 0; c < row.length; c++) {
      final label = _cellValue(row[c])?.toString().trim().toLowerCase();
      if (label != null && label.isNotEmpty) {
        map[label] = c;
      }
    }
    return map;
  }

  static bool _rowIsEmpty(Sheet sheet, int rowIndex) {
    if (rowIndex >= sheet.rows.length) return true;
    final row = sheet.rows[rowIndex];
    for (final cell in row) {
      final v = _cellValue(cell);
      if (v != null && v.toString().trim().isNotEmpty) return false;
    }
    return true;
  }

  static String? _cellString(
    Sheet sheet,
    int row,
    Map<String, int> header,
    String key,
  ) {
    final col = header[key];
    if (col == null || row >= sheet.rows.length) return null;
    final cells = sheet.rows[row];
    if (col >= cells.length) return null;
    final v = _cellValue(cells[col]);
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static double? _cellDouble(
    Sheet sheet,
    int row,
    Map<String, int> header,
    String key,
  ) {
    final col = header[key];
    if (col == null || row >= sheet.rows.length) return null;
    final cells = sheet.rows[row];
    if (col >= cells.length) return null;
    final v = _cellValue(cells[col]);
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().trim().replaceAll(',', '.'));
  }

  static int? _cellInt(
    Sheet sheet,
    int row,
    Map<String, int> header,
    String key,
  ) {
    final d = _cellDouble(sheet, row, header, key);
    return d?.round();
  }

  static bool _cellBool(
    Sheet sheet,
    int row,
    Map<String, int> header,
    String key,
  ) {
    final raw = _cellString(sheet, row, header, key)?.toLowerCase();
    if (raw == null) return false;
    return raw == '1' ||
        raw == 'true' ||
        raw == 'yes' ||
        raw == 'sí' ||
        raw == 'si';
  }

  static dynamic _cellValue(Data? cell) {
    if (cell == null || cell.value == null) return null;
    final v = cell.value;
    if (v is TextCellValue) return v.value;
    if (v is IntCellValue) return v.value;
    if (v is DoubleCellValue) return v.value;
    if (v is BoolCellValue) return v.value;
    return v.toString();
  }
}
