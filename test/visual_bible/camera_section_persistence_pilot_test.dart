import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/visual_bible/export/bible_section_export_reader.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/camera_pilot_resolve.dart';

const _markerResolution = 'FASE3-CAM-RES-4K';

Future<void> _ensureCameraSection(AppDatabase db, int bibleId) async {
  await db.ensureBibleSectionLayout(bibleId);
  await db.addBuiltinBibleSection(
    bibleId: bibleId,
    sectionId: BibleSectionId.camera,
  );
}

Future<void> _upsertCameraBlob(
  AppDatabase db,
  int bibleId,
  Map<String, dynamic> blobUpdate,
) async {
  final def = await (db.select(db.bibleSectionDefinitions)
        ..where(
          (d) => d.bibleId.equals(bibleId) & d.id.equals(BibleSectionId.camera),
        ))
      .getSingle();
  final current = BibleSectionExportReader.parseCustomBlob(
    def.contentJson,
    BibleSectionId.camera,
  );
  final merged = {...current, ...blobUpdate};
  final fields = BibleSectionFieldsConfig.parse(
    def.contentJson,
    BibleSectionId.camera,
  );
  final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
  values['cameraData'] = jsonEncode(merged);
  await db.upsertBibleSectionDefinition(
    def.copyWith(
      contentJson: Value(
        BibleSectionFieldsConfig.encode(fields, values: values),
      ),
    ),
  );
}

void main() {
  group('Camera piloto persistencia', () {
    test('escritura canónica no modifica columna legacy', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Camera no dual'),
      );
      final bible = await db.ensureVisualBibleForProject(projectId);
      await _ensureCameraSection(db, bible.id);

      await (db.update(db.visualBibles)..where((v) => v.id.equals(bible.id)))
          .write(
        const VisualBiblesCompanion(
          captureResolution: Value('6K legacy'),
        ),
      );

      await _upsertCameraBlob(db, bible.id, {
        'captureResolution': _markerResolution,
      });

      final row = await (db.select(db.visualBibles)
            ..where((v) => v.id.equals(bible.id)))
          .getSingle();

      expect(row.captureResolution, '6K legacy');
    });

    test('round-trip tras cerrar y reabrir base de datos en disco', () async {
      final tempDir = Directory.systemTemp.createTempSync('camera_pilot_');
      final dbPath = '${tempDir.path}/camera_pilot.sqlite';
      addTearDown(() async {
        final dbFile = File(dbPath);
        if (await dbFile.exists()) await dbFile.delete();
        if (await tempDir.exists()) await tempDir.delete(recursive: true);
      });

      final db1 = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
      final projectId = await db1.insertProject(
        ProjectsCompanion.insert(name: 'Camera reopen'),
      );
      final bible = await db1.ensureVisualBibleForProject(projectId);
      await _ensureCameraSection(db1, bible.id);
      await _upsertCameraBlob(db1, bible.id, {
        'captureResolution': _markerResolution,
      });
      await db1.close();

      final db2 = AppDatabase.forTesting(NativeDatabase(File(dbPath)));
      addTearDown(db2.close);

      final def = await (db2.select(db2.bibleSectionDefinitions)
            ..where(
              (d) =>
                  d.bibleId.equals(bible.id) &
                  d.id.equals(BibleSectionId.camera),
            ))
          .getSingle();
      final blob = BibleSectionExportReader.parseCustomBlob(
        def.contentJson,
        BibleSectionId.camera,
      );

      expect(blob['captureResolution'], _markerResolution);
    });

    test('lectura legacy cuando blob no tiene clave canónica', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);

      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Camera legacy read'),
      );
      final bible = await db.ensureVisualBibleForProject(projectId);
      await _ensureCameraSection(db, bible.id);

      await (db.update(db.visualBibles)..where((v) => v.id.equals(bible.id)))
          .write(
        const VisualBiblesCompanion(
          captureResolution: Value('4.6K Open Gate'),
        ),
      );

      final def = await (db.select(db.bibleSectionDefinitions)
            ..where(
              (d) =>
                  d.bibleId.equals(bible.id) &
                  d.id.equals(BibleSectionId.camera),
            ))
          .getSingle();
      final blob = BibleSectionExportReader.parseCustomBlob(
        def.contentJson,
        BibleSectionId.camera,
      );

      expect(
        CameraPilotResolve.captureResolution(
          blob,
          VisualBibleData.fromRow(
            await (db.select(db.visualBibles)
                  ..where((v) => v.id.equals(bible.id)))
                .getSingle(),
          ),
        ),
        '4.6K Open Gate',
      );
    });
  });
}
