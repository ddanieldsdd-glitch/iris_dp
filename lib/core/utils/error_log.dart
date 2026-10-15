import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Registro local de errores no capturados, para saber qué pasó cuando algo
/// falla fuera de la vista de desarrollo. Rota a [maxBytes]: se conservan el
/// archivo actual y el anterior.
abstract final class ErrorLog {
  static const fileName = 'iris_dp_errores.log';
  static const maxBytes = 1024 * 1024;

  /// Carpeta del registro. Los tests la fijan; si no, la de soporte de la app.
  @visibleForTesting
  static Directory? directoryOverride;

  static Future<void> _pending = Future.value();

  static Future<File> file() async {
    final dir =
        directoryOverride ??
        Directory(
          p.join(
            (await getApplicationSupportDirectory()).path,
            'iris_dp',
            'logs',
          ),
        );
    await dir.create(recursive: true);
    return File(p.join(dir.path, fileName));
  }

  /// Engancha el registro a los errores de Flutter y a los asíncronos que
  /// nadie captura. Se llama una vez, al arrancar.
  static void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      record(details.exception, details.stack, context: details.context);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      debugPrint('Error no capturado: $error\n$stack');
      record(error, stack);
      return true;
    };
  }

  /// Guarda aparte un contenido que no se puede leer antes de que se escriba
  /// encima, y lo anota en el registro. Devuelve la ruta de la copia.
  static Future<String?> preserveDamaged(String name, String content) async {
    try {
      final dir = (await file()).parent;
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
      final copy = File(p.join(dir.path, 'danado-$name-$stamp.json'));
      await copy.writeAsString(content, flush: true);
      await record(
        'Contenido ilegible guardado en ${copy.path}',
        null,
        context: name,
      );
      return copy.path;
    } catch (_) {
      return null;
    }
  }

  /// Añade un error al registro. Nunca lanza: un fallo al escribir el
  /// registro no puede tapar el error original.
  static Future<void> record(
    Object error,
    StackTrace? stack, {
    Object? context,
  }) {
    return _pending = _pending.then((_) async {
      try {
        final f = await file();
        if (f.existsSync() && f.lengthSync() > maxBytes) {
          f.renameSync('${f.path}.1');
        }
        final entry = StringBuffer()
          ..writeln('— ${DateTime.now().toIso8601String()}')
          ..writeln(context == null ? '$error' : '$context: $error');
        if (stack != null) entry.writeln(stack);
        await f.writeAsString('$entry\n', mode: FileMode.append, flush: true);
      } catch (_) {}
    });
  }
}
