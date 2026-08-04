import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:excel/excel.dart';

import '../../../core/database/app_database.dart';
import '../data/equipment_spreadsheet_models.dart';

class EquipmentSpreadsheetService {
  EquipmentSpreadsheetService(this._db);

  final AppDatabase _db;

  static const _validTypes = {'camera', 'lens', 'light'};
  static const _validSources = {'rental', 'owned', 'borrowed'};
  static const _validStatuses = {'available', 'pending', 'confirmed'};

  /// Exporta la lista del proyecto y equipos custom a bytes .xlsx.
  Future<Uint8List> exportProjectEquipment({
    required int projectId,
    String? projectName,
  }) async {
    final excel = Excel.createExcel();
    excel.rename(excel.getDefaultSheet()!, EquipmentSheetNames.instructions);
    excel[EquipmentSheetNames.project];
    excel[EquipmentSheetNames.cameras];
    excel[EquipmentSheetNames.lenses];
    excel[EquipmentSheetNames.lights];

    _writeInstructionsSheet(excel);
    await _writeProjectSheet(excel, projectId);
    await _writeCamerasSheet(excel);
    await _writeLensesSheet(excel);
    await _writeLightsSheet(excel);

    final encoded = excel.encode();
    if (encoded == null) {
      throw StateError('No se pudo generar el archivo Excel');
    }
    return Uint8List.fromList(encoded);
  }

  /// Parsea un archivo .xlsx sin modificar la base de datos.
  EquipmentSpreadsheetData parseBytes(Uint8List bytes) {
    final errors = <String>[];
    try {
      final excel = Excel.decodeBytes(bytes);
      final projectRows = _parseProjectSheet(excel, errors);
      final customCameras = _parseCamerasSheet(excel, errors);
      final customLenses = _parseLensesSheet(excel, errors);
      final customLights = _parseLightsSheet(excel, errors);
      return EquipmentSpreadsheetData(
        projectRows: projectRows,
        customCameras: customCameras,
        customLenses: customLenses,
        customLights: customLights,
        parseErrors: errors,
      );
    } catch (e) {
      errors.add('No se pudo leer el archivo Excel: $e');
      return EquipmentSpreadsheetData(parseErrors: errors);
    }
  }

  /// Calcula el resumen de cambios antes de aplicar.
  Future<EquipmentImportPreview> buildPreview({
    required int projectId,
    required EquipmentSpreadsheetData data,
  }) async {
    if (data.hasBlockingErrors) {
      return EquipmentImportPreview(errors: data.parseErrors, data: data);
    }

    final errors = <String>[...data.parseErrors];
    final warnings = <String>[];

    var customCreated = 0;
    var customUpdated = 0;
    var customDeleted = 0;

    for (final row in data.customCameras) {
      final result = await _previewCustomCamera(row, errors, warnings);
      switch (result) {
        case _CustomPreview.created:
          customCreated++;
        case _CustomPreview.updated:
          customUpdated++;
        case _CustomPreview.deleted:
          customDeleted++;
        case _CustomPreview.skipped:
          break;
      }
    }
    for (final row in data.customLenses) {
      final result = await _previewCustomLens(row, errors, warnings);
      switch (result) {
        case _CustomPreview.created:
          customCreated++;
        case _CustomPreview.updated:
          customUpdated++;
        case _CustomPreview.deleted:
          customDeleted++;
        case _CustomPreview.skipped:
          break;
      }
    }
    for (final row in data.customLights) {
      final result = await _previewCustomLight(row, errors, warnings);
      switch (result) {
        case _CustomPreview.created:
          customCreated++;
        case _CustomPreview.updated:
          customUpdated++;
        case _CustomPreview.deleted:
          customDeleted++;
        case _CustomPreview.skipped:
          break;
      }
    }

    final current = await _db.getProjectEquipment(projectId);
    final resolved = <({ProjectEquipmentRow row, int equipmentId})>[];

    for (final row in data.projectRows) {
      final equipmentId = await _resolveEquipmentId(
        row: row,
        data: data,
        errors: errors,
        dryRun: true,
      );
      if (equipmentId == null) continue;
      resolved.add((row: row, equipmentId: equipmentId));
    }

    var added = 0;
    var removed = 0;
    var updated = 0;

    final desiredKeys = resolved
        .map((r) => '${r.row.equipmentType}:${r.equipmentId}')
        .toSet();
    final currentKeys = current
        .map((a) => '${a.equipmentType}:${a.equipmentId}')
        .toSet();

    removed = current.where((a) {
      final key = '${a.equipmentType}:${a.equipmentId}';
      return !desiredKeys.contains(key);
    }).length;

    for (final item in resolved) {
      final existing = current.where((a) =>
          a.equipmentType == item.row.equipmentType &&
          a.equipmentId == item.equipmentId);
      if (existing.isEmpty) {
        added++;
      } else {
        final row = existing.first;
        if (row.source != item.row.source ||
            row.status != item.row.status ||
            row.notes != item.row.notes ||
            row.sortOrder != item.row.sortOrder) {
          updated++;
        }
      }
    }

    return EquipmentImportPreview(
      assignmentsAdded: added,
      assignmentsRemoved: removed,
      assignmentsUpdated: updated,
      customCreated: customCreated,
      customUpdated: customUpdated,
      customDeleted: customDeleted,
      errors: errors,
      warnings: warnings,
      data: data,
    );
  }

