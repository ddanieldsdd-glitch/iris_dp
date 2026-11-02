import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:archive/archive.dart';

import 'package:iris_dp/features/camera_plan/rig/scan_builder.dart';
import 'package:iris_dp/features/camera_plan/rig/scan_capture.dart';

/// Cámara de ARKit en (1, 1.5, -2) (Y arriba) mirando hacia +X del mundo:
/// derecha = −Z de ARKit, arriba = +Y, atrás (+Z de la cámara) = −X.
const lookingX = {
  'file': 'f_00001.jpg',
  'transform': [
    0.0, 0.0, -1.0, 0.0, // derecha
    0.0, 1.0, 0.0, 0.0, // arriba
    -1.0, 0.0, 0.0, 0.0, // atrás
    1.0, 1.5, -2.0, 1.0, // posición
  ],
  'intrinsics': [1500.0, 1500.0, 1000.0, 760.0],
  'width': 2000,
  'height': 1500,
};

void main() {
  test('lee una foto y rechaza rutas', () {
    expect(CaptureFrame.fromJson(lookingX)!.width, 2000);
    expect(CaptureFrame.fromJson({...lookingX, 'file': '../x.jpg'}), isNull);
    expect(
      CaptureFrame.fromJson({
        ...lookingX,
        'transform': [1, 2],
      }),
      isNull,
    );
  });

  test('pose en RealityScan: Z arriba, cámara mirando a +Z y Y abajo', () {
    final pose = realityScanPose(CaptureFrame.fromJson(lookingX)!);
    // (x, y, z) de ARKit pasa a (x, −z, y).
    expect(pose.position, [1.0, 2.0, 1.5]);
    // Filas: derecha, abajo y adelante, en el mundo de RealityScan.
    expect(pose.rotation, [
      0.0, 1.0, 0.0, // derecha: −Z de ARKit = +Y de RealityScan
      -0.0, -0.0, -1.0, // abajo
      1.0, -0.0, -0.0, // adelante: +X
    ]);
  });

  test('XMP con focal de 35 mm y punto principal', () {
    final xmp = xmpFor(CaptureFrame.fromJson(lookingX)!);
    expect(xmp, contains('xcr:PosePrior="initial"'));
    expect(xmp, contains('xcr:FocalLength35mm="27.000000000"'));
    expect(xmp, contains('xcr:PrincipalPointV="0.005000000"'));
    expect(xmp, contains('<xcr:Position>1.000000000 2.000000000 1.500000000'));
  });

  test('escribe un .xmp junto a cada foto que existe', () {
    final dir = Directory.systemTemp.createTempSync('captura');
    addTearDown(() => dir.deleteSync(recursive: true));
    File(p.join(dir.path, 'f_00001.jpg')).writeAsStringSync('');
    File(p.join(dir.path, CapturePackage.manifest)).writeAsStringSync(
      jsonEncode({
        'version': 1,
        'device': 'iPhone17,3',
        'frames': [
          lookingX,
          {...lookingX, 'file': 'f_00002.jpg'},
        ],
      }),
    );
    expect(CapturePackage.isCapture(dir.path), isTrue);
    final pkg = CapturePackage.read(dir.path)!;
    expect(pkg.device, 'iPhone17,3');
    expect(pkg.writeSidecars(), 1);
    expect(File(p.join(dir.path, 'f_00001.xmp')).existsSync(), isTrue);
  });

  test('el .zip del iPhone se abre aplanado y sin salirse de la carpeta', () {
    final dir = Directory.systemTemp.createTempSync('zip');
    addTearDown(() => dir.deleteSync(recursive: true));
    final archive = Archive()
      ..addFile(
        ArchiveFile('Sala.iriscapture/capture.json', 2, utf8.encode('{}')),
      )
      ..addFile(ArchiveFile('Sala.iriscapture/f_00001.jpg', 1, [1]))
      ..addFile(ArchiveFile('../fuera.jpg', 1, [2]))
      ..addFile(ArchiveFile('__MACOSX/._f_00001.jpg', 1, [3]));
    final zip = File(p.join(dir.path, 'Sala.iriscapture.zip'))
      ..writeAsBytesSync(ZipEncoder().encode(archive)!);
    final out = p.join(dir.path, 'captura');
    ScanBuildJob.extractCapture(zip.path, out);
    expect(Directory(out).listSync().map((e) => p.basename(e.path)).toSet(), {
      'capture.json',
      'f_00001.jpg',
      'fuera.jpg',
    });
    expect(File(p.join(dir.path, 'fuera.jpg')).existsSync(), isFalse);
    expect(CapturePackage.isCapture(out), isTrue);
  });
}
