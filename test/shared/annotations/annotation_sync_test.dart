import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('sincroniza tinta y remapea el plano de cámara de destino', () async {
    final sourceProjectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Origen'),
    );
    final targetProjectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Destino'),
    );
    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: sourceProjectId,
        number: 1,
        name: 'Escena',
        locationCanonical: 'INT. SET - DÍA',
        locationPureName: 'SET',
      ),
    );
    final sourceShotId = await db.insertShot(
      ShotsCompanion.insert(
        projectId: sourceProjectId,
        sceneId: sceneId,
        number: 1,
      ),
    );
    const document = AnnotationDocument(
      strokes: [
        AnnotationStroke(
          id: 'pencil-stroke',
          tool: AnnotationToolType.pen,
          colorArgb: 0xFF007AFF,
          width: 6,
          inputKind: AnnotationInputKind.stylus,
          points: [
            AnnotationPoint(x: 0.1, y: 0.2, pressure: 0.4),
            AnnotationPoint(x: 0.6, y: 0.7, pressure: 0.9),
          ],
        ),
      ],
    );
    await db.saveProjectAnnotationDocument(
      projectId: sourceProjectId,
      targetType: 'camera_plan_shot',
      targetId: sourceShotId.toString(),
      documentJson: document.encode(),
      documentSchemaVersion: document.schemaVersion,
    );

    final bundle = await ProjectContentBundle.export(db, sourceProjectId);
    await ProjectContentBundle.importBundle(db, targetProjectId, bundle);

    final importedShots = await (db.select(
      db.shots,
    )..where((shot) => shot.projectId.equals(targetProjectId))).get();
    final importedAnnotations =
        await (db.select(db.projectAnnotationDocuments)..where(
              (annotation) => annotation.projectId.equals(targetProjectId),
            ))
            .get();

    expect(importedShots, hasLength(1));
    expect(importedShots.single.id, isNot(sourceShotId));
    expect(importedAnnotations, hasLength(1));
    expect(
      importedAnnotations.single.targetId,
      importedShots.single.id.toString(),
    );
    expect(
      AnnotationDocument.decode(
        importedAnnotations.single.documentJson,
      ).strokes.single.inputKind,
      AnnotationInputKind.stylus,
    );
  });
}
