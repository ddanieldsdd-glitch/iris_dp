import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:iris_dp/features/camera_plan/rig/scan_builder.dart';
import 'package:iris_dp/features/camera_plan/rig/scan_store.dart';

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('scan_builder'));
  tearDown(() => tmp.deleteSync(recursive: true));

  group('RealityScanInstall.find', () {
    test('no vale el instalador (AppProxy.exe)', () {
      final d = Directory(p.join(tmp.path, 'RealityCapture'))..createSync();
      File(p.join(d.path, 'AppProxy.exe')).writeAsStringSync('');
      expect(
        RealityScanInstall.find(roots: [tmp.path], launcherFile: 'nada'),
        isNull,
      );
    });

    test('prefiere RealityScan a RealityCapture', () {
      for (final (dir, exe) in [
        ('RealityCapture', 'RealityCapture.exe'),
        ('RealityScan_2.0', 'RealityScan.exe'),
      ]) {
        final d = Directory(p.join(tmp.path, dir))..createSync();
        File(p.join(d.path, exe)).writeAsStringSync('');
      }
      final found = RealityScanInstall.find(
        roots: [tmp.path],
        launcherFile: 'nada',
      );
      expect(found?.name, 'RealityScan');
    });

    test('lee la lista del Epic Games Launcher', () {
      final d = Directory(p.join(tmp.path, 'otro', 'RealityScan_2.1'))
        ..createSync(recursive: true);
      File(p.join(d.path, 'RealityScan.exe')).writeAsStringSync('');
      final list = File(p.join(tmp.path, 'LauncherInstalled.dat'))
        ..writeAsStringSync(
          jsonEncode({
            'InstallationList': [
              {'InstallLocation': d.path},
            ],
          }),
        );
      expect(
        RealityScanInstall.find(roots: const [], launcherFile: list.path)?.exe,
        p.join(d.path, 'RealityScan.exe'),
      );
    });
  });

  test('findFfmpeg busca en el PATH', () {
    File(p.join(tmp.path, 'ffmpeg.exe')).writeAsStringSync('');
    expect(
      findFfmpeg(environment: {'PATH': r'C:\nada;' + tmp.path}),
      p.join(tmp.path, 'ffmpeg.exe'),
    );
    expect(findFfmpeg(environment: {'PATH': r'C:\nada'}), isNull);
  });

  test('argumentos de RealityScan: dos exportes, el de Unreal primero', () {
    final args = realityScanArgs(
      imagesDir: 'fotos',
      highGlb: 'unreal.glb',
      irisGlb: 'iris.glb',
      projectFile: 'escaneo.rsproj',
    );
    expect(args.first, '-headless');
    expect(args.last, '-quit');
    expect(args.sublist(args.indexOf('-addFolder'), 4), [
      '-addFolder',
      'fotos',
    ]);
    final exports = [
      for (var i = 0; i < args.length; i++)
        if (args[i] == '-exportSelectedModel') args[i + 1],
    ];
    expect(exports, ['unreal.glb', 'iris.glb']);
    final simplify = [
      for (var i = 0; i < args.length; i++)
        if (args[i] == '-simplify') int.parse(args[i + 1]),
    ];
    expect(simplify, [3000000, 400000]);
  });

  test('argumentos de ffmpeg', () {
    final args = ffmpegArgs('v.mp4', 'out', 2);
    expect(args, containsAllInOrder(['-i', 'v.mp4', '-vf', 'fps=2.0']));
    expect(args.last, p.join('out', 'f_%05d.jpg'));
  });

  group('nitidez', () {
    img.Image checker() {
      final im = img.Image(width: 200, height: 200);
      for (var y = 0; y < 200; y++) {
        for (var x = 0; x < 200; x++) {
          final on = ((x ~/ 4) + (y ~/ 4)).isEven;
          im.setPixelRgb(x, y, on ? 255 : 0, on ? 255 : 0, on ? 255 : 0);
        }
      }
      return im;
    }

    test('una imagen movida es menos nítida', () {
      final sharp = checker();
      final blurred = img.gaussianBlur(checker(), radius: 6);
      expect(sharpness(sharp), greaterThan(sharpness(blurred) * 5));
    });

    test('keepSharp descarta los muy por debajo de la mediana', () {
      final keep = keepSharp({
        'a.jpg': 100,
        'b.jpg': 90,
        'c.jpg': 110,
        'd.jpg': 10,
      });
      expect(keep, ['a.jpg', 'b.jpg', 'c.jpg']);
    });
  });

  test('nombre de carpeta sin caracteres raros y con fecha', () {
    expect(
      ScanBuildJob.folderName('Casa: salón/1', DateTime(2026, 11, 2, 9, 5)),
      'Casa salón1 20261102-0905',
    );
    expect(
      ScanBuildJob.folderName('  ', DateTime(2026, 1, 1)),
      'Escaneo 20260101-0000',
    );
  });

  test('vídeo sin ffmpeg: avisa y no lanza nada', () async {
    final video = File(p.join(tmp.path, 'v.mp4'))..writeAsStringSync('');
    final job = ScanBuildJob(
      source: video.path,
      name: 'prueba',
      realityScan: const RealityScanInstall('no-existe.exe'),
      outputRoot: tmp.path,
    );
    final events = await job.run().toList();
    expect(events.single.stage, ScanBuildStage.error);
    expect(events.single.message, contains('ffmpeg'));
  });

  test('pocas fotos: avisa antes de lanzar RealityScan', () async {
    final photos = Directory(p.join(tmp.path, 'fotos'))..createSync();
    for (var i = 0; i < 5; i++) {
      File(p.join(photos.path, '$i.jpg')).writeAsStringSync('');
    }
    final job = ScanBuildJob(
      source: photos.path,
      name: 'prueba',
      realityScan: const RealityScanInstall('no-existe.exe'),
      outputRoot: tmp.path,
    );
    final events = await job.run().toList();
    expect(events.single.stage, ScanBuildStage.error);
    expect(events.single.message, contains('Solo hay 5'));
  });

  test('la malla para Unreal se llama como el escaneo con _ue', () {
    expect(ScanStore.unrealName('m1abc.glb'), 'm1abc_ue.glb');
    expect(ScanStore.unrealName('m1abc.obj'), 'm1abc_ue.glb');
  });
}
