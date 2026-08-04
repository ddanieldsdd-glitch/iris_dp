import 'package:flutter/foundation.dart';

import 'export_file_saver.dart';

/// Convierte excepciones técnicas en mensajes legibles para el usuario.
String userFriendlyError(Object error) {
  if (kDebugMode) {
    debugPrint('Export/runtime error: $error');
  }
  if (error is MacFileAccessException) {
    return error.message;
  }
  final message = error.toString();
  if (message.contains('SocketException') ||
      message.contains('Failed host lookup') ||
      message.contains('Connection refused')) {
    return 'Sin conexión a internet. Comprueba tu red e inténtalo de nuevo.';
  }
  if (message.contains('TimeoutException') || message.contains('timed out')) {
    return 'La operación tardó demasiado. Inténtalo de nuevo.';
  }
  if (message.contains('Bytes are not supported on macOS')) {
    return 'No se pudo guardar el archivo en macOS. Inténtalo de nuevo.';
  }
  if (message.contains('UnsupportedError') ||
      message.contains('FormatException')) {
    return message.replaceFirst('Exception: ', '').replaceFirst('FormatException: ', '');
  }
  if (message.contains('MacFileAccessException') ||
      message.contains('Acceso a archivos no disponible')) {
    return 'Acceso a archivos no disponible. Cierra la app y ejecuta: flutter run -d macos';
  }
  if (message.contains('READ_FAILED') ||
      message.contains('No se pudo leer la imagen')) {
    return 'No se pudo leer la imagen seleccionada. Prueba con PNG o JPEG.';
  }
  if (message.contains('Almacenamiento no disponible')) {
    return 'Almacenamiento no disponible en este dispositivo.';
  }
  if (message.contains('FileSystemException') ||
      message.contains('PathNotFoundException') ||
      message.contains('Operation not permitted') ||
      message.contains('Permission denied')) {
    return 'No se pudo guardar el archivo. Comprueba permisos de la carpeta destino.';
  }
  if (message.contains('PlatformException')) {
    if (message.contains('cancel')) {
      return 'Exportación cancelada.';
    }
    if (message.contains('WRITE_FAILED') ||
        message.contains('Operation not permitted')) {
      return 'No se pudo guardar el archivo. Comprueba permisos de la carpeta destino.';
    }
    return 'No se pudo completar la exportación. Prueba otra carpeta de destino.';
  }
  if (message.contains('Invalid argument') && message.contains('clamp')) {
    return 'No hay espacio suficiente para maquetar el PDF. Prueba con menos planos.';
  }
  if (message.contains('Image') && message.contains('decode')) {
    return 'No se pudo incluir una imagen de referencia. Prueba con PNG o JPEG.';
  }
  if (message.contains('Unable to load asset') &&
      message.contains('NotoSans')) {
    return 'Faltan fuentes del PDF. Reinstala o recompila la app.';
  }
  if (message.contains('Unable to find font') || message.contains('Unicode')) {
    return 'Error al maquetar texto del PDF. Inténtalo de nuevo.';
  }
  return 'Ha ocurrido un error inesperado. Inténtalo de nuevo.';
}
