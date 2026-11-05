import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/update/mac_auto_update.dart';

void main() {
  test('lee dónde se montó el DMG (hdiutil -plist)', () {
    const plist = '''
<plist version="1.0"><dict><key>system-entities</key><array>
<dict><key>content-hint</key><string>GUID_partition_scheme</string></dict>
<dict><key>mount-point</key>
  <string>/Volumes/IRIS</string></dict>
</array></dict></plist>''';
    expect(MacAutoUpdate.mountPointFromPlist(plist), '/Volumes/IRIS');
    expect(MacAutoUpdate.mountPointFromPlist(''), isNull);
  });

  test('sabe qué app está en marcha', () {
    expect(
      MacAutoUpdate.runningBundle(
        '/Applications/IRIS DP.app/Contents/MacOS/iris_dp',
      ),
      '/Applications/IRIS DP.app',
    );
    expect(MacAutoUpdate.runningBundle('/usr/bin/dart'), isNull);
  });

  test('solo se actualiza sola la copia de /Applications', () {
    expect(MacAutoUpdate.isInstalledCopy('/Applications/IRIS DP.app'), isTrue);
    expect(
      MacAutoUpdate.isInstalledCopy(
        '/Users/d/iris_dp_calle/build/macos/Build/Products/Release/'
        'iris_dp.app',
      ),
      isFalse,
    );
  });

  test('una sola copia de IRIS prepara la versión a la vez', () {
    final tmp = Directory.systemTemp.createTempSync('cerrojo');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final lock = Directory('${tmp.path}/preparando');
    // Lo toma este proceso; otro vivo (este mismo pid, visto desde fuera)
    // no puede.
    expect(MacAutoUpdate.takeLock(lock), isTrue);
    expect(MacAutoUpdate.takeLock(lock, ownPid: pid + 1), isFalse);
    // Uno que quedó de un proceso que ya no existe se quita.
    File('${lock.path}/pid').writeAsStringSync('999999');
    expect(MacAutoUpdate.takeLock(lock, ownPid: pid + 1), isTrue);
    expect(File('${lock.path}/pid').readAsStringSync(), '${pid + 1}');
  });

  group(
    'al cerrarse IRIS se cambia por la nueva',
    () {
      late Directory dir;
      late String dest;
      late File marker;
      late File script;
      late File verify;

      setUp(() {
        dir = Directory.systemTemp.createTempSync('iris_auto_update');
        dest = '${dir.path}/IRIS DP.app';
        Directory('$dest/Contents').createSync(recursive: true);
        File('$dest/Contents/version').writeAsStringSync('1.0.19');
        script = File('${dir.path}/instalar.sh')
          ..writeAsStringSync(MacAutoUpdate.applyScript);
        marker = File('${dir.path}/preparada.json');
        // En los tests, «entera» = lleva Contents/ok (no hay firma).
        verify = File('${dir.path}/verificar.sh')
          ..writeAsStringSync('#!/bin/bash\ntest -f "\$1/Contents/ok"\n');
        Process.runSync('chmod', ['+x', verify.path]);
      });

      tearDown(() => dir.deleteSync(recursive: true));

      String stage(String version, {bool whole = true}) {
        final app = '${dir.path}/IRIS-$version.app';
        Directory('$app/Contents').createSync(recursive: true);
        File('$app/Contents/version').writeAsStringSync(version);
        if (whole) File('$app/Contents/ok').writeAsStringSync('');
        marker.writeAsStringSync(
          jsonEncode({'version': version, 'build': 17, 'app': app}),
        );
        return app;
      }

      Future<void> run(Process app) async {
        final waiter = await Process.start(
          '/bin/bash',
          [
            script.path,
            '${app.pid}',
            dest,
            marker.path,
            '0',
            '${dir.path}/instalar.log',
          ],
          environment: {'IRIS_UPDATE_VERIFY': verify.path},
        );
        // Mientras IRIS sigue abierta, no toca nada.
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        expect(File('$dest/Contents/version').readAsStringSync(), '1.0.19');
        app.kill();
        expect(await waiter.exitCode.timeout(const Duration(seconds: 10)), 0);
      }

      test('instala la preparada y borra el marcador', () async {
        stage('1.1.0');
        final app = await Process.start('sleep', ['30']);
        await run(app);
        expect(File('$dest/Contents/version').readAsStringSync(), '1.1.0');
        expect(marker.existsSync(), isFalse);
        expect(Directory('$dest.anterior').existsSync(), isFalse);
      });

      test('si mientras espera se prepara otra más nueva, entra esa', () async {
        stage('1.1.0');
        final app = await Process.start('sleep', ['30']);
        final waiting = run(app);
        await Future<void>.delayed(const Duration(milliseconds: 300));
        Directory('${dir.path}/IRIS-1.1.0.app').deleteSync(recursive: true);
        stage('1.1.1');
        await waiting;
        expect(File('$dest/Contents/version').readAsStringSync(), '1.1.1');
      });

      test('una preparada rota no se instala: sigue la que había', () async {
        final broken = stage('1.5.0', whole: false);
        final app = await Process.start('sleep', ['30']);
        await run(app);
        expect(File('$dest/Contents/version').readAsStringSync(), '1.0.19');
        expect(Directory(broken).existsSync(), isFalse);
        expect(marker.existsSync(), isFalse);
        expect(
          File('${dir.path}/instalar.log').readAsStringSync(),
          contains('no está entera'),
        );
      });

      test('sin versión preparada deja la que había', () async {
        final app = await Process.start('sleep', ['30']);
        await run(app);
        expect(File('$dest/Contents/version').readAsStringSync(), '1.0.19');
      });
    },
    skip: Platform.isMacOS ? false : 'Solo en Mac (usa plutil)',
  );
}
