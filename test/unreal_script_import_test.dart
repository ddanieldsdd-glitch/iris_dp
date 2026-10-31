import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// El script de Unreal (IRIS Stage Link) se carga sin errores: un fallo al
/// importarlo deja a IRIS sin conexión con Unreal («Unreal responde, pero no
/// tiene IRIS Stage Link») y en Unreal solo sale en su registro. Se carga
/// con Python y un módulo `unreal` de mentira (`tools/unreal/iris_stage/
/// tests/check_import.py`).
void main() {
  test('iris_stage_link.py se importa', () async {
    String? python;
    for (final candidate in ['python3', 'python']) {
      try {
        final r = await Process.run(candidate, ['--version']);
        if (r.exitCode == 0) {
          python = candidate;
          break;
        }
      } on ProcessException {
        continue;
      }
    }
    if (python == null) {
      markTestSkipped('Sin Python en este equipo.');
      return;
    }
    final result = await Process.run(python, [
      'tools/unreal/iris_stage/tests/check_import.py',
      'tools/unreal/iris_stage/Content/Python/iris_stage_link.py',
    ]);
    expect(
      result.exitCode,
      0,
      reason: '${result.stdout}\n${result.stderr}',
    );
    expect('${result.stdout}', contains('OK'));
  });
}
