import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/widgets/sections/location_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/snapshot.dart';

void main() {
  test('los enlaces de mapas llevan las coordenadas de la localización', () {
    final links = locationMapLinks(41.3797, 2.1682);
    expect(links.map((l) => l.$1), [
      'Google Maps',
      'Waze',
      'Google Earth',
      'Apple Mapas',
    ]);
    for (final (_, url) in links) {
      expect(url, contains('41.3797'));
      expect(url, contains('2.1682'));
      expect(Uri.parse(url).scheme, 'https');
    }
  });

  for (final width in [900.0, 1500.0]) {
    testWidgets('Localización a $width px: una localización nueva no trae '
        'datos inventados ni rótulos en inglés', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await loadSnapshotFonts();
      tester.view.physicalSize = Size(width, 3600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      // La base no se cierra al acabar: con las consultas de esta pantalla
      // el cierre deja el test esperando. Es una base en memoria.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      late int projectId;
      late int bibleId;
      String? contentJson;

      await tester.runAsync(() async {
        projectId = await db.insertProject(
          ProjectsCompanion.insert(name: 'Localización'),
        );
        final bible = await db.ensureVisualBibleForProject(projectId);
        bibleId = bible.id;
        await db.addBuiltinBibleSection(
          bibleId: bible.id,
          sectionId: BibleSectionId.location,
        );
        await db.ensureSiteAndSet(
          projectId: projectId,
          siteName: 'CALLE RAVAL',
          setName: 'CALLE RAVAL',
        );
        await db.ensureSiteAndSet(
          projectId: projectId,
          siteName: 'KEBAB KHALED',
          setName: 'KEBAB KHALED',
        );
        final defs = await db.select(db.bibleSectionDefinitions).get();
        contentJson = defs
            .firstWhere((d) => d.id == BibleSectionId.location)
            .contentJson;
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: LocationSection(
                projectId: projectId,
                bibleId: bibleId,
                sectionContentJson: contentJson,
              ),
            ),
          ),
        ),
      );
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);

      // La entrada: una tarjeta por localización, sin ninguna abierta.
      expect(find.text('CALLE RAVAL'), findsOneWidget);
      expect(find.text('KEBAB KHALED'), findsOneWidget);
      expect(find.text('Todas las localizaciones'), findsNothing);
      expect(
        find.byTooltip('Renombrar, unir o eliminar'),
        findsNWidgets(2),
      );

      // Se entra en una: su página, con lo suyo.
      await tester.tap(find.text('CALLE RAVAL'));
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      expect(find.text('Todas las localizaciones'), findsOneWidget);
      expect(find.text('KEBAB KHALED'), findsNothing);
      expect(find.text('Sin ubicar en el mapa'), findsOneWidget);
      expect(find.text('LA LUZ DEL LUGAR'), findsOneWidget);

      expect(find.textContaining('CALLE RAVAL'), findsWidgets);
      expect(
        find.textContaining(RegExp('luz del sitio', caseSensitive: false)),
        findsWidgets,
      );
      expect(
        find.textContaining(RegExp('hora dorada', caseSensitive: false)),
        findsWidgets,
      );

      // Ningún dato que el usuario no haya escrito.
      for (final example in [
        '06:42',
        '19:15',
        '12h 33m',
        'HMI 18K',
        'Skypanel',
        'Bortle',
        'Partly Cloudy',
        '1:8 (High)',
        'Reflejos en ventanales',
        '#A58D70',
      ]) {
        expect(find.textContaining(example), findsNothing, reason: example);
      }
      // Ni rótulos en inglés.
      for (final english in [
        'Contrast Ratio',
        'Quality of Light',
        'Bounce Potential',
        'Sunrise',
        'Sunset',
        'Blue Hour',
        'Golden Hour',
        'Humidity',
        'Spatial Psychology',
        'Practical Light Sources',
        'Google Earth Location',
      ]) {
        expect(find.textContaining(english), findsNothing, reason: english);
      }

      // Editar un dato no pide «Guardar»: se escribe y se confirma con Intro.
      await tester.tap(
        find.textContaining(RegExp('^contraste\$', caseSensitive: false)).first,
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Guardar'), findsNothing);
      expect(find.text('Cancelar'), findsNothing);
      await tester.enterText(find.byType(TextField).last, '4:1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      // La pantalla de la app relee su contenido; aquí se mira la base.
      late String stored;
      await tester.runAsync(() async {
        final defs = await db.select(db.bibleSectionDefinitions).get();
        stored =
            defs
                .firstWhere((d) => d.id == BibleSectionId.location)
                .contentJson ??
            '';
      });
      expect(stored, contains('4:1'));

      await saveSnapshot(tester, 'localizacion_${width.toInt()}');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  }
}
