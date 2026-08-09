import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/optics_lab/optics_calculator.dart';
import 'package:iris_dp/features/optics_lab/sensor_mode_utils.dart';
import 'package:iris_dp/shared/equipment/catalog_excel_importer.dart';
import 'package:iris_dp/shared/equipment/catalog_models.dart';

Uint8List _buildCatalogWorkbook({
  bool includeModes = true,
  bool includeCustomCamera = false,
}) {
  final excel = Excel.createExcel();
  excel.rename(excel.getDefaultSheet()!, CatalogExcelSheetNames.cameras);
  final cams = excel[CatalogExcelSheetNames.cameras];
  final camHeaders = [
    'external_id',
    'marca',
    'modelo',
    'sensor_ancho_mm',
    'sensor_alto_mm',
    'mount',
    'vintage',
    'luka_compatible',
    'es_custom',
    'accion',
    'iso_base',
    'tipo_sensor',
    'rango_dinamico_stops',
    'fuente_datos',
  ];
  for (var c = 0; c < camHeaders.length; c++) {
    cams
        .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
        .value = TextCellValue(camHeaders[c]);
  }
  void writeCamRow(int row, List<Object?> values) {
    for (var c = 0; c < values.length; c++) {
      final v = values[c];
      final cell = cams.cell(
        CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row),
      );
      if (v == null) continue;
      if (v is int) {
        cell.value = IntCellValue(v);
      } else if (v is double) {
        cell.value = DoubleCellValue(v);
      } else {
        cell.value = TextCellValue(v.toString());
      }
    }
  }

  writeCamRow(1, [
    'arri_alexa35',
    'ARRI',
    'ALEXA 35',
    27.99,
    19.22,
    'LPL',
    0,
    0,
    0,
    'mantener',
    800,
    'CMOS Bayer',
    17.0,
    'https://arri.example',
  ]);
  if (includeCustomCamera) {
    writeCamRow(2, [
      'user_custom_cam',
      'User',
      'Custom Cam',
      24.0,
      18.0,
      'PL',
      0,
      0,
      1,
      'mantener',
      400,
      null,
      null,
      null,
    ]);
  }

  if (includeModes) {
    final modes = excel[CatalogExcelSheetNames.cameraModes];
    final modeHeaders = [
      'camera_external_id',
      'marca',
      'modelo',
      'modo_sensor',
      'res_x',
      'res_y',
      'aspect_ratio',
      'gate_ancho_mm',
      'gate_alto_mm',
      'crop_x',
      'crop_y',
      'codec',
      'fps_max',
    ];
    for (var c = 0; c < modeHeaders.length; c++) {
      modes
          .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
          .value = TextCellValue(modeHeaders[c]);
    }
    void writeMode(int row, List<Object?> values) {
      for (var c = 0; c < values.length; c++) {
        final v = values[c];
        final cell = modes.cell(
          CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row),
        );
        if (v == null) continue;
        if (v is int) {
          cell.value = IntCellValue(v);
        } else if (v is double) {
          cell.value = DoubleCellValue(v);
        } else {
          cell.value = TextCellValue(v.toString());
        }
      }
    }

    writeMode(1, [
      'arri_alexa35',
      'ARRI',
      'ALEXA 35',
      '4.6K 3:2 Open Gate',
      4608,
      3164,
      '3:2',
      28.0,
      19.2,
      1.0,
      1.0,
      'ARRIRAW',
      120,
    ]);
    writeMode(2, [
      'arri_alexa35',
      'ARRI',
      'ALEXA 35',
      '4K 16:9',
      4096,
      2304,
      '16:9',
      24.9,
      14.0,
      1.12,
      1.37,
      'ProRes',
      120,
    ]);
  }

  return Uint8List.fromList(excel.encode()!);
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('parse agrupa modos por camera_external_id', () {
    final parsed = CatalogExcelImporter.parseCamerasWorkbook(
      _buildCatalogWorkbook(),
    );
    expect(parsed.errors, isEmpty);
    expect(parsed.cameras, hasLength(1));
    expect(parsed.modesParsed, 2);
    final cam = parsed.cameras.single;
    expect(cam.externalId, 'arri_alexa35');
    expect(cam.sensorModes, hasLength(2));
    expect(cam.sensorModes.first['name'], '4.6K 3:2 Open Gate');
    expect(cam.sensorModes.first['maxWidthPx'], 4608);
    expect(cam.nativeIso, 800);
    expect(cam.mountType, 'LPL');
  });

  test('import escribe sensorModesJson y no toca custom', () async {
    await db.insertCamera(
      CamerasCompanion.insert(
        brand: 'User',
        model: 'Custom Cam',
        sensorWidthMm: 24,
        sensorHeightMm: 18,
        externalId: const Value('user_custom_cam'),
        isCustom: const Value(true),
      ),
    );

    final result = await CatalogExcelImporter.importCameras(
      db,
      _buildCatalogWorkbook(includeCustomCamera: true),
    );

    expect(result.ok, isTrue);
    expect(result.camerasParsed, 1); // custom omitida en parse
    expect(result.camerasUpserted, 1);
    expect(result.warnings, isNotEmpty);

    final official = await db.getCameraByExternalId('arri_alexa35');
    expect(official, isNotNull);
    expect(official!.isCustom, isFalse);
    final modes = parseSensorModesJson(official.sensorModesJson);
    expect(modes, hasLength(2));
    expect(modes.first, isA<SensorModeSpec>());
    expect(modes.first.name, '4.6K 3:2 Open Gate');
    expect(modes.first.widthMm, 28.0);
    expect(modes.first.maxWidthPx, 4608);

    final custom = await db.getCameraByExternalId('user_custom_cam');
    expect(custom!.brand, 'User');
    expect(custom.isCustom, isTrue);
  });

  test('Excel v1.7 normalizado (JSON): import Cámaras + modos', () async {
    final path = File('docs/catalog/cameras_modos_v1_7.json');
    expect(path.existsSync(), isTrue);
    final result = await CatalogExcelImporter.importCamerasFromJson(
      db,
      path.readAsStringSync(),
    );
    expect(result.ok, isTrue);
    expect(result.camerasParsed, greaterThanOrEqualTo(60));
    expect(result.modesParsed, greaterThanOrEqualTo(10));
    expect(result.camerasUpserted, result.camerasParsed);

    final alexa = await db.getCameraByExternalId('arri_alexa35');
    expect(alexa, isNotNull);
    final modes = parseSensorModesJson(alexa!.sensorModesJson);
    expect(modes.length, greaterThanOrEqualTo(2));
    expect(modes.first, isA<SensorModeSpec>());
    expect(modes.first.name, contains('Open Gate'));

    // Roundtrip shape vía CatalogCameraEntry
    final entries = parseCameraCatalog(path.readAsStringSync());
    expect(entries.first.externalId, isNotEmpty);
  });

  test('Excel v1.7 JSON: import Ópticas no toca custom', () async {
    await db.insertLens(
      LensesCompanion.insert(
        brand: 'User',
        model: 'Custom Lens',
        focalLength: 50,
        minTStop: 1.5,
        formatCoverage: 'S35',
        externalId: const Value('user_custom_lens'),
        isCustom: const Value(true),
      ),
    );

    final path = File('docs/catalog/lenses_v1_7.json');
    expect(path.existsSync(), isTrue);
    final result = await CatalogExcelImporter.importLensesFromJson(
      db,
      path.readAsStringSync(),
    );
    expect(result.ok, isTrue);
    expect(result.camerasParsed, greaterThanOrEqualTo(400));
    expect(result.camerasUpserted, result.camerasParsed);

    final official = await db.getLensByExternalId('arri_signature_12');
    expect(official, isNotNull);
    expect(official!.isCustom, isFalse);
    expect(official.focalLength, 12);

    final custom = await db.getLensByExternalId('user_custom_lens');
    expect(custom!.brand, 'User');
    expect(custom.isCustom, isTrue);
  });

  test('Excel v1.7 JSON: import Luces', () async {
    final path = File('docs/catalog/lights_v1_7.json');
    expect(path.existsSync(), isTrue);
    final result = await CatalogExcelImporter.importLightsFromJson(
      db,
      path.readAsStringSync(),
    );
    expect(result.ok, isTrue);
    expect(result.camerasParsed, greaterThanOrEqualTo(90));
    expect(result.camerasUpserted, result.camerasParsed);

    final lights = await db.watchAllLights().first;
    final sky = lights.where((l) => l.externalId == 'arri_skypanel_s360');
    expect(sky, isNotEmpty);
    expect(sky.first.powerW, 900);
  });
}
