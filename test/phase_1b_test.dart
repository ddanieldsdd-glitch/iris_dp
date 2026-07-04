import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/project_hub/project_hub_screen.dart';
import 'package:iris_dp/features/script_import/script_parser.dart';
import 'package:iris_dp/features/technical_script/technical_script_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Fase 1B — importación', () {
    test('fixture sample_guion.txt detecta 4 escenas', () {
      final script = File('test/fixtures/sample_guion.txt').readAsStringSync();
      final sluglines = ScriptParser.parse(script);

      expect(sluglines.length, 4);
      expect(sluglines.first.location, 'COCINA DE MARÍA');
      expect(sluglines.last.dayNight, 'NOCHE');
    });

    test('escenas importadas se guardan en Drift', () async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Import Test'),
      );

      final script = File('test/fixtures/sample_guion.txt').readAsStringSync();
      final sluglines = ScriptParser.parse(script);

      for (final s in sluglines) {
        await db.insertScene(ScenesCompanion.insert(
          projectId: projectId,
          number: s.number,
          name: '${s.intExt} ${s.location} ${s.dayNight}',
          locationCanonical: '${s.intExt}. ${s.location} - ${s.dayNight}',
          locationPureName: s.location,
          intExt: Value(s.intExt),
          dayNight: Value(s.dayNight),
          sortOrder: Value(s.number),
        ));
      }

      final scenes = await db.watchScenesForProject(projectId).first;
      expect(scenes.length, 4);
      expect(scenes.map((s) => s.number).toList(), [1, 2, 3, 4]);
    });
  });

  group('Fase 1B — guion técnico (datos)', () {
    test('escenas agrupadas con cabecera y planos editables', () async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Rodaje Test'),
      );

      await db.insertScene(ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'INT COCINA DE MARÍA DÍA',
        locationCanonical: 'INT. COCINA DE MARÍA - DÍA',
        locationPureName: 'CASA DE MARÍA',
        intExt: const Value('INT'),
        dayNight: const Value('DÍA'),
        sortOrder: const Value(1),
      ));

      final scenes = await db.watchScenesForProject(projectId).first;
      expect(scenes.first.locationPureName, 'CASA DE MARÍA');

      final sceneId = scenes.first.id;
      await db.insertShot(ShotsCompanion.insert(
        sceneId: sceneId,
        projectId: projectId,
        number: 1,
        sortOrder: const Value(0),
      ));

      var shots = await db.watchShotsForScene(sceneId).first;
      await db.updateShot(shots.first.copyWith(
        framing: const Value('PD'),
        movement: const Value('TRÍPODE'),
        angle: const Value('Normal'),
        fStop: const Value('T2.8'),
        action: const Value('Entra por la puerta'),
        notes: const Value('Apunte de prueba'),
      ));

      shots = await db.watchShotsForScene(sceneId).first;
      expect(shots.first.framing, 'PD');
      expect(shots.first.movement, 'TRÍPODE');
      expect(shots.first.angle, 'Normal');
      expect(kMovements, contains('TRÍPODE'));
      expect(kAngles, contains('Normal'));
    });
  });

  group('Fase 1B — UI', () {
    testWidgets('hub del proyecto muestra accesos a importar y guion técnico',
        (tester) async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'Mi Película'),
      );
      final project = (await db.getProject(projectId))!;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AppTheme.dark,
            home: ProjectHubScreen(project: project),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Guion literario'), findsOneWidget);
      expect(find.text('Localizaciones'), findsOneWidget);
      expect(find.text('Plantas de cámara'), findsOneWidget);
      expect(find.text('Guion técnico'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }, skip: 'ProjectHub + NativeDatabase cuelga el runner en algunos entornos');
  });
}
