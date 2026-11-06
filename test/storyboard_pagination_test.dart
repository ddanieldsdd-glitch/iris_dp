import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/storyboard/storyboard_group_export_options.dart';
import 'package:iris_dp/shared/pdf_export/storyboard_pdf.dart';

/// El paquete `pdf` descarta sin error lo que no cabe en una columna, así que
/// estos tests cuentan los planos pintados, no el tamaño del archivo.
void main() {
  late AppDatabase db;
  late Project project;
  late Scene scene;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'Prueba'),
    );
    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Calle',
        locationCanonical: 'EXT. CALLE - NOCHE',
        locationPureName: 'CALLE',
      ),
    );
    project = (await db.getProject(projectId))!;
    scene = (await db.getSceneById(sceneId))!;
  });

  tearDown(() async {
    StoryboardPdfExporter.debugPaintedShots = null;
    await db.close();
  });

  Future<List<Shot>> seedShots(int count) async {
    for (var i = 0; i < count; i++) {
      await db.insertShot(
        ShotsCompanion.insert(
          projectId: project.id,
          sceneId: scene.id,
          number: i + 1,
          sortOrder: Value(i),
          action: Value('Acción del plano ${i + 1}'),
          notes: const Value('Una nota del plano'),
        ),
      );
    }
    return db.getShotsForScene(scene.id);
  }

  Future<List<int>> painted(
    List<Shot> shots,
    StoryboardGroupExportChoice choice,
  ) async {
    final seen = <int>[];
    StoryboardPdfExporter.debugPaintedShots = seen;
    await StoryboardPdfExporter.buildBytes(
      project: project,
      scenes: [scene],
      shotsByScene: {scene.id: shots},
      groupChoice: choice,
      db: db,
    );
    return seen;
  }

  test('storyboard de 6 por página pinta todos los planos', () async {
    final shots = await seedShots(20);
    final seen = await painted(
      shots,
      StoryboardGroupExportChoice.sequences(
        StoryboardSequenceLayout.storyboard,
      ),
    );
    expect(seen, shots.map((s) => s.id).toList());
  });

  test('storyboard de 9 por página pinta todos los planos', () async {
    final shots = await seedShots(20);
    final seen = await painted(
      shots,
      StoryboardGroupExportChoice.sequences(
        StoryboardSequenceLayout.storyboard,
        density: StoryboardGridDensity.nine,
      ),
    );
    expect(seen, shots.map((s) => s.id).toList());
  });

  test('shot list pinta todos los planos', () async {
    final shots = await seedShots(10);
    final seen = await painted(
      shots,
      StoryboardGroupExportChoice.sequences(StoryboardSequenceLayout.shotList),
    );
    expect(seen, shots.map((s) => s.id).toList());
  });

  test('una selección exporta solo esos planos', () async {
    final shots = await seedShots(10);
    final picked = [shots[1], shots[4], shots[7]];
    final seen = await painted(
      picked,
      StoryboardGroupExportChoice.sequences(
        StoryboardSequenceLayout.storyboard,
      ),
    );
    expect(seen, picked.map((s) => s.id).toList());
  });
}
