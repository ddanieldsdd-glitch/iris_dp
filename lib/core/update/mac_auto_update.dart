import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app_release.dart';
import 'app_update_installer.dart';

/// Una versión ya descargada y preparada, esperando a que se cierre IRIS.
class StagedMacUpdate {
  final String version;
  final int buildNumber;

  /// La app nueva, ya copiada fuera del DMG.
  final String appPath;

  const StagedMacUpdate({
    required this.version,
    required this.buildNumber,
    required this.appPath,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'build': buildNumber,
    'app': appPath,
  };

  static StagedMacUpdate? fromJson(Object? json) {
    if (json is! Map) return null;
    final version = json['version'];
    final build = json['build'];
    final app = json['app'];
    if (version is! String || build is! num || app is! String) return null;
    return StagedMacUpdate(
      version: version,
      buildNumber: build.toInt(),
      appPath: app,
    );
  }
}

/// Actualización sola en el Mac: en cuanto hay una versión nueva se descarga
/// y se prepara sin decir nada; al cerrar IRIS (como sea que se cierre), un
/// proceso aparte cambia la app por la nueva. La próxima vez que se abre, ya
/// está al día. «Reiniciar ahora» hace lo mismo y la vuelve a abrir.
abstract final class MacAutoUpdate {
  static Future<Directory> _dir() async {
    final dir = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'actualizaciones'),
    );
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<File> _marker() async =>
      File(p.join((await _dir()).path, 'preparada.json'));

  /// La app que está en marcha (…/IRIS DP.app); nulo si no se sabe.
  static String? runningBundle([String? executable]) {
    var dir = p.dirname(executable ?? Platform.resolvedExecutable);
    while (dir != '/' && !dir.endsWith('.app')) {
      dir = p.dirname(dir);
    }
    return dir.endsWith('.app') ? dir : null;
  }

  /// La versión preparada, si la hay y sigue en disco.
  static Future<StagedMacUpdate?> staged() async {
    try {
      final file = await _marker();
      if (!file.existsSync()) return null;
      final staged = StagedMacUpdate.fromJson(
        jsonDecode(await file.readAsString()),
      );
      if (staged == null || !Directory(staged.appPath).existsSync()) {
        return null;
      }
      return staged;
    } catch (_) {
      return null;
    }
  }

  /// Tira la versión preparada (ya instalada, o más vieja que la actual).
  static Future<void> discard() async {
    try {
      final dir = await _dir();
      for (final e in dir.listSync()) {
        if (e is Directory && e.path.endsWith('.app')) {
          e.deleteSync(recursive: true);
        }
      }
      final marker = await _marker();
      if (marker.existsSync()) marker.deleteSync();
    } catch (_) {}
  }

  /// Descarga [release] y la deja lista (si no lo estaba ya).
  static Future<StagedMacUpdate> stage(AppRelease release) async {
    final already = await staged();
    if (already != null && already.buildNumber >= release.buildNumber) {
      return already;
    }
    final dir = await _dir();
    final dmg = await downloadAppRelease(release);
    try {
      final mount = await _attach(dmg);
      try {
        final source = Directory(mount)
            .listSync()
            .whereType<Directory>()
            .firstWhere(
              (d) => d.path.endsWith('.app'),
              orElse: () => throw StateError('El DMG no trae la app'),
            );
        final target = p.join(dir.path, 'IRIS-${release.buildNumber}.app');
        if (Directory(target).existsSync()) {
          Directory(target).deleteSync(recursive: true);
        }
        final copy = await Process.run('ditto', [source.path, target]);
        if (copy.exitCode != 0) {
          throw StateError('No se pudo preparar la app: ${copy.stderr}');
        }
        await Process.run('xattr', ['-dr', 'com.apple.quarantine', target]);
        // Las preparadas de antes sobran.
        for (final old in dir.listSync().whereType<Directory>()) {
          if (old.path != target && old.path.endsWith('.app')) {
            old.deleteSync(recursive: true);
          }
        }
        final staged = StagedMacUpdate(
          version: release.version,
          buildNumber: release.buildNumber,
          appPath: target,
        );
        await (await _marker()).writeAsString(jsonEncode(staged.toJson()));
        return staged;
      } finally {
        await Process.run('hdiutil', ['detach', mount, '-quiet', '-force']);
      }
    } finally {
      try {
        File(dmg).deleteSync();
      } catch (_) {}
    }
  }

