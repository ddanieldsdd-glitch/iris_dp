import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Visto en el iPad (2026-10-16): un dibujo huérfano hacía chocar la
/// importación entera y el proyecto no se descargaba nunca.
void main() {
  late AppDatabase db;
  late int projectId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'lala'));
    await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'INT. CASA - DÍA',
        locationCanonical: 'INT. CASA - DÍA',
        locationPureName: 'CASA',
      ),
    );
  });

  Future<int> addStill() => db
      .into(db.moodboardImages)
      .insert(
        MoodboardImagesCompanion.insert(
          projectId: projectId,
          imagePath: '/tmp/still.png',
        ),
      );

  Future<void> addDrawing(String type, String targetId) => db
      .into(db.projectAnnotationDocuments)
      .insert(
        ProjectAnnotationDocumentsCompanion.insert(
          projectId: projectId,
          targetType: type,
          targetId: targetId,
          documentJson: '{"strokes":[]}',
        ),
      );

  Future<List<ProjectAnnotationDocument>> drawingsOf(int project) =>
      (db.select(
        db.projectAnnotationDocuments,
      )..where((d) => d.projectId.equals(project))).get();

  test('un dibujo huérfano no tumba la importación', () async {
    final still = await addStill();
    await addDrawing('moodboard_image', '$still');
    // Dibujo de una imagen ya borrada.
    await addDrawing('moodboard_image', '999');
    final bundle = await ProjectContentBundle.export(db, projectId);
    // Un bundle de antes del arreglo traía el huérfano con el id del otro
    // equipo; aquí ese id coincide con el que recibirá la imagen importada.
    final target = await db.insertProject(ProjectsCompanion.insert(name: 'otro'));
    final nextStillId = still + 1;
    (bundle['projectAnnotationDocuments'] as List).add({
      'targetType': 'moodboard_image',
      'targetId': '$nextStillId',
      'targetKey': null,
      'documentJson': '{"huerfano":true}',
    });

    await ProjectContentBundle.importBundle(db, target, bundle);

    final drawings = await drawingsOf(target);
    expect(drawings, hasLength(1));
    expect(drawings.single.documentJson, '{"strokes":[]}');
    final scenes = await (db.select(
      db.scenes,
    )..where((s) => s.projectId.equals(target))).get();
    expect(scenes, hasLength(1));
  });

  test('el huérfano ya no sale en el bundle', () async {
    await addDrawing('moodboard_image', '999');
    await addDrawing('camera_plan_shot', '41');
    final bundle = await ProjectContentBundle.export(db, projectId);
    expect(bundle['projectAnnotationDocuments'], isEmpty);
  });

  test('los dibujos de un esquema de luz vuelven a su esquema', () async {
    final setupId = await db
        .into(db.lightSetups)
        .insert(LightSetupsCompanion.insert(projectId: projectId, name: 'Noche'));
    await addDrawing('camera_plan_light_setup', '$setupId');
    final bundle = await ProjectContentBundle.export(db, projectId);
    final target = await db.insertProject(ProjectsCompanion.insert(name: 'otro'));

    await ProjectContentBundle.importBundle(db, target, bundle);

    final setup = await (db.select(
      db.lightSetups,
    )..where((s) => s.projectId.equals(target))).getSingle();
    expect((await drawingsOf(target)).single.targetId, '${setup.id}');
  });

  test('el boceto de una ficha de luz de la biblia vuelve a su ficha', () async {
    final bible = await db.ensureVisualBibleForProject(projectId);
    // Una ficha antes para que los ids de los dos proyectos no coincidan.
    await db
        .into(db.lightingSetups)
        .insert(
          LightingSetupsCompanion.insert(
            bibleId: bible.id,
            setupName: 'Relleno',
            diagramJson: '{}',
          ),
        );
    final lightingId = await db
        .into(db.lightingSetups)
        .insert(
          LightingSetupsCompanion.insert(
            bibleId: bible.id,
            setupName: 'Clave',
            diagramJson: '{}',
          ),
        );
    await addDrawing('lighting_setup', '$lightingId');
    final bundle = await ProjectContentBundle.export(db, projectId);
    final target = await db.insertProject(ProjectsCompanion.insert(name: 'otro'));

    await ProjectContentBundle.importBundle(db, target, bundle);

    final targetBible = await db.ensureVisualBibleForProject(target);
    final clave = await (db.select(db.lightingSetups)..where(
          (s) => s.bibleId.equals(targetBible.id) & s.setupName.equals('Clave'),
        ))
        .getSingle();
    expect((await drawingsOf(target)).single.targetId, '${clave.id}');
  });
}
