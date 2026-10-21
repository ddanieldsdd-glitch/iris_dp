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

  group(
    'al cerrarse IRIS se cambia por la nueva',
    () {
      late Directory dir;
      late String dest;
      late File marker;
      late File script;

      setUp(() {
        dir = Directory.systemTemp.createTempSync('iris_auto_update');
        dest = '${dir.path}/IRIS DP.app';
        Directory('$dest/Contents').createSync(recursive: true);
        File('$dest/Contents/version').writeAsStringSync('1.0.19');
        script = File('${dir.path}/instalar.sh')
          ..writeAsStringSync(MacAutoUpdate.applyScript);
        marker = File('${dir.path}/preparada.json');
      });

      tearDown(() => dir.deleteSync(recursive: true));

      String stage(String version) {
        final app = '${dir.path}/IRIS-$version.app';
        Directory('$app/Contents').createSync(recursive: true);
        File('$app/Contents/version').writeAsStringSync(version);
        marker.writeAsStringSync(
          jsonEncode({'version': version, 'build': 17, 'app': app}),
        );
        return app;
      }

      Future<void> run(Process app) async {
        final waiter = await Process.start('/bin/bash', [
          script.path,
          '${app.pid}',
          dest,
          marker.path,
          '0',
          '${dir.path}/instalar.log',
        ]);
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

      test('sin versión preparada deja la que había', () async {
        final app = await Process.start('sleep', ['30']);
        await run(app);
        expect(File('$dest/Contents/version').readAsStringSync(), '1.0.19');
      });
    },
    skip: Platform.isMacOS ? false : 'Solo en Mac (usa plutil)',
  );
}