  /// Aplica la importación. Lanza si hay errores bloqueantes.
  Future<EquipmentImportPreview> applyImport({
    required int projectId,
    required EquipmentSpreadsheetData data,
  }) async {
    final preview = await buildPreview(projectId: projectId, data: data);
    if (!preview.canApply) return preview;

    await _db.transaction(() async {
      for (final row in data.customCameras) {
        await _applyCustomCamera(row);
      }
      for (final row in data.customLenses) {
        await _applyCustomLens(row);
      }
      for (final row in data.customLights) {
        await _applyCustomLight(row);
      }

      final resolved = <({ProjectEquipmentRow row, int equipmentId})>[];
      final resolveErrors = <String>[];
      for (final row in data.projectRows) {
        final equipmentId = await _resolveEquipmentId(
          row: row,
          data: data,
          errors: resolveErrors,
          dryRun: false,
        );
        if (equipmentId == null) continue;
        resolved.add((row: row, equipmentId: equipmentId));
      }
      if (resolveErrors.isNotEmpty) {
        throw StateError(resolveErrors.join('\n'));
      }

      await _db.clearProjectEquipment(projectId);

      for (final item in resolved) {
        await _db.assignEquipmentToProject(
          projectId: projectId,
          equipmentType: item.row.equipmentType,
          equipmentId: item.equipmentId,
          source: item.row.source,
          status: item.row.status,
          notes: item.row.notes,
          sortOrder: item.row.sortOrder,
        );
      }
    });

    return preview;
  }

  // ── Export helpers ────────────────────────────────────────────────

  void _writeInstructionsSheet(Excel excel) {
    final sheet = excel[EquipmentSheetNames.instructions];
    const lines = [
      'IRIS DP — Lista de equipo',
      '',
      '1. Exporta desde la app → edita en Excel → importa de nuevo.',
      '2. Pestaña "Proyecto": equipo asignado al proyecto (editable).',
      '   Columnas: orden, tipo, external_id, marca, modelo, fuente, estado, notas',
      '   tipo: camera | lens | light',
      '   fuente: rental | owned | borrowed',
      '   estado: available | pending | confirmed',
      '3. Pestañas Cámaras / Ópticas / Luces: catálogo completo.',
      '   es_custom=true → se importa como equipo personalizado.',
      '   es_custom=false → referencia del catálogo (no se modifica al importar).',
      '   accion: mantener (default) | eliminar (solo custom)',
      '4. Matching: external_id > marca+modelo+tipo',
    ];
    for (var i = 0; i < lines.length; i++) {
      _setCell(sheet, 0, i, lines[i]);
    }
  }

  Future<void> _writeProjectSheet(Excel excel, int projectId) async {
    final sheet = excel[EquipmentSheetNames.project];
    const headers = [
      'orden',
      'tipo',
      'external_id',
      'marca',
      'modelo',
      'fuente',
      'estado',
      'notas',
    ];
    for (var c = 0; c < headers.length; c++) {
      _setCell(sheet, c, 0, headers[c]);
    }

    final assignments = await _db.getProjectEquipment(projectId);
    var row = 1;
    for (final assignment in assignments) {
      final details = await _equipmentDetails(
        assignment.equipmentType,
        assignment.equipmentId,
      );
      if (details == null) continue;
      _setCell(sheet, 0, row, assignment.sortOrder);
      _setCell(sheet, 1, row, assignment.equipmentType);
      _setCell(sheet, 2, row, _exportExternalId(
        externalId: details.externalId,
        id: assignment.equipmentId,
        brand: details.brand,
        model: details.model,
      ));
      _setCell(sheet, 3, row, details.brand);
      _setCell(sheet, 4, row, details.model);
      _setCell(sheet, 5, row, assignment.source);
      _setCell(sheet, 6, row, assignment.status);
      _setCell(sheet, 7, row, assignment.notes);
      row++;
    }
  }

  Future<void> _writeCamerasSheet(Excel excel) async {
    final sheet = excel[EquipmentSheetNames.cameras];
    const headers = [
      'external_id',
      'marca',
      'modelo',
      'sensor_ancho_mm',
      'sensor_alto_mm',
      'mount',
      'vintage',
      'luka_compatible',
      'notas',
      'es_custom',
      'accion',
    ];
    for (var c = 0; c < headers.length; c++) {
      _setCell(sheet, c, 0, headers[c]);
    }
    final items = await _db.getAllCameras();
    for (var i = 0; i < items.length; i++) {
      final c = items[i];
      final row = i + 1;
      _setCell(sheet, 0, row, _exportExternalId(
        externalId: c.externalId,
        id: c.id,
        brand: c.brand,
        model: c.model,
      ));
      _setCell(sheet, 1, row, c.brand);
      _setCell(sheet, 2, row, c.model);
      _setCell(sheet, 3, row, c.sensorWidthMm);
      _setCell(sheet, 4, row, c.sensorHeightMm);
      _setCell(sheet, 5, row, c.mountType);
      _setCell(sheet, 6, row, c.vintage);
      _setCell(sheet, 7, row, c.lukaCompatible);
      _setCell(sheet, 8, row, c.notes);
      _setCell(sheet, 9, row, c.isCustom);
      _setCell(sheet, 10, row, 'mantener');
    }
  }

