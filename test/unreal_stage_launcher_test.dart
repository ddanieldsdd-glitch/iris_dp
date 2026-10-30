import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/unreal_link/unreal_stage_launcher.dart';

void main() {
  test('el nombre del proyecto de Unreal es válido', () {
    expect(UnrealStageLauncher.projectNameFor('La caída'), 'IRISLaCaida');
    expect(UnrealStageLauncher.projectNameFor('año 1950 · tren'), 'IRISAno1950Tren');
    expect(
      UnrealStageLauncher.projectNameFor('Un título larguísimo de película'),
      hasLength(20),
    );
    expect(UnrealStageLauncher.projectNameFor('???'), 'IRIS');
  });

  test('crea un proyecto vacío que Unreal abre', () async {
    final dir = await Directory.systemTemp.createTemp('iris_stage_');
    addTearDown(() => dir.delete(recursive: true));
    final path = await UnrealStageLauncher.createProject(
      parentDir: dir.path,
      name: 'IRISPrueba',
      engineVersion: '5.5',
    );
    expect(path, endsWith('IRISPrueba.uproject'));
    final json = jsonDecode(File(path).readAsStringSync()) as Map;
    expect(json['EngineAssociation'], '5.5');
    expect(json['FileVersion'], 3);
    expect(Directory('${dir.path}/IRISPrueba/Content').existsSync(), isTrue);
    // Volver a crearlo no lo pisa.
    File(path).writeAsStringSync('{"FileVersion":3,"Mio":true}');
    await UnrealStageLauncher.createProject(
      parentDir: dir.path,
      name: 'IRISPrueba',
      engineVersion: '5.5',
    );
    expect(File(path).readAsStringSync(), contains('Mio'));
  });

  test('encuentra el Unreal más nuevo desde la 5.5', () async {
    final root = await Directory.systemTemp.createTemp('epic_');
    addTearDown(() => root.delete(recursive: true));
    for (final v in ['5.3', '5.5', '5.6', '4.27']) {
      final bin = Directory('${root.path}/UE_$v/Engine/Binaries/Win64')
        ..createSync(recursive: true);
      File('${bin.path}/UnrealEditor.exe').writeAsStringSync('');
    }
    const none = 'no-existe.dat';
    final found = UnrealStageLauncher.findEngine(
      root: root.path,
      launcherFile: none,
    )!;
    expect(found.version, '5.6');
    expect(found.editor, endsWith('UnrealEditor.exe'));

    Directory('${root.path}/UE_5.6').deleteSync(recursive: true);
    expect(
      UnrealStageLauncher.findEngine(root: root.path, launcherFile: none)!
          .version,
      '5.5',
    );
    Directory('${root.path}/UE_5.5').deleteSync(recursive: true);
    expect(
      UnrealStageLauncher.findEngine(root: root.path, launcherFile: none),
      isNull,
    );
  });

  test('también lo encuentra en otro disco, por la lista del launcher', () async {
    final other = await Directory.systemTemp.createTemp('disco_d_');
    addTearDown(() => other.delete(recursive: true));
    final ue = '${other.path}${Platform.pathSeparator}UE_5.7';
    final bin = Directory('$ue/Engine/Binaries/Win64')
      ..createSync(recursive: true);
    File('${bin.path}/UnrealEditor.exe').writeAsStringSync('');
    final list = File('${other.path}/LauncherInstalled.dat')
      ..writeAsStringSync(
        jsonEncode({
          'InstallationList': [
            {'InstallLocation': ue, 'AppName': 'UE_5.7'},
            {'InstallLocation': '${other.path}/Fortnite', 'AppName': 'Fortnite'},
          ],
        }),
      );
    final found = UnrealStageLauncher.findEngine(
      root: '${other.path}/nada',
      launcherFile: list.path,
    )!;
    expect(found.version, '5.7');
  });
}
