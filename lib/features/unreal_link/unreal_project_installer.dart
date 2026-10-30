import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;

/// Lo que ha hecho el instalador, en palabras de quien lo lee.
class UnrealInstallLine {
  final String text;

  /// `true` si ha cambiado algo; `false` si ya estaba.
  final bool changed;

  /// Algo que hay que hacer a mano.
  final bool warning;

  const UnrealInstallLine(this.text, {this.changed = true, this.warning = false});
}

class UnrealInstallReport {
  final String projectName;
  final String projectPath;
  final List<UnrealInstallLine> lines;

  /// El lanzador «Abrir … con IRIS Stage.bat», si se ha podido crear.
  final String? launcherPath;

  const UnrealInstallReport({
    required this.projectName,
    required this.projectPath,
    required this.lines,
    this.launcherPath,
  });

  bool get hasWarnings => lines.any((l) => l.warning);
}

/// Prepara un proyecto de Unreal para IRIS Stage (lo que explica
/// `tools/unreal/iris_stage/README.md`, hecho por la app):
/// - activa los plugins en el `.uproject`;
/// - copia `iris_stage_link.py` y lo importa en `init_unreal.py`;
/// - añade la calidad RTX a `Config/DefaultEngine.ini`;
/// - en Windows, crea junto al proyecto un lanzador que abre Unreal con
///   Pixel Streaming emitiendo.
///
/// No borra nada: solo añade lo que falta, y guarda una copia
/// (`*.antes-de-iris`) de cada archivo del proyecto antes de tocarlo.
class UnrealProjectInstaller {
  UnrealProjectInstaller._();

  static const plugins = [
    'PythonScriptPlugin',
    'RemoteControl',
    'EditorScriptingUtilities',
    'PixelStreaming2',
  ];

  static const pythonAsset =
      'tools/unreal/iris_stage/Content/Python/iris_stage_link.py';
  static const iniAsset = 'tools/unreal/iris_stage/Config/DefaultEngine.ini';
  static const importLine = 'import iris_stage_link  # IRIS Stage';
  static const backupSuffix = '.antes-de-iris';

  /// Opciones con las que el lanzador abre Unreal: Pixel Streaming emitiendo
  /// el visor desde el principio.
  static const launchFlags =
      '-EditorPixelStreamingStartOnLaunch '
      '-PixelStreamingEditorSource=LevelEditorViewport';

  static Future<UnrealInstallReport> install(
    String uprojectPath, {
    Future<String> Function(String asset)? loadAsset,
    String? Function(String engineAssociation)? findEditor,
    bool? windows,
  }) async {
    final load = loadAsset ?? rootBundle.loadString;
    final uproject = File(uprojectPath);
    if (!uprojectPath.toLowerCase().endsWith('.uproject') ||
        !await uproject.exists()) {
      throw const FormatException('Elige el archivo .uproject del proyecto.');
    }
    final dir = uproject.parent.path;
    final sep = Platform.pathSeparator;
    final name = uproject.uri.pathSegments.last.replaceAll(
      RegExp(r'\.uproject$', caseSensitive: false),
      '',
    );
    final lines = <UnrealInstallLine>[];

    // 1 · Plugins.
    final Map<String, dynamic> json;
    try {
      json = jsonDecode(await uproject.readAsString()) as Map<String, dynamic>;
    } catch (_) {
      throw const FormatException('El .uproject no se puede leer.');
    }
    final list = [
      for (final p in (json['Plugins'] as List? ?? const [])) Map.of(p as Map),
    ];
    final added = <String>[];
    for (final plugin in plugins) {
      final i = list.indexWhere((p) => p['Name'] == plugin);
      if (i < 0) {
        list.add({'Name': plugin, 'Enabled': true});
        added.add(plugin);
      } else if (list[i]['Enabled'] != true) {
        list[i]['Enabled'] = true;
        added.add(plugin);
      }
    }
    if (added.isEmpty) {
      lines.add(const UnrealInstallLine(
        'Los plugins ya estaban activados.',
        changed: false,
      ));
    } else {
      json['Plugins'] = list;
      await _backup(uproject);
      await uproject.writeAsString(
        '${const JsonEncoder.withIndent('\t').convert(json)}\n',
      );
      lines.add(UnrealInstallLine('Plugins activados: ${added.join(', ')}.'));
    }

    // 2 · Python.
    final python = Directory('$dir${sep}Content${sep}Python');
    await python.create(recursive: true);
    final link = File('${python.path}${sep}iris_stage_link.py');
    final linkSource = await load(pythonAsset);
    if (await link.exists() && await link.readAsString() == linkSource) {
      lines.add(const UnrealInstallLine(
        'IRIS Stage Link ya estaba al día.',
        changed: false,
      ));
    } else {
      final existed = await link.exists();
      await link.writeAsString(linkSource);
      lines.add(UnrealInstallLine(
        existed ? 'IRIS Stage Link actualizado.' : 'IRIS Stage Link copiado.',
      ));
    }
    final init = File('${python.path}${sep}init_unreal.py');
    if (!await init.exists()) {
      await init.writeAsString(
        '# Unreal ejecuta este archivo al abrir el editor.\n$importLine\n',
      );
      lines.add(const UnrealInstallLine('init_unreal.py creado.'));
    } else if (!(await init.readAsString()).contains('import iris_stage_link')) {
      await _backup(init);
      await init.writeAsString('\n$importLine\n', mode: FileMode.append);
      lines.add(const UnrealInstallLine('init_unreal.py: añadido IRIS Stage.'));
    } else {
      lines.add(const UnrealInstallLine(
        'init_unreal.py ya cargaba IRIS Stage.',
        changed: false,
      ));
    }

    // 3 · Calidad RTX.
    final config = Directory('$dir${sep}Config');
    await config.create(recursive: true);
    final engineIni = File('${config.path}${sep}DefaultEngine.ini');
    final before = await engineIni.exists()
        ? await engineIni.readAsString()
        : '';
    final merged = mergeIni(before, await load(iniAsset));
    if (merged == before) {
      lines.add(const UnrealInstallLine(
        'Lumen con trazado de rayos ya estaba activado.',
        changed: false,
      ));
    } else {
      if (before.isNotEmpty) await _backup(engineIni);
      await engineIni.writeAsString(merged);
      lines.add(const UnrealInstallLine(
        'Lumen con trazado de rayos por hardware activado. La primera vez '
        'Unreal compilará sombreadores un rato.',
      ));
    }

    // 4 · Lanzador.
    String? launcher;
    if (windows ?? Platform.isWindows) {
      final association = json['EngineAssociation']?.toString() ?? '';
      final editor = (findEditor ?? defaultEditorPath)(association);
      if (editor == null) {
        lines.add(UnrealInstallLine(
          'No encuentro Unreal ${association.isEmpty ? '' : '$association '}'
          'en este PC: abre el proyecto a mano y pon en marcha Pixel '
          'Streaming desde su botón de la barra.',
          changed: false,
          warning: true,
        ));
      } else {
        launcher = '$dir${sep}Abrir $name con IRIS Stage.bat';
        await File(launcher).writeAsString(
          launcherScript(editor: editor, uproject: '$name.uproject'),
        );
        lines.add(UnrealInstallLine(
          'Lanzador creado junto al proyecto: «Abrir $name con IRIS Stage».',
        ));
      }
    } else {
      lines.add(const UnrealInstallLine(
        'Fuera de Windows no se crea el lanzador: abre Unreal y pon en '
        'marcha Pixel Streaming desde su botón de la barra.',
        changed: false,
        warning: true,
      ));
    }

    return UnrealInstallReport(
      projectName: name,
      projectPath: uprojectPath,
      lines: lines,
      launcherPath: launcher,
    );
  }

