import 'dart:convert';

import '../../core/database/app_database.dart';
import 'catalog_excel_importer.dart';

/// Tipo de pack JSON del catálogo oficial (v1.7+).
enum OfficialCatalogJsonKind { cameras, lenses, lights }

/// Resumen de un import de catálogo oficial desde uno o más JSON.
class OfficialCatalogImportSummary {
  final int camerasUpserted;
  final int lensesUpserted;
  final int lightsUpserted;
  final int camerasSkippedCustom;
  final int lensesSkippedCustom;
  final int lightsSkippedCustom;
  final int modesParsed;
  final List<String> errors;
  final List<String> warnings;
  final List<String> importedKinds;

  const OfficialCatalogImportSummary({
    this.camerasUpserted = 0,
    this.lensesUpserted = 0,
    this.lightsUpserted = 0,
    this.camerasSkippedCustom = 0,
    this.lensesSkippedCustom = 0,
    this.lightsSkippedCustom = 0,
    this.modesParsed = 0,
    this.errors = const [],
    this.warnings = const [],
    this.importedKinds = const [],
  });

  bool get ok => errors.isEmpty && importedKinds.isNotEmpty;

  String get snackMessage {
    if (errors.isNotEmpty && importedKinds.isEmpty) {
      return errors.first;
    }
    final parts = <String>[];
    if (camerasUpserted > 0 || importedKinds.contains('cameras')) {
      parts.add('$camerasUpserted cámaras');
    }
    if (lensesUpserted > 0 || importedKinds.contains('lenses')) {
      parts.add('$lensesUpserted ópticas');
    }
    if (lightsUpserted > 0 || importedKinds.contains('lights')) {
      parts.add('$lightsUpserted luces');
    }
    final body = parts.isEmpty ? 'sin cambios' : parts.join(', ');
    if (errors.isNotEmpty) return 'Parcial: $body (${errors.length} error/es)';
    return 'Catálogo oficial: $body';
  }
}

/// Clasifica un JSON de catálogo por nombre de archivo y/o forma del payload.
OfficialCatalogJsonKind? classifyOfficialCatalogJson({
  required String fileName,
  required String jsonStr,
}) {
  final lower = fileName.toLowerCase();
  if (lower.contains('light')) return OfficialCatalogJsonKind.lights;
  if (lower.contains('lens')) return OfficialCatalogJsonKind.lenses;
  if (lower.contains('camera') || lower.contains('modo')) {
    return OfficialCatalogJsonKind.cameras;
  }

  try {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! List || decoded.isEmpty) return null;
    final first = decoded.first;
    if (first is! Map) return null;
    final map = Map<String, dynamic>.from(first);
    if (map.containsKey('sensorWidthMm') || map.containsKey('sensorModes')) {
      return OfficialCatalogJsonKind.cameras;
    }
    if (map.containsKey('focalLength') || map.containsKey('tStop')) {
      return OfficialCatalogJsonKind.lenses;
    }
    if (map.containsKey('powerW') ||
        map.containsKey('beamAngle') ||
        map.containsKey('lightType')) {
      return OfficialCatalogJsonKind.lights;
    }
  } catch (_) {
    return null;
  }
  return null;
}

/// Importa packs oficiales (Cámaras+modos / Ópticas / Luces) vía [CatalogExcelImporter].
///
/// Distinto del roundtrip de proyecto ([EquipmentSpreadsheetService]).
Future<OfficialCatalogImportSummary> importOfficialCatalogJsonFiles(
  AppDatabase db,
  List<({String name, String content})> files,
) async {
  if (files.isEmpty) {
    return const OfficialCatalogImportSummary(
      errors: ['No se seleccionó ningún archivo'],
    );
  }

  var camerasUpserted = 0;
  var lensesUpserted = 0;
  var lightsUpserted = 0;
  var camerasSkipped = 0;
  var lensesSkipped = 0;
  var lightsSkipped = 0;
  var modesParsed = 0;
  final errors = <String>[];
  final warnings = <String>[];
  final kinds = <String>[];

  for (final file in files) {
    final kind = classifyOfficialCatalogJson(
      fileName: file.name,
      jsonStr: file.content,
    );
    if (kind == null) {
      errors.add('${file.name}: no se reconoce como cámaras/ópticas/luces');
      continue;
    }

    switch (kind) {
      case OfficialCatalogJsonKind.cameras:
        final r = await CatalogExcelImporter.importCamerasFromJson(
          db,
          file.content,
        );
        camerasUpserted += r.camerasUpserted;
        camerasSkipped += r.camerasSkippedCustom;
        modesParsed += r.modesParsed;
        errors.addAll(r.errors.map((e) => '${file.name}: $e'));
        warnings.addAll(r.warnings.map((w) => '${file.name}: $w'));
        if (r.ok || r.camerasUpserted > 0) kinds.add('cameras');
      case OfficialCatalogJsonKind.lenses:
        final r = await CatalogExcelImporter.importLensesFromJson(
          db,
          file.content,
        );
        lensesUpserted += r.camerasUpserted;
        lensesSkipped += r.camerasSkippedCustom;
        errors.addAll(r.errors.map((e) => '${file.name}: $e'));
        warnings.addAll(r.warnings.map((w) => '${file.name}: $w'));
        if (r.ok || r.camerasUpserted > 0) kinds.add('lenses');
      case OfficialCatalogJsonKind.lights:
        final r = await CatalogExcelImporter.importLightsFromJson(
          db,
          file.content,
        );
        lightsUpserted += r.camerasUpserted;
        lightsSkipped += r.camerasSkippedCustom;
        errors.addAll(r.errors.map((e) => '${file.name}: $e'));
        warnings.addAll(r.warnings.map((w) => '${file.name}: $w'));
        if (r.ok || r.camerasUpserted > 0) kinds.add('lights');
    }
  }

  return OfficialCatalogImportSummary(
    camerasUpserted: camerasUpserted,
    lensesUpserted: lensesUpserted,
    lightsUpserted: lightsUpserted,
    camerasSkippedCustom: camerasSkipped,
    lensesSkippedCustom: lensesSkipped,
    lightsSkippedCustom: lightsSkipped,
    modesParsed: modesParsed,
    errors: errors,
    warnings: warnings,
    importedKinds: kinds.toSet().toList(),
  );
}
