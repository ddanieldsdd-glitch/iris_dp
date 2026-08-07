import 'dart:io';
import 'dart:ui' as ui;

/// Cache de aspect ratios reales (width/height) de stills del moodboard.
abstract final class MoodboardImageAspect {
  static final Map<String, double> _cache = {};
  static final Map<String, Future<double>> _inflight = {};

  static double? cached(String path) => _cache[path];

  /// Ratio width/height. Fallback 1.0 si no se puede leer.
  static Future<double> resolve(String path) {
    final hit = _cache[path];
    if (hit != null) return Future.value(hit);

    return _inflight.putIfAbsent(path, () async {
      try {
        final file = File(path);
        if (!await file.exists()) {
          _cache[path] = 1.0;
          return 1.0;
        }
        final bytes = await file.readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;
        final w = image.width.toDouble();
        final h = image.height.toDouble();
        image.dispose();
        final ratio = (w > 0 && h > 0) ? w / h : 1.0;
        _cache[path] = ratio;
        return ratio;
      } catch (_) {
        _cache[path] = 1.0;
        return 1.0;
      } finally {
        _inflight.remove(path);
      }
    });
  }

  static Future<void> resolveMany(Iterable<String> paths) async {
    await Future.wait(paths.map(resolve));
  }
}
