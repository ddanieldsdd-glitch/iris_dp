import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('guarda y actualiza una sola capa por objetivo', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Pencil'),
    );
    const first = AnnotationDocument(
      strokes: [
        AnnotationStroke(
          id: 'one',
          tool: AnnotationToolType.pen,
          colorArgb: 0xFF007AFF,
          width: 6,
          points: [
            AnnotationPoint(x: 0.1, y: 0.2),
            AnnotationPoint(x: 0.4, y: 0.5),
          ],
        ),
      ],
    );

    await db.saveProjectAnnotationDocument(
      projectId: projectId,
      targetType: 'camera_plan_shot',
      targetId: '12',
      documentJson: first.encode(),
      documentSchemaVersion: first.schemaVersion,
    );
    await db.saveProjectAnnotationDocument(
      projectId: projectId,
      targetType: 'camera_plan_shot',
      targetId: '12',
      documentJson: const AnnotationDocument().encode(),
      documentSchemaVersion: AnnotationDocument.currentSchemaVersion,
    );

    final rows = await db.select(db.projectAnnotationDocuments).get();
    expect(rows, hasLength(1));
    expect(AnnotationDocument.decode(rows.single.documentJson).isEmpty, isTrue);
  });
}