  Future<void> _writeLensesSheet(Excel excel) async {
    final sheet = excel[EquipmentSheetNames.lenses];
    const headers = [
      'external_id',
      'marca',
      'modelo',
      'distancia_focal',
      't_stop_min',
      'cobertura',
      'mount',
      'anamorfica',
      'notas',
      'es_custom',
      'accion',
    ];
    for (var c = 0; c < headers.length; c++) {
      _setCell(sheet, c, 0, headers[c]);
    }
    final items = await _db.getAllLenses();
    for (var i = 0; i < items.length; i++) {
      final l = items[i];
      final row = i + 1;
      _setCell(sheet, 0, row, _exportExternalId(
        externalId: l.externalId,
        id: l.id,
        brand: l.brand,
        model: l.model,
      ));
      _setCell(sheet, 1, row, l.brand);
      _setCell(sheet, 2, row, l.model);
      _setCell(sheet, 3, row, l.focalLength);
      _setCell(sheet, 4, row, l.minTStop);
      _setCell(sheet, 5, row, l.formatCoverage);
      _setCell(sheet, 6, row, l.mountType);
      _setCell(sheet, 7, row, l.isAnamorphic);
      _setCell(sheet, 8, row, l.notes);
      _setCell(sheet, 9, row, l.isCustom);
      _setCell(sheet, 10, row, 'mantener');
    }
  }

  Future<void> _writeLightsSheet(Excel excel) async {
    final sheet = excel[EquipmentSheetNames.lights];
    const headers = [
      'external_id',
      'marca',
      'modelo',
      'tipo_luz',
      'potencia_w',
      'temp_min',
      'temp_max',
      'notas',
      'es_custom',
      'accion',
    ];
    for (var c = 0; c < headers.length; c++) {
      _setCell(sheet, c, 0, headers[c]);
    }
    final items = await _db.getAllLights();
    for (var i = 0; i < items.length; i++) {
      final l = items[i];
      final row = i + 1;
      _setCell(sheet, 0, row, _exportExternalId(
        externalId: l.externalId,
        id: l.id,
        brand: l.brand,
        model: l.model,
      ));
      _setCell(sheet, 1, row, l.brand);
      _setCell(sheet, 2, row, l.model);
      _setCell(sheet, 3, row, l.lightType);
      _setCell(sheet, 4, row, l.powerW);
      _setCell(sheet, 5, row, l.colorTempMin);
      _setCell(sheet, 6, row, l.colorTempMax);
      _setCell(sheet, 7, row, l.notes);
      _setCell(sheet, 8, row, l.isCustom);
      _setCell(sheet, 9, row, 'mantener');
    }
  }

  // ── Parse helpers ─────────────────────────────────────────────────

  List<ProjectEquipmentRow> _parseProjectSheet(
    Excel excel,
    List<String> errors,
  ) {
    final sheet = _findSheet(excel, EquipmentSheetNames.project);
    if (sheet == null) {
      errors.add('Falta la pestaña "${EquipmentSheetNames.project}"');
      return [];
    }

    final header = _headerMap(sheet, 0);
    final rows = <ProjectEquipmentRow>[];
    for (var r = 1; r < sheet.rows.length; r++) {
      if (_rowIsEmpty(sheet, r)) continue;

      final sortOrder = _cellInt(sheet, r, header, 'orden') ?? r;
      final type = _cellString(sheet, r, header, 'tipo')?.toLowerCase().trim();
      final externalId = _cellString(sheet, r, header, 'external_id')?.trim();
      final brand = _cellString(sheet, r, header, 'marca')?.trim();
      final model = _cellString(sheet, r, header, 'modelo')?.trim();
      final source =
          _cellString(sheet, r, header, 'fuente')?.toLowerCase().trim() ??
              'rental';
      final status =
          _cellString(sheet, r, header, 'estado')?.toLowerCase().trim() ??
              'available';
      final notes = _cellString(sheet, r, header, 'notas');

      if (type == null || type.isEmpty) {
        errors.add('Proyecto fila ${r + 1}: falta tipo');
        continue;
      }
      if (!_validTypes.contains(type)) {
        errors.add('Proyecto fila ${r + 1}: tipo inválido "$type"');
        continue;
      }
      if ((externalId == null || externalId.isEmpty) &&
          (brand == null || brand.isEmpty || model == null || model.isEmpty)) {
        errors.add(
          'Proyecto fila ${r + 1}: indica external_id o marca+modelo',
        );
        continue;
      }
      if (!_validSources.contains(source)) {
        errors.add('Proyecto fila ${r + 1}: fuente inválida "$source"');
        continue;
      }
      if (!_validStatuses.contains(status)) {
        errors.add('Proyecto fila ${r + 1}: estado inválido "$status"');
        continue;
      }

      rows.add(ProjectEquipmentRow(
        rowIndex: r + 1,
        sortOrder: sortOrder,
        equipmentType: type,
        externalId: externalId?.isEmpty == true ? null : externalId,
        brand: brand,
        model: model,
        source: source,
        status: status,
        notes: notes,
      ));
    }
    return rows;
  }

