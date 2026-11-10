import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/update/app_release.dart';
import 'package:iris_dp/core/update/app_update_installer.dart';
import 'package:path/path.dart' as p;

void main() {
  group('huella de la descarga', () {
    late Directory dir;
    late File file;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('iris_sha_');
      file = File(p.join(dir.path, 'iris.dmg'))
        ..writeAsBytesSync(utf8.encode('versión buena'));
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('si coincide, el archivo se queda', () async {
      final good = crypto.sha256
          .convert(file.readAsBytesSync())
          .toString()
          .toUpperCase();
      await verifyReleaseFile(file.path, good);
      expect(file.existsSync(), isTrue);
    });

    test('si no coincide, se borra y no se instala', () async {
      await expectLater(
        verifyReleaseFile(file.path, 'a' * 64),
        throwsA(isA<AppUpdateIntegrityException>()),
      );
      expect(file.existsSync(), isFalse);
    });

    test('una publicación antigua sin huella sigue instalándose', () async {
      await verifyReleaseFile(file.path, null);
      await verifyReleaseFile(file.path, '  ');
      expect(file.existsSync(), isTrue);
    });
  });

  test('la huella es optativa al leer la publicación', () {
    final base = {
      'platform': 'macos',
      'version': '1.8.0',
      'build_number': 40,
      'download_url': 'https://example.com/a.dmg',
    };
    expect(AppRelease.fromJson(base).sha256, isNull);
    expect(AppRelease.fromJson({...base, 'sha256': 'abc'}).sha256, 'abc');
  });

  group('rutas del zip', () {
    const root = 'staging';

    test('las normales quedan dentro', () {
      expect(
        safeZipEntryPath(root, 'data/flutter_assets/a.json'),
        p.join(root, 'data', 'flutter_assets', 'a.json'),
      );
      expect(
        safeZipEntryPath(root, './iris_dp.exe'),
        p.join(root, 'iris_dp.exe'),
      );
    });

    test('se rechaza todo lo que se sale', () {
      for (final bad in [
        '../fuera.exe',
        'a/../../fuera.exe',
        r'..\fuera.exe',
        r'a\..\..\fuera.exe',
        '/etc/passwd',
        r'\Windows\System32\x.dll',
        r'C:\Windows\x.dll',
        'C:/Windows/x.dll',
        '',
      ]) {
        expect(safeZipEntryPath(root, bad), isNull, reason: bad);
      }
    });
  });

  group('marcha atrás en Windows', () {
    test('guarda la instalación antes de copiar y la devuelve si falla', () {
      final script = windowsUpdateScript(
        stagingDir: r'C:\tmp\staging',
        installDir: r'C:\iris',
        previousDir: r'C:\datos\version-anterior',
      );
      final save = script.indexOf(r'"C:\iris\*" "C:\datos\version-anterior\"');
      final restore = script.indexOf(
        r'"C:\datos\version-anterior\*" "C:\iris\"',
      );
      expect(save, greaterThan(0));
      expect(save, lessThan(script.indexOf(':copy')));
      expect(restore, greaterThan(script.indexOf(':failed')));
      expect(restore, lessThan(script.indexOf('MessageBox')));
      expect(script.replaceAll('\r\n', ''), isNot(contains('\n')));
    });

    test('sin carpeta de copia no cambia nada', () {
      final script = windowsUpdateScript(
        stagingDir: r'C:\tmp\staging',
        installDir: r'C:\iris',
      );
      expect(script, isNot(contains('saved')));
    });
  });
}
