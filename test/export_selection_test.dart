import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/export_center/export_selection.dart';
import 'package:iris_dp/features/shoot_documents/shoot_plan.dart';
import 'package:iris_dp/features/technical_script/technical_script_export.dart';
import 'package:iris_dp/features/technical_script/technical_script_settings.dart';

void main() {
  late AppDatabase db;
  late int projectId;
  late int sceneA;
  late int sceneB;
  late List<int> shotsA;
  late List<int> shotsB;
  late ShootPlanService plan;
  late int day1;
  late int day2;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Prueba'),
    );
    Future<int> scene(int number) => db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: number,
        sortOrder: Value(number),
        name: 'Escena $number',
        locationCanonical: 'INT. CASA - DÍA',
        locationPureName: 'CASA',
      ),
    );
    Future<List<int>> shots(int sceneId, int count) async => [
      for (var i = 0; i < count; i++)
        await db.insertShot(
          ShotsCompanion.insert(
            projectId: projectId,
            sceneId: sceneId,
            number: i + 1,
            sortOrder: Value(i),
          ),
        ),
    ];
    sceneA = await scene(1);
    sceneB = await scene(2);
    shotsA = await shots(sceneA, 3);
    shotsB = await shots(sceneB, 2);
    plan = ShootPlanService(db);
    day1 = await plan.addDay(projectId);
    day2 = await plan.addDay(projectId);
    // Día 1: B2, A1. Día 2: A2, A3 y B2, que se repite.
    await plan.place(
      projectId: projectId,
      dayId: day1,
      items: [
        (sceneId: sceneB, shotId: shotsB[1]),
        (sceneId: sceneA, shotId: shotsA[0]),
      ],
    );
    await plan.place(
      projectId: projectId,
      dayId: day2,
      items: [
        (sceneId: sceneA, shotId: shotsA[1]),
        (sceneId: sceneA, shotId: shotsA[2]),
        (sceneId: sceneB, shotId: shotsB[1]),
      ],
    );
  });

  tearDown(() => db.close());

  Future<ExportSource> source() async =>
      (await ExportSource.load(db, projectId))!;

  Set<int> blocksOf(ExportSource s, Iterable<int> days) => {
    for (final day in days)
      for (final b in s.plan.blocksByDay[day]!) b.id,
  };

  test('Todo: orden de guion, con todos los planos', () async {
    final sections = resolveExportSections(
      await source(),
      const ExportSelection(),
    );
    expect(sections, hasLength(1));
    expect(sections.single.day, isNull);
    expect(sections.single.scenes.map((s) => s.scene.id), [sceneA, sceneB]);
    expect(sections.single.shotCount, 5);
  });

  test(
    'por jornada: orden de rodaje, escena repartida y plano repetido',
    () async {
      final s = await source();
      final sections = resolveExportSections(
        s,
        ExportSelection(
          scope: ExportScope.days,
          blockIds: blocksOf(s, [day1, day2]),
        ),
      );
      expect(sections.map((d) => d.day!.id), [day1, day2]);

      final first = sections[0].scenes;
      expect(first.map((t) => t.scene.id), [sceneB, sceneA]);
      expect(first[0].shots.single.shot.id, shotsB[1]);
      expect(first[0].shots.single.order, 1);
      expect(first[1].shots.single.order, 2);

      final second = sections[1].scenes;
      expect(second.map((t) => t.scene.id), [sceneA, sceneB]);
      expect(second[0].shots.map((x) => x.shot.id), [shotsA[1], shotsA[2]]);
      expect(second[1].shots.single.shot.id, shotsB[1]);

      // El repetido se marca con la otra jornada en cada día.
      expect(first[0].shots.single.alsoIn, ['Jornada 2']);
      expect(second[1].shots.single.alsoIn, ['Jornada 1']);
      expect(first[1].shots.single.alsoIn, isEmpty);
    },
  );

  test('parte de una jornada: conserva su número de orden', () async {
    final s = await source();
    final last = s.plan.blocksByDay[day2]!.last;
    final sections = resolveExportSections(
      s,
      ExportSelection(scope: ExportScope.days, blockIds: {last.id}),
    );
    expect(sections.single.shotCount, 1);
    expect(sections.single.scenes.single.shots.single.order, 3);
  });

  test('un tramo vuelve a abrirse si la escena se interrumpe', () async {
    await plan.place(
      projectId: projectId,
      dayId: day1,
      items: [(sceneId: sceneB, shotId: shotsB[0])],
    );
    final s = await source();
    final sections = resolveExportSections(
      s,
      ExportSelection(scope: ExportScope.days, blockIds: blocksOf(s, [day1])),
    );
    expect(sections.single.scenes.map((t) => t.scene.id), [
      sceneB,
      sceneA,
      sceneB,
    ]);
  });

  test('planos sueltos: solo los elegidos, en orden de guion', () async {
    final sections = resolveExportSections(
      await source(),
      ExportSelection(
        scope: ExportScope.shots,
        shotIds: {shotsB[0], shotsA[2]},
      ),
    );
    expect(sections.single.scenes.map((t) => t.scene.id), [sceneA, sceneB]);
    expect(sections.single.shotCount, 2);
  });

  test('sin nada elegido no hay secciones', () async {
    final s = await source();
    expect(
      resolveExportSections(s, const ExportSelection(scope: ExportScope.days)),
      isEmpty,
    );
    expect(
      resolveExportSections(s, const ExportSelection(scope: ExportScope.shots)),
      isEmpty,
    );
  });

  test('guion de varias jornadas: cada día abre con su cabecera', () async {
    final s = await source();
    final doc = await buildScriptDocFor(
      db,
      s,
      resolveExportSections(
        s,
        ExportSelection(
          scope: ExportScope.days,
          blockIds: blocksOf(s, [day1, day2]),
        ),
      ),
      const TechnicalScriptSettings(),
      hiddenColumns: const {'story', 'ref', 'planta'},
    );
    expect(doc!.columns.first.key, 'orden');
    expect(doc.sections, hasLength(4));
    expect(doc.sections[0].dayHeading, 'Jornada 1');
    expect(doc.sections[1].dayHeading, isNull);
    expect(doc.sections[2].dayHeading, 'Jornada 2');
    expect(
      doc.sections[0].rows.single.cells['orden'],
      contains('También en Jornada 2'),
    );
    expect(doc.sections[3].rows.single.cells['orden'], startsWith('3'));
  });
}