  /// Monta el DMG y devuelve dónde.
  static Future<String> _attach(String dmg) async {
    final attach = await Process.run('hdiutil', [
      'attach',
      '-nobrowse',
      '-readonly',
      '-noautoopen',
      '-plist',
      dmg,
    ]);
    if (attach.exitCode != 0) {
      throw StateError('No se pudo abrir el DMG: ${attach.stderr}');
    }
    final mount = mountPointFromPlist(attach.stdout.toString());
    if (mount == null) throw StateError('No se encontró dónde se montó el DMG');
    return mount;
  }

  /// El punto de montaje en la salida `-plist` de `hdiutil attach`.
  @visibleForTesting
  static String? mountPointFromPlist(String plist) => RegExp(
    r'<key>mount-point</key>\s*<string>([^<]+)</string>',
  ).firstMatch(plist)?.group(1);

  /// Deja un proceso aparte esperando a que IRIS se cierre para cambiarla
  /// por [staged]. Con [relaunch], la vuelve a abrir.
  static Future<void> applyOnExit(
    StagedMacUpdate staged, {
    bool relaunch = false,
  }) async {
    final dest = runningBundle();
    if (dest == null) throw StateError('No se sabe dónde está la app');
    final dir = await _dir();
    final script = File(p.join(dir.path, 'instalar.sh'));
    await script.writeAsString(applyScript);
    await Process.start('/bin/bash', [
      script.path,
      '$pid',
      dest,
      (await _marker()).path,
      relaunch ? '1' : '0',
      p.join(dir.path, 'instalar.log'),
    ], mode: ProcessStartMode.detached);
  }

  /// Espera a que el proceso `$1` termine y cambia la app `$2` por la
  /// preparada (la que diga el marcador en ese momento: si mientras tanto se
  /// preparó otra más nueva, entra esa). Si algo falla, deja la que había.
  @visibleForTesting
  static const applyScript = r'''#!/bin/bash
PID="$1"; DEST="$2"; MARKER="$3"; RELAUNCH="$4"; LOG="$5"
log() { printf '%s  %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }
# Un solo instalador esperando.
DIR="$(dirname "$MARKER")"
LOCK="$DIR/instalando"
REOPEN="$DIR/reabrir"
if ! mkdir "$LOCK" 2>/dev/null; then
  OTHER="$(cat "$LOCK/pid" 2>/dev/null)"
  if [ -n "$OTHER" ] && kill -0 "$OTHER" 2>/dev/null; then
    # Ya hay uno esperando: que sea él quien la vuelva a abrir.
    [ "$RELAUNCH" = "1" ] && touch "$REOPEN"
    exit 0
  fi
  rm -rf "$LOCK"; mkdir "$LOCK" || exit 0
fi
[ "$RELAUNCH" = "1" ] || rm -f "$REOPEN"
echo $$ > "$LOCK/pid"
trap 'rm -rf "$LOCK"' EXIT
while kill -0 "$PID" 2>/dev/null; do sleep 1; done
sleep 1
STAGED="$(plutil -extract app raw "$MARKER" 2>/dev/null)"
if [ -z "$STAGED" ] || [ ! -d "$STAGED" ]; then
  log "No hay versión preparada."
  [ "$RELAUNCH" = "1" ] || [ -f "$REOPEN" ] && { rm -f "$REOPEN"; open "$DEST"; }
  exit 0
fi
OLD="$DEST.anterior"
rm -rf "$OLD"
if mv "$DEST" "$OLD" && mv "$STAGED" "$DEST"; then
  rm -rf "$OLD"
  rm -f "$MARKER"
  log "Actualizada: $DEST"
else
  [ -d "$DEST" ] || mv "$OLD" "$DEST"
  log "No se pudo actualizar; sigue la versión que había."
fi
if [ "$RELAUNCH" = "1" ] || [ -f "$REOPEN" ]; then
  rm -f "$REOPEN"
  open "$DEST"
fi
exit 0
''';
}
