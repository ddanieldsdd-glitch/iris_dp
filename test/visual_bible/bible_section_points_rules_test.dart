import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';

/// Reglas de los puntos de una pantalla: restablecer, quitar y migraciones.
void main() {
  const mine = BibleSectionField(
    key: 'field_mio',
    label: 'Notas del foquista',
    type: BibleSectionFieldType.list,
  );

  group('restablecer pantalla', () {
    test('vuelven los puntos de fábrica y los del usuario quedan al final', () {
      final defaults = BibleSectionFieldsConfig.defaultsFor(
        BibleSectionId.direction,
      );
      // El usuario quitó «Actos», renombró «Tono», puso el suyo en medio y
      // añadió el opcional Key Frame.
      final current = [
        defaults.firstWhere((f) => f.key == 'transitions'),
        mine,
        defaults.firstWhere((f) => f.key == 'tone').copyWith(label: 'Mi tono'),
        const BibleSectionField(key: 'keyFrame', label: 'Key Frame'),
      ];

      final reset = BibleSectionFieldsConfig.resetKeepingUserPoints(
        BibleSectionId.direction,
        current,
      );
      expect(reset.map((f) => f.key), [
        ...defaults.map((f) => f.key),
        'field_mio',
      ]);
      expect(
        reset.firstWhere((f) => f.key == 'tone').label,
        'Tono y atmósfera',
      );
      expect(reset.last.type, BibleSectionFieldType.list);
    });

    test('distingue los puntos del usuario de los de la pantalla', () {
      expect(
        BibleSectionFieldsConfig.isUserPoint(BibleSectionId.direction, mine),
        isTrue,
      );
      expect(
        BibleSectionFieldsConfig.isUserPoint(
          BibleSectionId.direction,
          const BibleSectionField(key: 'tone', label: 'Tono'),
        ),
        isFalse,
      );
    });
  });

  group('quitar un punto', () {
    late AppDatabase db;
    late int bibleId;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Puntos'),
      );
      bibleId = (await db.ensureVisualBibleForProject(projectId)).id;
      await db.addBuiltinBibleSection(
        bibleId: bibleId,
        sectionId: BibleSectionId.direction,
      );
    });

    Future<Map<String, String>> values() async =>
        BibleSectionFieldsConfig.parseValues(
          (await (db.select(db.bibleSectionDefinitions)..where(
                    (d) => d.bibleId.equals(bibleId) & d.id.equals('direction'),
                  ))
                  .getSingle())
              .contentJson,
        );

    test('un punto del usuario se borra con su contenido', () async {
      final defaults = BibleSectionFieldsConfig.defaultsFor(
        BibleSectionId.direction,
      );
      await db.saveBibleSectionFields(bibleId, 'direction', [
        ...defaults,
        mine,
      ]);
      await db.saveBibleSectionFieldValue(
        bibleId,
        'direction',
        'field_mio',
        'A',
      );
      await db.saveBibleSectionFieldValue(
        bibleId,
        'direction',
        'field_mio__images',
        '["a.png"]',
      );
      await db.saveBibleSectionFieldValue(
        bibleId,
        'direction',
        'directionData',
        '{"sceneTag":"X"}',
      );

      await db.saveBibleSectionFields(
        bibleId,
        'direction',
        defaults,
        dropValueKeys: {'field_mio'},
      );
      final after = await values();
      expect(after.containsKey('field_mio'), isFalse);
      expect(after.containsKey('field_mio__images'), isFalse);
      expect(after['directionData'], contains('sceneTag'));
    });

    test('un punto de la pantalla conserva su contenido al quitarlo', () async {
      final defaults = BibleSectionFieldsConfig.defaultsFor(
        BibleSectionId.direction,
      );
      await db.saveBibleSectionFieldValue(
        bibleId,
        'direction',
        'directionData',
        '{"tonePoints":[{"title":"Frío"}]}',
      );
      await db.saveBibleSectionFields(
        bibleId,
        'direction',
        defaults.where((f) => f.key != 'tone').toList(),
      );
      expect((await values())['directionData'], contains('Frío'));
    });
  });

  group('migraciones de puntos', () {
    BibleSectionField f(String key) => BibleSectionField(key: key, label: key);

    test('«Composición» se añade una vez a un Concepto antiguo', () {
      final old = BibleSectionFieldsConfig.encode([
        f('narrative'),
        f('shadowTreatment'),
        f('actNotes'),
      ]).replaceFirst(
        '"layoutVersion":${BibleSectionFieldsConfig.layoutVersion}',
        '"layoutVersion":1',
      );
      expect(
        BibleSectionFieldsConfig.parse(
          old,
          BibleSectionId.concept,
        ).map((x) => x.key),
        ['narrative', 'shadowTreatment', 'composition', 'actNotes'],
      );
    });

    test('Cámara antigua: el bloque único se abre en sus puntos nuevos', () {
      final old = BibleSectionFieldsConfig.encode([
        f('narrative'),
        f('cameraBody'),
        f('philosophy'),
        f('movements'),
        f('specsReference'),
        f('references'),
      ]).replaceFirst(
        '"layoutVersion":${BibleSectionFieldsConfig.layoutVersion}',
        '"layoutVersion":3',
      );
      expect(
        BibleSectionFieldsConfig.parse(
          old,
          BibleSectionId.camera,
        ).map((x) => x.key),
        [
          'narrative',
          'equipment',
          'cameraBody',
          'recording',
          'colorPipeline',
          'recordingMatrix',
          'philosophy',
          'movements',
          'specsReference',
          'accessories',
          'dataManagement',
          'references',
        ],
      );
      // Una vez guardada con la versión actual, quitar un punto es quitarlo.
      final saved = BibleSectionFieldsConfig.encode([
        f('narrative'),
        f('cameraBody'),
      ]);
      expect(
        BibleSectionFieldsConfig.parse(
          saved,
          BibleSectionId.camera,
        ).map((x) => x.key),
        ['narrative', 'cameraBody'],
      );
    });

    test('si el usuario la quita, no vuelve', () {
      // Cualquier guardado escribe la versión actual.
      final saved = BibleSectionFieldsConfig.encode([
        f('narrative'),
        f('shadowTreatment'),
        f('actNotes'),
      ]);
      expect(
        saved,
        contains('"layoutVersion":${BibleSectionFieldsConfig.layoutVersion}'),
      );
      expect(
        BibleSectionFieldsConfig.parse(
          saved,
          BibleSectionId.concept,
        ).map((x) => x.key),
        ['narrative', 'shadowTreatment', 'actNotes'],
      );
    });
  });

  group('pantalla personalizada nueva', () {
    late AppDatabase db;

    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    test('nace con tres puntos y sin bloques V2', () async {
      final projectId = await db
          .into(db.projects)
          .insert(ProjectsCompanion.insert(name: 'Pantallas'));
      final bibleId = await db
          .into(db.visualBibles)
          .insert(VisualBiblesCompanion.insert(projectId: projectId));

      final id = await db.insertCustomBibleSection(
        bibleId: bibleId,
        groupId: 'narrative',
        label: 'Vestuario',
      );
      final def = await (db.select(
        db.bibleSectionDefinitions,
      )..where((d) => d.id.equals(id))).getSingle();

      expect(def.contentJson, isNot(contains('v2Blocks')));
      final fields = BibleSectionFieldsConfig.parse(def.contentJson, id);
      expect(fields.map((f) => f.type), [
        BibleSectionFieldType.narrative,
        BibleSectionFieldType.text,
        BibleSectionFieldType.referenceDeck,
      ]);
    });
  });
}
