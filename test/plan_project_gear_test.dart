import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' show Color, Offset;
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/plan_cast.dart';
import 'package:iris_dp/features/camera_plan/plan_equipment.dart';
import 'package:iris_dp/features/camera_plan/plan_marks.dart';

void main() {
  late AppDatabase db;
  late int projectId;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    projectId = await db.insertProject(ProjectsCompanion.insert(name: 'Gear'));
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> camera(String model, double sensor) => db
      .into(db.cameras)
      .insert(
        CamerasCompanion.insert(
          brand: 'ARRI',
          model: model,
          sensorWidthMm: sensor,
          sensorHeightMm: 19,
          nativeIso: const Value(800),
        ),
      );

  Future<int> lens(double focal, {String series = 'Master Prime'}) => db
      .into(db.lenses)
      .insert(
        LensesCompanion.insert(
          brand: 'ARRI',
          model: '$series ${focal.round()}mm',
          focalLength: focal,
          minTStop: 1.3,
          formatCoverage: 'S35',
          series: Value(series),
        ),
      );

  test(
    'un juego entero menos una focal deja en el proyecto las demás',
    () async {
      final ids = [
        for (final f in [18.0, 25.0, 35.0, 50.0, 75.0]) await lens(f),
      ];
      final other = await lens(40, series: 'Signature Prime');

      await ProjectGearEdits.set(db, projectId, 'lens', ids, inProject: true);
      await ProjectGearEdits.set(db, projectId, 'lens', [
        ids[2],
      ], inProject: false);
      await ProjectGearEdits.set(db, projectId, 'lens', [
        other,
      ], inProject: true);
      // Repetir no duplica.
      await ProjectGearEdits.set(
        db,
        projectId,
        'lens',
        ids.take(2).toList(),
        inProject: true,
      );

      final gear = await ProjectGear.load(db, projectId);
      expect(gear.lenses.map((l) => l.focalLength), [18, 25, 40, 50, 75]);
      // Marca el proyecto como cambiado, para que la nube no lo pise.
      final project = await db.getProject(projectId);
      expect(project!.contentSyncUpdatedAt, isNotNull);
    },
  );

  test(
    'las cámaras llevan letra por orden y la planta coge su cuerpo',
    () async {
      final mini = await camera('Alexa Mini', 28.25);
      final a35 = await camera('Alexa 35', 27.99);
      await ProjectGearEdits.set(db, projectId, 'camera', [
        mini,
        a35,
      ], inProject: true);

      var gear = await ProjectGear.load(db, projectId);
      expect(gear.cameras.map((c) => c.model), ['Alexa Mini', 'Alexa 35']);
      expect(gear.cameraForLetter('A')!.id, mini);
      expect(gear.cameraForLetter('B')!.id, a35);
      expect(gear.cameraForLetter('C'), isNull);

      // «Hacer A» cambia la principal.
      await ProjectGearEdits.makePrimaryCamera(db, projectId, gear.cameras[1]);
      gear = await ProjectGear.load(db, projectId);
      expect(gear.cameraForLetter('A')!.id, a35);
      expect(gear.cameraForLetter('B')!.id, mini);

      final onPlan = PlanElement(
        id: 1,
        type: ElementType.camera,
        position: Offset.zero,
        cameraLetter: 'B',
      );
      PlanEquipment.applyCamera(onPlan, gear.cameraForLetter('B')!);
      expect(onPlan.props['sensorWidthMm'], 28.25);
      expect(onPlan.props['cameraName'], 'ARRI Alexa Mini');
    },
  );

  test(
    'un zoom entra por su focal corta y se mueve dentro de su rango',
    () async {
      final id = await db
          .into(db.lenses)
          .insert(
            LensesCompanion.insert(
              brand: 'Fujinon',
              model: 'Premista 28-100mm',
              focalLength: 0,
              focalMin: const Value(28),
              focalMax: const Value(100),
              minTStop: 2.9,
              formatCoverage: 'LF',
            ),
          );
      final zoom = (await db.getLensById(id))!;
      final cam = PlanElement(
        id: 1,
        type: ElementType.camera,
        position: Offset.zero,
      );
      PlanEquipment.applyLens(cam, zoom);
      expect(cam.lens, '28mm');
      PlanEquipment.setFocal(cam, 64.4);
      expect(cam.lens, '64mm');
      expect(PlanEquipment.focalOf(cam), 64);
    },
  );

  test('cada posición guarda su giro, y al quitar una no se descolocan', () {
    final actor = PlanElement(
      id: 1,
      type: ElementType.actor,
      position: Offset.zero,
      rotation: 10,
    );
    for (final x in [100.0, 200.0, 300.0]) {
      PlanMarks.add(actor, Offset(x, 0));
    }
    // Sin giro propio, mira como en la anterior.
    expect(PlanMarks.rotationAt(actor, 2), 10);
    PlanMarks.setRotation(actor, 0, 90);
    PlanMarks.setRotation(actor, 2, -90);
    expect(PlanMarks.rotationAt(actor, 0), 90);
    expect(PlanMarks.rotationAt(actor, 1), 90);
    expect(PlanMarks.rotationAt(actor, 2), 270);

    PlanMarks.removeAt(actor, 0);
    expect(actor.pathPoints, const [Offset(200, 0), Offset(300, 0)]);
    expect(PlanMarks.rotationAt(actor, 0), 10);
    expect(PlanMarks.rotationAt(actor, 1), 270);

    PlanMarks.clear(actor);
    expect(actor.pathPoints, isEmpty);
    expect(actor.props.containsKey(PlanMarks.rotKey), isFalse);
    // La postura cambia la altura a la que hace sombra.
    actor.props[PlanMarks.poseKey] = PlanMarks.poseLie;
    expect(PlanMarks.heightM(actor), lessThan(1));
  });

  test('un personaje lleva el mismo color en todas las plantas', () async {
    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'Escena 1',
        locationCanonical: 'INT. CASA - DÍA',
        locationPureName: 'CASA',
      ),
    );
    Future<int> shot(int n) => db.insertShot(
      ShotsCompanion.insert(sceneId: sceneId, projectId: projectId, number: n),
    );
    Future<void> actor(int shotId, String name, String colour) =>
        db.insertCameraPlanElement(
          CameraPlanElementsCompanion.insert(
            shotId: shotId,
            type: 'actor',
            label: Value(name),
            color: Value(colour),
          ),
        );
    final first = await shot(1);
    final second = await shot(2);
    await actor(first, 'Adil', '#FF453A');
    await actor(second, 'ADIL ', '#0A84FF');
    await actor(second, 'Juan', '#30D158');
    await actor(second, 'Actor 3', '#FFD60A');

    var cast = await PlanCast.load(db, projectId);
    // «Actor 3» no es un personaje; Adil cuenta una vez, con su primer
    // color.
    expect(cast.keys, ['ADIL', 'JUAN']);
    expect(cast['ADIL']!.name, 'Adil');
    expect(cast['ADIL']!.color, const Color(0xFFFF453A));

    await PlanCast.recolour(db, projectId, 'adil', const Color(0xFFBF5AF2));
    cast = await PlanCast.load(db, projectId);
    expect(cast['ADIL']!.color, const Color(0xFFBF5AF2));
    final rows = await db.getCameraPlanElementsForShot(second);
    expect(
      rows.firstWhere((r) => r.label == 'ADIL ').color!.toUpperCase(),
      contains('BF5AF2'),
    );
    // A Juan no le cambia.
    expect(cast['JUAN']!.color, const Color(0xFF30D158));
    // Un personaje nuevo coge un color libre.
    expect(
      PlanCast.freeColor(cast.values.map((c) => c.color)),
      isNot(anyOf(const Color(0xFFBF5AF2), const Color(0xFF30D158))),
    );
  });
}
