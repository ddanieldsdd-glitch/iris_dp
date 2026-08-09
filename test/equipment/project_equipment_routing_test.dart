import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> seedProject() => db.insertProject(
        ProjectsCompanion.insert(
          name: 'Routing smoke',
          director: const Value('DP'),
        ),
      );

  Future<int> seedCamera({String externalId = 'route_cam_1'}) => db.insertCamera(
        CamerasCompanion.insert(
          brand: 'ARRI',
          model: 'ALEXA 35',
          sensorWidthMm: 27.99,
          sensorHeightMm: 19.22,
          externalId: Value(externalId),
        ),
      );

  Future<int> seedLens({String externalId = 'route_lens_1'}) => db.insertLens(
        LensesCompanion.insert(
          brand: 'Zeiss',
          model: 'Supreme 50',
          focalLength: 50,
          minTStop: 1.5,
          formatCoverage: 'LF',
          externalId: Value(externalId),
        ),
      );

  group('project equipment routing', () {
    test('asignar cámara en Equipo promueve a principal si Biblia vacía', () async {
      final projectId = await seedProject();
      final cameraId = await seedCamera();

      await db.assignEquipmentToProject(
        projectId: projectId,
        equipmentType: 'camera',
        equipmentId: cameraId,
      );
      await db.maybePromotePrimaryOnEquipmentAssign(
        projectId: projectId,
        equipmentType: 'camera',
        equipmentId: cameraId,
      );

      final bible = await db.getVisualBibleForProject(projectId);
      expect(bible?.primaryCameraId, cameraId);

      final resolved = await db.resolveProjectCamera(projectId);
      expect(resolved?.id, cameraId);
      expect(resolved?.sensorWidthMm, closeTo(27.99, 0.01));
    });

    test('segunda cámara asignada no reemplaza principal existente', () async {
      final projectId = await seedProject();
      final cam1 = await seedCamera(externalId: 'route_cam_a');
      final cam2 = await seedCamera(externalId: 'route_cam_b');

      await db.syncBiblePrimaryCamera(projectId, cam1);

      await db.assignEquipmentToProject(
        projectId: projectId,
        equipmentType: 'camera',
        equipmentId: cam2,
      );
      await db.maybePromotePrimaryOnEquipmentAssign(
        projectId: projectId,
        equipmentType: 'camera',
        equipmentId: cam2,
      );

      final bible = await db.getVisualBibleForProject(projectId);
      expect(bible?.primaryCameraId, cam1);

      final resolved = await db.resolveProjectCamera(projectId);
      expect(resolved?.id, cam1);
    });

    test('resolveProjectCamera lee asignación sin columna principal', () async {
      final projectId = await seedProject();
      final cameraId = await seedCamera();

      await db.assignEquipmentToProject(
        projectId: projectId,
        equipmentType: 'camera',
        equipmentId: cameraId,
      );

      final bible = await db.getVisualBibleForProject(projectId);
      expect(bible?.primaryCameraId, null);

      final resolved = await db.resolveProjectCamera(projectId);
      expect(resolved?.id, cameraId);
    });

    test('asignar lente promueve a principal y resolveProjectLens la encuentra', () async {
      final projectId = await seedProject();
      final lensId = await seedLens();

      await db.assignEquipmentToProject(
        projectId: projectId,
        equipmentType: 'lens',
        equipmentId: lensId,
      );
      await db.maybePromotePrimaryOnEquipmentAssign(
        projectId: projectId,
        equipmentType: 'lens',
        equipmentId: lensId,
      );

      final bible = await db.getVisualBibleForProject(projectId);
      expect(bible?.primaryLensId, lensId);

      final resolved = await db.resolveProjectLens(projectId);
      expect(resolved?.id, lensId);
    });

    test('segunda lente asignada no reemplaza principal existente', () async {
      final projectId = await seedProject();
      final lens1 = await seedLens(externalId: 'route_lens_a');
      final lens2 = await seedLens(externalId: 'route_lens_b');

      await db.syncBiblePrimaryLens(projectId, lens1);

      await db.assignEquipmentToProject(
        projectId: projectId,
        equipmentType: 'lens',
        equipmentId: lens2,
      );
      await db.maybePromotePrimaryOnEquipmentAssign(
        projectId: projectId,
        equipmentType: 'lens',
        equipmentId: lens2,
      );

      final bible = await db.getVisualBibleForProject(projectId);
      expect(bible?.primaryLensId, lens1);
      expect((await db.resolveProjectLens(projectId))?.id, lens1);
    });
  });
}
