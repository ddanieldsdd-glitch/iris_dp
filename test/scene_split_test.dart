import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/script/script_scene_matcher.dart';
import 'package:iris_dp/core/utils/scene_text_parts.dart';

void main() {
  group('frases de una escena', () {
    test('reúne los saltos de página y separa por frases', () {
      expect(
        sceneTextSentences('Ali baja la\npersiana. Respira hondo.\n¿Entra?'),
        ['Ali baja la persiana.', 'Respira hondo.', '¿Entra?'],
      );
    });

    test('la acción elegida se añade sin borrar lo escrito', () {
      expect(appendActionText('Antes', 'Nuevo'), 'Antes\nNuevo');
      expect(appendActionText(null, 'Nuevo'), 'Nuevo');
    });

    test('las letras avanzan por lo que ya existe', () {
      expect(splitSceneSuffixes(null, [null]), (first: 'A', second: 'B'));
      expect(splitSceneSuffixes('A', ['A', 'B']), (first: 'A', second: 'C'));
    });
  });

  group('dividir una escena', () {
    late AppDatabase db;
    late int projectId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
    });
    tearDown(() => db.close());

    Future<int> scene(int number, {String? text}) => db
        .into(db.scenes)
        .insert(
          ScenesCompanion.insert(
            projectId: projectId,
            number: number,
            name: 'E$number',
            locationCanonical: 'INT. BAR - DÍA',
            locationPureName: 'BAR',
            intExt: const Value('INT'),
            sortOrder: Value(number),
            actionText: Value(text),
            scriptLinked: const Value(true),
            scriptHeadingKey: Value(
              scriptHeadingKey(intExt: 'INT', location: 'BAR', dayNight: 'DÍA'),
            ),
            charactersJson: Value(jsonEncode(['ALI'])),
          ),
        );

    Future<int> shot(int sceneId, int number) => db
        .into(db.shots)
        .insert(
          ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: number,
            sortOrder: Value(number - 1),
          ),
        );

    test('13 pasa a 13A y 13B, y los planos elegidos cambian', () async {
      final id = await scene(13, text: 'Uno. Dos.');
      final after = await scene(14);
      final s1 = await shot(id, 1);
      final s2 = await shot(id, 2);
      final s3 = await shot(id, 3);

      final newId = await db.splitScene(
        sceneId: id,
        firstText: 'Uno.',
        secondText: 'Dos.',
        shotIdsForSecond: {s2},
      );

      final a = (await db.getSceneById(id))!;
      final b = (await db.getSceneById(newId))!;
      expect(a.label, '13A');
      expect(b.label, '13B');
      expect(b.actionText, 'Dos.');
      expect(b.charactersJson, a.charactersJson);
      expect(b.sortOrder, a.sortOrder + 1);
      expect((await db.getSceneById(after))!.sortOrder, b.sortOrder + 1);

      Future<Shot> read(int i) =>
          (db.select(db.shots)..where((s) => s.id.equals(i))).getSingle();
      expect((await read(s2)).sceneId, newId);
      expect((await read(s2)).number, 1);
      expect((await read(s1)).sceneId, id);
      expect((await read(s3)).number, 2);
    });

    test('actualizar el guion conserva 13A y 13B con sus planos', () async {
      final id = await scene(1, text: 'Uno. Dos.');
      final newId = await db.splitScene(
        sceneId: id,
        firstText: 'Uno.',
        secondText: 'Dos.',
      );
      await shot(newId, 1);

      WorkspaceScene item(String location) => (
        intExt: 'INT',
        dayNight: 'DÍA',
        location: location,
        shootSet: location,
        locationSite: location,
        name: null,
        description: null,
        locationColor: null,
        charactersJson: null,
        sourceStartIndex: 10,
        sceneText: null,
      );
      await db.syncScenesFromWorkspace(projectId, [
        item('PORTAL'),
        item('BAR'),
        item('CALLE'),
      ]);

      final scenes = await (db.select(
        db.scenes,
      )..orderBy([(s) => OrderingTerm.asc(s.sortOrder)])).get();
      expect(
        scenes.map((s) => (s.label, s.offScript)),
        [('1', false), ('2A', false), ('2B', false), ('3', false)],
      );
      expect((await db.getSceneById(newId))!.actionText, 'Dos.');
    });
  });
}
