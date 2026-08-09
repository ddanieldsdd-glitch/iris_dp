import '../../core/database/app_database.dart';

/// Etiquetas A-CAM / B-CAM para equipo asignado al proyecto.
abstract final class ProjectEquipmentRoles {
  static int? resolvePrimaryCameraId({
    required int? primaryCameraId,
    required List<Camera> assignedInOrder,
  }) {
    if (primaryCameraId != null) return primaryCameraId;
    if (assignedInOrder.isEmpty) return null;
    return assignedInOrder.first.id;
  }

  static String cameraRoleLabel({
    required int cameraId,
    required int? primaryCameraId,
    required List<Camera> assignedInOrder,
  }) {
    final primary = resolvePrimaryCameraId(
      primaryCameraId: primaryCameraId,
      assignedInOrder: assignedInOrder,
    );
    if (primary != null && cameraId == primary) return 'A-CAM';

    final backups =
        assignedInOrder.where((c) => c.id != primary).toList(growable: false);
    final index = backups.indexWhere((c) => c.id == cameraId);
    return switch (index) {
      0 => 'B-CAM',
      1 => 'C-CAM',
      _ => 'En proyecto',
    };
  }

  static String cameraRoleHint(String role) => switch (role) {
        'A-CAM' => 'Specs activas (Format / Lab)',
        'B-CAM' || 'C-CAM' => 'Asignada al proyecto · no altera specs',
        _ => 'Asignada al proyecto',
      };

  static bool drivesActiveSpecs({
    required int cameraId,
    required int? primaryCameraId,
    required List<Camera> assignedInOrder,
  }) {
    final primary = resolvePrimaryCameraId(
      primaryCameraId: primaryCameraId,
      assignedInOrder: assignedInOrder,
    );
    return primary != null && cameraId == primary;
  }
}
