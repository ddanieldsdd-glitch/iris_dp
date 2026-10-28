import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/unreal_link/unreal_project_installer.dart';

const _ini = '''
; comentario
[/Script/Engine.RendererSettings]
r.RayTracing=True
r.Lumen.HardwareRayTracing=True
''';

Future<String> _load(String asset) async =>
    asset == UnrealProjectInstaller.iniAsset ? _ini : '# link v1\n';

void main() {
  late Directory dir;
  late String uproject;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('iris_unreal_');
    uproject = '${dir.path}${Platform.pathSeparator}Plato.uproject';
    await File(uproject).writeAsString(
      jsonEncode({
        'FileVersion': 3,
        'EngineAssociation': '5.5',
        'Plugins': [
          {'Name': 'RemoteControl', 'Enabled': false},
          {'Name': 'Water', 'Enabled': true},
        ],
      }),
    );
    final python = Directory('${dir.path}/Content/Python')
      ..createSync(recursive: true);
    File('${python.path}/init_unreal.py').writeAsStringSync('import mio\n');
    Directory('${dir.path}/Config').createSync();
    File('${dir.path}/Config/DefaultEngine.ini').writeAsStringSync(
      '[/Script/EngineSettings.GameMapsSettings]\nGameDefaultMap=/Game/Mapa\n'
      '\n[/Script/Engine.RendererSettings]\nr.RayTracing=False\n',
    );
  });

  tearDown(() => dir.delete(recursive: true));

  Future<UnrealInstallReport> run() => UnrealProjectInstaller.install(
    uproject,
    loadAsset: _load,
    findEditor: (_) => r'C:\UE\UnrealEditor.exe',
    windows: true,
  );

  test('deja el proyecto listo sin perder lo que tenía', () async {
    final report = await run();
    expect(report.projectName, 'Plato');
    expect(report.hasWarnings, isFalse);

    final json = jsonDecode(File(uproject).readAsStringSync()) as Map;
    final plugins = {
      for (final p in json['Plugins'] as List) p['Name']: p['Enabled'],
    };
    expect(plugins['Water'], true);
    for (final p in UnrealProjectInstaller.plugins) {
      expect(plugins[p], true, reason: p);
    }
    expect(File('$uproject.antes-de-iris').existsSync(), isTrue);

    final init = File('${dir.path}/Content/Python/init_unreal.py');
    expect(init.readAsStringSync(), contains('import mio'));
    expect(init.readAsStringSync(), contains('import iris_stage_link'));
    expect(
      File('${dir.path}/Content/Python/iris_stage_link.py').readAsStringSync(),
      '# link v1\n',
    );

    final ini = File('${dir.path}/Config/DefaultEngine.ini').readAsStringSync();
    expect(ini, contains('GameDefaultMap=/Game/Mapa'));
    expect(ini, contains('r.RayTracing=True'));
    expect(ini, isNot(contains('r.RayTracing=False')));
    expect(ini, contains('r.Lumen.HardwareRayTracing=True'));
    expect('[/Script/Engine.RendererSettings]'.allMatches(ini), hasLength(1));

    final bat = File(report.launcherPath!).readAsStringSync();
    expect(bat, contains(r'"C:\UE\UnrealEditor.exe" "%~dp0Plato.uproject"'));
    expect(bat, contains('-EditorPixelStreamingStartOnLaunch'));
  });

  test('la segunda vez no cambia nada', () async {
    await run();
    final again = await run();
    expect(
      again.lines.where((l) => l.changed).map((l) => l.text),
      ['Lanzador creado junto al proyecto: «Abrir Plato con IRIS Stage».'],
    );
  });

  test('sin Unreal en el PC avisa y no crea el lanzador', () async {
    final report = await UnrealProjectInstaller.install(
      uproject,
      loadAsset: _load,
      findEditor: (_) => null,
      windows: true,
    );
    expect(report.hasWarnings, isTrue);
    expect(report.launcherPath, isNull);
  });

  test('un archivo que no es .uproject no se toca', () async {
    expect(
      () => UnrealProjectInstaller.install(
        '${dir.path}/Config/DefaultEngine.ini',
        loadAsset: _load,
      ),
      throwsFormatException,
    );
  });

  test('mergeIni añade secciones nuevas al final', () {
    expect(
      UnrealProjectInstaller.mergeIni('', _ini),
      '[/Script/Engine.RendererSettings]\n'
      'r.RayTracing=True\n'
      'r.Lumen.HardwareRayTracing=True\n',
    );
  });
}