  List<CustomCameraRow> _parseCamerasSheet(
    Excel excel,
    List<String> errors,
  ) {
    final rows = <CustomCameraRow>[];
    final full = _findSheet(excel, EquipmentSheetNames.cameras);
    if (full != null) {
      rows.addAll(_parseCameraRows(
        full,
        errors,
        sheetLabel: EquipmentSheetNames.cameras,
        requireCustomFlag: true,
      ));
    }
    final legacy = _findSheet(excel, EquipmentSheetNames.customCameras);
    if (legacy != null && legacy != full) {
      rows.addAll(_parseCameraRows(
        legacy,
        errors,
        sheetLabel: EquipmentSheetNames.customCameras,
        requireCustomFlag: false,
      ));
    }
    return _dedupeCustomCameraRows(rows);
  }

  List<CustomCameraRow> _parseCameraRows(
    Sheet sheet,
    List<String> errors, {
    required String sheetLabel,
    required bool requireCustomFlag,
  }) {
    final header = _headerMap(sheet, 0);
    final rows = <CustomCameraRow>[];
    for (var r = 1; r < sheet.rows.length; r++) {
      if (_rowIsEmpty(sheet, r)) continue;

      final externalId = _cellString(sheet, r, header, 'external_id')?.trim();
      final brand = _cellString(sheet, r, header, 'marca')?.trim();
      final model = _cellString(sheet, r, header, 'modelo')?.trim();
      final sensorW = _cellDouble(sheet, r, header, 'sensor_ancho_mm');
      final sensorH = _cellDouble(sheet, r, header, 'sensor_alto_mm');
      final isCustom = _cellBool(sheet, r, header, 'es_custom');
      final action =
          _cellString(sheet, r, header, 'accion')?.toLowerCase().trim() ??
              'mantener';

      if (externalId == null || externalId.isEmpty) {
        errors.add('$sheetLabel fila ${r + 1}: falta external_id');
        continue;
      }
      if (requireCustomFlag && !isCustom && action != 'eliminar') continue;
      if (action == 'eliminar') {
        rows.add(CustomCameraRow(
          rowIndex: r + 1,
          externalId: externalId,
          brand: brand ?? '',
          model: model ?? '',
          sensorWidthMm: sensorW ?? 0,
          sensorHeightMm: sensorH ?? 0,
          action: action,
        ));
        continue;
      }
      if (brand == null ||
          brand.isEmpty ||
          model == null ||
          model.isEmpty ||
          sensorW == null ||
          sensorH == null) {
        errors.add(
          '$sheetLabel fila ${r + 1}: faltan marca, modelo o sensor',
        );
        continue;
      }

      rows.add(CustomCameraRow(
        rowIndex: r + 1,
        externalId: externalId,
        brand: brand,
        model: model,
        sensorWidthMm: sensorW,
        sensorHeightMm: sensorH,
        mountType: _cellString(sheet, r, header, 'mount'),
        vintage: _cellBool(sheet, r, header, 'vintage'),
        lukaCompatible: _cellBool(sheet, r, header, 'luka_compatible'),
        notes: _cellString(sheet, r, header, 'notas'),
        action: action,
      ));
    }
    return rows;
  }

  List<CustomLensRow> _parseLensesSheet(
    Excel excel,
    List<String> errors,
  ) {
    final rows = <CustomLensRow>[];
    final full = _findSheet(excel, EquipmentSheetNames.lenses);
    if (full != null) {
      rows.addAll(_parseLensRows(
        full,
        errors,
        sheetLabel: EquipmentSheetNames.lenses,
        requireCustomFlag: true,
      ));
    }
    final legacy = _findSheet(excel, EquipmentSheetNames.customLenses);
    if (legacy != null && legacy != full) {
      rows.addAll(_parseLensRows(
        legacy,
        errors,
        sheetLabel: EquipmentSheetNames.customLenses,
        requireCustomFlag: false,
      ));
    }
    return _dedupeCustomLensRows(rows);
  }