  /// Dónde instala Epic Games Launcher el editor de esa versión.
  static String? defaultEditorPath(String association) {
    if (!RegExp(r'^\d+\.\d+$').hasMatch(association)) return null;
    final path =
        r'C:\Program Files\Epic Games\UE_' +
        association +
        r'\Engine\Binaries\Win64\UnrealEditor.exe';
    return File(path).existsSync() ? path : null;
  }

  static String launcherScript({
    required String editor,
    required String uproject,
  }) => [
    '@echo off',
    'rem Abre el proyecto con Pixel Streaming emitiendo: IRIS lo ve en',
    'rem «Render RTX». Lo creó IRIS; se puede volver a crear desde la app.',
    'start "" "$editor" "%~dp0$uproject" $launchFlags',
    '',
  ].join('\r\n');

  /// Añade a [current] las secciones y claves de [ours] que falten; las que
  /// existan con otro valor pasan al de IRIS. No toca nada más.
  static String mergeIni(String current, String ours) {
    final wanted = <String, Map<String, String>>{};
    String? section;
    for (final raw in const LineSplitter().convert(ours)) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith(';')) continue;
      if (line.startsWith('[') && line.endsWith(']')) {
        section = line;
        wanted[section] = {};
      } else if (section != null && line.contains('=')) {
        final i = line.indexOf('=');
        wanted[section]![line.substring(0, i).trim()] = line.substring(i + 1);
      }
    }
    final nl = current.contains('\r\n') ? '\r\n' : '\n';
    final out = const LineSplitter().convert(current);
    for (final MapEntry(key: header, value: keys) in wanted.entries) {
      final start = out.indexWhere((l) => l.trim() == header);
      if (start < 0) {
        if (out.isNotEmpty && out.last.trim().isNotEmpty) out.add('');
        out.add(header);
        for (final MapEntry(:key, :value) in keys.entries) {
          out.add('$key=$value');
        }
        continue;
      }
      var end = out.indexWhere((l) => l.trim().startsWith('['), start + 1);
      if (end < 0) end = out.length;
      for (final MapEntry(:key, :value) in keys.entries) {
        final at = out.indexWhere(
          (l) => l.split('=').first.trim() == key,
          start + 1,
        );
        if (at >= 0 && at < end) {
          out[at] = '$key=$value';
        } else {
          out.insert(start + 1, '$key=$value');
          end++;
        }
      }
    }
    final text = out.join(nl);
    return text.isEmpty || text.endsWith(nl) ? text : '$text$nl';
  }

  static Future<void> _backup(File f) async {
    final copy = File('${f.path}$backupSuffix');
    if (!await copy.exists()) await f.copy(copy.path);
  }
}
