import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../core/settings/app_prefs.dart';
import 'unreal_link.dart';
import 'unreal_project_installer.dart';

enum UnrealLaunchPhase {
  idle,
  preparing,
  starting,
  waiting,
  connecting,
  done,
  error,
}

/// Un Unreal instalado en este PC.
class UnrealEngineInstall {
  final String version;
  final String editor;
  const UnrealEngineInstall(this.version, this.editor);
}

/// «Abrir en Unreal»: todo lo que hace falta para trabajar con Unreal desde
/// IRIS, con un botón (F6.19).
///
/// 1. Busca Unreal 5.5 o posterior en el PC.
/// 2. Crea el proyecto de Unreal de este proyecto de IRIS, si no lo tiene
///    (en Documentos\Unreal Projects).
/// 3. Lo prepara ([UnrealProjectInstaller]).
/// 4. Abre Unreal con Pixel Streaming emitiendo.
/// 5. Espera a que esté listo y conecta IRIS ([UnrealLink]).
///
/// Si Unreal ya está abierto, solo conecta.
class UnrealStageLauncher extends ChangeNotifier {
  UnrealStageLauncher({UnrealLink? link}) : link = link ?? UnrealLink.instance;

  static final instance = UnrealStageLauncher();

  final UnrealLink link;

  /// El .uproject de cada proyecto de IRIS (ajuste por proyecto).
  static const projectKey = PrefKey<String>('unrealStage.project', '');

  /// Abrir Unreal y preparar proyectos solo se puede en el PC: en el Mac y
  /// el iPad se conecta al PC.
  static bool get supported => Platform.isWindows;

  /// La primera vez Unreal compila sombreadores: puede tardar.
  static const maxWait = Duration(minutes: 20);

  UnrealLaunchPhase phase = UnrealLaunchPhase.idle;
  String? message;
  String? error;
  String? projectPath;
  UnrealInstallReport? report;
  Duration waited = Duration.zero;

  bool get busy =>
      phase != UnrealLaunchPhase.idle &&
      phase != UnrealLaunchPhase.done &&
      phase != UnrealLaunchPhase.error;

  /// Unreal 5.5 o posterior instalado con el Epic Games Launcher; el más
  /// nuevo si hay varios.
  static UnrealEngineInstall? findEngine({
    String root = r'C:\Program Files\Epic Games',
  }) {
    final dir = Directory(root);
    if (!dir.existsSync()) return null;
    UnrealEngineInstall? best;
    (int, int)? bestVersion;
    for (final entry in dir.listSync().whereType<Directory>()) {
      final m = RegExp(r'UE_(\d+)\.(\d+)$').firstMatch(entry.path);
      if (m == null) continue;
      final v = (int.parse(m.group(1)!), int.parse(m.group(2)!));
      if (v.$1 < 5 || (v.$1 == 5 && v.$2 < 5)) continue;
      final editor = [
        entry.path,
        'Engine',
        'Binaries',
        'Win64',
        'UnrealEditor.exe',
      ].join(Platform.pathSeparator);
      if (!File(editor).existsSync()) continue;
      if (bestVersion == null ||
          v.$1 > bestVersion.$1 ||
          (v.$1 == bestVersion.$1 && v.$2 > bestVersion.$2)) {
        bestVersion = v;
        best = UnrealEngineInstall('${v.$1}.${v.$2}', editor);
      }
    }
    return best;
  }

  /// Nombre válido para un proyecto de Unreal: letras y números, empieza
  /// por letra, como mucho 20 caracteres.
  static String projectNameFor(String irisProject) {
    final plain = irisProject
        .replaceAll(RegExp('[áàäâ]'), 'a')
        .replaceAll(RegExp('[éèëê]'), 'e')
        .replaceAll(RegExp('[íìïî]'), 'i')
        .replaceAll(RegExp('[óòöô]'), 'o')
        .replaceAll(RegExp('[úùüû]'), 'u')
        .replaceAll(RegExp('[ÁÀÄÂ]'), 'A')
        .replaceAll(RegExp('[ÉÈËÊ]'), 'E')
        .replaceAll(RegExp('[ÍÌÏÎ]'), 'I')
        .replaceAll(RegExp('[ÓÒÖÔ]'), 'O')
        .replaceAll(RegExp('[ÚÙÜÛ]'), 'U')
        .replaceAll('ñ', 'n')
        .replaceAll('Ñ', 'N')
        .replaceAll('ç', 'c');
    final words = RegExp(r'[A-Za-z0-9]+').allMatches(plain).map((m) {
      final w = m.group(0)!;
      return w[0].toUpperCase() + w.substring(1);
    }).join();
    final name = 'IRIS$words';
    return name.length > 20 ? name.substring(0, 20) : name;
  }

