import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/core/utils/project_scene_colors.dart';
import 'package:iris_dp/features/script_import/import_scene_sheet.dart';
import 'package:iris_dp/features/script_import/normalized_scene.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('editar una escena del guion: el lugar se elige de los que hay, '
      'sin escribir localización ni set', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late int projectId;
    await tester.runAsync(() async {
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
      await db.ensureSiteAndSet(
        projectId: projectId,
        siteName: 'CALLE RAVAL',
        setName: 'PORTAL',
      );
      await db.ensureSite(projectId: projectId, siteName: 'KEBAB KHALED');
    });

    ImportSceneEditResult? result;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showImportSceneSheet(
                    context,
                    projectId: projectId,
                    scene: const NormalizedScene(
                      number: 3,
                      intExt: 'INT',
                      dayNight: 'NOCHE',
                      location: 'RELLANO BLOQUE PISOS',
                      shootSet: 'RELLANO BLOQUE PISOS',
                      locationSite: 'RELLANO BLOQUE PISOS',
                    ),
                    nextNumber: 3,
                    colorContext: ProjectSceneColors(locations: const []),
                  );
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await settle(tester);

    expect(find.text('Editar escena'), findsOneWidget);
    expect(find.text('En el guion: RELLANO BLOQUE PISOS'), findsOneWidget);
    // Los campos antiguos de texto libre ya no están.
    expect(find.text('Localización'), findsNothing);
    expect(find.text('Set de rodaje'), findsNothing);

    // Se asocia a un set que ya existe.
    await tester.tap(find.text('PORTAL'));
    await settle(tester);
    await tester.tap(find.text('EXT'));
    await settle(tester);
    await tester.tap(find.text('Guardar'));
    await settle(tester);

    expect(result, isNotNull);
    final scene = result!.scene;
    expect(scene.locationSite, 'CALLE RAVAL');
    expect(scene.shootSet, 'PORTAL');
    expect(scene.intExt, 'EXT');
    // El lugar tal como lo escribe el guion no se toca.
    expect(scene.location, 'RELLANO BLOQUE PISOS');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
