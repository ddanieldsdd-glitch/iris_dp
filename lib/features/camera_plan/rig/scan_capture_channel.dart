import 'dart:io';

import 'package:flutter/material.dart';
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

  /// Las cámaras con las que se puede capturar aquí: `wide` (la normal,
  /// con ARKit: mapa y metros) y `ultraWide` (la 0,5x, sin ARKit).
  static Future<List<String>> lenses() async {
    if (!Platform.isIOS) return const [];
    try {
      final list = await _channel.invokeListMethod<String>('lenses');
      return list ?? const [];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Abre la captura a pantalla completa. Devuelve el `.zip` (o la carpeta)
  /// con las fotos y `capture.json`, o `null` si se cancela. [ultraWide]:
  /// con la gran angular 0,5x, sin mapa ni metros.
  static Future<String?> start(String name, {bool ultraWide = false}) async {
    if (!Platform.isIOS) return null;
    try {
      return await _channel.invokeMethod<String>('start', {
        'name': name,
        'lens': ultraWide ? 'ultraWide' : 'wide',
      });
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Pregunta con qué cámara capturar si hay gran angular; si no, la
  /// normal. `null`: se canceló.
  static Future<bool?> chooseLens(BuildContext context) async {
    final lenses = await ScanCaptureChannel.lenses();
    if (!lenses.contains('ultraWide')) return false;
    if (!context.mounted) return null;
    return showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(title: Text('¿Con qué cámara?')),
            if (lenses.contains('wide'))
              ListTile(
                leading: const Icon(Icons.view_in_ar_outlined),
                title: const Text('Normal 1x'),
                subtitle: const Text(
                  'Con mapa en vivo y en metros reales. La mejor para casi '
                  'todo.',
                ),
                onTap: () => Navigator.pop(ctx, false),
              ),
            ListTile(
              leading: const Icon(Icons.panorama_wide_angle_outlined),
              title: const Text('Gran angular 0,5x'),
              subtitle: const Text(
                'Más campo para sitios pequeños y techos. Sin mapa ni '
                'metros: el escaneo se calibra después con una medida.',
              ),
              onTap: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
  }
}
