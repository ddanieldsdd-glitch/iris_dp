import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/shared/history/edit_history.dart';
import 'package:iris_dp/shared/history/shot_edits.dart';

void main() {
  test(
    'guardar desde storyboard escribe en la fila del guion y se deshace',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Prueba'),
      );
      final sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 1,
          name: 'Calle',
          locationCanonical: 'EXT. CALLE - NOCHE',
          locationPureName: 'CALLE',
        ),
      );
      final shotId = await db.insertShot(
        ShotsCompanion.insert(
          projectId: projectId,
          sceneId: sceneId,
          number: 1,
          lens: const Value('35mm'),
        ),
      );
      final history = EditHistory();
      final seen = <String?>[];
      final sub = db
          .watchShotsForScene(sceneId)
          .listen((shots) => seen.add(shots.single.lens));

      await saveShotFields(
        db,
        history,
        (await db.getShotById(shotId))!,
        const ShotsCompanion(lens: Value('85mm')),
      );
      expect((await db.getShotById(shotId))!.lens, '85mm');
      await pumpEventQueue();
      expect(seen.last, '85mm');

      await history.undo();
      expect((await db.getShotById(shotId))!.lens, '35mm');
      await sub.cancel();
    },
  );
}
