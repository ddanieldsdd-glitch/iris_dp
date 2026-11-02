import 'dart:io';

import 'package:flutter/services.dart';

/// La captura guiada del iPhone (F6.20 E6), en `ios/Runner/
/// IrisCapturePlugin.swift`. En el resto de plataformas no existe.
class ScanCaptureChannel {
  ScanCaptureChannel._();

  static const _channel = MethodChannel('iris/capture');

  /// Si este dispositivo puede capturar (iPhone o iPad con ARKit).
  static Future<bool> isSupported() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Abre la captura a pantalla completa. Devuelve el `.zip` (o la carpeta)
  /// con las fotos y `capture.json`, o `null` si se cancela.
  static Future<String?> start(String name) async {
    if (!Platform.isIOS) return null;
    try {
      return await _channel.invokeMethod<String>('start', {'name': name});
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
