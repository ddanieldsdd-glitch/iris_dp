import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_point_frame.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_point_panel.dart';
import 'package:iris_dp/shared/visual_bible/bible_point_extras.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';

void main() {
  group('complementos de un punto', () {
    test('sin guardar, las imágenes son las que el punto tenía antes', () {
      final extras = BiblePointExtras.read(const {}, 'tone', legacyImages: [3]);
      expect(extras.imageIds, [3]);
      expect(extras.hasText, isFalse);
    });

    test('guardados mandan, aunque estén vacíos', () {
      final saved = const BiblePointExtras().withImages(const []).encode();
      final extras = BiblePointExtras.read(
        {'tone__extra': saved},
        'tone',
        legacyImages: [3],
      );
      expect(extras.imageIds, isEmpty);
    });

    test('el texto añadido y vacío se distingue de no tener texto', () {
      final added = const BiblePointExtras().withText('');
      final again = BiblePointExtras.read({'p__extra': added.encode()}, 'p');
      expect(again.hasText, isTrue);
      expect(again.isEmpty, isTrue);
      expect(
        BiblePointExtras.read({
          'p__extra': again.withText(null).encode(),
        }, 'p').hasText,
        isFalse,
      );
    });

    test('reúne las imágenes de todos los complementos de una pantalla', () {
      expect(
        BiblePointExtras.allImageIds({
          'tone': '[]',
          'tone__extra': const BiblePointExtras(imageIds: [1, 2]).encode(),
          'acts__extra': const BiblePointExtras(imageIds: [2, 5]).encode(),
        }),
        {1, 2, 5},
      );
    });
  });

  test('borrar un punto del usuario borra también sus complementos', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Marco'),
    );
    final bible = await db.ensureVisualBibleForProject(projectId);
    await db.addBuiltinBibleSection(
      bibleId: bible.id,
      sectionId: BibleSectionId.direction,
    );
    const mine = BibleSectionField(key: 'field_mio', label: 'Mío');
    final defaults = BibleSectionFieldsConfig.defaultsFor(
      BibleSectionId.direction,
    );
    await db.saveBibleSectionFields(bible.id, BibleSectionId.direction, [
      ...defaults,
      mine,
    ]);
    for (final key in ['field_mio', 'field_mio__extra', 'tone__extra']) {
      await db.saveBibleSectionFieldValue(
        bible.id,
        BibleSectionId.direction,
        key,
        key.endsWith('__extra')
            ? const BiblePointExtras(text: 'Nota').encode()
            : 'Texto',
      );
    }
    await db.saveBibleSectionFields(
      bible.id,
      BibleSectionId.direction,
      defaults,
      dropValueKeys: {'field_mio'},
    );
    final def = await (db.select(
      db.bibleSectionDefinitions,
    )..where((d) => d.id.equals(BibleSectionId.direction))).getSingle();
    final values = BibleSectionFieldsConfig.parseValues(def.contentJson);
    expect(values.keys, isNot(contains('field_mio')));
    expect(values.keys, isNot(contains('field_mio__extra')));
    expect(values.keys, contains('tone__extra'));
  });

  testWidgets('el menú «⋯» ofrece duplicar, imágenes, texto y eliminar', (
    tester,
  ) async {
    var extras = const BiblePointExtras();
    var duplicated = 0;
    var removed = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => BiblePointFrame(
              projectId: 1,
              bibleId: 1,
              sectionId: BibleSectionId.direction,
              extras: extras,
              onExtrasChanged: (next) => setState(() => extras = next),
              onDuplicate: () => duplicated++,
              onRemove: () => removed++,
              child: const BiblePointPanel(
                label: 'Tono',
                child: Text('contenido'),
              ),
            ),
          ),
        ),
      ),
    );

    Future<void> choose(String label) async {
      await tester.tap(find.byTooltip('Opciones del punto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    await choose('Duplicar');
    expect(duplicated, 1);

    await choose('Añadir texto complementario');
    expect(extras.hasText, isTrue);
    await tester.enterText(find.byType(TextField), 'Más contexto');
    await tester.pump(const Duration(milliseconds: 600));
    expect(extras.text, 'Más contexto');

    await choose('Quitar texto complementario');
    expect(extras.hasText, isFalse);
    expect(find.byType(TextField), findsNothing);

    await choose('Eliminar');
    expect(removed, 1);
  });
}
