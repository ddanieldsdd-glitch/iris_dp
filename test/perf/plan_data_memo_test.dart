import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/widgets/sized_file_image.dart';
import 'package:iris_dp/features/camera_plan/plan_data.dart';

void main() {
  late AppDatabase db;
  late int projectId;
  late int shotId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'E',
        locationCanonical: 'Casa',
        locationPureName: 'Casa',
      ),
    );
    shotId = await db.insertShot(
      ShotsCompanion.insert(sceneId: sceneId, projectId: projectId, number: 1),
    );
  });

  tearDown(() => db.close());

  Future<void> addCamera(String letter) => db.insertCameraPlanElement(
    CameraPlanElementsCompanion.insert(
      shotId: shotId,
      type: 'camera',
      cameraLetter: Value(letter),
      cameraNumber: const Value(1),
    ),
  );

  test('lo calculado se reutiliza y no se puede tocar', () async {
    await addCamera('A');
    final data = await PlanProjectData.load(db, projectId);
    final shot = data.shots.single;

    expect(identical(data.ownOfShot(shot), data.ownOfShot(shot)), isTrue);
    expect(identical(data.baseOfShot(shot), data.baseOfShot(shot)), isTrue);
    expect(data.ownOfShot(shot).clear, throwsUnsupportedError);
  });

  test('cada instancia ve sus datos', () async {
    await addCamera('A');
    final before = await PlanProjectData.load(db, projectId);
    await addCamera('B');
    final after = await PlanProjectData.load(db, projectId);

    expect(before.ownOfShot(before.shots.single), hasLength(1));
    expect(after.ownOfShot(after.shots.single), hasLength(2));
    expect(after.camerasOfShot(after.shots.single), ['A', 'B']);
  });

  test('el rótulo de cámara no se queda en lo reutilizado', () async {
    await addCamera('A');
    final data = await PlanProjectData.load(db, projectId);
    final shot = data.shots.single;

    final tagged = data.ownOfShot(shot, tagged: true).single;
    expect(tagged.props['shotTag'], '1·1');
    expect(data.ownOfShot(shot).single.props.containsKey('shotTag'), isFalse);
  });

  test('un plano con otros ajustes no recibe los de antes', () async {
    final data = await PlanProjectData.load(db, projectId);
    final shot = data.shots.single;
    final changed = shot.copyWith(lightOverridesJson: const Value('{}'));

    data.baseOfShot(shot);
    expect(identical(data.baseOfShot(shot), data.baseOfShot(changed)), isFalse);
  });

  test('una imagen se decodifica al tamaño al que se ve', () {
    expect(SizedFileImage.decodeWidth(120, 2, BoxFit.contain), 320);
    // Con recorte deja margen para las más panorámicas.
    expect(SizedFileImage.decodeWidth(280, 2, BoxFit.cover), 960);
    // Un cambio pequeño de tamaño no pide otra decodificación.
    expect(
      SizedFileImage.decodeWidth(150, 2, BoxFit.contain),
      SizedFileImage.decodeWidth(155, 2, BoxFit.contain),
    );
  });
}
