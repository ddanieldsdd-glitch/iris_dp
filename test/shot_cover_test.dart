import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/utils/shot_reference_import.dart';

void main() {
  late AppDatabase db;
  late int shotId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Kebab Khaled'),
    );
    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Escena 1',
        locationCanonical: 'EXT. CALLE RAVAL - NOCHE',
        locationPureName: 'CALLE RAVAL',
      ),
    );
    shotId = await db.insertShot(
      ShotsCompanion.insert(sceneId: sceneId, projectId: projectId, number: 1),
    );
  });

  tearDown(() async => db.close());

  Future<Shot> shot() async => (await db.getShotById(shotId))!;

  Future<void> images({String? story, String? ref}) =>
      (db.update(db.shots)..where((s) => s.id.equals(shotId))).write(
        ShotsCompanion(
          storyboardImagePath: Value(story),
          referenceImagePath: Value(ref),
        ),
      );

  test('sin imágenes no hay imagen del plano', () async {
    expect(coverImageOf(await shot()), isNull);
    expect(coverSourceOf(await shot()), ShotCover.storyboard);
  });

  test('por defecto representa el storyboard y, sin él, la referencia', () async {
    await images(story: '/sb.png', ref: '/ref.png');
    expect(coverImageOf(await shot()), '/sb.png');
    await images(ref: '/ref.png');
    expect(coverImageOf(await shot()), '/ref.png');
  });

  test('se elige la referencia por plano y se guarda', () async {
    await images(story: '/sb.png', ref: '/ref.png');
    await db.setShotCoverImage(shotId, ShotCover.reference.name);
    expect((await shot()).coverImage, 'reference');
    expect(coverSourceOf(await shot()), ShotCover.reference);
    expect(coverImageOf(await shot()), '/ref.png');
    // Si la referencia se quita, sale el storyboard.
    await images(story: '/sb.png');
    expect(coverImageOf(await shot()), '/sb.png');
    // Volver a lo de por defecto.
    await db.setShotCoverImage(shotId, null);
    expect((await shot()).coverImage, isNull);
  });
}
