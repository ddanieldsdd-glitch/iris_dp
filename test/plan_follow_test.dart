import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/settings/app_prefs.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_repository.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_scope.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_follow.dart';
import 'package:iris_dp/features/camera_plan/plan_marks.dart';
import 'package:iris_dp/features/camera_plan/shot_create.dart';

/// PL.4: los actores de un plano nuevo vienen del anterior y le siguen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FloorPlanRepository repo;
  late int projectId;

  Future<Scene> addScene(int number) async {
    final id = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: number,
        name: 'Escena $number',
        locationCanonical: 'INT. CASA - DÍA',
        locationPureName: 'CASA',
      ),
    );
    return (db.select(db.scenes)..where((s) => s.id.equals(id))).getSingle();
  }

  Future<List<PlanElement>> elementsOf(int shotId) =>
      repo.loadElements(scope: FloorPlanScope.shot, shotId: shotId);

  Future<List<PlanElement>> actorsOf(int shotId) async => [
    for (final e in await elementsOf(shotId))
      if (e.type == ElementType.actor) e,
  ];

  Future<void> save(int shotId, List<PlanElement> elements) =>
      repo.saveElements(
        scope: FloorPlanScope.shot,
        shotId: shotId,
        elements: elements,
      );

  Future<int> newShot(Scene scene) async =>
      createShotInScene(db, scene, await db.getShotsForScene(scene.id));

  /// Escena con un plano 1 que lleva a ADIL con un recorrido y sus marcas.
  Future<(Scene, int)> firstShot() async {
    final scene = await addScene(6);
    final first = await db.insertShot(
      ShotsCompanion.insert(
        sceneId: scene.id,
        projectId: projectId,
        number: 1,
        sortOrder: const Value(0),
      ),
    );
    await save(first, [
      PlanElement(
        id: 0,
        type: ElementType.actor,
        position: const Offset(100, 100),
        rotation: 0.5,
        label: 'ADIL',
        pathPoints: const [Offset(150, 100), Offset(200, 120)],
        props: {
          PlanMarks.rotKey: [0.1, 0.2],
        },
      ),
      PlanElement(id: 0, type: ElementType.camera, position: Offset.zero),
    ]);
    return (scene, first);
  }

  /// Mueve a ADIL en [shotId] a [to] y guarda el plano entero.
  Future<void> moveActor(int shotId, Offset to) async {
    final els = await elementsOf(shotId);
    els.firstWhere((e) => e.type == ElementType.actor).position = to;
    await save(shotId, els);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.ensureLoaded();
    await AppPrefs.reloadForTest();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = FloorPlanRepository(db);
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
  });

  tearDown(() => db.close());

  test(
    'el plano nuevo trae los actores con su recorrido y le siguen',
    () async {
      final (scene, first) = await firstShot();
      final second = await newShot(scene);

      final original = (await actorsOf(first)).single;
      final copy = (await actorsOf(second)).single;
      expect(copy.position, const Offset(100, 100));
      expect(copy.rotation, 0.5);
      expect(copy.pathPoints, const [Offset(150, 100), Offset(200, 120)]);
      expect(copy.props[PlanMarks.rotKey], [0.1, 0.2]);
      expect(LightOverrides.uidOf(copy), isNot(LightOverrides.uidOf(original)));
      final follow = PlanFollow.of(copy)!;
      expect(follow.uid, LightOverrides.uidOf(original));
      expect(follow.shotUid, (await db.getShotById(first))!.uid);
      // La cámara viene también, y sigue siendo una sola.
      expect(
        (await elementsOf(second)).where((e) => e.type == ElementType.camera),
        hasLength(1),
      );
    },
  );

  test('mover en el primero arrastra al 2.º y al 3.º', () async {
    final (scene, first) = await firstShot();
    final second = await newShot(scene);
    final third = await newShot(scene);
    expect(
      PlanFollow.of((await actorsOf(third)).single)!.uid,
      LightOverrides.uidOf((await actorsOf(second)).single),
    );

    await moveActor(first, const Offset(300, 300));

    expect((await actorsOf(second)).single.position, const Offset(300, 300));
    expect((await actorsOf(third)).single.position, const Offset(300, 300));
    // El recorrido viaja también.
    final els = await elementsOf(first);
    els.firstWhere((e) => e.type == ElementType.actor)
      ..pathPoints = const [Offset(10, 10)]
      ..props[PlanMarks.rotKey] = [1.0];
    await save(first, els);
    final last = (await actorsOf(third)).single;
    expect(last.pathPoints, const [Offset(10, 10)]);
    expect(last.props[PlanMarks.rotKey], [1.0]);
  });

  test('si el 2.º se movió, ni él ni el 3.º siguen al primero', () async {
    final (scene, first) = await firstShot();
    final second = await newShot(scene);
    final third = await newShot(scene);

    await moveActor(second, const Offset(50, 50));
    // El 3.º sigue al 2.º, que es a quien copió.
    expect((await actorsOf(third)).single.position, const Offset(50, 50));

    await moveActor(first, const Offset(300, 300));

    expect((await actorsOf(second)).single.position, const Offset(50, 50));
    expect((await actorsOf(third)).single.position, const Offset(50, 50));
  });

  test('guardar un solo elemento (el editor) también arrastra', () async {
    final (scene, first) = await firstShot();
    final second = await newShot(scene);
    final actor = (await actorsOf(first)).single;
    final follow = PlanFollow(db);
    final before = (await follow.loadElement(actor.id))!;
    actor.position = const Offset(7, 7);
    await (db.update(db.cameraPlanElements)
          ..where((e) => e.id.equals(actor.id)))
        .write(const CameraPlanElementsCompanion(x: Value(7), y: Value(7)));
    await follow.elementSaved(first, before, actor);

    expect((await actorsOf(second)).single.position, const Offset(7, 7));
  });

  test('soltar deja de seguir', () async {
    final (scene, first) = await firstShot();
    final second = await newShot(scene);
    final els = await elementsOf(second);
    PlanFollow.release(els.firstWhere((e) => e.type == ElementType.actor));
    await save(second, els);

    await moveActor(first, const Offset(300, 300));

    final copy = (await actorsOf(second)).single;
    expect(PlanFollow.of(copy), isNull);
    expect(copy.position, const Offset(100, 100));
  });

  test('un plano de otra escena no hereda los actores', () async {
    final (_, first) = await firstShot();
    final other = await addScene(7);
    final shot = await newShot(other);

    expect(await actorsOf(shot), isEmpty);
    await moveActor(first, const Offset(300, 300));
    expect(await actorsOf(shot), isEmpty);
  });

  test('dos planos que se siguen el uno al otro no dan vueltas', () async {
    final (scene, first) = await firstShot();
    final second = await newShot(scene);
    // El original pasa a seguir a su copia: un ciclo.
    final a = await elementsOf(first);
    final b = (await actorsOf(second)).single;
    PlanFollow.set(
      a.firstWhere((e) => e.type == ElementType.actor),
      (await db.getShotById(second))!.uid!,
      LightOverrides.uidOf(b)!,
    );
    await save(first, a);

    await moveActor(first, const Offset(300, 300));

    expect((await actorsOf(first)).single.position, const Offset(300, 300));
    expect((await actorsOf(second)).single.position, const Offset(300, 300));
  });
}
