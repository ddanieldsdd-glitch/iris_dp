import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/camera_plan/plan_data.dart';

void main() {
  test('los documentos reciben los recorridos guardados', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'KK'),
    );
    final scene = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Escena 1',
        locationCanonical: 'INT. BAR - NOCHE',
        locationPureName: 'BAR',
      ),
    );
    final shotId = await db.insertShot(
      ShotsCompanion.insert(sceneId: scene, projectId: projectId, number: 1),
    );
    final actor = await db.insertCameraPlanElement(
      CameraPlanElementsCompanion.insert(
        shotId: shotId,
        type: 'actor',
        x: const Value(10),
        y: const Value(20),
      ),
    );
    await db.replacePathPoints(actor, [(x: 30, y: 40), (x: 50, y: 60)]);

    final data = await PlanProjectData.load(db, projectId);
    final shot = data.shots.single;

    expect(data.ownOfShot(shot).single.pathPoints, const [
      Offset(30, 40),
      Offset(50, 60),
    ]);
    expect(data.ownOfShot(shot, tagged: true).single.pathPoints, hasLength(2));
  });
}