  List<CustomLensRow> _parseLensRows(
    Sheet sheet,
    List<String> errors, {
    required String sheetLabel,
    required bool requireCustomFlag,
  }) {
    final header = _headerMap(sheet, 0);
    final rows = <CustomLensRow>[];
    for (var r = 1; r < sheet.rows.length; r++) {
      if (_rowIsEmpty(sheet, r)) continue;

      final externalId = _cellString(sheet, r, header, 'external_id')?.trim();
      final brand = _cellString(sheet, r, header, 'marca')?.trim();
      final model = _cellString(sheet, r, header, 'modelo')?.trim();
      final focal = _cellDouble(sheet, r, header, 'distancia_focal');
      final tStop = _cellDouble(sheet, r, header, 't_stop_min');
      final coverage = _cellString(sheet, r, header, 'cobertura')?.trim();
      final isCustom = _cellBool(sheet, r, header, 'es_custom');
      final action =
          _cellString(sheet, r, header, 'accion')?.toLowerCase().trim() ??
              'mantener';

      if (externalId == null || externalId.isEmpty) {
        errors.add('$sheetLabel fila ${r + 1}: falta external_id');
        continue;
      }
      if (requireCustomFlag && !isCustom && action != 'eliminar') continue;
      if (action == 'eliminar') {
        rows.add(CustomLensRow(
          rowIndex: r + 1,
          externalId: externalId,
          brand: brand ?? '',
          model: model ?? '',
          focalLength: focal ?? 0,
          minTStop: tStop ?? 2.0,
          formatCoverage: coverage ?? 'FF',
          action: action,
        ));
        continue;
      }
      if (brand == null ||
          brand.isEmpty ||
          model == null ||
          model.isEmpty ||
          focal == null ||
          tStop == null ||
          coverage == null ||
          coverage.isEmpty) {
        errors.add(
          '$sheetLabel fila ${r + 1}: faltan campos obligatorios',
        );
        continue;
      }

      rows.add(CustomLensRow(
        rowIndex: r + 1,
        externalId: externalId,
        brand: brand,
        model: model,
        focalLength: focal,
        minTStop: tStop,
        formatCoverage: coverage,
        mountType: _cellString(sheet, r, header, 'mount'),
        isAnamorphic: _cellBool(sheet, r, header, 'anamorfica'),
        notes: _cellString(sheet, r, header, 'notas'),
        action: action,
      ));
    }
    return rows;
  }

  List<CustomLightRow> _parseLightsSheet(
    Excel excel,
    List<String> errors,
  ) {
    final rows = <CustomLightRow>[];
    final full = _findSheet(excel, EquipmentSheetNames.lights);
    if (full != null) {
      rows.addAll(_parseLightRows(
        full,
        errors,
        sheetLabel: EquipmentSheetNames.lights,
        requireCustomFlag: true,
      ));
    }
    final legacy = _findSheet(excel, EquipmentSheetNames.customLights);
    if (legacy != null && legacy != full) {
      rows.addAll(_parseLightRows(
        legacy,
        errors,
        sheetLabel: EquipmentSheetNames.customLights,
        requireCustomFlag: false,
      ));
    }
    return _dedupeCustomLightRows(rows);
  }

  List<CustomLightRow> _parseLightRows(
    Sheet sheet,
    List<String> errors, {
    required String sheetLabel,
    required bool requireCustomFlag,
  }) {
    final header = _headerMap(sheet, 0);
    final rows = <CustomLightRow>[];
    for (var r = 1; r < sheet.rows.length; r++) {
      if (_rowIsEmpty(sheet, r)) continue;

      final externalId = _cellString(sheet, r, header, 'external_id')?.trim();
      final brand = _cellString(sheet, r, header, 'marca')?.trim();
      final model = _cellString(sheet, r, header, 'modelo')?.trim();
      final lightType = _cellString(sheet, r, header, 'tipo_luz')?.trim();
      final powerW = _cellInt(sheet, r, header, 'potencia_w');
      final tempMin = _cellInt(sheet, r, header, 'temp_min');
      final tempMax = _cellInt(sheet, r, header, 'temp_max');
      final isCustom = _cellBool(sheet, r, header, 'es_custom');
      final action =
          _cellString(sheet, r, header, 'accion')?.toLowerCase().trim() ??
              'mantener';

      if (externalId == null || externalId.isEmpty) {
        errors.add('$sheetLabel fila ${r + 1}: falta external_id');
        continue;
      }
      if (requireCustomFlag && !isCustom && action != 'eliminar') continue;
      if (action == 'eliminar') {
        rows.add(CustomLightRow(
          rowIndex: r + 1,
          externalId: externalId,
          brand: brand ?? '',
          model: model ?? '',
          lightType: lightType ?? 'led_panel',
          powerW: powerW ?? 0,
          colorTempMin: tempMin ?? 3200,
          colorTempMax: tempMax ?? 5600,
          action: action,
        ));
        continue;
      }
      if (brand == null ||
          brand.isEmpty ||
          model == null ||
          model.isEmpty ||
          lightType == null ||
          lightType.isEmpty ||
          powerW == null ||
          tempMin == null ||
          tempMax == null) {
        errors.add('$sheetLabel fila ${r + 1}: faltan campos obligatorios');
        continue;
      }

      rows.add(CustomLightRow(
        rowIndex: r + 1,
        externalId: externalId,
        brand: brand,
        model: model,
        lightType: lightType,
        powerW: powerW,
        colorTempMin: tempMin,
        colorTempMax: tempMax,
        notes: _cellString(sheet, r, header, 'notas'),
        action: action,
      ));
    }
    return rows;
  }

  List<CustomCameraRow> _dedupeCustomCameraRows(List<CustomCameraRow> rows) {
    final byId = <String, CustomCameraRow>{};
    for (final row in rows) {
      byId[row.externalId] = row;
    }
    return byId.values.toList();
  }

  List<CustomLensRow> _dedupeCustomLensRows(List<CustomLensRow> rows) {
    final byId = <String, CustomLensRow>{};
    for (final row in rows) {
      byId[row.externalId] = row;
    }
    return byId.values.toList();
  }

