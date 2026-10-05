import 'dart:convert';

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/visual_bible/visual_bible_model.dart';
import 'package:iris_dp/features/visual_bible/widgets/sections/direction_section.dart';
import 'package:iris_dp/shared/visual_bible/bible_acts.dart';

void main() {
  testWidgets('Dirección: de biblia antigua a puntos del catálogo y actos '
      'del proyecto', (tester) async {
    tester.view.physicalSize = const Size(1400, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    late VisualBibleData data;
    String? contentJson;
    Future<void> reload() async {
      final def =
          await (db.select(db.bibleSectionDefinitions)..where(
                (d) =>
                    d.bibleId.equals(data.id) &
                    d.id.equals(BibleSectionId.direction),
              ))
              .getSingle();
      contentJson = def.contentJson;
    }

    await tester.runAsync(() async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Dirección'),
      );
      final bible = await db.ensureVisualBibleForProject(projectId);
      await db.addBuiltinBibleSection(
        bibleId: bible.id,
        sectionId: BibleSectionId.direction,
      );
      data = VisualBibleData.fromRow(bible)..cameraPhilosophy = 'Lenta';
      // Contenido guardado con los puntos de antes.
      await db.saveBibleSectionFieldValue(
        bible.id,
        BibleSectionId.direction,
        'directionData',
        jsonEncode({
          'sceneTag': 'SCENE 01',
          'tonePoints': [
            {'title': 'Frío e industrial', 'body': 'Fluorescentes'},
          ],
          'act1Title': 'Orden y rigidez',
          'act1Desc': 'Composiciones simétricas',
        }),
      );
      await reload();
    });

    var changes = 0;
    Widget app() => ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: DirectionSection(
            data: data,
            projectId: data.projectId,
            sectionContentJson: contentJson,
            onChanged: (_) => changes++,
          ),
        ),
      ),
    );
    await tester.pumpWidget(app());
    await tester.pump();

    // Lo de antes se ve en su sitio; la cabecera de escena ya no está.
    expect(find.text('SCENE 01'), findsNothing);
    expect(find.text('Frío e industrial'), findsOneWidget);
    expect(find.text('Lenta'), findsOneWidget);
    expect(find.text('ACTO 1 · PLANTEAMIENTO'), findsOneWidget);
    expect(find.text('Orden y rigidez'), findsOneWidget);
    expect(find.text('Composiciones simétricas'), findsOneWidget);
    expect(find.text('ACTO 3 · DESENLACE'), findsOneWidget);
    expect(find.textContaining('Actos del proyecto'), findsOneWidget);

    // Renombrar un acto lo cambia en el proyecto; la intención es de aquí.
    await tester.tap(find.text('Orden y rigidez'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Título'), 'Orden');
    await tester.enterText(
      find.widgetWithText(TextField, 'Intención'),
      'Cámara fija',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Título y fase van al proyecto; la intención se queda en la pantalla.
    expect(changes, 1);
    final shared = BibleSharedActs.decode(data.actVisualNotes)!;
    expect(shared.map((a) => a.title), ['Orden', '', '']);
    expect(shared.every((a) => a.body.isEmpty), isTrue);

    // Deja que las consultas vivas de la pantalla se cierren.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
