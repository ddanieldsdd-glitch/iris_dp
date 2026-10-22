import 'package:flutter/foundation.dart';

/// Cuántos campos se están escribiendo ahora en este equipo.
///
/// Mientras haya alguno, la sincronización sube lo guardado pero no baja ni
/// mezcla nada: una bajada rehace filas y podría cortar lo que se escribe.
/// Lo retenido se aplica en cuanto se sale del campo.
abstract final class EditingGuard {
  static final active = ValueNotifier<int>(0);

  static bool get isEditing => active.value > 0;

  /// Devuelve con qué soltarlo; soltarlo dos veces no descuenta dos.
  static VoidCallback hold() {
    active.value++;
    var released = false;
    return () {
      if (released) return;
      released = true;
      active.value--;
    };
  }
}
