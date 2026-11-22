import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/shoot_block_overrides.dart';
import 'package:iris_dp/core/utils/error_log.dart';

/// FI.4: un bloque de jornada con ajustes ilegibles se guarda aparte antes de
/// que marcar «En set» escriba encima.
void main() {
  late Directory logs;

  setUp(() {
    logs = Directory.systemTemp.createTempSync('iris_block');
    ErrorLog.directoryOverride = logs;
  });

  tearDown(() {
    ErrorLog.directoryOverride = null;
    logs.deleteSync(recursive: true);
  });

  List<File> copies() => logs
      .listSync()
      .whereType<File>()
      .where((f) => p(f).startsWith('danado-bloque-de-jornada'))
      .toList();

  test('lo ilegible se guarda una vez y lo legible no deja rastro', () async {
    const broken = '{"onSet": {"at": 1}, "notas": "sin cerrar';
    expect(decodeBlockOverrides(broken), isEmpty);
    expect(decodeBlockOverrides(broken), isEmpty);
    expect(decodeBlockOverrides('{"onSet": true}'), {'onSet': true});
    // Que termine de escribir.
    await ErrorLog.record('fin', null);

    final saved = copies();
    expect(saved, hasLength(1));
    expect(saved.single.readAsStringSync(), broken);

    // La marca se pone, y lo de antes queda en la copia.
    final next = keepOnSetMark(broken, '{"onSet": {"at": 2}}');
    expect(jsonDecode(next!), {
      'onSet': {'at': 2},
    });
  });
}

String p(File f) => f.uri.pathSegments.last;
