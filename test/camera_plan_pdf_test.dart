import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:iris_dp/shared/pdf_export/camera_plan_pdf.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('renderiza planta vectorial completa con anotaciones', () async {
    final elements = [
      PlanElement(
        id: 1,
        type: ElementType.camera,
        position: const Offset(220, 900),
        cameraLetter: 'A',
        pathPoints: const [Offset(500, 700), Offset(800, 620)],
      ),
      PlanElement(
        id: 2,
        type: ElementType.actor,
        position: const Offset(800, 500),
        label: 'Intérprete',
      ),
      PlanElement(
        id: 3,
        type: ElementType.light,
        position: const Offset(1100, 350),
        lightType: LightType.led,
      ),
      PlanElement(
        id: 4,
        type: ElementType.prop,
        position: const Offset(650, 850),
        label: PropType.table.dbValue,
      ),
    ];
    const annotations = AnnotationDocument(
      strokes: [
        AnnotationStroke(
          id: 'blocking',
          tool: AnnotationToolType.arrow,
          colorArgb: 0xFFFF3B30,
          width: 3,
          points: [
            AnnotationPoint(x: 0.25, y: 0.25),
            AnnotationPoint(x: 0.7, y: 0.65),
          ],
        ),
      ],
    );
    final pdf = pw.Document()
      ..addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4.landscape,
          build: (_) => CameraPlanPdfDiagram.build(
            elements: elements,
            annotations: annotations,
          ),
        ),
      );

    final bytes = await pdf.save();

    expect(bytes, isNotEmpty);
    expect(bytes.take(4), orderedEquals('%PDF'.codeUnits));
  });

  test(
    'exportador conserva tabla y carga capa camera_plan_shot de DB',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'PDF plantas'),
      );
      final sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 1,
          name: 'Escena',
          locationCanonical: 'INT. PLATÓ - DÍA',
          locationPureName: 'PLATÓ',
        ),
      );
      final shotId = await db.insertShot(
        ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: 1,
        ),
      );
      final cameraId = await db.insertCameraPlanElement(
        CameraPlanElementsCompanion.insert(
          shotId: shotId,
          type: 'camera',
          x: const Value(300),
          y: const Value(700),
          cameraLetter: const Value('B'),
          cameraLens: const Value('35 mm'),
        ),
      );
      await db.replacePathPoints(cameraId, [(x: 600, y: 650)]);
      const annotations = AnnotationDocument(
        strokes: [
          AnnotationStroke(
            id: 'nota-plano',
            tool: AnnotationToolType.pen,
            colorArgb: 0xFF007AFF,
            width: 4,
            points: [
              AnnotationPoint(x: 0.1, y: 0.15),
              AnnotationPoint(x: 0.45, y: 0.35),
            ],
          ),
        ],
      );
      await db.saveProjectAnnotationDocument(
        projectId: projectId,
        targetType: 'camera_plan_shot',
        targetId: shotId.toString(),
        documentJson: annotations.encode(),
        documentSchemaVersion: AnnotationDocument.currentSchemaVersion,
      );
      final project = await db.getProject(projectId);
      final scenes = await (db.select(
        db.scenes,
      )..where((scene) => scene.projectId.equals(projectId))).get();

      final bytes = await CameraPlanPdfExporter.buildBytes(
        project: project!,
        scenes: scenes,
        db: db,
      );

      expect(bytes, isNotEmpty);
      expect(bytes.take(4), orderedEquals('%PDF'.codeUnits));
      final stored = await db.getProjectAnnotationDocument(
        projectId: projectId,
        targetType: 'camera_plan_shot',
        targetId: shotId.toString(),
      );
      expect(
        AnnotationDocument.decode(stored?.documentJson).strokes,
        hasLength(1),
      );
    },
  );
}
