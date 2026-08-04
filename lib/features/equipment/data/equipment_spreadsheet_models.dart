/// Fila de la pestaña "Proyecto" del Excel de equipo.
class ProjectEquipmentRow {
  final int rowIndex;
  final int sortOrder;
  final String equipmentType;
  final String? externalId;
  final String? brand;
  final String? model;
  final String source;
  final String status;
  final String? notes;

  const ProjectEquipmentRow({
    required this.rowIndex,
    required this.sortOrder,
    required this.equipmentType,
    this.externalId,
    this.brand,
    this.model,
    this.source = 'rental',
    this.status = 'available',
    this.notes,
  });
}

/// Fila de cámara custom en Excel.
class CustomCameraRow {
  final int rowIndex;
  final String externalId;
  final String brand;
  final String model;
  final double sensorWidthMm;
  final double sensorHeightMm;
  final String? mountType;
  final bool vintage;
  final bool lukaCompatible;
  final String? notes;
  final String action;

  const CustomCameraRow({
    required this.rowIndex,
    required this.externalId,
    required this.brand,
    required this.model,
    required this.sensorWidthMm,
    required this.sensorHeightMm,
    this.mountType,
    this.vintage = false,
    this.lukaCompatible = false,
    this.notes,
    this.action = 'mantener',
  });
}

/// Fila de óptica custom en Excel.
class CustomLensRow {
  final int rowIndex;
  final String externalId;
  final String brand;
  final String model;
  final double focalLength;
  final double minTStop;
  final String formatCoverage;
  final String? mountType;
  final bool isAnamorphic;
  final String? notes;
  final String action;

  const CustomLensRow({
    required this.rowIndex,
    required this.externalId,
    required this.brand,
    required this.model,
    required this.focalLength,
    required this.minTStop,
    required this.formatCoverage,
    this.mountType,
    this.isAnamorphic = false,
    this.notes,
    this.action = 'mantener',
  });
}

/// Fila de luz custom en Excel.
class CustomLightRow {
  final int rowIndex;
  final String externalId;
  final String brand;
  final String model;
  final String lightType;
  final int powerW;
  final int colorTempMin;
  final int colorTempMax;
  final String? notes;
  final String action;

  const CustomLightRow({
    required this.rowIndex,
    required this.externalId,
    required this.brand,
    required this.model,
    required this.lightType,
    required this.powerW,
    required this.colorTempMin,
    required this.colorTempMax,
    this.notes,
    this.action = 'mantener',
  });
}

/// Datos parseados de un Excel de equipo.
class EquipmentSpreadsheetData {
  final List<ProjectEquipmentRow> projectRows;
  final List<CustomCameraRow> customCameras;
  final List<CustomLensRow> customLenses;
  final List<CustomLightRow> customLights;
  final List<String> parseErrors;

  const EquipmentSpreadsheetData({
    this.projectRows = const [],
    this.customCameras = const [],
    this.customLenses = const [],
    this.customLights = const [],
    this.parseErrors = const [],
  });

  bool get hasBlockingErrors => parseErrors.isNotEmpty;
}

/// Resumen de cambios previstos antes de aplicar importación.
class EquipmentImportPreview {
  final int assignmentsAdded;
  final int assignmentsRemoved;
  final int assignmentsUpdated;
  final int customCreated;
  final int customUpdated;
  final int customDeleted;
  final List<String> errors;
  final List<String> warnings;
  final EquipmentSpreadsheetData data;

  const EquipmentImportPreview({
    this.assignmentsAdded = 0,
    this.assignmentsRemoved = 0,
    this.assignmentsUpdated = 0,
    this.customCreated = 0,
    this.customUpdated = 0,
    this.customDeleted = 0,
    this.errors = const [],
    this.warnings = const [],
    required this.data,
  });

  bool get canApply => errors.isEmpty;

  int get totalChanges =>
      assignmentsAdded +
      assignmentsRemoved +
      assignmentsUpdated +
      customCreated +
      customUpdated +
      customDeleted;
}

/// Nombres de pestañas del Excel.
abstract final class EquipmentSheetNames {
  static const instructions = 'Instrucciones';
  static const project = 'Proyecto';
  static const cameras = 'Cámaras';
  static const lenses = 'Ópticas';
  static const lights = 'Luces';
  // Compatibilidad con exportaciones anteriores
  static const customCameras = 'Cámaras custom';
  static const customLenses = 'Ópticas custom';
  static const customLights = 'Luces custom';
}
