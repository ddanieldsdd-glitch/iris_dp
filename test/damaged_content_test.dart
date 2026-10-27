import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/utils/error_log.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';

/// Lo que no se puede leer se guarda aparte antes de escribir encima.
void main() {
  late AppDatabase db;
  late Directory logs;
  late BibleSectionDefinition format;

  List<String> copies() => logs
      .listSync()
      .map((f) => f.uri.pathSegments.last)
      .where((n) => n.startsWith('danado-'))
      .toList();

  Future<void> store(String contentJson) => db
      .into(db.bibleSectionDefinitions)
      .insertOnConflictUpdate(format.copyWith(contentJson: Value(contentJson)));

  setUp(() async {
    logs = Directory.systemTemp.createTempSync('iris_damaged');
    ErrorLog.directoryOverride = logs;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'lala'),
    );
    final bibleId = (await db.ensureVisualBibleForProject(projectId)).id;
    await db.ensureBibleSectionLayout(bibleId);
    format =
        await (db.select(db.bibleSectionDefinitions)..where(
              (d) =>
                  d.bibleId.equals(bibleId) &
                  d.id.equals(BibleSectionId.format),
            ))
            .getSingle();
  });

  tearDown(() async {
    await db.close();
    ErrorLog.directoryOverride = null;
    logs.deleteSync(recursive: true);
  });

  test('detecta el JSON dañado y los bloques internos dañados', () {
    expect(unreadableContentParts('{"values":'), ['contentJson']);
    expect(
      unreadableContentParts(
        jsonEncode({
          'values': {'formatData': '{"activeRatio": ', 'tone': '{sin json'},
        }),
      ),
      ['formatData', 'tone'],
    );
    expect(
      unreadableContentParts(
        jsonEncode({
          'values': {'formatData': '{"activeRatio":"2.39"}', 'tone': 'cálido'},
        }),
      ),
      isEmpty,
    );
  });

  test('un contenido ilegible se guarda aparte antes de pisarlo', () async {
    await store('{"values": {"tone": "noche');

    await db.upsertBibleSectionDefinition(
      format.copyWith(contentJson: const Value('{"values":{}}')),
    );

    expect(copies(), hasLength(1));
    expect(
      File('${logs.path}/${copies().single}').readAsStringSync(),
      '{"values": {"tone": "noche',
    );
  });

  test('un bloque dañado que no cambia no deja otra copia', () async {
    final damaged = {'formatData': '{"activeRatio": ', 'tone': 'a'};
    await store(jsonEncode({'values': damaged}));

    await db.upsertBibleSectionDefinition(
      format.copyWith(
        contentJson: Value(
          jsonEncode({
            'values': {...damaged, 'tone': 'b'},
          }),
        ),
      ),
    );
    expect(copies(), isEmpty);

    await db.upsertBibleSectionDefinition(
      format.copyWith(
        contentJson: Value(
          jsonEncode({
            'values': {'formatData': '{}'},
          }),
        ),
      ),
    );
    expect(copies(), hasLength(1));
  });
}
