import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_generic_point_views.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';

void main() {
  group('BibleSectionPointValue', () {
    test('lista: ida y vuelta, y texto plano como un solo punto', () {
      final raw = BibleSectionPointValue.encodeList(['Uno', 'Dos']);
      expect(BibleSectionPointValue.decodeList(raw), ['Uno', 'Dos']);
      expect(BibleSectionPointValue.decodeList('Suelto'), ['Suelto']);
      expect(BibleSectionPointValue.encodeList([]), isNull);
    });

    test('specs: ida y vuelta', () {
      final raw = BibleSectionPointValue.encodeSpecs([('ISO', '800')]);
      expect(BibleSectionPointValue.decodeSpecs(raw), [('ISO', '800')]);
      expect(BibleSectionPointValue.decodeSpecs('no es json'), isEmpty);
    });

    test('un tipo desconocido se lee como texto', () {
      final field = BibleSectionField.fromJson({
        'key': 'k',
        'label': 'L',
        'type': 'tipo_futuro',
      });
      expect(field.type, BibleSectionFieldType.text);
    });
  });

  test('saveBibleSectionFieldValue conserva los demás valores y el orden',
      () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Punto propio'),
    );
    final bible = await db.ensureVisualBibleForProject(projectId);
    await db.addBuiltinBibleSection(
      bibleId: bible.id,
      sectionId: BibleSectionId.camera,
    );

    final fields = [
      ...BibleSectionFieldsConfig.defaultsFor(BibleSectionId.camera),
      const BibleSectionField(
        key: 'field_propio',
        label: 'Notas del foquista',
        type: BibleSectionFieldType.list,
      ),
    ];
    await db.saveBibleSectionFields(bible.id, BibleSectionId.camera, fields);
    await db.saveBibleSectionFieldValue(
      bible.id,
      BibleSectionId.camera,
      'cameraData',
      jsonEncode({'isoNote': 'ISO 800'}),
    );
    await db.saveBibleSectionFieldValue(
      bible.id,
      BibleSectionId.camera,
      'field_propio',
      BibleSectionPointValue.encodeList(['Marcas en suelo']),
    );

    Future<String?> content() async => (await (db.select(
          db.bibleSectionDefinitions,
        )..where((d) => d.bibleId.equals(bible.id) & d.id.equals('camera')))
            .getSingle())
        .contentJson;

    var json = await content();
    var values = BibleSectionFieldsConfig.parseValues(json);
    expect(values['cameraData'], contains('ISO 800'));
    expect(
      BibleSectionPointValue.decodeList(values['field_propio']),
      ['Marcas en suelo'],
    );
    expect(
      BibleSectionFieldsConfig.parse(json, BibleSectionId.camera).last.key,
      'field_propio',
    );

    await db.saveBibleSectionFieldValue(
      bible.id,
      BibleSectionId.camera,
      'field_propio',
      null,
    );
    json = await content();
    values = BibleSectionFieldsConfig.parseValues(json);
    expect(values.containsKey('field_propio'), isFalse);
    expect(values['cameraData'], contains('ISO 800'));
  });

  group('BibleGenericPointView', () {
    Future<List<String?>> pump(
      WidgetTester tester,
      BibleSectionField field, {
      String? value,
    }) async {
      final changes = <String?>[];
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: BibleGenericPointView(
                field: field,
                value: value,
                onChanged: changes.add,
              ),
            ),
          ),
        ),
      );
      return changes;
    }

    testWidgets('texto: muestra el rótulo y guarda lo escrito', (tester) async {
      final changes = await pump(
        tester,
        const BibleSectionField(key: 'k', label: 'Notas de rodaje'),
      );
      expect(find.text('NOTAS DE RODAJE'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), 'Grúa a las 7');
      expect(changes, isEmpty);
      await tester.pump(const Duration(milliseconds: 500));
      expect(changes, ['Grúa a las 7']);
    });

    testWidgets('lista: añade un punto y lo guarda como array', (tester) async {
      final changes = await pump(
        tester,
        const BibleSectionField(
          key: 'k',
          label: 'Riesgos',
          type: BibleSectionFieldType.list,
        ),
        value: BibleSectionPointValue.encodeList(['Lluvia']),
      );
      expect(find.text('Lluvia'), findsOneWidget);

      await tester.tap(find.text('AÑADIR PUNTO'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField).last, 'Viento');
      await tester.pump(const Duration(milliseconds: 500));
      expect(BibleSectionPointValue.decodeList(changes.last), [
        'Lluvia',
        'Viento',
      ]);
    });

    testWidgets('specs: añade un dato con etiqueta y valor', (tester) async {
      final changes = await pump(
        tester,
        const BibleSectionField(
          key: 'k',
          label: 'Filtros',
          type: BibleSectionFieldType.specs,
        ),
      );
      await tester.tap(find.text('AÑADIR DATO'));
      await tester.pump();
      final inputs = find.byType(TextFormField);
      await tester.enterText(inputs.at(0), 'ND');
      await tester.enterText(inputs.at(1), '0.9');
      await tester.pump(const Duration(milliseconds: 500));
      expect(BibleSectionPointValue.decodeSpecs(changes.last), [('ND', '0.9')]);
    });

    testWidgets('guarda lo pendiente al desmontarse', (tester) async {
      final changes = await pump(
        tester,
        const BibleSectionField(key: 'k', label: 'Notas'),
      );
      await tester.enterText(find.byType(TextFormField), 'Sin esperar');
      await tester.pumpWidget(const SizedBox());
      expect(changes, ['Sin esperar']);
    });
  });
}
