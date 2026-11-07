import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/core/utils/shot_reference_import.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';
import 'package:iris_dp/features/camera_plan/light/ambient.dart';
import 'package:iris_dp/features/camera_plan/plan_data.dart';
import 'package:iris_dp/features/camera_plan/plan_images.dart';
import 'package:iris_dp/features/camera_plan/plan_renderer.dart';
import 'package:iris_dp/features/camera_plan/plan_sketch_promote.dart';
import 'package:iris_dp/features/camera_plan/shot_plan_view.dart';

class _TempDocs extends PathProviderPlatform with MockPlatformInterfaceMixin {
  final String path;

  _TempDocs(this.path);

  @override
  Future<String?> getApplicationDocumentsPath() async => path;

  @override
  Future<String?> getApplicationSupportPath() async => path;
}

PlanElement _actor(Offset at) =>
    PlanElement(id: 1, type: ElementType.actor, position: at);

Future<Uint8List> _png() async {
  final recorder = ui.PictureRecorder();
  Canvas(
    recorder,
  ).drawRect(const Rect.fromLTWH(0, 0, 4, 3), Paint()..color = Colors.red);
  final image = await recorder.endRecording().toImage(4, 3);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  late AppDatabase db;
  late FloorPlanRepository repo;
  late int projectId;
  late int sceneId;
  late int setId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FloorPlanRepository(db);
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
    setId = await db.insertLocation(
      LocationBasePlansCompanion.insert(
        projectId: projectId,
        locationName: 'Cocina',
      ),
    );
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Escena',
        locationCanonical: 'INT. COCINA - NOCHE',
        locationPureName: 'COCINA',
      ),
    );
  });
  tearDown(() => db.close());

  Future<Shot> addShot(int number) async {
    final id = await db.insertShot(
      ShotsCompanion.insert(
        sceneId: sceneId,
        projectId: projectId,
        number: number,
      ),
    );
    return (await db.getShotById(id))!;
  }

  Future<LightSetup> sketch({String kind = LightSetupKind.sketchElements}) =>
      repo.createLightSetup(
        projectId: projectId,
        name: 'Boceto · Esc 1',
        kind: kind,
        sceneId: sceneId,
      );

  group('hacer oficial un boceto', () {
    test(
      'el mismo esquema pasa a ser planta del set, con sus planos',
      () async {
        final draft = await sketch();
        await repo.saveElements(
          scope: FloorPlanScope.lightSetup,
          lightSetupId: draft.id,
          elements: [_actor(const Offset(100, 100))],
        );
        final shown = await addShot(1);
        await addShotPlanSketchSetup(db: db, shot: shown, setupId: draft.id);
        final free = await addShot(2);

        final promoted = await repo.promoteSketch(
          (await db.getLightSetupById(draft.id))!,
          setId: setId,
          shotIds: {shown.id},
        );

        expect(promoted.id, draft.id, reason: 'no deja una copia detrás');
        expect(LightSetupKind.isSketch(promoted), isFalse);
        expect(promoted.status, 'definitivo');
        expect(promoted.sceneId, isNull);
        expect(promoted.locationBasePlanId, setId);
        expect(promoted.name, 'Esc 1');
        expect(FloorPlanJson.decode(promoted.planJson), hasLength(1));

        final after = (await db.getShotById(shown.id))!;
        expect(after.lightSetupId, draft.id);
        expect(after.locationBasePlanId, setId);
        expect(planSketchEntriesOf(after), isEmpty);
        expect((await db.getShotById(free.id))!.lightSetupId, isNull);

        final data = await PlanProjectData.load(db, projectId);
        expect(data.planSetups.map((s) => s.id), contains(draft.id));
        expect(data.sketchesOfScene(sceneId), isEmpty);
      },
    );

    test('un nombre ocupado en el set no se pisa', () async {
      await repo.createLightSetup(
        projectId: projectId,
        name: 'Esc 1',
        setId: setId,
      );
      final promoted = await repo.promoteSketch(await sketch(), setId: setId);
      expect(promoted.name, 'Esc 1 (2)');
    });

    test('sin set queda en la luz general o como planta libre', () async {
      final siteId = await db.insertSite(
        LocationSitesCompanion.insert(projectId: projectId, name: 'Casa'),
      );
      final general = await repo.promoteSketch(await sketch(), siteId: siteId);
      expect(general.locationSiteId, siteId);
      expect(general.locationBasePlanId, isNull);

      final loose = await repo.promoteSketch(await sketch());
      expect(loose.locationSiteId, isNull);
      expect(loose.locationBasePlanId, isNull);
    });

    test('un boceto a mano entra como imagen de la planta', () async {
      final dir = await Directory.systemTemp.createTemp('boceto_oficial');
      addTearDown(() => dir.delete(recursive: true));
      final previous = PathProviderPlatform.instance;
      PathProviderPlatform.instance = _TempDocs(dir.path);
      addTearDown(() => PathProviderPlatform.instance = previous);
      final file = File('${dir.path}/boceto.png');
      await file.writeAsBytes(await _png());
      final draft = await sketch(kind: LightSetupKind.sketchFreehand);
      await db.updateLightSetup(
        draft.copyWith(sketchImagePath: Value(file.path)),
      );

      final promoted = await repo.promoteSketch(
        (await db.getLightSetupById(draft.id))!,
        setId: setId,
      );

      expect(LightSetupKind.isSketch(promoted), isFalse);
      final images = await PlanImageStore(
        db,
      ).forLayers(projectId: projectId, lightSetupId: promoted.id);
      expect(images, hasLength(1));
      expect(images.single.w, 1600);
    });
  });

  group('sección para documentos', () {
    const view = Rect.fromLTWH(100, 200, 400, 300);

    test('va y vuelve en la planta y se quita', () async {
      final setup = await repo.createLightSetup(projectId: projectId);
      await repo.saveDocumentView(setup.id, view);
      var row = (await db.getLightSetupById(setup.id))!;
      expect(FloorPlanJson.decodeDocument(row.planJson).documentView, view);

      await repo.saveDocumentView(setup.id, null);
      row = (await db.getLightSetupById(setup.id))!;
      expect(FloorPlanJson.decodeDocument(row.planJson).documentView, isNull);
    });

    test('no se pierde al guardar elementos, ambiente o entorno', () async {
      final setup = await repo.createLightSetup(projectId: projectId);
      await repo.saveDocumentView(setup.id, view);
      await repo.saveHiddenGroupLights(setup.id, ['luz']);
      await repo.saveElements(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: setup.id,
        elements: [_actor(const Offset(10, 10))],
      );
      await repo.saveAmbient(setup.id, const PlanAmbient());

      final doc = FloorPlanJson.decodeDocument(
        (await db.getLightSetupById(setup.id))!.planJson,
      );
      expect(doc.documentView, view);
      expect(doc.elements, hasLength(1));
      expect(doc.hiddenGroupLights, ['luz']);
    });

    test('viaja con una copia del esquema', () async {
      final setup = await repo.createLightSetup(projectId: projectId);
      await repo.saveDocumentView(setup.id, view);
      final copy = await repo.copyLightSetup(
        (await db.getLightSetupById(setup.id))!,
        renewUids: true,
      );
      expect(FloorPlanJson.decodeDocument(copy.planJson).documentView, view);
    });

    test('el plano usa la del esquema si no tiene la suya', () async {
      final setup = await repo.createLightSetup(projectId: projectId);
      await repo.saveDocumentView(setup.id, view);
      final shot = await addShot(1);
      await db.assignLightSetupToShot(shot.id, setup.id);

      var data = await PlanProjectData.load(db, projectId);
      var row = (await db.getShotById(shot.id))!;
      expect(data.framingOf(row).crop, view);

      const own = Rect.fromLTWH(0, 0, 200, 100);
      await db.updateShot(
        row.copyWith(planViewJson: Value(encodeShotPlanView(own))),
      );
      data = await PlanProjectData.load(db, projectId);
      row = (await db.getShotById(shot.id))!;
      expect(data.framingOf(row).crop, own);
    });

    Widget host(void Function(BuildContext) open) => ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => open(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );

    test('la planta sale recortada en lo elegido', () async {
      final setup = await repo.createLightSetup(projectId: projectId);
      await repo.saveElements(
        scope: FloorPlanScope.lightSetup,
        lightSetupId: setup.id,
        elements: [
          _actor(const Offset(150, 150)),
          _actor(const Offset(1400, 1000)),
        ],
      );
      final renderer = await PlanRenderer.load(db, projectId);
      final row = renderer.data.setup(setup.id)!;
      final whole = await renderer.setup(row);

      await repo.saveDocumentView(
        setup.id,
        const Rect.fromLTWH(0, 0, 300, 300),
      );
      final again = await PlanRenderer.load(db, projectId);
      final cut = await again.setup(again.data.setup(setup.id)!);

      expect(whole, isNotNull);
      expect(cut, isNotNull);
      expect(cut, isNot(whole));
    });

    testWidgets('el diálogo de hacer oficial propone el set y los planos', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1000, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      late final LightSetup draft;
      late final PlanProjectData data;
      await tester.runAsync(() async {
        await db.updateScene(
          (await db.getSceneById(sceneId))!.copyWith(locationId: Value(setId)),
        );
        await addShot(1);
        draft = await repo.createLightSetup(
          projectId: projectId,
          name: 'Boceto · Esc 1',
          kind: LightSetupKind.sketchElements,
          sceneId: sceneId,
        );
        data = await PlanProjectData.load(db, projectId);
      });
      await tester.pumpWidget(
        host((context) => showPromoteSketchDialog(context, db, data, draft)),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Hacer planta oficial'), findsOneWidget);
      expect(find.text('Cocina'), findsOneWidget);
      expect(find.byType(CheckboxListTile), findsOneWidget);
      expect(
        tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    });

    test('la extensión cuenta imágenes y elementos aunque haya sección', () {
      final picture = PlanPicture(
        elements: [_actor(const Offset(1000, 1000))],
        crop: const Rect.fromLTWH(0, 0, 50, 50),
      );
      final extent = picture.extent!;
      expect(extent.contains(const Offset(1000, 1000)), isTrue);
      expect(extent.contains(const Offset(10, 10)), isTrue);
      expect(const PlanPicture().extent, isNull);
    });
  });
}
