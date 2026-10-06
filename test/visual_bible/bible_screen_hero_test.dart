import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/widgets/bible_screen_hero.dart';
import 'package:iris_dp/shared/visual_bible/bible_image_links.dart';
import 'package:iris_dp/shared/visual_bible/bible_point_extras.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_ids.dart';

void main() {
  test('la imagen de cabecera se guarda y se quita', () {
    final saved = BibleScreenHeroValue.encode(12)!;
    expect(BibleScreenHeroValue.read({BibleScreenHeroValue.key: saved}), 12);
    expect(BibleScreenHeroValue.encode(null), isNull);
    expect(BibleScreenHeroValue.read(const {}), isNull);
  });

  test('cabecera y complementos se reenlazan al descargar de la nube', () {
    final content = BibleSectionFieldsConfig.encode(
      BibleSectionFieldsConfig.defaultsFor(BibleSectionId.direction),
      values: {
        BibleScreenHeroValue.key: BibleScreenHeroValue.encode(4)!,
        'tone__extra': const BiblePointExtras(imageIds: [4, 5]).encode(),
      },
    );
    final values = BibleSectionFieldsConfig.parseValues(
      BibleImageLinks.remap(content, {4: 40, 5: 50}),
    );
    expect(BibleScreenHeroValue.read(values), 40);
    expect(BiblePointExtras.read(values, 'tone').imageIds, [40, 50]);
    expect(jsonDecode(values['tone__extra']!)['images'], [40, 50]);
  });

  testWidgets('sin imagen, la cabecera lleva el título y ofrece elegirla', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    int? chosen = -1;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: BibleScreenHero(
              projectId: 1,
              bibleId: 1,
              sectionId: BibleSectionId.direction,
              title: 'Dirección',
              onChanged: (id) => chosen = id,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Dirección'), findsOneWidget);
    expect(find.text('BIBLIA DE FOTOGRAFÍA'), findsOneWidget);
    expect(find.text('ELEGIR IMAGEN'), findsOneWidget);
    expect(find.byTooltip('Quitar imagen'), findsNothing);
    expect(chosen, -1);
  });
}
