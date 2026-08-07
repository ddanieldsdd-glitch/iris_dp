#!/usr/bin/env dart
// Verificación arquitectónica IRIS DP (Fase 11).
// Uso: dart run tool/check_architecture.dart

import 'dart:io';

void main() {
  final root = Directory.current;
  if (!File('${root.path}/pubspec.yaml').existsSync()) {
    stderr.writeln('Ejecutar desde la raíz del repo.');
    exit(1);
  }

  var violations = 0;

  violations += _checkPattern(
    dir: 'lib/core',
    pattern: RegExp(r"import\s+'\.+/features/"),
    rule: 'core/ no debe importar features/',
  );

  violations += _checkPattern(
    dir: 'lib/shared',
    pattern: RegExp(r"import\s+'\.+/features/"),
    rule: 'shared/ no debe importar features/',
  );

  if (violations == 0) {
    stdout.writeln('OK: sin violaciones arquitectónicas detectadas.');
  } else {
    stderr.writeln('$violations violación(es) arquitectónica(s).');
    exit(1);
  }
}

int _checkPattern({
  required String dir,
  required RegExp pattern,
  required String rule,
}) {
  var count = 0;
  final folder = Directory(dir);
  if (!folder.existsSync()) return 0;

  for (final entity in folder.listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final lines = entity.readAsLinesSync();
    for (var i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i])) {
        stderr.writeln('${entity.path}:${i + 1}: $rule');
        stderr.writeln('  ${lines[i].trim()}');
        count++;
      }
    }
  }
  return count;
}
