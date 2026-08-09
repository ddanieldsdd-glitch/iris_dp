import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:iris_dp/shared/visual_bible/format_sensor_mode_resolve.dart';

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
    test('segunda cámara sin principal previo promueve la primera asignada, no la nueva', () async {
      final projectId = await seedProject();
      final camA = await seedCamera(externalId: 'route_cam_first');
      final camB = await seedCamera(externalId: 'route_cam_second');

      await db.assignEquipmentToProject(
        projectId: projectId,
        equipmentType: 'camera',
        equipmentId: camA,
      );
      // Simula asignación legacy sin auto-promoción tras la primera cámara.
      await db.assignEquipmentToProject(
        projectId: projectId,
        equipmentType: 'camera',
        equipmentId: camB,
      );
      await db.maybePromotePrimaryOnEquipmentAssign(
        projectId: projectId,
        equipmentType: 'camera',
        equipmentId: camB,
      );

      final bible = await db.getVisualBibleForProject(projectId);
      expect(bible?.primaryCameraId, camA);
      expect((await db.resolveProjectCamera(projectId))?.id, camA);
    });

    test('cambiar A-CAM re-resuelve sensorModeName de Format si no aplica', () async {
      final projectId = await seedProject();
      final camSony = await db.insertCamera(
        CamerasCompanion.insert(
          brand: 'Sony',
          model: 'Venice',
          sensorWidthMm: 36,
          sensorHeightMm: 24,
          externalId: const Value('route_sony'),
          sensorModesJson: Value(jsonEncode([
            {
              'name': '6K 3:2 Full Frame',
              'widthMm': 36.0,
              'heightMm': 24.0,
              'maxWidthPx': 6048,
              'maxHeightPx': 4032,
            },
          ])),
        ),
      );
      final camArri = await db.insertCamera(
        CamerasCompanion.insert(
          brand: 'ARRI',
          model: 'ALEXA 35',
          sensorWidthMm: 27.99,
          sensorHeightMm: 19.22,
          externalId: const Value('route_arri'),
          sensorModesJson: Value(jsonEncode([
            {
              'name': '4.6K 3:2 Open Gate',
              'widthMm': 27.99,
              'heightMm': 19.22,
              'maxWidthPx': 4608,
              'maxHeightPx': 3164,
            },
          ])),
        ),
      );

      final bible = await db.ensureVisualBibleForProject(projectId);
      await db.ensureBibleSectionLayout(bible.id);
      await db.addBuiltinBibleSection(
        bibleId: bible.id,
        sectionId: BibleSectionId.format,
      );
      final def = await (db.select(db.bibleSectionDefinitions)
            ..where(
              (d) =>
                  d.bibleId.equals(bible.id) &
                  d.id.equals(BibleSectionId.format),
            ))
          .getSingle();
      final fields = BibleSectionFieldsConfig.parse(
        def.contentJson,
        BibleSectionId.format,
      );
      final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
      values['formatData'] = jsonEncode({
        FormatSensorModeResolve.nameKey: '6K 3:2 Full Frame',
        FormatSensorModeResolve.detailKey: 'Sony mode',
      });
      await db.upsertBibleSectionDefinition(
        def.copyWith(
          contentJson: Value(
            BibleSectionFieldsConfig.encode(fields, values: values),
          ),
        ),
      );

      await db.syncBiblePrimaryCamera(projectId, camSony);
      await db.syncBiblePrimaryCamera(projectId, camArri);

      final after = await (db.select(db.bibleSectionDefinitions)
            ..where(
              (d) =>
                  d.bibleId.equals(bible.id) &
                  d.id.equals(BibleSectionId.format),
            ))
          .getSingle();
      final name = FormatSensorModeResolve.modeNameFromSectionContentJson(
        after.contentJson,
      );
      expect(name, '4.6K 3:2 Open Gate');
    });

    test('desasignar A-CAM promociona la siguiente o limpia primary', () async {
      final projectId = await seedProject();
      final cam1 = await seedCamera(externalId: 'route_un_a');
      final cam2 = await seedCamera(externalId: 'route_un_b');

      await db.syncBiblePrimaryCamera(projectId, cam1);
      await db.assignEquipmentToProject(
        projectId: projectId,
        equipmentType: 'camera',
        equipmentId: cam2,
      );

      final rows = await db.watchProjectEquipment(projectId).first;
      final row1 = rows.firstWhere(
        (r) => r.equipmentType == 'camera' && r.equipmentId == cam1,
      );
      await db.unassignProjectEquipment(row1.id);
      await db.maybeReconcilePrimaryOnEquipmentUnassign(
        projectId: projectId,
        equipmentType: 'camera',
        equipmentId: cam1,
      );

      expect((await db.getVisualBibleForProject(projectId))?.primaryCameraId, cam2);

      final rows2 = await db.watchProjectEquipment(projectId).first;
      final row2 = rows2.firstWhere(
        (r) => r.equipmentType == 'camera' && r.equipmentId == cam2,
      );
      await db.unassignProjectEquipment(row2.id);
      await db.maybeReconcilePrimaryOnEquipmentUnassign(
        projectId: projectId,
        equipmentType: 'camera',
        equipmentId: cam2,
      );
      expect((await db.getVisualBibleForProject(projectId))?.primaryCameraId, equals(null));
    });
  });
}