  /// Crea un proyecto de Unreal vacío: con un .uproject le basta a Unreal.
  static Future<String> createProject({
    required String parentDir,
    required String name,
    required String engineVersion,
    String? description,
  }) async {
    final sep = Platform.pathSeparator;
    final dir = Directory('$parentDir$sep$name');
    await Directory('${dir.path}${sep}Content').create(recursive: true);
    await Directory('${dir.path}${sep}Config').create(recursive: true);
    final uproject = File('${dir.path}$sep$name.uproject');
    if (!await uproject.exists()) {
      await uproject.writeAsString(
        '${const JsonEncoder.withIndent('\t').convert({
          'FileVersion': 3,
          'EngineAssociation': engineVersion,
          'Category': '',
          'Description': description ?? 'Proyecto de Unreal creado por IRIS',
        })}\n',
      );
    }
    return uproject.path;
  }

  /// El .uproject guardado para [projectId], si existe aún.
  static String? savedProject(int? projectId) {
    final path = AppPrefs.instance.get(projectKey, projectId: projectId);
    return path.isNotEmpty && File(path).existsSync() ? path : null;
  }

  static Future<void> rememberProject(int? projectId, String path) =>
      AppPrefs.instance.setIn(
        projectKey,
        projectId == null
            ? const SettingsScope.global()
            : SettingsScope.project(projectId),
        path,
      );

  Future<bool> _remoteControlUp() async {
    try {
      final r = await http
          .get(Uri.parse('http://127.0.0.1:${link.port}/remote/info'))
          .timeout(const Duration(seconds: 2));
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  void _set(UnrealLaunchPhase p, String? text, {String? fail}) {
    phase = p;
    message = text;
    error = fail;
    notifyListeners();
  }

  /// Todo en uno. [uproject] para usar un proyecto de Unreal propio en vez
  /// del que IRIS crea para [projectName].
  Future<bool> open({
    required int? projectId,
    required String projectName,
    String? uproject,
  }) async {
    if (busy) return false;
    report = null;
    waited = Duration.zero;
    try {
      // ¿Ya está abierto? Entonces solo hay que conectar.
      if (uproject == null && await _remoteControlUp()) {
        _set(UnrealLaunchPhase.connecting, 'Unreal ya está abierto: conectando…');
        return _connect();
      }
      if (!supported) {
        _set(
          UnrealLaunchPhase.error,
          null,
          fail:
              'Unreal se abre desde IRIS en el PC. Desde aquí, conecta con el '
              'PC (botón de Unreal del 3D).',
        );
        return false;
      }
      final engine = findEngine();
      if (engine == null) {
        _set(
          UnrealLaunchPhase.error,
          null,
          fail:
              'No encuentro Unreal 5.5 o posterior en este PC. Instálalo desde '
              'el Epic Games Launcher (Unreal Engine → Biblioteca → +).',
        );
        return false;
      }

      _set(UnrealLaunchPhase.preparing, 'Preparando el proyecto de Unreal…');
      var path = uproject ?? savedProject(projectId);
      if (path == null) {
        final docs = await getApplicationDocumentsDirectory();
        path = await createProject(
          parentDir:
              '${docs.path}${Platform.pathSeparator}Unreal Projects',
          name: projectNameFor(projectName),
          engineVersion: engine.version,
          description: 'IRIS · $projectName',
        );
      }
      projectPath = path;
      report = await UnrealProjectInstaller.install(
        path,
        findEditor: (_) => engine.editor,
      );
      await rememberProject(projectId, path);

      _set(UnrealLaunchPhase.starting, 'Abriendo Unreal ${engine.version}…');
      await Process.start(engine.editor, [
        path,
        ...UnrealProjectInstaller.launchFlags.split(' '),
      ], mode: ProcessStartMode.detached);

      final watch = Stopwatch()..start();
      while (watch.elapsed < maxWait) {
        await Future<void>.delayed(const Duration(seconds: 2));
        waited = watch.elapsed;
        _set(
          UnrealLaunchPhase.waiting,
          watch.elapsed < const Duration(minutes: 1)
              ? 'Unreal se está abriendo…'
              : 'Unreal se está abriendo (${watch.elapsed.inMinutes} min). La '
                    'primera vez prepara la calidad RTX y tarda varios '
                    'minutos.',
        );
        if (await _remoteControlUp()) break;
      }
      if (!await _remoteControlUp()) {
        _set(
          UnrealLaunchPhase.error,
          null,
          fail:
              'Unreal no ha terminado de abrirse. Si ves su ventana, espera a '
              'que acabe y pulsa «Abrir en Unreal» otra vez.',
        );
        return false;
      }
      _set(UnrealLaunchPhase.connecting, 'Conectando con Unreal…');
      // Remote Control arranca un poco antes que IRIS Stage Link.
      for (var i = 0; i < 15; i++) {
        if (await _connect(quiet: i < 14)) return true;
        await Future<void>.delayed(const Duration(seconds: 2));
      }
      return false;
    } catch (e) {
      _set(UnrealLaunchPhase.error, null, fail: UnrealLink.describe(e));
      return false;
    }
  }

  Future<bool> _connect({bool quiet = false}) async {
    final ok = await link.connect(host: '127.0.0.1', port: link.port);
    if (ok) {
      final other = projectPath != null &&
          link.project != null &&
          !_samePath(link.project!, projectPath!);
      _set(
        UnrealLaunchPhase.done,
        other
            ? 'Conectado, pero Unreal tiene abierto otro proyecto '
                  '(${link.project!.split(RegExp(r'[/\\]')).last}).'
            : 'Conectado con Unreal ${link.engine?.split('-').first ?? ''}.',
      );
      return true;
    }
    if (!quiet) _set(UnrealLaunchPhase.error, null, fail: link.error);
    return false;
  }

  static bool _samePath(String a, String b) =>
      a.replaceAll('\\', '/').toLowerCase() ==
      b.replaceAll('\\', '/').toLowerCase();
}
