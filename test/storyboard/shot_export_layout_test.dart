import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/sync/project_content_bundle.dart';
import 'package:iris_dp/features/storyboard/shot_export_layout.dart';
import 'package:iris_dp/features/storyboard/shot_frames_sheet_pdf.dart';
import 'package:iris_dp/features/storyboard/shot_sheet_data.dart';

Uint8List jpg(int w, int h) => img.encodeJpg(
  img.Image(width: w, height: h)..clear(img.ColorRgb8(90, 120, 160)),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('el tipo sale del movimiento del guion técnico', () {
    expect(
      ShotExportLayout.kindFromMovement('Paneo a la izquierda'),
      ShotLayoutKind.move,
    );
    expect(
      ShotExportLayout.kindFromMovement('Travelling in'),
      ShotLayoutKind.move,
    );
    expect(
      ShotExportLayout.kindFromMovement('Plano secuencia'),
      ShotLayoutKind.sequence,
    );
    expect(ShotExportLayout.kindFromMovement('Fijo'), ShotLayoutKind.single);
    expect(ShotExportLayout.kindFromMovement(null), ShotLayoutKind.single);
  });

  test('en un paneo, antes y después; lo demás de refuerzo; se guarda', () {
    const images = [
      ShotLayoutImage(id: 'storyboard', path: 's', name: 'Storyboard'),
      ShotLayoutImage(id: 'ref:a', path: 'a', name: 'Referencia 1'),
      ShotLayoutImage(id: 'ref:b', path: 'b', name: 'Referencia 2'),
    ];
    final shot = Shot(
      id: 1,
      sceneId: 1,
      projectId: 1,
      number: 3,
      movement: 'Paneo',
      sortOrder: 0,
      autoNumbering: true,
    );
    var layout = ShotExportLayout.suggested(shot, images);
    expect(layout.kind, ShotLayoutKind.move);
    expect(layout.frames, ['storyboard', 'ref:a']);
    expect(layout.support, ['ref:b']);
    expect(layout.frameLabel(0, 2), 'Antes del movimiento');
    expect(layout.frameLabel(1, 2), 'Después del movimiento');

    // La 2.ª referencia es el final; la 1.ª, fuera.
    layout = layout
        .place('ref:b', ShotImageRole.frame)
        .place('ref:a', ShotImageRole.excluded);
    expect(layout.frames, ['storyboard', 'ref:b']);
    layout = layout.moveFrame('ref:b', -1);
    expect(layout.frames, ['ref:b', 'storyboard']);

    final back = ShotExportLayout.decode(layout.encode())!;
    expect(back.frames, ['ref:b', 'storyboard']);
    expect(back.excluded, ['ref:a']);

    // Una imagen nueva entra de refuerzo; una borrada desaparece.
    final now = back.reconciled(const [
      ShotLayoutImage(id: 'storyboard', path: 's', name: 'Storyboard'),
      ShotLayoutImage(id: 'ref:a', path: 'a', name: 'Referencia 1'),
      ShotLayoutImage(id: 'ref:c', path: 'c', name: 'Referencia 3'),
    ]);
    expect(now.frames, ['storyboard']);
    expect(now.support, ['ref:c']);
    expect(now.excluded, ['ref:a']);
    expect(ShotExportLayout.decode('no es json'), isNull);
  });

  test('la elección viaja con el plano a los demás equipos', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final projectId = await db.insertProject(
      ProjectsCompanion.insert(name: 'P'),
    );
    final sceneId = await db.insertScene(
      ScenesCompanion.insert(
        projectId: projectId,
        number: 1,
        name: 'E',
        locationCanonical: 'INT. CASA - DÍA',
        locationPureName: 'CASA',
      ),
    );
    final layout = const ShotExportLayout(
      kind: ShotLayoutKind.sequence,
      frames: ['storyboard'],
    ).encode();
    await db.insertShot(
      ShotsCompanion.insert(
        sceneId: sceneId,
        projectId: projectId,
        number: 1,
        exportLayoutJson: Value(layout),
      ),
    );
    final bundle = await ProjectContentBundle.export(db, projectId);
    final other = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(other.close);
    final otherProject = await other.insertProject(
      ProjectsCompanion.insert(name: 'P'),
    );
    await ProjectContentBundle.importBundle(other, otherProject, bundle);
    final shot = (await other.getShotsForProject(otherProject)).single;
    expect(
      ShotExportLayout.decode(shot.exportLayoutJson)!.kind,
      ShotLayoutKind.sequence,
    );
  });

  test('la hoja con imágenes se genera con encuadres y refuerzos', () async {
    final dir = Directory.systemTemp.createTempSync('iris_frames');
    addTearDown(() => dir.deleteSync(recursive: true));
    final bytes = await ShotFramesSheetPdf.buildBytes(
      data: const ShotSheetData(
        projectName: 'Aldrun',
        sceneNumber: '13A',
        sceneTitle: 'Bosque',
        sceneSlug: 'EXT. BOSQUE - NOCHE',
        shotNumber: 4,
        shotIndex: 4,
        totalShots: 8,
        sensorWidthMm: 36,
        focalMm: 35,
        fovDegrees: 54,
        movement: 'Paneo',
        action: 'Ali cruza el claro.',
      ),
      kind: ShotLayoutKind.move,
      frames: [
        ShotSheetFrame(bytes: jpg(320, 180), label: 'Antes del movimiento'),
        ShotSheetFrame(bytes: jpg(320, 180), label: 'Después del movimiento'),
      ],
      support: [jpg(200, 200), jpg(300, 150)],
    );
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
    // Cinco partes de una secuencia también caben (dos filas).
    final many = await ShotFramesSheetPdf.buildBytes(
      data: const ShotSheetData(
        projectName: 'Aldrun',
        sceneNumber: '2',
        sceneTitle: '',
        sceneSlug: 'INT. CASA - DÍA',
        shotNumber: 1,
        shotIndex: 1,
        totalShots: 1,
        sensorWidthMm: 36,
        focalMm: 35,
        fovDegrees: 54,
      ),
      kind: ShotLayoutKind.sequence,
      frames: [
        for (var i = 0; i < 5; i++)
          ShotSheetFrame(bytes: jpg(320, 180), label: 'Parte ${i + 1}'),
      ],
      support: const [],
    );
    expect(many.length, greaterThan(1000));
  });
}
