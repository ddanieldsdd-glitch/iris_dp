import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/templates/user_template_models.dart';
import 'package:iris_dp/features/visual_bible/bible_preset_service.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Aplicar una plantilla o restablecer la estructura no borra lo escrito.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const mine = BibleSectionField(
    key: 'field_mio',
    label: 'Notas del foquista',
    type: BibleSectionFieldType.list,
  );

  late AppDatabase db;
  late int projectId;
  late int bibleId;

  Future<BibleSectionDefinition?> section(String id) =>
      (db.select(db.bibleSectionDefinitions)
            ..where((d) => d.bibleId.equals(bibleId) & d.id.equals(id)))
          .getSingleOrNull();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Estructura'),
    );
    bibleId = (await db.ensureVisualBibleForProject(projectId)).id;
    await db.resetBibleSectionLayoutToBuiltin(bibleId);

    // Dirección con un punto del usuario y contenido escrito.
    final fields = [
      ...BibleSectionFieldsConfig.defaultsFor(BibleSectionId.direction),
      mine,
    ];
    await db.saveBibleSectionFields(bibleId, BibleSectionId.direction, fields);
    await db.saveBibleSectionFieldValue(
      bibleId,
      BibleSectionId.direction,
      'directionData',
      '{"tone":"Frío y contenido"}',
    );
    await db.saveBibleSectionFieldValue(
      bibleId,
      BibleSectionId.direction,
      'field_mio',
      'Foco a ojo en los planos largos',
    );
  });

  test('una plantilla guarda los puntos, no lo escrito', () async {
    final def = (await section(BibleSectionId.direction))!;
    final structure = BibleSectionFieldsConfig.structureOnly(
      def.id,
      def.contentJson,
    );
    expect(BibleSectionFieldsConfig.parseValues(structure), isEmpty);
    expect(
      BibleSectionFieldsConfig.parse(structure, def.id).map((f) => f.key),
      contains('field_mio'),
    );
  });

  test('las fichas de referencias conservan su tipo, sin fichas', () {
    final json = BibleSectionFieldsConfig.encode(
      const [
        BibleSectionField(
          key: 'field_refs',
          label: 'Referencias técnicas',
          type: BibleSectionFieldType.referenceDeck,
        ),
      ],
      values: {
        'field_refs': '{"preset":"technical","items":[{"title":"Heat"}]}',
      },
    );
    final structure = BibleSectionFieldsConfig.structureOnly('custom_1', json);
    final deck = jsonDecode(
      BibleSectionFieldsConfig.parseValues(structure)['field_refs']!,
    );
    expect(deck, {'preset': 'technical', 'items': <dynamic>[]});
  });

  test('restablecer la estructura conserva contenido y pantallas', () async {
    final customId = await db.insertCustomBibleSection(
      bibleId: bibleId,
      groupId: (await section(BibleSectionId.direction))!.groupId,
      label: 'Vestuario',
    );
    await db.saveBibleSectionFieldValue(bibleId, customId, 'body', 'Lino');

    await db.resetBibleSectionLayoutToBuiltin(bibleId);

    final direction = (await section(BibleSectionId.direction))!;
    final values = BibleSectionFieldsConfig.parseValues(direction.contentJson);
    expect(values['directionData'], contains('Frío y contenido'));
    expect(values['field_mio'], 'Foco a ojo en los planos largos');
    expect(
      BibleSectionFieldsConfig.parse(
        direction.contentJson,
        direction.id,
      ).last.key,
      'field_mio',
    );

    final custom = (await section(customId))!;
    expect(custom.isHidden, isTrue);
    expect(
      BibleSectionFieldsConfig.parseValues(custom.contentJson)['body'],
      'Lino',
    );
  });

  test('aplicar una plantilla conserva contenido y oculta lo que no trae', () async {
    final direction = (await section(BibleSectionId.direction))!;
    final concept = (await section(BibleSectionId.concept))!;
    final group = (await (db.select(
      db.bibleSectionGroups,
    )..where((g) => g.id.equals(direction.groupId))).getSingle());

    // Plantilla con una sola pantalla, guardada con contenido ajeno.
    await db.applyBibleLayoutTemplate(
      bibleId,
      BibleLayoutTemplatePayload(
        groups: [
          BibleLayoutGroupPayload(
            id: group.id,
            label: group.label,
            sortOrder: 0,
            isBuiltIn: true,
          ),
        ],
        sections: [
          BibleLayoutSectionPayload(
            id: direction.id,
            groupId: group.id,
            label: 'Dirección',
            iconKey: direction.iconKey,
            sortOrder: 0,
            isBuiltIn: true,
            isHidden: false,
            template: direction.template,
            contentJson: BibleSectionFieldsConfig.encode(
              BibleSectionFieldsConfig.defaultsFor(BibleSectionId.direction),
              values: {'directionData': '{"tone":"De otra película"}'},
            ),
          ),
        ],
      ),
    );

    final after = (await section(BibleSectionId.direction))!;
    final values = BibleSectionFieldsConfig.parseValues(after.contentJson);
    expect(values['directionData'], contains('Frío y contenido'));
    expect(values['field_mio'], 'Foco a ojo en los planos largos');

    final keptConcept = (await section(concept.id))!;
    expect(keptConcept.isHidden, isTrue);
  });

  test('guardar y aplicar en otra biblia no arrastra contenido', () async {
    final templateId = await BiblePresetService.saveCurrentAsBundle(
      db: db,
      projectId: projectId,
      bibleId: bibleId,
      name: 'Mi biblia',
    );

    final otherProject = await db.insertProject(
      ProjectsCompanion.insert(name: 'Otra'),
    );
    final otherBible = (await db.ensureVisualBibleForProject(otherProject)).id;
    await BiblePresetService.applyById(
      db: db,
      projectId: otherProject,
      bibleId: otherBible,
      templateId: templateId,
      applySampleSeed: false,
    );

    final direction =
        await (db.select(db.bibleSectionDefinitions)..where(
              (d) =>
                  d.bibleId.equals(otherBible) &
                  d.id.equals(BibleSectionId.direction),
            ))
            .getSingle();
    expect(
      BibleSectionFieldsConfig.parse(
        direction.contentJson,
        direction.id,
      ).map((f) => f.key),
      contains('field_mio'),
    );
    expect(BibleSectionFieldsConfig.parseValues(direction.contentJson), isEmpty);
  });
}
