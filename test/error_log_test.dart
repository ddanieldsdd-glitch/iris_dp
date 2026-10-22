import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/utils/error_log.dart';

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('iris_error_log');
    ErrorLog.directoryOverride = dir;
  });

  tearDown(() {
    ErrorLog.directoryOverride = null;
    dir.deleteSync(recursive: true);
  });

  test('guarda el error con su contexto y su traza', () async {
    await ErrorLog.record(
      StateError('se rompió'),
      StackTrace.fromString('#0 main (main.dart:1)'),
      context: 'al exportar',
    );

    final text = await (await ErrorLog.file()).readAsString();
    expect(text, contains('al exportar: Bad state: se rompió'));
    expect(text, contains('#0 main (main.dart:1)'));
  });

  test('rota al pasar del tamaño máximo y conserva el anterior', () async {
    final log = await ErrorLog.file();
    log.writeAsStringSync('x' * (ErrorLog.maxBytes + 1));

    await ErrorLog.record('nuevo', null);

    expect(File('${log.path}.1').lengthSync(), ErrorLog.maxBytes + 1);
    expect(log.readAsStringSync(), contains('nuevo'));
    expect(log.lengthSync(), lessThan(ErrorLog.maxBytes));
  });
}
