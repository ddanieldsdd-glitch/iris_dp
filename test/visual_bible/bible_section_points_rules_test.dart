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
      ]).replaceFirst('"layoutVersion":2', '"layoutVersion":1');
      expect(
        BibleSectionFieldsConfig.parse(
          old,
          BibleSectionId.concept,
        ).map((x) => x.key),
        ['narrative', 'shadowTreatment', 'composition', 'actNotes'],
      );
    });

    test('si el usuario la quita, no vuelve', () {
      // Cualquier guardado escribe la versión actual.
      final saved = BibleSectionFieldsConfig.encode([
        f('narrative'),
        f('shadowTreatment'),
        f('actNotes'),
      ]);
      expect(saved, contains('"layoutVersion":2'));
      expect(
        BibleSectionFieldsConfig.parse(
          saved,
          BibleSectionId.concept,
        ).map((x) => x.key),
        ['narrative', 'shadowTreatment', 'actNotes'],
      );
    });
  });
}
