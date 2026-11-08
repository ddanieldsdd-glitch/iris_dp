import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/update/app_update_installer.dart';
import 'package:path/path.dart' as p;

void main() {
  test('el script cierra solo las copias de esta instalación', () {
    final script = windowsUpdateScript(
      stagingDir: r'C:\tmp\staging',
      installDir: r"C:\Users\O'Neil\IRIS DP",
    );
    expect(
      script,
      contains(r"$_.Path -eq 'C:\Users\O''Neil\IRIS DP\iris_dp.exe'"),
    );
    expect(script, contains('Stop-Process -Force'));
    expect(script.indexOf('Stop-Process'), lessThan(script.indexOf('xcopy')));
  });

  test('si la copia falla reintenta y avisa', () {
    final script = windowsUpdateScript(
      stagingDir: r'C:\tmp\staging',
      installDir: r'C:\iris',
    );
    expect(script, contains('if not errorlevel 1 goto done'));
    expect(script, contains('goto failed'));
    expect(script, contains('MessageBox'));
  });

  test(
    'instala aunque otra copia tenga bloqueado el ejecutable',
    () async {
      final root = Directory.systemTemp.createTempSync('iris_update_');
      addTearDown(() => root.deleteSync(recursive: true));
      final install = Directory(p.join(root.path, 'IRIS DP'))..createSync();
      final staging = Directory(p.join(root.path, 'staging'))..createSync();
      final exe = p.join(install.path, 'iris_dp.exe');
      // Un programa cualquiera hace de copia de IRIS que se queda abierta.
      File(r'C:\Windows\System32\ping.exe').copySync(exe);
      File(p.join(staging.path, 'nuevo.txt')).writeAsStringSync('1.7.4');
      File(
        r'C:\Windows\System32\where.exe',
      ).copySync(p.join(staging.path, 'iris_dp.exe'));
      final ghost = await Process.start(exe, ['-n', '120', '127.0.0.1']);
      ghost.stdout.drain<void>();
      ghost.stderr.drain<void>();

      final bat = p.join(root.path, 'aplicar.bat');
      File(bat).writeAsStringSync(
        windowsUpdateScript(stagingDir: staging.path, installDir: install.path),
        encoding: utf8,
      );
      final result = await Process.run('cmd', ['/c', bat]);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(
        await ghost.exitCode.timeout(const Duration(seconds: 5)),
        isNot(0),
      );
      expect(
        File(p.join(install.path, 'nuevo.txt')).readAsStringSync(),
        '1.7.4',
      );
      expect(
        File(exe).lengthSync(),
        File(p.join(staging.path, 'iris_dp.exe')).lengthSync(),
      );
    },
    skip: Platform.isWindows ? false : 'Solo en Windows',
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
