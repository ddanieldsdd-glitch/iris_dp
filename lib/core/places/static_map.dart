import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

import '../utils/media_storage.dart';
import 'place_search.dart';

/// Un plano de calle pequeño de un punto, hecho con teselas de
/// OpenStreetMap, con la chincheta en el centro y su atribución. Se pide una
/// vez al ubicar la localización y se guarda: los PDF lo usan sin red.
class StaticMap {
  StaticMap({http.Client? client}) : _client = client;

  final http.Client? _client;

  static const tileSize = 256;
  static const width = 720;
  static const height = 420;

  /// Lo justo para ver las calles de alrededor y llegar.
  static const zoom = 16;

  /// Píxel del mundo (a [zoom]) de un punto.
  static ({double x, double y}) worldPixel(
    double latitude,
    double longitude, {
    int zoom = zoom,
  }) {
    final scale = tileSize * math.pow(2, zoom).toDouble();
    final x = (longitude + 180) / 360 * scale;
    final lat = latitude * math.pi / 180;
    final y =
        (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * scale;
    return (x: x, y: y);
  }

  /// El mapa en PNG, o nulo si no hay red o el servidor no responde.
  Future<Uint8List?> render(double latitude, double longitude) async {
    final client = _client ?? http.Client();
    try {
      final center = worldPixel(latitude, longitude);
      final left = center.x - width / 2;
      final top = center.y - height / 2;
      final firstX = (left / tileSize).floor();
      final firstY = (top / tileSize).floor();
      final lastX = ((left + width) / tileSize).floor();
      final lastY = ((top + height) / tileSize).floor();
      final canvas = img.Image(width: width, height: height, numChannels: 3)
        ..clear(img.ColorRgb8(236, 234, 228));
      var any = false;
      const max = 1 << zoom;
      for (var tx = firstX; tx <= lastX; tx++) {
        for (var ty = firstY; ty <= lastY; ty++) {
          if (ty < 0 || ty >= max) continue;
          final wrapped = ((tx % max) + max) % max;
          final uri = Uri.https(
            'tile.openstreetmap.org',
            '/$zoom/$wrapped/$ty.png',
          );
          final response = await client
              .get(uri, headers: {'User-Agent': kPlacesUserAgent})
              .timeout(const Duration(seconds: 12));
          if (response.statusCode != 200) continue;
          final tile = img.decodeImage(response.bodyBytes);
          if (tile == null) continue;
          img.compositeImage(
            canvas,
            tile,
            dstX: (tx * tileSize - left).round(),
            dstY: (ty * tileSize - top).round(),
          );
          any = true;
        }
      }
      if (!any) return null;
      _drawPin(canvas);
      _drawAttribution(canvas);
      return Uint8List.fromList(img.encodePng(canvas));
    } on Exception {
      return null;
    } finally {
      if (_client == null) client.close();
    }
  }

  static void _drawPin(img.Image canvas) {
    const cx = width ~/ 2;
    const cy = height ~/ 2;
    // Sombra, borde blanco y centro rojo: se ve sobre calles y tejados.
    img.fillCircle(
      canvas,
      x: cx + 1,
      y: cy + 2,
      radius: 13,
      color: img.ColorRgba8(0, 0, 0, 90),
    );
    img.fillCircle(
      canvas,
      x: cx,
      y: cy,
      radius: 12,
      color: img.ColorRgb8(255, 255, 255),
    );
    img.fillCircle(
      canvas,
      x: cx,
      y: cy,
      radius: 9,
      color: img.ColorRgb8(226, 55, 45),
    );
    img.fillCircle(
      canvas,
      x: cx,
      y: cy,
      radius: 3,
      color: img.ColorRgb8(255, 255, 255),
    );
  }

  static void _drawAttribution(img.Image canvas) {
    const text = '(c) OpenStreetMap';
    const w = 128;
    const h = 18;
    img.fillRect(
      canvas,
      x1: width - w,
      y1: height - h,
      x2: width - 1,
      y2: height - 1,
      color: img.ColorRgba8(255, 255, 255, 200),
    );
    img.drawString(
      canvas,
      text,
      font: img.arial14,
      x: width - w + 4,
      y: height - h + 1,
      color: img.ColorRgb8(60, 60, 60),
    );
  }
}

/// El mapa guardado de una localización en ese punto, haciéndolo si aún no
/// está. Nulo sin almacenamiento o sin red.
Future<String?> ensureSiteMap({
  required int projectId,
  required int siteId,
  required double latitude,
  required double longitude,
  StaticMap? maker,
}) async {
  final path = await MediaStorage.siteMapPath(
    projectId: projectId,
    siteId: siteId,
    latitude: latitude,
    longitude: longitude,
  );
  if (path == null) return null;
  final file = File(path);
  if (await file.exists()) return path;
  final bytes = await (maker ?? StaticMap()).render(latitude, longitude);
  if (bytes == null) return null;
  await file.parent.create(recursive: true);
  await file.writeAsBytes(bytes, flush: true);
  return path;
}

/// El mapa ya guardado, sin pedir nada a la red. Para los PDF.
Future<String?> savedSiteMap({
  required int projectId,
  required int siteId,
  required double latitude,
  required double longitude,
}) async {
  final path = await MediaStorage.siteMapPath(
    projectId: projectId,
    siteId: siteId,
    latitude: latitude,
    longitude: longitude,
  );
  if (path == null || !await File(path).exists()) return null;
  return path;
}
