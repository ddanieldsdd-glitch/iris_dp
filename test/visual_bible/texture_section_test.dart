import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/widgets/sections/texture_section.dart';
import 'package:iris_dp/shared/visual_bible/bible_section_fields.dart';
import 'package:iris_dp/shared/visual_bible/texture_points.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/snapshot.dart';

void main() {
  test('un grano que estaba apagado no trae sus números de partida', () {
    final off = TexturePoints.grainValue(const {}, {
      'grainEnabled': false,
      'grainSize': 1.5,
      'grainIntensity': 0.45,
      'grainPreset': 'Kodak Vision3 500T',
    });
    expect(off.filledRows, isEmpty);

    final on = TexturePoints.grainValue(const {}, {
      'grainEnabled': true,
      'grainSize': 2.4,
      'grainIntensity': 0.65,
      'grainPreset': 'Kodak Vision3 500T',
    });
    expect(on.rows.first, ('Emulación', 'Kodak Vision3 500T'));
    expect(on.rows[1], ('Tamaño', '2.4 µm'));
    expect(on.rows[2], ('Intensidad', '65 %'));
  });

  test('los puntos de Textura con rótulo en inglés pasan al castellano', () {
    final old = BibleSectionFieldsConfig.encode(const [
      BibleSectionField(key: 'filmGrain', label: 'Film Grain'),
      BibleSectionField(key: 'diffusion', label: 'Mis filtros'),
      BibleSectionField(key: 'sensorNoise', label: 'Sensor Noise Floor'),
    ]);
    expect(
      BibleSectionFieldsConfig.parse(
        old,
        BibleSectionId.texture,
      ).map((f) => f.label),
      // El que el usuario renombró se queda como lo dejó.
      ['Grano', 'Mis filtros', 'Ruido del sensor'],
    );
  });

  for (final width in [900.0, 1500.0]) {
    testWidgets('Textura a $width px: en castellano, sin deslizadores ni '
        'ejemplos', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await loadSnapshotFonts();
      tester.view.physicalSize = Size(width, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      late VisualBibleData data;
      String? contentJson;

      await tester.runAsync(() async {
        final projectId = await db.insertProject(
          ProjectsCompanion.insert(name: 'Textura'),
        );
        final bible = await db.ensureVisualBibleForProject(projectId);
        await db.addBuiltinBibleSection(
          bibleId: bible.id,
          sectionId: BibleSectionId.texture,
        );
        data = VisualBibleData.fromRow(bible);
        // Contenido guardado con la pantalla de antes.
        await db.saveBibleSectionFieldValue(
          bible.id,
          BibleSectionId.texture,
          'textureData',
          jsonEncode({
            'grainEnabled': true,
            'grainPreset': 'Kodak Vision3 500T',
            'grainSize': 2.4,
            'diffusionEnabled': true,
            'diffusionFilter': 'Glimmerglass',
            'diffusionDensity': '1/4',
            'pushPullProcessing': '+1 paso',
          }),
        );
        final defs = await db.select(db.bibleSectionDefinitions).get();
        contentJson = defs
            .firstWhere((d) => d.id == BibleSectionId.texture)
            .contentJson;
      });

      var changes = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: TextureSection(
                data: data,
                projectId: data.projectId,
                sectionContentJson: contentJson,
                onChanged: (_) => changes++,
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);

      expect(find.text('GRANO'), findsOneWidget);
      expect(find.text('DIFUSIÓN'), findsOneWidget);
      expect(find.text('RUIDO DEL SENSOR'), findsOneWidget);
      expect(find.text('Kodak Vision3 500T'), findsOneWidget);
      expect(find.text('2.4 µm'), findsOneWidget);
      expect(find.text('Glimmerglass'), findsOneWidget);
      expect(find.text('1/4'), findsOneWidget);
      expect(find.text('+1 paso'), findsOneWidget);
      expect(find.byType(Slider), findsNothing);

      for (final example in [
        'Film Grain',
        'Diffusion',
        'Sensor Noise',
        'Save Preset',
        'Reset',
        'Split View',
        'Calibrate',
        'Soft roll-off',
      ]) {
        expect(find.textContaining(example), findsNothing, reason: example);
      }

      // Cambiar la densidad actualiza también la nota que leen Óptica y
      // el resumen.
      await tester.enterText(find.widgetWithText(TextFormField, '1/4'), '1/8');
      await tester.pump(const Duration(milliseconds: 600));
      expect(changes, greaterThan(0));
      expect(data.diffusionNotes, 'Glimmerglass 1/8');

      await saveSnapshot(tester, 'textura_${width.toInt()}');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  }
}
