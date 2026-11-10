import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

/// USDZ de otras apps (Polycam, Scaniverse, RoomPlan). El visor no lo abre:
/// el sistema lo pasa a OBJ, que trae la malla y deja atrás las texturas.
/// Solo Apple sabe hacerlo; en Windows no se ofrece.
class ScanUsdz {
  ScanUsdz._();

  static const _channel = MethodChannel('iris/usdz');

  static bool get supported => Platform.isMacOS || Platform.isIOS;

  static bool isUsdz(String path) => p.extension(path).toLowerCase() == '.usdz';

  /// Ruta del OBJ, en una carpeta temporal. Lanza [PlatformException] con el
  /// motivo si no se puede convertir.
  static Future<String> toObj(String path) async {
    final obj = await _channel.invokeMethod<String>('toObj', path);
    if (obj == null) {
      throw PlatformException(code: 'empty', message: 'Sin resultado.');
    }
    return obj;
  }

  /// Borra lo que dejó [toObj], material incluido.
  static Future<void> discard(String objPath) async {
    try {
      await File(objPath).parent.delete(recursive: true);
    } on FileSystemException {
      // Es una carpeta temporal: ya la limpiará el sistema.
    }
  }
}
