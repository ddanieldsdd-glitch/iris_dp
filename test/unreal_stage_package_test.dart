import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/light/surfaces.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';
import 'package:iris_dp/features/unreal_link/unreal_stage_package.dart';
import 'package:path/path.dart' as p;

void main() {
  final payload = <String, dynamic>{
    'v': 1,
    'lights': [
      {'id': 'L1'},
    ],
    'scans': [
      {'id': 's', 'file': 'nave.glb'},
    ],
    'scanFolders': ['/Users/alguien/privado'],
    'structure': {'file': 'x.glb', 'folder': '/Users/alguien/privado'},
  };
  final glb = Uint8List.fromList([1, 2, 3, 4]);

  group('paquete .irisstage', () {
    Map<String, dynamic> manifestOf(Archive a) =>
        jsonDecode(
              utf8.decode(a.findFile('manifest.json')!.content as List<int>),
            )
            as Map<String, dynamic>;

    test('lleva la escena entera y sus archivos, sin rutas de este equipo', () {
      final archive = ZipDecoder().decodeBytes(
        UnrealStagePackage.build(
          payload: payload,
          structureGlb: glb,
          scans: {'nave.glb': glb},
        ),
      );
      final manifest = manifestOf(archive);
      expect(manifest['format'], 'irisstage');
      expect(archive.findFile(manifest['structure'] as String), isNotNull);
      expect(archive.findFile('scans/nave.glb'), isNotNull);
      final scene = manifest['payload'] as Map<String, dynamic>;
      expect(scene['full'], isTrue);
      expect(scene.containsKey('scanFolders'), isFalse);
      expect(scene.containsKey('structure'), isFalse);
      expect(jsonEncode(manifest), isNot(contains('/Users/')));
    });

    test('dos estructuras distintas no comparten nombre', () {
      String nameOf(List<int> bytes) =>
          manifestOf(
                ZipDecoder().decodeBytes(
                  UnrealStagePackage.build(
                    payload: payload,
                    structureGlb: Uint8List.fromList(bytes),
                  ),
                ),
              )['structure']
              as String;
      expect(nameOf([1, 2]), isNot(nameOf([3, 4])));
      expect(nameOf([1, 2]), nameOf([1, 2]));
    });

    test('recoge el escaneo y su versión de detalle si están', () async {
      final dir = Directory.systemTemp.createTempSync('iris_pkg_');
      addTearDown(() => dir.deleteSync(recursive: true));
      File(p.join(dir.path, 'nave.glb')).writeAsBytesSync(glb);
      File(p.join(dir.path, 'nave_ue.glb')).writeAsBytesSync(glb);
      final found = await UnrealStagePackage.collectScans(
        [
          {'file': 'nave.glb'},
          {'file': 'no_esta.glb'},
        ],
        ['/no/existe', dir.path],
      );
      expect(found.keys, unorderedEquals(['nave.glb', 'nave_ue.glb']));
    });

    test(
      'el plugin de Unreal lo abre (fuera de Unreal)',
      () async {
        final dir = Directory.systemTemp.createTempSync('iris_pkg_');
        addTearDown(() => dir.deleteSync(recursive: true));
        final file = File(p.join(dir.path, 'set.irisstage'))
          ..writeAsBytesSync(
            UnrealStagePackage.build(
              payload: payload,
              structureGlb: glb,
              scans: {'nave.glb': glb},
            ),
          );
        final run = await Process.run('python3', [
          'tools/unreal/iris_stage/tests/check_import.py',
          'tools/unreal/iris_stage/Content/Python/iris_stage_link.py',
          file.path,
        ]);
        expect(run.exitCode, 0, reason: '${run.stdout}\n${run.stderr}');
      },
      skip: Platform.isWindows ? 'Necesita python3' : false,
    );

    test('la orden de la consola usa ruta literal', () {
      expect(
        UnrealStagePackage.importCommand(r'C:\a\b.irisstage'),
        r'import iris_stage_link; iris_stage_link.import_package(r"C:\a\b.irisstage")',
      );
    });
  });

  group('color de las superficies', () {
    double luminance(int rgb) =>
        (0.2126 * (rgb >> 16 & 255) +
            0.7152 * (rgb >> 8 & 255) +
            0.0722 * (rgb & 255)) /
        255;

    test('el brillo es la reflectancia, en todas las paredes', () {
      for (final m in kWallMaterials) {
        expect(
          luminance(m.albedoRgb),
          closeTo(m.reflectance, 0.02),
          reason: m.id,
        );
      }
    });

    test('lo cálido tira a rojo, lo neutro es gris', () {
      final brick = SurfaceMaterial.byId('brick', kWallMaterials).albedoRgb;
      expect(brick >> 16 & 255, greaterThan(brick & 255));
      final grey = SurfaceMaterial.byId('grey', kWallMaterials).albedoRgb;
      expect(grey >> 16 & 255, grey & 255);
    });

    test('solo la pared con material elegido lleva color', () {
      final plain = PlanSegment.create(
        start: Offset.zero,
        end: const Offset(100, 0),
      )..id = 1;
      final brick = PlanSegment.create(
        start: const Offset(0, 100),
        end: const Offset(100, 100),
      )..id = 2;
      brick.props[LightScene.materialKey] = 'brick';
      final scene = PlanScene3d.build([plain, brick], metersPerUnit: 0.02);
      final walls = (scene['walls'] as List).cast<Map>();
      expect(walls, hasLength(2));
      expect(walls.where((w) => w['rgb'] != null), hasLength(1));
      expect(
        walls.firstWhere((w) => w['rgb'] != null)['rgb'],
        SurfaceMaterial.byId('brick', kWallMaterials).albedoRgb,
      );
    });
  });
}
