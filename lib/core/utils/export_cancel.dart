import 'dart:async';

/// Se lanza dentro de una exportación que ya nadie espera.
class ExportCancelled implements Exception {
  const ExportCancelled();
}

/// Corta una exportación en curso: una vista previa que se ha quedado vieja
/// deja de gastar tiempo en cuanto llega al siguiente plano.
abstract final class ExportCancel {
  static const _key = #exportCancel;

  /// Ejecuta [build]; dentro, [check] corta si [isCancelled] dice que sí.
  static Future<T> run<T>(
    bool Function() isCancelled,
    Future<T> Function() build,
  ) => runZoned(build, zoneValues: {_key: isCancelled});

  /// Lanza [ExportCancelled] si la exportación de esta zona ya no hace falta.
  static void check() {
    final isCancelled = Zone.current[_key] as bool Function()?;
    if (isCancelled != null && isCancelled()) throw const ExportCancelled();
  }

  /// [build] sobre cada elemento, con [width] a la vez como mucho y el
  /// resultado en el orden de [items].
  static Future<List<R>> mapPooled<T, R>(
    List<T> items,
    Future<R> Function(T item) build, {
    int width = 4,
  }) async {
    final results = List<R?>.filled(items.length, null);
    var next = 0;
    Future<void> worker() async {
      while (next < items.length) {
        final i = next++;
        check();
        results[i] = await build(items[i]);
      }
    }

    await Future.wait([for (var i = 0; i < width; i++) worker()]);
    return results.cast<R>();
  }
}
