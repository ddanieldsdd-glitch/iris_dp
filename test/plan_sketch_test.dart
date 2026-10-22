import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/core/utils/shot_reference_import.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/plan_data.dart';
import 'package:iris_dp/features/camera_plan/plan_thumbnail.dart';
import 'package:iris_dp/shared/annotations/annotation_canvas.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';

const _drawing = AnnotationDocument(
  strokes: [
    AnnotationStroke(
      id: 'a',
      tool: AnnotationToolType.pen,
      colorArgb: 0xFFFF0000,
      width: 6,
      points: [
        AnnotationPoint(x: 0.2, y: 0.2),
        AnnotationPoint(x: 0.6, y: 0.5),
      ],
    ),
  ],
);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('un boceto dibujado se ofrece en la escena y el plano lo enseña sin '
      'cambiar de esquema de luz', () async {
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Bocetos'),
    );
    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Escena',
        locationCanonical: 'INT. BAR - NOCHE',
        locationPureName: 'BAR',
      ),
    );
    final shotId = await db.insertShot(
      ShotsCompanion.insert(sceneId: sceneId, projectId: projectId, number: 1),
    );
    final repo = FloorPlanRepository(db);
    final empty = await repo.createLightSetup(projectId: projectId);
    final sketch = await repo.createLightSetup(
      projectId: projectId,
      name: 'Boceto · Esc 1',
    );
    final done = await repo.createLightSetup(
      projectId: projectId,
      name: 'Definitivo',
      status: 'definitivo',
    );
    for (final setup in [sketch, done]) {
      await db.saveProjectAnnotationDocument(
        projectId: projectId,
        targetType: 'camera_plan_light_setup',
        targetId: '${setup.id}',
        documentJson: _drawing.encode(),
        documentSchemaVersion: 1,
      );
    }

    Future<PlanProjectData> load() async => PlanProjectData(
      sites: const [],
      sets: const [],
      setups: await db.getLightSetupsForProject(projectId),
      scenes: await db.watchScenesForProject(projectId).first,
      shots: await db.watchShotsForProject(projectId).first,
      drawingRows: await db.watchPlanAnnotationDocuments(projectId).first,
    );

    var data = await load();
    final scene = data.scenes.single;
    // Solo los que están en boceto y tienen algo dibujado.
    expect(data.sketchesForScene(scene).map((s) => s.id), [sketch.id]);
    expect(data.drawingsOfSetup(empty), isEmpty);
    expect(data.drawingsOfSetup(sketch), hasLength(1));

    var shot = (await db.getShotById(shotId))!;
    await addShotPlanSketchSetup(db: db, shot: shot, setupId: sketch.id);
    await addShotPlanSketchSetup(db: db, shot: shot, setupId: sketch.id);
    shot = (await db.getShotById(shotId))!;
    expect(planSketchEntriesOf(shot), ['setup:${sketch.id}']);
    expect(planSketchSetupId(planSketchEntriesOf(shot).single), sketch.id);
    // No es una imagen, y el plano sigue sin esquema de luz.
    expect(planSketchesOf(shot), isEmpty);
    expect(shot.lightSetupId, isNull);

    await removeShotPlanSketch(db: db, shot: shot, path: 'setup:${sketch.id}');
    expect(planSketchEntriesOf((await db.getShotById(shotId))!), isEmpty);
  });

  testWidgets('la miniatura de un boceto a mano pinta sus trazos', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Center(
          child: SizedBox(
            width: 200,
            height: 120,
            child: PlanThumbnail(
              elements: [],
              drawings: [_drawing],
              emptyIcon: Icons.draw_outlined,
            ),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.draw_outlined), findsNothing);
    final paints = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .where((p) => p.painter is AnnotationPainter);
    expect(paints, hasLength(1));
    expect(tester.takeException(), isNull);

    final bounds = PlanThumbnail.drawingBounds(const [_drawing])!;
    expect(bounds.left, closeTo(0.2 * 1600 - 1, 0.01));
    expect(bounds.bottom, closeTo(0.5 * 1200 + 1, 0.01));
  });
}
