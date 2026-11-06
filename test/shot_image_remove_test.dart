import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/utils/shot_reference_import.dart';
import 'package:iris_dp/shared/history/edit_history.dart';
import 'package:iris_dp/shared/history/shot_edits.dart';

void main() {
  late AppDatabase db;
  late int shotId;
  late Directory dir;

  String file(String name) =>
      (File('${dir.path}/$name')..writeAsBytesSync([1])).path;

  Future<Shot> shot() async => (await db.getShotById(shotId))!;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    dir = Directory.systemTemp.createTempSync('iris_quitar');
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
    shotId = await db.insertShot(
      ShotsCompanion.insert(projectId: projectId, sceneId: sceneId, number: 1),
    );
  });

  tearDown(() async {
    await db.close();
    dir.deleteSync(recursive: true);
  });

  Future<void> addReference(String path) async {
    await db
        .into(db.shotReferences)
        .insert(
          ShotReferencesCompanion.insert(shotId: shotId, imagePath: path),
        );
    await db.updateShotFields(
      shotId,
      ShotsCompanion(referenceImagePath: Value(path)),
    );
  }

  test('quitar la propia deja ver la referencia', () async {
    final own = file('own.png');
    final ref = file('ref.png');
    await addReference(ref);
    await db.updateShotFields(
      shotId,
      ShotsCompanion(storyboardImagePath: Value(own)),
    );

    await removeVisibleShotImage(db: db, shot: await shot(), path: own);

    expect((await shot()).storyboardImagePath, isNull);
    expect(storyboardImageOf(await shot()), ref);
  });

  test('quitar una referencia heredada la borra del plano', () async {
    final ref = file('ref.png');
    await addReference(ref);

    await removeVisibleShotImage(db: db, shot: await shot(), path: ref);

    expect(storyboardImageOf(await shot()), isNull);
    expect(await db.watchReferencesForShot(shotId).first, isEmpty);
  });

  test('quedando otra referencia, aparece la siguiente', () async {
    final first = file('a.png');
    final second = file('b.png');
    await addReference(second);
    await addReference(first);

    await removeVisibleShotImage(db: db, shot: await shot(), path: first);

    expect(storyboardImageOf(await shot()), second);
  });

  test('deshacer recupera la imagen quitada', () async {
    final ref = file('ref.png');
    await addReference(ref);
    final history = EditHistory();

    await recordShotImages(db, history, shotId, () async {
      await removeVisibleShotImage(db: db, shot: await shot(), path: ref);
    });
    expect(storyboardImageOf(await shot()), isNull);

    await history.undo();
    expect(storyboardImageOf(await shot()), ref);
    expect(await db.watchReferencesForShot(shotId).first, hasLength(1));
  });
}
