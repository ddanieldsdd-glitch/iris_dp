import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/shared/history/edit_history.dart';
import 'package:iris_dp/shared/history/shot_edits.dart';

void main() {
  late AppDatabase db;
  late int shotId;
  late int sceneId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'P'),
    );
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'E',
        locationCanonical: 'INT. BAR - NOCHE',
        locationPureName: 'BAR',
      ),
    );
    shotId = await db.insertShot(
      ShotsCompanion.insert(
        sceneId: sceneId,
        projectId: projectId,
        number: 1,
        framing: const Value('PP'),
      ),
    );
  });
  tearDown(() => db.close());

  test(
    'un cambio de celda se deshace y se rehace, también desde vacío',
    () async {
      final history = EditHistory();
      await writeShotFields(
        db,
        history,
        shotId,
        const ShotsCompanion(framing: Value('PG'), notes: Value('ojo')),
      );
      expect(history.canUndo, isTrue);
      expect(await history.undo(), isNotNull);
      var shot = (await db.getShotById(shotId))!;
      expect(shot.framing, 'PP');
      expect(shot.notes, isNull);
      expect(history.canUndo, isFalse);

      await history.redo();
      shot = (await db.getShotById(shotId))!;
      expect(shot.framing, 'PG');
      expect(shot.notes, 'ojo');
      expect(await history.redo(), isNull);

      // Un cambio nuevo borra lo que quedaba por rehacer.
      await history.undo();
      await writeShotFields(
        db,
        history,
        shotId,
        const ShotsCompanion(framing: Value('PM')),
      );
      expect(history.canRedo, isFalse);
    },
  );

  test('las imágenes de un plano vuelven a como estaban', () async {
    final history = EditHistory();
    await db.insertShotReference(
      ShotReferencesCompanion.insert(shotId: shotId, imagePath: '/a.png'),
    );
    await recordShotImages(db, history, shotId, () async {
      final refs = await db.watchReferencesForShot(shotId).first;
      await db.deleteShotReference(refs.single.id);
      await db.updateShotFields(
        shotId,
        const ShotsCompanion(cameraPlanImagePath: Value('["/b.png"]')),
      );
    });
    expect(await db.watchReferencesForShot(shotId).first, isEmpty);

    await history.undo();
    final refs = await db.watchReferencesForShot(shotId).first;
    expect(refs.single.imagePath, '/a.png');
    expect((await db.getShotById(shotId))!.cameraPlanImagePath, isNull);

    await history.redo();
    expect(await db.watchReferencesForShot(shotId).first, isEmpty);
    expect((await db.getShotById(shotId))!.cameraPlanImagePath, '["/b.png"]');

    // Sin cambio no se apunta nada.
    final quiet = EditHistory();
    await recordShotImages(db, quiet, shotId, () async {});
    expect(quiet.canUndo, isFalse);
  });
}
