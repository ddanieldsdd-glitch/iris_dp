import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/sync_plan.dart';
import 'package:iris_dp/features/projects/project_card_stats.dart';

/// B3: lo que enseña la tarjeta de cada proyecto.
void main() {
  late AppDatabase db;
  late int projectId;
  late int sceneId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'lala', cloudId: const Value('cloud-1')),
    );
    sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'INT. CASA - DÍA',
        locationCanonical: 'INT. CASA - DÍA',
        locationPureName: 'CASA',
      ),
    );
  });

  Future<int> addShot({String? lens, String? storyboard}) => db
      .into(db.shots)
      .insert(
        ShotsCompanion.insert(
          sceneId: sceneId,
          projectId: projectId,
          number: 1,
          lens: Value(lens),
          storyboardImagePath: Value(storyboard),
        ),
      );

  test('cuenta planta, storyboard y lente de los planos', () async {
    final withPlan = await addShot(lens: '50mm');
    await db
        .into(db.cameraPlanElements)
        .insert(
          CameraPlanElementsCompanion.insert(shotId: withPlan, type: 'camera'),
        );
    await addShot(storyboard: '/tmp/sb.png');
    await addShot(lens: '  ');
    await addShot();

    final stats = await loadProjectCardStats(db, projectId);

    expect(stats.scenes, 1);
    expect(stats.shots, 4);
    expect(stats.shotsWithPlan, 1);
    expect(stats.shotsWithStoryboard, 1);
    expect(stats.shotsWithLens, 1);
  });

  test('la biblia cuenta las pantallas visibles con algo escrito', () async {
    final bibleId = (await db.ensureVisualBibleForProject(projectId)).id;
    await db.ensureBibleSectionLayout(bibleId);
    final before = await loadProjectCardStats(db, projectId);
    expect(before.bibleScreensTotal, greaterThan(0));

    await db.customStatement(
      'UPDATE bible_section_definitions SET content_json = ? '
      'WHERE bible_id = ? AND is_hidden = 0 AND rowid = '
      '(SELECT MIN(rowid) FROM bible_section_definitions '
      'WHERE bible_id = ? AND is_hidden = 0)',
      ['{"values":{"tone":"nocturno"}}', bibleId, bibleId],
    );

    final after = await loadProjectCardStats(db, projectId);
    expect(after.bibleScreensFilled, before.bibleScreensFilled + 1);
  });

  test('el avance es la media de lo que tiene de qué', () {
    expect(
      const ProjectCardStats(
        shots: 4,
        shotsWithPlan: 4,
        shotsWithStoryboard: 2,
        shotsWithLens: 0,
        bibleScreensFilled: 1,
        bibleScreensTotal: 2,
      ).preparationPercent(),
      50,
    );
    expect(
      const ProjectCardStats(
        bibleScreensFilled: 3,
        bibleScreensTotal: 4,
      ).preparationPercent(),
      75,
    );
    expect(const ProjectCardStats().preparationPercent(), 0);
  });

  group('estado con la nube', () {
    Future<ProjectSyncState> state({
      ProjectCardStats stats = const ProjectCardStats(),
      List<SyncPlanAction> plan = const [],
      bool inCloud = true,
    }) async {
      var project = (await db.getProject(projectId))!;
      if (!inCloud) project = project.copyWith(cloudId: const Value(null));
      return projectSyncState(
        project: project,
        stats: stats,
        pendingPlan: SyncPlan(
          items: [
            for (final a in plan)
              SyncPlanItem(
                action: a,
                title: '',
                description: '',
                localProjectId: projectId,
              ),
          ],
        ),
      );
    }

    test('lo más urgente manda', () async {
      expect(await state(), ProjectSyncState.upToDate);
      expect(await state(inCloud: false), ProjectSyncState.localOnly);
      expect(
        await state(stats: const ProjectCardStats(imagesPending: 2)),
        ProjectSyncState.imagesPending,
      );
      expect(
        await state(
          stats: const ProjectCardStats(imagesPending: 2, imagesFailed: 1),
        ),
        ProjectSyncState.imagesFailed,
      );
      expect(
        await state(stats: const ProjectCardStats(contentQueued: true)),
        ProjectSyncState.toUpload,
      );
      expect(
        await state(plan: [SyncPlanAction.pullContentCloud]),
        ProjectSyncState.toDownload,
      );
      expect(
        await state(
          stats: const ProjectCardStats(contentQueued: true),
          plan: [SyncPlanAction.contentConflict],
        ),
        ProjectSyncState.conflict,
      );
    });

    test('la cola de contenido pendiente marca «por subir»', () async {
      await db.touchProjectContent(projectId);
      final stats = await loadProjectCardStats(db, projectId);
      expect(stats.contentQueued, isTrue);
    });
  });

  test(
    'los datos elegidos se guardan y se leen; sin elección, los de siempre',
    () {
      expect(ProjectCardMetric.of(null), ProjectCardMetric.defaults);
      expect(ProjectCardMetric.of('no es json'), ProjectCardMetric.defaults);
      final chosen = [ProjectCardMetric.references, ProjectCardMetric.plan];
      expect(ProjectCardMetric.of(ProjectCardMetric.encode(chosen)), chosen);
      expect(
        ProjectCardMetric.of(
          ProjectCardMetric.encode(ProjectCardMetric.values),
        ),
        hasLength(ProjectCardMetric.maxShown),
      );
    },
  );

  test('el anillo cuenta solo los datos de avance elegidos', () {
    const stats = ProjectCardStats(
      shots: 4,
      shotsWithPlan: 4,
      shotsWithLens: 0,
      references: 99,
    );
    expect(stats.preparationPercent([ProjectCardMetric.plan]), 100);
    expect(
      stats.preparationPercent([
        ProjectCardMetric.plan,
        ProjectCardMetric.lens,
        ProjectCardMetric.references,
      ]),
      50,
    );
  });
}
