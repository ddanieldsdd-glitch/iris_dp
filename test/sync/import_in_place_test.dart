import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Al bajar, escenas y planos no cambian de id: lo que esté abierto (visor
/// de storyboard, planta, deshacer) sigue apuntando a ellos.
void main() {
  late AppDatabase db;
  late int projectId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'p'));
    for (final n in [1, 2]) {
      final sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: n,
          name: 'INT. CASA $n - DÍA',
          locationCanonical: 'INT. CASA $n - DÍA',
          locationPureName: 'CASA $n',
          sortOrder: Value(n),
        ),
      );
      for (final s in [1, 2]) {
        final shotId = await db.insertShot(
          ShotsCompanion.insert(
            projectId: projectId,
            sceneId: sceneId,
            number: s,
            sortOrder: Value(s),
          ),
        );
        await db.insertShotReference(
          ShotReferencesCompanion.insert(
            shotId: shotId,
            imagePath: '/no/existe/$n-$s.jpg',
          ),
        );
      }
    }
  });

  Future<Map<String, int>> shotIds() async => {
    for (final s in await (db.select(db.shots)
          ..where((s) => s.projectId.equals(projectId)))
        .get())
      s.uid!: s.id,
  };

  Future<Map<String, int>> sceneIds() async => {
    for (final s in await (db.select(db.scenes)
          ..where((s) => s.projectId.equals(projectId)))
        .get())
      s.uid!: s.id,
  };

  Map<String, dynamic> copy(Map<String, dynamic> m) =>
      jsonDecode(jsonEncode(m)) as Map<String, dynamic>;

  test('importar lo mismo deja los mismos ids y la misma huella', () async {
    final bundle = await ProjectContentBundle.export(db, projectId);
    final shotsBefore = await shotIds();
    final scenesBefore = await sceneIds();

    await ProjectContentBundle.importBundle(db, projectId, copy(bundle));

    expect(await shotIds(), shotsBefore);
    expect(await sceneIds(), scenesBefore);
    expect(await db.select(db.shotReferences).get(), hasLength(4));
    expect(
      ProjectContentBundle.hashBundle(
        await ProjectContentBundle.export(db, projectId),
      ),
      ProjectContentBundle.hashBundle(bundle),
    );
  });

  test('cambia lo editado, borra lo quitado y añade lo nuevo', () async {
    final bundle = copy(await ProjectContentBundle.export(db, projectId));
    final shots = (bundle['shots'] as List).cast<Map<String, dynamic>>();
    final before = await shotIds();
    final edited = shots[0]['uid'] as String;
    final removed = shots[1]['uid'] as String;
    shots[0]['lens'] = '35mm';
    shots.removeAt(1);
    (bundle['shotReferences'] as List).removeWhere(
      (r) => (r as Map)['shotKey'] == 'shot:1:2',
    );
    shots.add({
      ...shots[0],
      'uid': 'nuevo-plano',
      'shotKey': 'shot:1:3',
      'number': 3,
      'lens': null,
    });

    await ProjectContentBundle.importBundle(db, projectId, bundle);

    final after = await shotIds();
    expect(after[edited], before[edited]);
    expect(after.containsKey(removed), isFalse);
    expect(after.containsKey('nuevo-plano'), isTrue);
    final lens = await (db.select(db.shots)
          ..where((s) => s.id.equals(after[edited]!)))
        .getSingle();
    expect(lens.lens, '35mm');
    // La referencia del plano borrado se fue con él.
    final refs = await db.select(db.shotReferences).get();
    expect(refs.map((r) => r.shotId).toSet(), isNot(contains(before[removed])));
  });

  test('una escena quitada se lleva sus planos', () async {
    final bundle = copy(await ProjectContentBundle.export(db, projectId));
    final scene2 = (bundle['scenes'] as List).cast<Map<String, dynamic>>()[1];
    (bundle['scenes'] as List).removeAt(1);
    (bundle['shots'] as List).removeWhere(
      (s) => (s as Map)['sceneKey'] == scene2['sceneKey'],
    );

    await ProjectContentBundle.importBundle(db, projectId, bundle);

    expect(await sceneIds(), hasLength(1));
    expect(await shotIds(), hasLength(2));
  });

  test('sin uid en todos, se sustituye como antes', () async {
    final bundle = copy(await ProjectContentBundle.export(db, projectId));
    (bundle['shots'] as List).cast<Map<String, dynamic>>()[0]['uid'] = null;
    final before = await shotIds();

    await ProjectContentBundle.importBundle(db, projectId, bundle);

    final ids = (await db.select(db.shots).get()).map((s) => s.id).toSet();
    expect(ids.intersection(before.values.toSet()), isEmpty);
    expect(ids, hasLength(4));
  });
}