  List<CustomLightRow> _dedupeCustomLightRows(List<CustomLightRow> rows) {
    final byId = <String, CustomLightRow>{};
    for (final row in rows) {
      byId[row.externalId] = row;
    }
    return byId.values.toList();
  }

  // ── Custom apply / preview ────────────────────────────────────────

  Future<_CustomPreview> _previewCustomCamera(
    CustomCameraRow row,
    List<String> errors,
    List<String> warnings,
  ) async {
    if (row.action == 'eliminar') {
      final existing = await _db.getCameraByExternalId(row.externalId);
      if (existing == null) return _CustomPreview.skipped;
      if (!existing.isCustom) {
        warnings.add(
          'Cámara "${row.externalId}": no se elimina (catálogo embebido)',
        );
        return _CustomPreview.skipped;
      }
      return _CustomPreview.deleted;
    }

    final existing = await _db.getCameraByExternalId(row.externalId);
    if (existing != null) {
      if (!existing.isCustom) {
        warnings.add(
          'Cámara "${row.externalId}": ignorada (catálogo embebido)',
        );
        return _CustomPreview.skipped;
      }
      return _CustomPreview.updated;
    }
    return _CustomPreview.created;
  }

  Future<_CustomPreview> _previewCustomLens(
    CustomLensRow row,
    List<String> errors,
    List<String> warnings,
  ) async {
    if (row.action == 'eliminar') {
      final existing = await _db.getLensByExternalId(row.externalId);
      if (existing == null) return _CustomPreview.skipped;
      if (!existing.isCustom) {
        warnings.add(
          'Óptica "${row.externalId}": no se elimina (catálogo embebido)',
        );
        return _CustomPreview.skipped;
      }
      return _CustomPreview.deleted;
    }

    final existing = await _db.getLensByExternalId(row.externalId);
    if (existing != null) {
      if (!existing.isCustom) {
        warnings.add(
          'Óptica "${row.externalId}": ignorada (catálogo embebido)',
        );
        return _CustomPreview.skipped;
      }
      return _CustomPreview.updated;
    }
    return _CustomPreview.created;
  }

  Future<_CustomPreview> _previewCustomLight(
    CustomLightRow row,
    List<String> errors,
    List<String> warnings,
  ) async {
    if (row.action == 'eliminar') {
      final existing = await _db.getLightByExternalId(row.externalId);
      if (existing == null) return _CustomPreview.skipped;
      if (!existing.isCustom) {
        warnings.add(
          'Luz "${row.externalId}": no se elimina (catálogo embebido)',
        );
        return _CustomPreview.skipped;
      }
      return _CustomPreview.deleted;
    }

    final existing = await _db.getLightByExternalId(row.externalId);
    if (existing != null) {
      if (!existing.isCustom) {
        warnings.add(
          'Luz "${row.externalId}": ignorada (catálogo embebido)',
        );
        return _CustomPreview.skipped;
      }
      return _CustomPreview.updated;
    }
    return _CustomPreview.created;
  }

  Future<void> _applyCustomCamera(CustomCameraRow row) async {
    if (row.action == 'eliminar') {
      final existing = await _db.getCameraByExternalId(row.externalId);
      if (existing != null && existing.isCustom) {
        await _db.deleteCamera(existing.id);
      }
      return;
    }

    final existing = await _db.getCameraByExternalId(row.externalId);
    if (existing != null) {
      if (!existing.isCustom) return;
      await _db.updateCamera(existing.copyWith(
        brand: row.brand,
        model: row.model,
        sensorWidthMm: row.sensorWidthMm,
        sensorHeightMm: row.sensorHeightMm,
        mountType: Value(row.mountType),
        vintage: row.vintage,
        lukaCompatible: row.lukaCompatible,
        notes: Value(row.notes),
      ));
      return;
    }

    await _db.insertCamera(CamerasCompanion.insert(
      brand: row.brand,
      model: row.model,
      sensorWidthMm: row.sensorWidthMm,
      sensorHeightMm: row.sensorHeightMm,
      mountType: Value(row.mountType),
      vintage: Value(row.vintage),
      lukaCompatible: Value(row.lukaCompatible),
      notes: Value(row.notes),
      externalId: Value(row.externalId),
      isCustom: const Value(true),
    ));
  }

  Future<void> _applyCustomLens(CustomLensRow row) async {
    if (row.action == 'eliminar') {
      final existing = await _db.getLensByExternalId(row.externalId);
      if (existing != null && existing.isCustom) {
        await _db.deleteLens(existing.id);
      }
      return;
    }

    final existing = await _db.getLensByExternalId(row.externalId);
    if (existing != null) {
      if (!existing.isCustom) return;
      await _db.updateLens(existing.copyWith(
        brand: row.brand,
        model: row.model,
        focalLength: row.focalLength,
        minTStop: row.minTStop,
        formatCoverage: row.formatCoverage,
        mountType: Value(row.mountType),
        isAnamorphic: row.isAnamorphic,
        notes: Value(row.notes),
      ));
      return;
    }

    await _db.insertLens(LensesCompanion.insert(
      brand: row.brand,
      model: row.model,
      focalLength: row.focalLength,
      minTStop: row.minTStop,
      formatCoverage: row.formatCoverage,
      mountType: Value(row.mountType),
      isAnamorphic: Value(row.isAnamorphic),
      notes: Value(row.notes),
      externalId: Value(row.externalId),
      isCustom: const Value(true),
    ));
  }

