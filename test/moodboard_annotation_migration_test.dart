import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/visual_bible/moodboard_annotation_store.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late AppDatabase db;
  late int projectId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Moodboard migration'),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('migra trazos, flechas y etiquetas al documento común', () async {
    await MoodboardAnnotationStore.saveStrokes(42, const [
      MoodboardStroke(
        id: 'pen',
        color: Color(0xFF112233),
        width: 3,
        points: [Offset(0.1, 0.2), Offset(0.4, 0.5)],
      ),
      MoodboardStroke(
        id: 'arrow',
        color: Color(0xFF445566),
        width: 4,
        points: [Offset(0.2, 0.3), Offset(0.8, 0.7)],
        label: 'ARROW',
      ),
      MoodboardStroke(
        id: 'label',
        color: Color(0xFFFF3B30),
        width: 2,
        points: [Offset(0.6, 0.1)],
        label: 'KEY LIGHT',
      ),
    ]);

    final document = await MoodboardAnnotationStore.loadDocument(
      db: db,
      projectId: projectId,
      imageId: 42,
    );

    expect(document.strokes, hasLength(2));
    expect(document.strokes.first.tool, AnnotationToolType.pen);
    expect(document.strokes.last.tool, AnnotationToolType.arrow);
    expect(document.strokes.first.points.last.x, 0.4);
    expect(document.notes.single.text, 'KEY LIGHT');
    expect(document.notes.single.x, 0.6);

    final row = await db.getProjectAnnotationDocument(
      projectId: projectId,
      targetType: MoodboardAnnotationStore.annotationTargetType,
      targetId: '42',
    );
    expect(row, isNotNull);
    expect(AnnotationDocument.decode(row!.documentJson).strokes, hasLength(2));
    expect(await MoodboardAnnotationStore.loadStrokes(42), isEmpty);
  });

  test('una fila existente impide repetir la migración legacy', () async {
    const current = AnnotationDocument(
      strokes: [
        AnnotationStroke(
          id: 'current',
          tool: AnnotationToolType.pen,
          colorArgb: 0xFF000000,
          width: 5,
          points: [AnnotationPoint(x: 0.3, y: 0.4)],
        ),
      ],
    );
    await MoodboardAnnotationStore.saveDocument(
      db: db,
      projectId: projectId,
      imageId: 7,
      document: current,
    );
    await MoodboardAnnotationStore.saveStrokes(7, const [
      MoodboardStroke(
        id: 'legacy',
        color: Colors.red,
        width: 3,
        points: [Offset(0.1, 0.1), Offset(0.2, 0.2)],
      ),
    ]);

    final loaded = await MoodboardAnnotationStore.loadDocument(
      db: db,
      projectId: projectId,
      imageId: 7,
    );

    expect(loaded.strokes.single.id, 'current');
    expect(await MoodboardAnnotationStore.loadStrokes(7), hasLength(1));
  });

  test('persiste documento vacío como marca de migración', () async {
    final loaded = await MoodboardAnnotationStore.loadDocument(
      db: db,
      projectId: projectId,
      imageId: 99,
    );

    expect(loaded.isEmpty, isTrue);
    expect(
      await db.getProjectAnnotationDocument(
        projectId: projectId,
        targetType: MoodboardAnnotationStore.annotationTargetType,
        targetId: '99',
      ),
      isNotNull,
    );
  });
}
