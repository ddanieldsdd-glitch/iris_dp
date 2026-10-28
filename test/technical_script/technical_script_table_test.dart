import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/core/utils/platform_keys.dart';
import 'package:iris_dp/core/utils/shot_reference_import.dart';
import 'package:iris_dp/features/technical_script/table/editable_cell.dart';
import 'package:iris_dp/features/technical_script/technical_script_screen.dart';

/// Base de datos que tarda en guardar el orden, como la de verdad.
class _SlowDb extends AppDatabase {
  _SlowDb() : super.forTesting(NativeDatabase.memory());

  bool slow = true;

  @override
  Future<void> reorderShotsInScene(int sceneId, List<int> ids) async {
    if (slow) await Future<void>.delayed(const Duration(milliseconds: 120));
    return super.reorderShotsInScene(sceneId, ids);
  }
}

void main() {
  late AppDatabase db;

  // Sin red en las pruebas: sin esto cada fuente se intenta bajar y espera
  // hasta fallar (en Windows, minutos por prueba).
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = _SlowDb();
  });

  tearDown(() async {
    await db.close();
  });

  Widget host(Widget child) => ProviderScope(
    overrides: [databaseProvider.overrideWithValue(db)],
    child: MaterialApp(theme: AppTheme.dark, home: child),
  );

  /// Deja que Drift responda y la pantalla se repinte.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Deja acabar una acción con varias escrituras seguidas: cada una
  /// necesita tiempo de verdad y un repintado.
  Future<void> flush(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
    }
  }

  /// Desmonta la pantalla para que Drift cierre sus consultas dentro del test.
  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<int> seed(WidgetTester tester) async {
    late int projectId;
    await tester.runAsync(() async {
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
      final sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 1,
          name: 'Escena',
          locationCanonical: 'EXT. CALLE RAVAL - NOCHE',
          locationPureName: 'CALLE RAVAL',
        ),
      );
      for (var i = 0; i < 3; i++) {
        await db.insertShot(
          ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: i + 1,
            sortOrder: Value(i),
            framing: Value('PML de ALI ${i + 1}'),
            fStop: const Value('T2.8'),
            notes: const Value('mirar planta cam y corregir'),
          ),
        );
      }
    });
    return projectId;
  }

  for (final width in [900.0, 1222.0, 2000.0]) {
    testWidgets('la tabla no desborda a $width px y enseña los planos', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final projectId = await seed(tester);
      await tester.pumpWidget(
        host(TechnicalScriptScreen(projectId: projectId)),
      );
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('PML de ALI 2'), findsOneWidget);
      expect(find.byTooltip('Eliminar plano'), findsNWidgets(3));
      expect(find.byTooltip('Eliminar escena'), findsOneWidget);

      // A todo el ancho, la tabla llega al borde derecho de la ventana.
      if (width >= 1222) {
        final header = tester.getRect(find.text('APUNTES'));
        expect(header.right, lessThanOrEqualTo(width));
        expect(header.left, greaterThan(width * 0.75));
      }
      await unmount(tester);
    });
  }

  testWidgets('eliminar un plano pide confirmación y renumera', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    await tester.tap(find.byTooltip('Eliminar plano').first);
    await settle(tester);
    expect(find.text('Eliminar el plano 1'), findsOneWidget);
    await tester.tap(find.text('Eliminar'));
    await settle(tester);

    expect(find.text('PML de ALI 1'), findsNothing);
    expect(find.byTooltip('Eliminar plano'), findsNWidgets(2));
    final shots = await db.getShotsForProject(projectId);
    expect(shots.map((s) => s.number), [1, 2]);
    await unmount(tester);
  });

  for (final focusFirst in [false, true]) {
    testWidgets('arrastrar un plano lo reordena sin romper la pantalla '
        '(${focusFirst ? 'con' : 'sin'} una celda en edición)', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final projectId = await seed(tester);
      await tester.pumpWidget(
        host(TechnicalScriptScreen(projectId: projectId)),
      );
      await settle(tester);

      if (focusFirst) {
        await tester.tap(find.text('PML de ALI 1'));
        await tester.pump();
      }

      final handles = find.byIcon(Icons.drag_indicator);
      final from = tester.getCenter(handles.at(0));
      // Soltar bajo la última fila lo lleva al final de la escena.
      final to = tester.getCenter(find.text('Añadir plano'));
      final gesture = await tester.startGesture(from);
      await tester.pump(const Duration(milliseconds: 50));
      for (var i = 1; i <= 10; i++) {
        await gesture.moveTo(
          Offset(from.dx, from.dy + (to.dy - from.dy) * i / 10),
        );
        await tester.pump(const Duration(milliseconds: 30));
      }
      await gesture.up();
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(3));
      final shots = await db.getShotsForProject(projectId);
      expect(shots.map((s) => s.framing), [
        'PML de ALI 2',
        'PML de ALI 3',
        'PML de ALI 1',
      ]);
      expect(shots.map((s) => s.number), [1, 2, 3]);
      await unmount(tester);
    });
  }

  testWidgets('arrastrar con ratón, con el aviso del asa a la vista', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    final handles = find.byIcon(Icons.drag_indicator);
    // Soltar sobre una fila coloca el plano delante de ella.
    final from = tester.getCenter(handles.at(2));
    final to = tester.getCenter(handles.at(0));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: from - const Offset(0, 4));
    await mouse.moveTo(from);
    await settle(tester);

    await mouse.down(from);
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 1; i <= 10; i++) {
      await mouse.moveTo(Offset(from.dx, from.dy + (to.dy - from.dy) * i / 10));
      await tester.pump(const Duration(milliseconds: 30));
    }
    await mouse.up();
    await settle(tester);

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(3));
    final shots = await db.getShotsForProject(projectId);
    expect(shots.map((s) => s.framing), [
      'PML de ALI 3',
      'PML de ALI 1',
      'PML de ALI 2',
    ]);
    expect(shots.map((s) => s.number), [1, 2, 3]);
    await mouse.removePointer();
    await unmount(tester);
  });

  testWidgets('editar una celda tras reordenar no devuelve el orden antiguo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    // El plano 1 queda en edición; mientras, se mueve el plano 3 al principio.
    await tester.tap(find.text('PML de ALI 1'));
    await tester.pump();
    await tester.enterText(find.text('PML de ALI 1'), 'PP de ALI');
    (db as _SlowDb).slow = false;
    final before = await db.getShotsForProject(projectId);
    await db.reorderShotsInScene(before.first.sceneId, [
      before[2].id,
      before[0].id,
      before[1].id,
    ]);
    await settle(tester);
    FocusManager.instance.primaryFocus?.unfocus();
    await settle(tester);

    expect(tester.takeException(), isNull);
    final shots = await db.getShotsForProject(projectId);
    expect(shots.map((s) => s.framing), [
      'PML de ALI 3',
      'PP de ALI',
      'PML de ALI 2',
    ]);
    expect(shots.map((s) => s.number), [1, 2, 3]);
    await unmount(tester);
  });

  testWidgets('referencia y planta ocupan el ancho de su columna', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    final header = tester.getSize(
      find
          .ancestor(
            of: find.text('REFERENCIA'),
            matching: find.byType(Container),
          )
          .first,
    );
    final ref = tester.getSize(
      find
          .ancestor(
            of: find.text('Ref.').first,
            matching: find.byType(Container),
          )
          .first,
    );
    expect(ref.width, closeTo(header.width - 8, 0.5));
    await unmount(tester);
  });

  for (final target in ['Arrastra para cambiar el orden', 'Eliminar plano']) {
    testWidgets('el orden cambia con el ratón sobre «$target»', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      (db as _SlowDb).slow = false;

      final projectId = await seed(tester);
      await tester.pumpWidget(
        host(TechnicalScriptScreen(projectId: projectId)),
      );
      await settle(tester);

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      final at = tester.getCenter(find.byTooltip(target).at(1));
      await mouse.addPointer(location: at - const Offset(0, 3));
      await mouse.moveTo(at);
      await settle(tester);
      expect(find.text(target), findsOneWidget, reason: 'aviso a la vista');

      final before = await db.getShotsForProject(projectId);
      await db.reorderShotsInScene(before.first.sceneId, [
        before[2].id,
        before[1].id,
        before[0].id,
      ]);
      await settle(tester);

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(3));
      await mouse.removePointer();
      await unmount(tester);
    });
  }

  testWidgets('una celda es texto hasta que se toca, y al salir guarda', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    // En reposo no hay ningún campo de texto montado.
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.text('PML de ALI 2'));
    await tester.pump();
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'PP de DIEGO');
    // Tocar otra celda saca el foco de la primera.
    await tester.tap(find.text('PML de ALI 3'));
    await settle(tester);

    expect(find.byType(TextField), findsOneWidget);
    final shots = await db.getShotsForProject(projectId);
    expect(shots[1].framing, 'PP de DIEGO');
    expect(find.text('PP de DIEGO'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('la cabecera de la escena cambia INT/EXT y momento al toque', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    await tester.tap(find.byTooltip('Cambiar el momento'));
    await settle(tester);
    await tester.tap(find.text('ATARDECER').last);
    await settle(tester);
    await tester.tap(find.byTooltip('Cambiar interior o exterior'));
    await settle(tester);
    await tester.tap(find.text('EXT').last);
    await settle(tester);

    final scene = (await db.select(db.scenes).get()).single;
    expect(scene.dayNight, 'ATARDECER');
    expect(scene.intExt, 'EXT');
    expect(scene.locationCanonical, 'EXT. CALLE RAVAL - ATARDECER');
    // El nombre propio de la escena no se toca.
    expect(scene.name, 'Escena');
    expect(find.byTooltip('Cambiar el lugar'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('la duración está oculta hasta que se activa en Columnas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);
    expect(find.text('DUR.'), findsNothing);

    await tester.tap(find.text('Columnas'));
    await settle(tester);
    await tester.tap(find.text('Duración'));
    await settle(tester);

    expect(find.text('DUR.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('se puede añadir un movimiento de cámara propio', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    await tester.tap(find.text('Movimiento').first);
    await settle(tester);
    await tester.tap(find.text('Añadir movimiento…'));
    await settle(tester);
    await tester.enterText(find.byType(TextField), 'CAMERA CAR');
    await tester.tap(find.text('Añadir'));
    await settle(tester);

    final shots = await db.getShotsForProject(projectId);
    expect(shots.first.movement, 'CAMERA CAR');

    // Queda en la lista para los demás planos.
    await tester.tap(find.text('Movimiento').first);
    await settle(tester);
    expect(find.text('CAMERA CAR'), findsNWidgets(2));
    await tester.tapAt(const Offset(5, 5));
    await settle(tester);
    await unmount(tester);
  });

  testWidgets('el color de la barra tiñe el plano en el que se trabaja', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    await tester.tap(find.text('PML de ALI 2'));
    await settle(tester);
    await tester.tap(find.byTooltip('Azul'));
    await settle(tester);

    final shots = await db.getShotsForProject(projectId);
    expect(shots.map((s) => s.notesHighlight), [null, 'blue', null]);
    await unmount(tester);
  });

  Future<void> typeWhere(WidgetTester tester, String text) async {
    await tester.enterText(
      find.widgetWithText(TextField, '¿Dónde ocurre?'),
      text,
    );
    await settle(tester);
  }

  testWidgets('menú de nueva escena: un nombre nuevo crea la localización '
      'con Intro y la escena toma ese nombre', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    await tester.tap(find.byTooltip('Añadir escena'));
    await settle(tester);
    expect(find.text('Nueva escena'), findsWidgets);

    await typeWhere(tester, 'kebab khaled');
    expect(
      find.text('Crear «KEBAB KHALED» como localización nueva'),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    await tester.tap(find.text('NOCHE'));
    await settle(tester);
    await tester.tap(find.text('Crear escena'));
    await settle(tester);

    final scenes = await db.select(db.scenes).get();
    final created = scenes.firstWhere((s) => s.number == 2);
    expect(created.locationCanonical, 'INT. KEBAB KHALED - NOCHE');
    expect(created.locationSiteId, isNotNull);
    expect(created.locationId, isNotNull);
    final sites = await db.select(db.locationSites).get();
    expect(sites.map((s) => s.name), ['KEBAB KHALED']);
    await unmount(tester);
  });

  testWidgets('fila «Nueva escena»: asociar a una localización que ya existe '
      'no crea otra, y un set se crea dentro de ella', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await db.ensureSite(projectId: projectId, siteName: 'CALLE RAVAL');
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    await tester.tap(find.text('Nueva escena'));
    await settle(tester);
    // Vacío, enseña las localizaciones que ya hay.
    expect(find.text('CALLE RAVAL'), findsWidgets);

    // Elegir la que existe crea la escena y no otra localización.
    await typeWhere(tester, 'raval');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settle(tester);
    var scenes = await db.select(db.scenes).get();
    expect(scenes.map((s) => s.number), [1, 2]);
    expect(scenes.last.locationCanonical, 'EXT. CALLE RAVAL - DÍA');
    expect((await db.select(db.locationSites).get()).length, 1);

    // Un nombre nuevo, como set dentro de la que existe.
    await typeWhere(tester, 'portal');
    await tester.tap(find.text('Crear «PORTAL» como set dentro de…'));
    await settle(tester);
    expect(
      find.text('¿Dentro de qué localización está «PORTAL»?'),
      findsOneWidget,
    );
    await tester.tap(find.text('aquí'));
    await settle(tester);

    scenes = await db.select(db.scenes).get();
    expect(scenes.map((s) => s.number), [1, 2, 3]);
    expect(scenes.last.locationCanonical, 'EXT. PORTAL - DÍA');
    expect((await db.select(db.locationSites).get()).length, 1);
    final sets = await db.select(db.locationBasePlans).get();
    expect(
      sets.map((s) => s.locationName),
      containsAll(['CALLE RAVAL', 'PORTAL']),
    );
    expect(
      sets.firstWhere((s) => s.locationName == 'PORTAL').siteId,
      isNotNull,
    );
    await unmount(tester);
  });

  testWidgets('un plano con varios encuadres enseña todas sus referencias y '
      'el menú deja quitarlas una a una', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    final tmp = Directory.systemTemp.createTempSync('iris_encuadres');
    addTearDown(() => tmp.deleteSync(recursive: true));
    late int shotId;
    await tester.runAsync(() async {
      final shot = (await db.getShotsForProject(projectId)).first;
      shotId = shot.id;
      final paths = <String>[];
      for (var i = 0; i < 3; i++) {
        final image = img.Image(width: 32, height: 18);
        img.fill(image, color: img.ColorRgb8(40 * i, 60, 110));
        paths.add('${tmp.path}/encuadre$i.png');
        File(paths.last).writeAsBytesSync(img.encodePng(image));
        await db.insertShotReference(
          ShotReferencesCompanion.insert(
            shotId: shot.id,
            imagePath: paths.last,
            sortOrder: Value(i),
          ),
        );
      }
      await db.updateShotFields(
        shot.id,
        ShotsCompanion(referenceImagePath: Value(paths.first)),
      );
    });
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    // Las tres, una debajo de otra, y los otros planos siguen vacíos.
    final images = find.byType(Image);
    expect(images, findsNWidgets(3));
    expect(
      tester.getTopLeft(images.at(1)).dy,
      greaterThan(tester.getBottomLeft(images.at(0)).dy),
    );
    expect(find.text('Ref.'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await tester.tap(images.first);
    await settle(tester);
    expect(find.text('Referencia · Plano 1'), findsOneWidget);
    expect(find.byTooltip('Quitar esta imagen'), findsNWidgets(3));
    // La primera pasa detrás y la segunda queda de principal.
    late List<ShotReference> reordered;
    late Shot afterMove;
    late List<ShotReference> before;
    await tester.runAsync(() async {
      before = await db.watchReferencesForShot(shotId).first;
    });
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Mover detrás').first);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    // Son dos escrituras: la segunda sale tras repintar.
    await flush(tester);
    await tester.runAsync(() async {
      reordered = await db.watchReferencesForShot(shotId).first;
      afterMove = (await db.getShotById(shotId))!;
    });
    expect(reordered.map((r) => r.id), [
      before[1].id,
      before[0].id,
      before[2].id,
    ]);
    expect(afterMove.referenceImagePath, reordered.first.imagePath);
    await settle(tester);
    // El borrado consulta la base con tiempo de verdad.
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Quitar esta imagen').first);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await settle(tester);
    // El menú sigue abierto con las que quedan.
    expect(find.byTooltip('Quitar esta imagen'), findsNWidgets(2));
    late List<ShotReference> left;
    late Shot shot;
    await tester.runAsync(() async {
      left = await db.watchReferencesForShot(shotId).first;
      shot = (await db.getShotById(shotId))!;
    });
    expect(left, hasLength(2));
    expect(shot.referenceImagePath, left.first.imagePath);

    await tester.tap(find.byTooltip('Cerrar'));
    await settle(tester);
    await unmount(tester);
  });

  testWidgets('la referencia abre su menú con arrastrar, pegar y moodboard', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    await tester.tap(find.text('Ref.').first);
    await settle(tester);
    expect(find.text('Referencia · Plano 1'), findsOneWidget);
    expect(find.text('Arrastra una imagen aquí'), findsOneWidget);
    expect(find.text('Del ordenador'), findsOneWidget);
    expect(find.text('Pegar'), findsOneWidget);
    expect(find.text('Dibujar'), findsOneWidget);

    await tester.tap(find.text('Del moodboard'));
    await settle(tester);
    expect(
      find.text('El moodboard de este proyecto aún no tiene imágenes.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Cerrar'));
    await settle(tester);
    await unmount(tester);
  });

  testWidgets('la barra pone negrita a la selección sin sacar el cursor de '
      'la celda, y el texto se lee sin las marcas', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    await tester.tap(find.text('PML de ALI 2'));
    await tester.pump();
    final editor = activeScriptEditor.value!;
    editor.selection = const TextSelection(baseOffset: 0, extentOffset: 3);
    await tester.pump();

    await tester.tap(find.byTooltip('Negrita (${modKey}B)'));
    await settle(tester);
    // Sigue en edición: la barra no le ha quitado el foco.
    expect(activeScriptEditor.value, same(editor));
    expect(editor.text, '**PML** de ALI 2');

    await tester.tap(find.byTooltip('Marcador verde'));
    await settle(tester);
    expect(editor.text, '**==g:PML==** de ALI 2');

    // Al salir de la celda se guarda y se lee sin marcas.
    await tester.tap(find.text('PML de ALI 3'));
    await settle(tester);
    final shots = await db.getShotsForProject(projectId);
    expect(shots[1].framing, '**==g:PML==** de ALI 2');
    expect(find.text('PML de ALI 2', findRichText: true), findsOneWidget);
    expect(find.textContaining('**', findRichText: true), findsNothing);
    await unmount(tester);
  });

  testWidgets('color de una celda suelta', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    await tester.tap(find.text('PML de ALI 2'));
    await settle(tester);
    await tester.tap(find.text('Celda'));
    await settle(tester);
    await tester.tap(find.byTooltip('Verde'));
    await settle(tester);

    var shots = await db.getShotsForProject(projectId);
    expect(shots[1].cellStylesJson, '{"encuadre":"green"}');
    // El plano entero no se tiñe.
    expect(shots[1].notesHighlight, isNull);

    await tester.tap(find.byTooltip('Quitar el color de la celda'));
    await settle(tester);
    shots = await db.getShotsForProject(projectId);
    expect(shots[1].cellStylesJson, isNull);
    await unmount(tester);
  });

  test(
    'referencia y storyboard se prestan la imagen cuando falta la propia',
    () async {
      final projectId = await db.insertProject(
        ProjectsCompanion.insert(name: 'P'),
      );
      final sceneId = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 1,
          name: 'E',
          locationCanonical: 'INT. A - DÍA',
          locationPureName: 'A',
        ),
      );
      Future<Shot> shot({String? reference, String? story}) async {
        final id = await db.insertShot(
          ShotsCompanion.insert(
            sceneId: sceneId,
            projectId: projectId,
            number: 1,
            referenceImagePath: Value(reference),
            storyboardImagePath: Value(story),
          ),
        );
        return (await db.getShotById(id))!;
      }

      final onlyRef = await shot(reference: '/ref.jpg');
      expect(referenceImageOf(onlyRef), '/ref.jpg');
      expect(storyboardImageOf(onlyRef), '/ref.jpg');

      final onlyStory = await shot(story: '/story.jpg');
      expect(referenceImageOf(onlyStory), '/story.jpg');
      expect(storyboardImageOf(onlyStory), '/story.jpg');

      final both = await shot(reference: '/ref.jpg', story: '/story.jpg');
      expect(referenceImageOf(both), '/ref.jpg');
      expect(storyboardImageOf(both), '/story.jpg');

      final none = await shot();
      expect(referenceImageOf(none), isNull);
      expect(storyboardImageOf(none), isNull);
    },
  );

  testWidgets('la planta admite bocetos: imágenes que se ven en la casilla y '
      'se quitan desde su menú', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    final tmp = Directory.systemTemp.createTempSync('iris_bocetos');
    addTearDown(() => tmp.deleteSync(recursive: true));
    late int shotId;
    final paths = <String>[];
    await tester.runAsync(() async {
      final shot = (await db.getShotsForProject(projectId)).first;
      shotId = shot.id;
      for (var i = 0; i < 2; i++) {
        final image = img.Image(width: 32, height: 18);
        img.fill(image, color: img.ColorRgb8(200, 60 * i, 40));
        paths.add('${tmp.path}/boceto$i.png');
        File(paths.last).writeAsBytesSync(img.encodePng(image));
      }
      // Una ruta suelta (como se guardaba antes) también vale.
      await db.updateShotFields(
        shot.id,
        ShotsCompanion(cameraPlanImagePath: Value(paths.first)),
      );
      expect(planSketchesOf((await db.getShotById(shot.id))!), [paths.first]);
      await db.updateShotFields(
        shot.id,
        ShotsCompanion(
          cameraPlanImagePath: Value(jsonEncode(paths)),
        ),
      );
    });
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    // Los dos bocetos del plano 1; los otros planos ofrecen añadir el suyo.
    expect(find.byType(Image), findsNWidgets(2));
    expect(
      find.byTooltip('Añadir un boceto de planta (imagen)'),
      findsNWidgets(2),
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(Image).first);
    await settle(tester);
    expect(find.text('Boceto de planta · Plano 1'), findsOneWidget);
    expect(find.text('Más orígenes'), findsNothing);
    expect(find.byTooltip('Quitar esta imagen'), findsNWidgets(2));

    // Copiar deja la imagen lista para pegarla en otra casilla.
    const channel = MethodChannel('com.iris_dp/export_file_saver');
    final copied = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method != 'writeClipboardImage') return null;
      copied.add((call.arguments as Map)['path']);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.tap(find.byTooltip('Copiar esta imagen').first);
    await settle(tester);
    expect(copied, [paths[0]]);
    expect(find.textContaining('Imagen copiada'), findsOneWidget);

    // La primera pasa detrás: el orden es la prioridad.
    late Shot moved;
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Mover detrás').first);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await flush(tester);
    await settle(tester);
    await tester.runAsync(() async {
      moved = (await db.getShotById(shotId))!;
    });
    expect(planSketchesOf(moved), [paths[1], paths[0]]);

    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Quitar esta imagen').first);
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await flush(tester);
    await settle(tester);
    late Shot shot;
    await tester.runAsync(() async {
      shot = (await db.getShotById(shotId))!;
    });
    expect(planSketchesOf(shot), [paths[0]]);
    await settle(tester);
    expect(find.byTooltip('Quitar esta imagen'), findsOneWidget);

    await tester.tap(find.byTooltip('Cerrar'));
    await settle(tester);
    // La casilla se queda con el que queda.
    expect(find.byType(Image), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('un boceto dibujado en la planta se elige en la casilla y sale '
      'con su rótulo', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    late int shotId;
    late int setupId;
    await tester.runAsync(() async {
      shotId = (await db.getShotsForProject(projectId)).first.id;
      setupId = await db.insertLightSetup(
        LightSetupsCompanion.insert(
          projectId: projectId,
          name: 'Boceto · Esc 1',
        ),
      );
      await db.saveProjectAnnotationDocument(
        projectId: projectId,
        targetType: 'camera_plan_light_setup',
        targetId: '$setupId',
        documentJson:
            '{"strokes":[{"id":"a","tool":"pen","colorArgb":4294901760,'
            '"width":6,"points":[{"x":0.2,"y":0.2},{"x":0.6,"y":0.5}]}]}',
        documentSchemaVersion: 1,
      );
    });
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);
    // Nada llega solo: hay que elegirlo.
    expect(find.text('BOCETO'), findsNothing);

    await tester.tap(
      find.byTooltip('Añadir un boceto de planta (imagen)').first,
    );
    await settle(tester);
    expect(find.text('Bocetos de la planta'), findsOneWidget);
    expect(find.text('Dibujar un boceto nuevo'), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.byTooltip('Enseñar este boceto en el plano'));
      await Future<void>.delayed(const Duration(milliseconds: 300));
    });
    await flush(tester);
    await settle(tester);
    late Shot shot;
    await tester.runAsync(() async {
      shot = (await db.getShotById(shotId))!;
    });
    expect(planSketchEntriesOf(shot), ['setup:$setupId']);
    expect(shot.lightSetupId, isNull);

    await tester.tap(find.byTooltip('Cerrar'));
    await settle(tester);
    expect(find.text('BOCETO'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('deshacer y rehacer: el botón y ⌘Z devuelven una celda a como '
      'estaba', (tester) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);

    Future<String?> framing() async {
      late String? value;
      await tester.runAsync(() async {
        value = (await db.getShotsForProject(projectId))[1].framing;
      });
      return value;
    }

    await tester.tap(find.text('PML de ALI 2'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'PP de DIEGO');
    await tester.tap(find.text('mirar planta cam y corregir').first);
    await flush(tester);
    await settle(tester);
    expect(await framing(), 'PP de DIEGO');

    await tester.tap(find.byTooltip('Deshacer (${modKey}Z)'));
    await flush(tester);
    await settle(tester);
    expect(await framing(), 'PML de ALI 2');

    await tester.tap(find.byTooltip('Rehacer (⇧${modKey}Z)'));
    await flush(tester);
    await settle(tester);
    expect(await framing(), 'PP de DIEGO');
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('la columna de storyboard se activa en Columnas y abre su menú', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final projectId = await seed(tester);
    await tester.pumpWidget(host(TechnicalScriptScreen(projectId: projectId)));
    await settle(tester);
    expect(find.text('STORYBOARD'), findsNothing);

    await tester.tap(find.text('Columnas'));
    await settle(tester);
    await tester.tap(find.text('Storyboard'), warnIfMissed: false);
    await settle(tester);
    expect(find.text('STORYBOARD'), findsOneWidget);
    expect(find.text('Story'), findsNWidgets(3));

    await tester.tap(find.text('Story').first);
    await settle(tester);
    expect(find.text('Storyboard · Plano 1'), findsOneWidget);
    // Los orígenes de captura son solo de la referencia.
    expect(find.text('Más orígenes'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Cerrar'));
    await settle(tester);
    await unmount(tester);
  });
}
