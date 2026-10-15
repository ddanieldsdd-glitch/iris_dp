import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/widgets/sections/lighting_section.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Iluminación: sin «Ver en…», puntos clave y la luz general '
      'como punto propio solo si ya estaba configurada', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(1400, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    // La base no se cierra: las consultas de la pantalla siguen vivas.
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    late VisualBibleData data;
    String? contentJson;
    await tester.runAsync(() async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Luz'),
      );
      final bible = await db.ensureVisualBibleForProject(projectId);
      await db.addBuiltinBibleSection(
        bibleId: bible.id,
        sectionId: BibleSectionId.lighting,
      );
      data = VisualBibleData.fromRow(bible);
      await db.saveBibleSectionFieldValue(
        bible.id,
        BibleSectionId.lighting,
        'lightingData',
        jsonEncode({
          'metrics': {'kelvin': 3200, 'ratio': 4},
        }),
      );
      final defs = await db.select(db.bibleSectionDefinitions).get();
      contentJson = defs
          .firstWhere((d) => d.id == BibleSectionId.lighting)
          .contentJson;
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: LightingSection(
              data: data,
              projectId: data.projectId,
              bibleId: data.id,
              sectionContentJson: contentJson,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(() => db.select(db.bibleSectionDefinitions).get());
    }

    expect(find.text('Ver en Exposición'), findsNothing);
    expect(find.text('Ver en Color'), findsNothing);
    expect(
      find.text('Lo más importante que vamos a destacar de la luz en el '
          'proyecto'),
      findsNothing,
    );

    late List<BibleSectionField> fields;
    await tester.runAsync(() async {
      final defs = await db.select(db.bibleSectionDefinitions).get();
      fields = BibleSectionFieldsConfig.parse(
        defs.firstWhere((d) => d.id == BibleSectionId.lighting).contentJson,
        BibleSectionId.lighting,
      );
    });
    final keys = fields.map((f) => f.key).toList();
    expect(fields.first.label, 'Puntos clave');
    // Estaba configurada: pasa a su propio punto, justo detrás.
    expect(keys.indexOf('globalLight'), keys.indexOf('overview') + 1);
    expect(fields[keys.indexOf('globalLight')].widget, 'light_metrics');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });
}