  Future<void> _applyCustomLight(CustomLightRow row) async {
    if (row.action == 'eliminar') {
      final existing = await _db.getLightByExternalId(row.externalId);
      if (existing != null && existing.isCustom) {
        await _db.deleteLight(existing.id);
      }
      return;
    }

    final existing = await _db.getLightByExternalId(row.externalId);
    if (existing != null) {
      if (!existing.isCustom) return;
      await _db.updateLight(existing.copyWith(
        brand: row.brand,
        model: row.model,
        lightType: row.lightType,
        powerW: row.powerW,
        colorTempMin: row.colorTempMin,
        colorTempMax: row.colorTempMax,
        notes: Value(row.notes),
      ));
      return;
    }

    await _db.insertLight(LightsCompanion.insert(
      brand: row.brand,
      model: row.model,
      lightType: row.lightType,
      powerW: row.powerW,
      colorTempMin: row.colorTempMin,
      colorTempMax: row.colorTempMax,
      notes: Value(row.notes),
      externalId: Value(row.externalId),
      isCustom: const Value(true),
    ));
  }

  // ── Equipment resolution ──────────────────────────────────────────

  Future<int?> _resolveEquipmentId({
    required ProjectEquipmentRow row,
    required EquipmentSpreadsheetData data,
    required List<String> errors,
    required bool dryRun,
  }) async {
    if (row.externalId != null && row.externalId!.isNotEmpty) {
      final id = await _lookupByExternalId(row.equipmentType, row.externalId!);
      if (id != null) return id;
    }

    if (row.brand != null &&
        row.brand!.isNotEmpty &&
        row.model != null &&
        row.model!.isNotEmpty) {
      final id = await _lookupByBrandModel(
        row.equipmentType,
        row.brand!,
        row.model!,
      );
      if (id != null) return id;
    }

    // Buscar en filas custom del Excel por external_id o marca+modelo
    final customId = _findCustomExternalId(row, data);
    if (customId != null) {
      final id = await _lookupByExternalId(row.equipmentType, customId);
      if (id != null) return id;
    }

    if (!dryRun) {
      // Crear custom mínimo si hay marca+modelo
      if (row.brand != null &&
          row.brand!.isNotEmpty &&
          row.model != null &&
          row.model!.isNotEmpty) {
        final extId = customId ?? _slugify(row.brand!, row.model!);
        return _createMinimalCustom(row, extId);
      }
    } else if (row.brand != null &&
        row.model != null &&
        customId != null) {
      // En preview, asumir que se creará
      return -1;
    }

    errors.add(
      'Proyecto fila ${row.rowIndex}: no se encontró equipo '
      '(${row.externalId ?? "${row.brand} ${row.model}"})',
    );
    return null;
  }

  String? _findCustomExternalId(
    ProjectEquipmentRow row,
    EquipmentSpreadsheetData data,
  ) {
    if (row.externalId != null && row.externalId!.isNotEmpty) {
      return row.externalId;
    }
    switch (row.equipmentType) {
      case 'camera':
        for (final c in data.customCameras) {
          if (c.brand == row.brand && c.model == row.model) return c.externalId;
        }
      case 'lens':
        for (final l in data.customLenses) {
          if (l.brand == row.brand && l.model == row.model) return l.externalId;
        }
      case 'light':
        for (final l in data.customLights) {
          if (l.brand == row.brand && l.model == row.model) return l.externalId;
        }
    }
    return null;
  }

  Future<int?> _lookupByExternalId(String type, String externalId) async {
    final idMatch = RegExp(r'^id_(\d+)$').firstMatch(externalId);
    if (idMatch != null) {
      final id = int.parse(idMatch.group(1)!);
      switch (type) {
        case 'camera':
          return (await _db.getCameraById(id))?.id;
        case 'lens':
          return (await _db.getLensById(id))?.id;
        case 'light':
          return (await _db.getLightById(id))?.id;
      }
    }

    switch (type) {
      case 'camera':
        return (await _db.getCameraByExternalId(externalId))?.id;
      case 'lens':
        return (await _db.getLensByExternalId(externalId))?.id;
      case 'light':
        return (await _db.getLightByExternalId(externalId))?.id;
      default:
        return null;
    }
  }

  Future<int?> _lookupByBrandModel(
    String type,
    String brand,
    String model,
  ) async {
    switch (type) {
      case 'camera':
        return (await _db.getCameraByBrandModel(brand, model))?.id;
      case 'lens':
        return (await _db.getLensByBrandModel(brand, model))?.id;
      case 'light':
        return (await _db.getLightByBrandModel(brand, model))?.id;
      default:
        return null;
    }
  }

