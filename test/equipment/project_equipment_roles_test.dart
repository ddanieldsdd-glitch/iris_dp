import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/shared/equipment/project_equipment_roles.dart';

void main() {
  group('ProjectEquipmentRoles', () {
    test('asigna A-CAM a principal y B-CAM a la segunda en orden', () {
      final a = Camera(
        id: 1,
        brand: 'ARRI',
        model: 'A',
        sensorWidthMm: 28,
        sensorHeightMm: 19,
        isCustom: false,
        vintage: false,
        lukaCompatible: false,
      );
      final b = Camera(
        id: 2,
        brand: 'RED',
        model: 'B',
        sensorWidthMm: 28,
        sensorHeightMm: 19,
        isCustom: false,
        vintage: false,
        lukaCompatible: false,
      );

      expect(
        ProjectEquipmentRoles.cameraRoleLabel(
          cameraId: 1,
          primaryCameraId: 1,
          assignedInOrder: [a, b],
        ),
        'A-CAM',
      );
      expect(
        ProjectEquipmentRoles.cameraRoleLabel(
          cameraId: 2,
          primaryCameraId: 1,
          assignedInOrder: [a, b],
        ),
        'B-CAM',
      );
    });

    test('A-CAM sigue en la cámara principal aunque la lista venga en otro orden', () {
      final a = Camera(
        id: 1,
        brand: 'ARRI',
        model: 'A',
        sensorWidthMm: 28,
        sensorHeightMm: 19,
        isCustom: false,
        vintage: false,
        lukaCompatible: false,
      );
      final b = Camera(
        id: 2,
        brand: 'RED',
        model: 'B',
        sensorWidthMm: 28,
        sensorHeightMm: 19,
        isCustom: false,
        vintage: false,
        lukaCompatible: false,
      );

      expect(
        ProjectEquipmentRoles.cameraRoleLabel(
          cameraId: 1,
          primaryCameraId: 1,
          assignedInOrder: [b, a],
        ),
        'A-CAM',
      );
      expect(
        ProjectEquipmentRoles.cameraRoleLabel(
          cameraId: 2,
          primaryCameraId: 1,
          assignedInOrder: [b, a],
        ),
        'B-CAM',
      );
    });

    test('drivesActiveSpecs solo es true para A-CAM', () {
      final a = Camera(
        id: 1,
        brand: 'ARRI',
        model: 'A',
        sensorWidthMm: 28,
        sensorHeightMm: 19,
        isCustom: false,
        vintage: false,
        lukaCompatible: false,
      );
      final b = Camera(
        id: 2,
        brand: 'RED',
        model: 'B',
        sensorWidthMm: 28,
        sensorHeightMm: 19,
        isCustom: false,
        vintage: false,
        lukaCompatible: false,
      );
      final assigned = [a, b];

      expect(
        ProjectEquipmentRoles.drivesActiveSpecs(
          cameraId: 1,
          primaryCameraId: 1,
          assignedInOrder: assigned,
        ),
        isTrue,
      );
      expect(
        ProjectEquipmentRoles.drivesActiveSpecs(
          cameraId: 2,
          primaryCameraId: 1,
          assignedInOrder: assigned,
        ),
        isFalse,
      );
    });
  });
}
