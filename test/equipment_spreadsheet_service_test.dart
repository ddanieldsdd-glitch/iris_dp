import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/equipment/data/equipment_spreadsheet_models.dart';
import 'package:iris_dp/features/equipment/services/equipment_spreadsheet_service.dart';

void main() {
  late AppDatabase db;
  late EquipmentSpreadsheetService service;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    service = EquipmentSpreadsheetService(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> _seedProject() => db.insertProject(
        ProjectsCompanion.insert(name: 'Proyecto test'),
      );

  Future<int> _seedCamera({
    required String externalId,
    String brand = 'ARRI',
    String model = 'ALEXA 35',
    bool isCustom = false,
  }) =>
      db.insertCamera(
        CamerasCompanion.insert(
          brand: brand,
          model: model,
          sensorWidthMm: 28,
          sensorHeightMm: 19,
          externalId: Value(externalId),
          isCustom: Value(isCustom),
        ),
      );

  group('EquipmentSpreadsheetService', () {
    test('export genera pestañas esperadas con datos del proyecto', () async {
      final projectId = await _seedProject();
      final cameraId = await _seedCamera(externalId: 'export_test_cam');
      await db.assignEquipmentToProject(
        projectId: projectId,
        equipmentType: 'camera',
        equipmentId: cameraId,
        source: 'rental',
        status: 'confirmed',
        notes: 'Principal',
        sortOrder: 1,
      );

      final bytes = await service.exportProjectEquipment(projectId: projectId);
      final parsed = service.parseBytes(bytes);

      expect(parsed.parseErrors, isEmpty);
      expect(parsed.projectRows, hasLength(1));
      expect(parsed.projectRows.first.externalId, 'export_test_cam');
      expect(parsed.projectRows.first.equipmentType, 'camera');
      expect(parsed.projectRows.first.status, 'confirmed');
      expect(parsed.projectRows.first.notes, 'Principal');
    });

    test('export incluye catálogo completo de cámaras y ópticas', () async {
      final projectId = await _seedProject();
      await _seedCamera(externalId: 'extra_export_cam');
      await db.insertLens(
        LensesCompanion.insert(
          brand: 'Zeiss',
          model: 'Supreme 50',
          focalLength: 50,
          minTStop: 1.5,
          formatCoverage: 'LF',
          externalId: const Value('extra_export_lens'),
        ),
      );

      final bytes = await service.exportProjectEquipment(projectId: projectId);
      final excel = Excel.decodeBytes(bytes);

      Sheet? camerasSheet;
      Sheet? lensesSheet;
      for (final name in excel.tables.keys) {
        if (name == EquipmentSheetNames.cameras) camerasSheet = excel.tables[name];
        if (name == EquipmentSheetNames.lenses) lensesSheet = excel.tables[name];
      }

      expect(camerasSheet, isNot(null));
      expect(lensesSheet, isNot(null));
      // Header + al menos catálogo embebido + cámara extra
      expect(camerasSheet!.rows.length, greaterThan(2));
      expect(lensesSheet!.rows.length, greaterThan(2));
    });

    test('import con external_id existente asigna correctamente', () async {
      final projectId = await _seedProject();
      await _seedCamera(
        externalId: 'test_camera_assign',
        brand: 'ARRI',
        model: 'ALEXA MINI LF',
      );

      final data = EquipmentSpreadsheetData(
        projectRows: const [
          ProjectEquipmentRow(
            rowIndex: 2,
            sortOrder: 1,
            equipmentType: 'camera',
            externalId: 'test_camera_assign',
            brand: 'ARRI',
            model: 'ALEXA MINI LF',
            source: 'owned',
            status: 'confirmed',
            notes: 'Desde Excel',
          ),
        ],
      );

      final preview = await service.buildPreview(
        projectId: projectId,
        data: data,
      );
      expect(preview.canApply, isTrue);
      expect(preview.assignmentsAdded, 1);

      await service.applyImport(projectId: projectId, data: data);

      final assigned = await db.getProjectEquipment(projectId);
      expect(assigned, hasLength(1));
      expect(assigned.first.source, 'owned');
      expect(assigned.first.status, 'confirmed');
      expect(assigned.first.notes, 'Desde Excel');
    });

    test('import crea custom y asigna cuando no existe en catálogo', () async {
      final projectId = await _seedProject();

      final data = EquipmentSpreadsheetData(
        customCameras: const [
          CustomCameraRow(
            rowIndex: 2,
            externalId: 'custom_red_komodo',
            brand: 'RED',
            model: 'KOMODO',
            sensorWidthMm: 27.03,
            sensorHeightMm: 14.26,
            mountType: 'RF',
          ),
        ],
        projectRows: const [
          ProjectEquipmentRow(
            rowIndex: 2,
            sortOrder: 1,
            equipmentType: 'camera',
            externalId: 'custom_red_komodo',
            brand: 'RED',
            model: 'KOMODO',
          ),
        ],
      );

      final preview = await service.buildPreview(
        projectId: projectId,
        data: data,
      );
      expect(preview.canApply, isTrue);
      expect(preview.customCreated, 1);
      expect(preview.assignmentsAdded, 1);

      await service.applyImport(projectId: projectId, data: data);

      final custom = await db.getCameraByExternalId('custom_red_komodo');
      expect(custom, isNot(null));
      expect(custom!.isCustom, isTrue);

      final assigned = await db.getProjectEquipment(projectId);
      expect(assigned, hasLength(1));
      expect(assigned.first.equipmentId, custom.id);
    });

    test('import no modifica entradas del catálogo embebido', () async {
      final projectId = await _seedProject();
      final cameraId = await _seedCamera(
        externalId: 'catalog_camera_protected',
        brand: 'ARRI',
        model: 'ALEXA 35 Protected',
        isCustom: false,
      );

      final data = EquipmentSpreadsheetData(
        customCameras: const [
          CustomCameraRow(
            rowIndex: 2,
            externalId: 'catalog_camera_protected',
            brand: 'Otra',
            model: 'Marca',
            sensorWidthMm: 10,
            sensorHeightMm: 10,
          ),
        ],
        projectRows: const [
          ProjectEquipmentRow(
            rowIndex: 2,
            sortOrder: 1,
            equipmentType: 'camera',
            externalId: 'catalog_camera_protected',
          ),
        ],
      );

      final preview = await service.buildPreview(
        projectId: projectId,
        data: data,
      );
      expect(preview.customUpdated, 0);
      expect(preview.warnings, isNotEmpty);

      await service.applyImport(projectId: projectId, data: data);

      final camera = await db.getCameraById(cameraId);
      expect(camera!.brand, 'ARRI');
      expect(camera.model, 'ALEXA 35 Protected');
      expect(camera.isCustom, isFalse);
    });

    test('errores de validación se reportan sin corromper DB', () async {
      final projectId = await _seedProject();
      await db.assignEquipmentToProject(
        projectId: projectId,
        equipmentType: 'camera',
        equipmentId: await _seedCamera(externalId: 'seed_cam'),
      );

      final data = EquipmentSpreadsheetData(
        projectRows: const [
          ProjectEquipmentRow(
            rowIndex: 2,
            sortOrder: 1,
            equipmentType: 'camera',
          ),
        ],
      );

      final preview = await service.buildPreview(
        projectId: projectId,
        data: data,
      );
      expect(preview.canApply, isFalse);
      expect(preview.errors, isNotEmpty);

      final before = await db.getProjectEquipment(projectId);
      expect(before, hasLength(1));
    });
  });
}