  Future<int> _createMinimalCustom(ProjectEquipmentRow row, String extId) async {
    switch (row.equipmentType) {
      case 'camera':
        return _db.insertCamera(CamerasCompanion.insert(
          brand: row.brand!,
          model: row.model!,
          sensorWidthMm: 24,
          sensorHeightMm: 13.5,
          externalId: Value(extId),
          isCustom: const Value(true),
        ));
      case 'lens':
        return _db.insertLens(LensesCompanion.insert(
          brand: row.brand!,
          model: row.model!,
          focalLength: 50,
          minTStop: 2.0,
          formatCoverage: 'FF',
          externalId: Value(extId),
          isCustom: const Value(true),
        ));
      case 'light':
        return _db.insertLight(LightsCompanion.insert(
          brand: row.brand!,
          model: row.model!,
          lightType: 'led_panel',
          powerW: 100,
          colorTempMin: 3200,
          colorTempMax: 5600,
          externalId: Value(extId),
          isCustom: const Value(true),
        ));
      default:
        throw ArgumentError('tipo desconocido: ${row.equipmentType}');
    }
  }

  Future<({String brand, String model, String? externalId})?> _equipmentDetails(
    String type,
    int id,
  ) async {
    switch (type) {
      case 'camera':
        final c = await _db.getCameraById(id);
        if (c == null) return null;
        return (brand: c.brand, model: c.model, externalId: c.externalId);
      case 'lens':
        final l = await _db.getLensById(id);
        if (l == null) return null;
        return (brand: l.brand, model: l.model, externalId: l.externalId);
      case 'light':
        final l = await _db.getLightById(id);
        if (l == null) return null;
        return (brand: l.brand, model: l.model, externalId: l.externalId);
      default:
        return null;
    }
  }

  // ── Cell utilities ────────────────────────────────────────────────

  Sheet? _findSheet(Excel excel, String name) {
    for (final key in excel.tables.keys) {
      if (key.trim().toLowerCase() == name.trim().toLowerCase()) {
        return excel.tables[key];
      }
    }
    return excel.tables[name];
  }

  Map<String, int> _headerMap(Sheet sheet, int headerRow) {
    final map = <String, int>{};
    if (headerRow >= sheet.rows.length) return map;
    final row = sheet.rows[headerRow];
    for (var c = 0; c < row.length; c++) {
      final label = _cellValue(row[c])?.toString().trim().toLowerCase();
      if (label != null && label.isNotEmpty) {
        map[label] = c;
      }
    }
    return map;
  }

  bool _rowIsEmpty(Sheet sheet, int rowIndex) {
    if (rowIndex >= sheet.rows.length) return true;
    final row = sheet.rows[rowIndex];
    for (final cell in row) {
      final v = _cellValue(cell);
      if (v != null && v.toString().trim().isNotEmpty) return false;
    }
    return true;
  }

  String? _cellString(
    Sheet sheet,
    int row,
    Map<String, int> header,
    String column,
  ) {
    final col = header[column.toLowerCase()];
    if (col == null || row >= sheet.rows.length) return null;
    final rowData = sheet.rows[row];
    if (col >= rowData.length) return null;
    return _cellValue(rowData[col])?.toString();
  }

  int? _cellInt(
    Sheet sheet,
    int row,
    Map<String, int> header,
    String column,
  ) {
    final s = _cellString(sheet, row, header, column);
    if (s == null || s.isEmpty) return null;
    return int.tryParse(s) ?? double.tryParse(s)?.round();
  }

  double? _cellDouble(
    Sheet sheet,
    int row,
    Map<String, int> header,
    String column,
  ) {
    final s = _cellString(sheet, row, header, column);
    if (s == null || s.isEmpty) return null;
    return double.tryParse(s.replaceAll(',', '.'));
  }

  bool _cellBool(
    Sheet sheet,
    int row,
    Map<String, int> header,
    String column,
  ) {
    final s = _cellString(sheet, row, header, column)?.toLowerCase().trim();
    if (s == null || s.isEmpty) return false;
    return s == 'true' || s == '1' || s == 'sí' || s == 'si' || s == 'yes';
  }

  void _setCell(Sheet sheet, int col, int row, Object? value) {
    final cell = sheet.cell(
      CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row),
    );
    if (value == null) {
      cell.value = null;
    } else if (value is int) {
      cell.value = IntCellValue(value);
    } else if (value is double) {
      cell.value = DoubleCellValue(value);
    } else if (value is bool) {
      cell.value = BoolCellValue(value);
    } else {
      cell.value = TextCellValue(value.toString());
    }
  }

  dynamic _cellValue(Data? cell) {
    if (cell == null || cell.value == null) return null;
    final v = cell.value;
    if (v is TextCellValue) return v.value;
    if (v is IntCellValue) return v.value;
    if (v is DoubleCellValue) return v.value;
    if (v is BoolCellValue) return v.value;
    return v.toString();
  }

  static String _exportExternalId({
    required String? externalId,
    required int id,
    required String brand,
    required String model,
  }) {
    if (externalId != null && externalId.trim().isNotEmpty) {
      return externalId.trim();
    }
    return _slugify(brand, model, fallbackId: id);
  }

  static String _slugify(String brand, String model, {int? fallbackId}) {
    final raw = fallbackId == null
        ? 'custom_${brand}_$model'.toLowerCase()
        : 'id_$fallbackId';
    if (fallbackId != null) return raw;
    return raw
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }
}

enum _CustomPreview { created, updated, deleted, skipped }
