import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/visual_bible/export/bible_section_export_reader.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_value_resolve.dart';

const _markerRatio = 'FASE3-FMT-RATIO-239';
const _markerResolution = 'FASE3-FMT-RES-4K';
const _markerNarrative = 'FASE3-FMT-NARR-PILOT';

Future<void> _ensureFormatSection(AppDatabase db, int bibleId) async {
  await db.ensureBibleSectionLayout(bibleId);
  await db.addBuiltinBibleSection(
    bibleId: bibleId,
    sectionId: BibleSectionId.format,
  );
}

Future<void> _upsertFormatBlob(
  AppDatabase db,
  int bibleId,
  Map<String, dynamic> blobUpdate,
) async {
  final def = await (db.select(db.bibleSectionDefinitions)
        ..where(
          (d) => d.bibleId.equals(bibleId) & d.id.equals(BibleSectionId.format),
        ))
      .getSingle();
  final current = BibleSectionExportReader.parseCustomBlob(
    def.contentJson,
    BibleSectionId.format,
  );
  final merged = {...current, ...blobUpdate};
  final fields = BibleSectionFieldsConfig.parse(
    def.contentJson,
    BibleSectionId.format,
  );
  final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
  values['formatData'] = jsonEncode(merged);
  await db.upsertBibleSectionDefinition(
    def.copyWith(
      contentJson: Value(
        BibleSectionFieldsConfig.encode(fields, values: values),
      ),
    ),
  );
}

void main() {
  group('Format piloto persistencia', () {
    test('escritura canónica no modifica columnas legacy', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Format no dual'),
      );
      final bible = await db.ensureVisualBibleForProject(projectId);
      await _ensureFormatSection(db, bible.id);

      await (db.update(db.visualBibles)..where((v) => v.id.equals(bible.id)))
          .write(
        const VisualBiblesCompanion(
          aspectRatio: Value('1.85:1'),
          captureResolution: Value('1080p legacy'),
          formatNarrativeIntent: Value('Narrativa legacy'),
        ),
      );

      await _upsertFormatBlob(db, bible.id, {
        'activeRatio': _markerRatio,
        'resolution': _markerResolution,
        'intentNarrative': _markerNarrative,
      });

      final row = await (db.select(db.visualBibles)
            ..where((v) => v.id.equals(bible.id)))
          .getSingle();

      expect(row.aspectRatio, '1.85:1');
      expect(row.captureResolution, '1080p legacy');
      expect(row.formatNarrativeIntent, 'Narrativa legacy');
    });

    test('round-trip tras cerrar y reabrir base de datos en disco', () async {
      final tempDir = Directory.systemTemp.createTempSync('format_pilot_');
      final dbPath = '${tempDir.path}/format_pilot.sqlite';
      addTearDown(() async {
        final dbFile = File(dbPath);
        if (await dbFile.exists()) await dbFile.delete();
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });

      final db1 = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
      final projectId = await db1.insertProject(
        ProjectsCompanion.insert(name: 'Format reopen'),
      );
      final bible = await db1.ensureVisualBibleForProject(projectId);
      await _ensureFormatSection(db1, bible.id);
      await _upsertFormatBlob(db1, bible.id, {
        'activeRatio': _markerRatio,
        'resolution': _markerResolution,
        'intentNarrative': _markerNarrative,
      });
      await db1.close();

      final db2 = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
      addTearDown(db2.close);

      final def = await (db2.select(db2.bibleSectionDefinitions)
            ..where(
              (d) =>
                  d.bibleId.equals(bible.id) &
                  d.id.equals(BibleSectionId.format),
            ))
          .getSingle();
      final blob = BibleSectionExportReader.parseCustomBlob(
        def.contentJson,
        BibleSectionId.format,
      );

      expect(blob['activeRatio'], _markerRatio);
      expect(blob['resolution'], _markerResolution);
      expect(blob['intentNarrative'], _markerNarrative);
    });

    test('lectura legacy cuando blob no tiene claves canónicas', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Format legacy read'),
      );
      final bible = await db.ensureVisualBibleForProject(projectId);
      await _ensureFormatSection(db, bible.id);

      await (db.update(db.visualBibles)..where((v) => v.id.equals(bible.id)))
          .write(
        const VisualBiblesCompanion(
          aspectRatio: Value('2.35:1'),
          captureResolution: Value('6K'),
          formatNarrativeIntent: Value('Intent legacy'),
        ),
      );

      final def = await (db.select(db.bibleSectionDefinitions)
            ..where(
              (d) =>
                  d.bibleId.equals(bible.id) &
                  d.id.equals(BibleSectionId.format),
            ))
          .getSingle();
      final blob = BibleSectionExportReader.parseCustomBlob(
        def.contentJson,
        BibleSectionId.format,
      );

      expect(
        BibleSectionValueResolve.resolveSectionString(
          blob,
          'activeRatio',
          legacy: '2.35:1',
        ),
        '2.35:1',
      );
      expect(
        BibleSectionValueResolve.resolveSectionString(
          blob,
          'resolution',
          legacy: '6K',
        ),
        '6K',
      );
      expect(
        BibleSectionValueResolve.resolveSectionString(
          blob,
          'intentNarrative',
          legacyFallbacks: ['Intent legacy'],
        ),
        'Intent legacy',
      );
    });

    test('export incluye campos canónicos del piloto', () async {
      final blob = {
        'activeRatio': _markerRatio,
        'resolution': _markerResolution,
        'intentNarrative': _markerNarrative,
      };
      final rows = BibleSectionExportReader.rowsForSection(
        BibleSectionId.format,
        blob,
      );
      final text = rows.map((r) => '${r.label}:${r.value}').join('\n');

      expect(text, contains(_markerRatio));
      expect(text, contains(_markerResolution));
      expect(text, contains(_markerNarrative));
    });
  });
}
