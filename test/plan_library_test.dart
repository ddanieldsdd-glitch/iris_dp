import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide Column, Table;
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/plan_library_store.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_library.dart';
import 'package:iris_dp/features/camera_plan/plan_start_from.dart';

PlanElement lamp(int id) => PlanElement(
  id: id,
  type: ElementType.light,
  lightType: LightType.fresnelMedium,
  position: const Offset(10, 20),
)..props[LightOverrides.uidKey] = 'uid-$id';

String planWithLamps(int n) => FloorPlanJson.encodeDocument(
  FloorPlanDocument(
    elements: [for (var i = 1; i <= n; i++) lamp(i)],
    metersPerUnit: 0.02,
    ambient: const {'day': true},
    underlay: const FloorPlanUnderlay(
      path: '/proyecto/fondo.png',
      rect: Rect.fromLTWH(0, 0, 100, 100),
    ),
  ),
);

void main() {
  late Directory dir;
  late PlanLibraryStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('iris_lib_');
    store = PlanLibraryStore(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  PlanLibraryEntry entry(String uid, int second, {bool deleted = false}) =>
      PlanLibraryEntry(
        uid: uid,
        name: uid,
        updatedAt: DateTime.utc(2026, 1, 1, 0, 0, second),
        deleted: deleted,
      );

  group('en este equipo', () {
    test('guarda, renombra y quita', () {
      final saved = store.add(
        name: 'Noche',
        schemes: [PlanLibraryScheme(name: 'A', planJson: planWithLamps(2))],
      );
      expect(store.list().single.name, 'Noche');
      expect(store.list().single.schemes.single.name, 'A');
      store.rename(saved, 'Noche azul');
      expect(store.list().single.name, 'Noche azul');
      store.remove(store.list().single);
      expect(store.list(), isEmpty);
      expect(store.all().single.deleted, isTrue);
      expect(store.all().single.schemes, isEmpty);
    });

    test('un archivo roto no se lleva la biblioteca', () {
      store.add(name: 'Buena', schemes: const []);
      File('${dir.path}/rota.json').writeAsStringSync('{no es json');
      expect(store.list().single.name, 'Buena');
    });

    test('sin carpeta aún está vacía', () {
      expect(PlanLibraryStore(Directory('${dir.path}/nada')).list(), isEmpty);
    });
  });

  group('entre equipos', () {
    test('gana lo más reciente, en los dos sentidos', () {
      final plan = planLibraryMerge(
        [entry('a', 5), entry('b', 1), entry('solo-aqui', 1)],
        [entry('a', 1), entry('b', 5), entry('solo-alli', 1)],
      );
      expect(
        plan.toUpload.map((e) => e.uid),
        unorderedEquals(['a', 'solo-aqui']),
      );
      expect(
        plan.toStore.map((e) => e.uid),
        unorderedEquals(['b', 'solo-alli']),
      );
    });

    test('un borrado más nuevo no se resucita', () {
      final plan = planLibraryMerge(
        [entry('a', 1)],
        [entry('a', 5, deleted: true)],
      );
      expect(plan.toStore.single.deleted, isTrue);
      expect(plan.toUpload, isEmpty);
    });

    test('si coinciden no se mueve nada', () {
      final plan = planLibraryMerge([entry('a', 1)], [entry('a', 1)]);
      expect(plan.toStore, isEmpty);
      expect(plan.toUpload, isEmpty);
    });

    test('lo que viene de la nube se lee igual', () {
      final original = store.add(
        name: 'Set',
        setPlanJson: '{}',
        schemes: const [PlanLibraryScheme(name: 'A', planJson: '{}')],
      );
      final back = PlanLibraryEntry.fromJson({
        ...original.payload(),
        'uid': original.uid,
        'updatedAt': '2026-01-01T00:00:00+00:00',
        'deleted': false,
      })!;
      expect(back.isSet, isTrue);
      expect(back.schemes.single.name, 'A');
      expect(back.updatedAt.isUtc, isTrue);
    });
  });

  group('entre proyectos', () {
    late AppDatabase db;
    late FloorPlanRepository repo;
    late int source, target, targetSite;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repo = FloorPlanRepository(db);
      source = await db.insertProject(ProjectsCompanion.insert(name: 'Uno'));
      target = await db.insertProject(ProjectsCompanion.insert(name: 'Dos'));
      targetSite = await db.insertSite(
        LocationSitesCompanion.insert(projectId: target, name: 'Nave'),
      );
    });
    tearDown(() => db.close());

    test('el fondo no viaja; luces, escala y ambiente, sí', () {
      final doc = FloorPlanJson.decodeDocument(
        PlanLibrary.portable(planWithLamps(2)),
      );
      expect(doc.underlay, isNull);
      expect(doc.elements, hasLength(2));
      expect(doc.metersPerUnit, 0.02);
      expect(doc.ambient?['day'], isTrue);
    });

    test('un esquema pasa a otro proyecto como copia independiente', () async {
      final setup = (await repo.createLightSetup(
        projectId: source,
        name: 'Contraluz',
      )).copyWith(planJson: Value(planWithLamps(3)));
      await db.updateLightSetup(setup);
      final entry = PlanLibrary(db).saveSetup(store, setup, name: 'Contraluz');

      final made = await PlanLibrary(
        db,
      ).createSetup(entry.schemes.single, projectId: target);
      expect(made.projectId, target);
      expect(made.name, 'Contraluz');
      final stored = await db.getLightSetupById(made.id);
      final lights = FloorPlanJson.decode(stored!.planJson);
      expect(lights, hasLength(3));
      expect(
        lights.map(LightOverrides.uidOf).toSet().intersection({
          'uid-1',
          'uid-2',
          'uid-3',
        }),
        isEmpty,
      );
      expect(
        FloorPlanJson.decode(store.list().single.schemes.single.planJson),
        hasLength(3),
      );

      final again = await PlanLibrary(
        db,
      ).createSetup(entry.schemes.single, projectId: target);
      expect(again.name, 'Contraluz (copia)');
    });

    test('un set pasa con su planta y todos sus esquemas', () async {
      final siteId = await db.insertSite(
        LocationSitesCompanion.insert(projectId: source, name: 'Casa'),
      );
      final setId = await db.insertLocation(
        LocationBasePlansCompanion.insert(
          projectId: source,
          siteId: Value(siteId),
          locationName: 'Cocina',
          floorPlanJson: Value(planWithLamps(1)),
        ),
      );
      final set = (await db.getLocationById(setId))!;
      for (final name in ['Día', 'Noche']) {
        final s = await repo.createLightSetup(
          projectId: source,
          setId: setId,
          name: name,
        );
        await db.updateLightSetup(
          s.copyWith(planJson: Value(planWithLamps(2))),
        );
      }
      final entry = await PlanLibrary(db).saveSet(store, set, name: 'Cocina');
      expect(entry.isSet, isTrue);
      expect(planLibrarySummary(entry), contains('2 esquemas'));

      final made = await PlanLibrary(db).createSet(
        entry,
        projectId: target,
        siteId: targetSite,
        name: 'Cocina nueva',
      );
      expect(made.projectId, target);
      expect(made.siteId, targetSite);
      expect(FloorPlanJson.decode(made.floorPlanJson), hasLength(1));
      final setups = (await db.getLightSetupsForProject(
        target,
      )).where((s) => s.locationBasePlanId == made.id).toList();
      expect(setups.map((s) => s.name), unorderedEquals(['Día', 'Noche']));
      expect(FloorPlanJson.decode(setups.first.planJson), hasLength(2));
    });
  });

  group('en pantalla', () {
    Widget host(Future<void> Function(BuildContext) open) => MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => open(context),
          child: const Text('abrir'),
        ),
      ),
    );

    final saved = PlanLibraryEntry(
      uid: 'x',
      name: 'Noche azul',
      updatedAt: DateTime.utc(2026),
      schemes: [PlanLibraryScheme(name: 'A', planJson: planWithLamps(2))],
    );
    final savedSet = PlanLibraryEntry(
      uid: 'y',
      name: 'Cocina',
      updatedAt: DateTime.utc(2026),
      setPlanJson: '{}',
      schemes: const [],
    );

    testWidgets('«Nuevo esquema» ofrece la biblioteca', (tester) async {
      LightSetupStart? choice;
      await tester.pumpWidget(
        host(
          (context) async => choice = await pickLightSetupStart(
            context,
            sources: const [],
            siteName: 'Nave',
            library: [saved],
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('De la biblioteca · Noche azul'));
      await tester.pumpAndSettle();
      expect(choice?.scheme?.name, 'A');
      expect(choice?.source, isNull);
    });

    testWidgets('«Nuevo set» parte de un set guardado y toma su nombre', (
      tester,
    ) async {
      NewSetRequest? request;
      await tester.pumpWidget(
        host(
          (context) async => request = await askNewSet(
            context,
            siteName: 'Nave',
            sets: const [],
            siteHasLights: false,
            setsWithLights: const {},
            library: [saved, savedSet],
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vacío'));
      await tester.pumpAndSettle();
      expect(find.text('Biblioteca · Noche azul'), findsNothing);
      await tester.tap(find.text('Biblioteca · Cocina').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();
      expect(request?.fromLibrary?.uid, 'y');
      expect(request?.name, 'Cocina');
    });

    testWidgets('la hoja quita con confirmación', (tester) async {
      store.add(name: 'Noche', schemes: const []);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(body: PlanLibrarySheet(store: store)),
        ),
      );
      expect(find.text('Noche'), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quitar…'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('library-remove-yes')));
      await tester.pumpAndSettle();
      expect(find.text('Noche'), findsNothing);
      expect(store.list(), isEmpty);
    });
  });
}
