import 'dart:io';

import 'package:flutter/material.dart';

/// Si existe un archivo, sin ir al disco en cada reconstrucción.
///
/// Las celdas y los fotogramas lo preguntan en su `build`, y una lista lo
/// pregunta decenas de veces por fotograma. La respuesta se guarda unos
/// segundos: basta para una reconstrucción, y una imagen recién descargada
/// aparece en la siguiente.
abstract final class FileExistsCache {
  static const _ttl = Duration(seconds: 3);
  static const _kept = 2000;
  static final _known = <String, ({bool exists, DateTime at})>{};

  static bool exists(String path) {
    final now = DateTime.now();
    final known = _known[path];
    if (known != null && now.difference(known.at) < _ttl) return known.exists;
    if (_known.length >= _kept) _known.clear();
    final exists = File(path).existsSync();
    _known[path] = (exists: exists, at: now);
    return exists;
  }

  /// Para los tests y para quien acaba de escribir o borrar un archivo.
  static void forget([String? path]) =>
      path == null ? _known.clear() : _known.remove(path);
}

/// Una imagen de disco decodificada al tamaño al que se ve.
///
/// Una foto de 6000 px ocupa más de 100 MB decodificada: llena la caché de
/// imágenes de Flutter y hace que todo se decodifique otra vez al desplazar.
/// Para una miniatura basta con los píxeles que se pintan.
class SizedFileImage extends StatelessWidget {
  final String path;
  final BoxFit fit;

  const SizedFileImage(this.path, {super.key, this.fit = BoxFit.contain});

  /// Se decodifica por tramos: cambiar un poco el tamaño de la ventana no
  /// vuelve a decodificar nada.
  static const _step = 160;

  /// Ancho de decodificación para un hueco de [width] puntos.
  ///
  /// [BoxFit.cover] recorta, así que deja margen para las imágenes más
  /// panorámicas que el hueco.
  static int decodeWidth(double width, double pixelRatio, BoxFit fit) {
    final oversample = fit == BoxFit.cover ? 1.5 : 1.0;
    final wanted = (width * pixelRatio * oversample).ceil();
    return ((wanted / _step).ceil() * _step).clamp(_step, 4096);
  }

  @override
  Widget build(BuildContext context) {
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => Image.file(
        File(path),
        fit: fit,
        gaplessPlayback: true,
        cacheWidth: constraints.hasBoundedWidth
            ? decodeWidth(constraints.maxWidth, pixelRatio, fit)
            : null,
      ),
    );
  }
}
