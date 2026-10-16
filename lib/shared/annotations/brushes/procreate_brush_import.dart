import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'bplist.dart';

/// Un pincel leído de un `.brush` o `.brushset` de Procreate, ya convertido
/// a lo que entiende el motor: punta y grano como PNG blancos con alfa, y
/// los ajustes que se han podido leer.
class ImportedBrushData {
  final String name;
  final Uint8List shapePng;
  final Uint8List? grainPng;
  final Map<String, double> params;

  const ImportedBrushData({
    required this.name,
    required this.shapePng,
    this.grainPng,
    this.params = const {},
  });
}

/// Lee pinceles de Procreate. Un `.brush` es un zip con `Brush.archive`
/// (plist binario con los ajustes), `Shape.png` (punta) y `Grain.png`
/// (textura); un `.brushset` lleva varios, uno por carpeta.
abstract final class ProcreateBrushImport {
  static const _maxTip = 256;
  static const _maxGrain = 512;

  static List<ImportedBrushData> parse(Uint8List bytes, {String? fileName}) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('El archivo no es un pincel de Procreate');
    }
    // Ficheros agrupados por carpeta (la raíz en un `.brush` suelto).
    final groups = <String, Map<String, ArchiveFile>>{};
    for (final file in archive) {
      if (!file.isFile) continue;
      final name = file.name.replaceAll('\\', '/');
      if (name.startsWith('__MACOSX/')) continue;
      final dir = p.posix.dirname(name);
      groups.putIfAbsent(dir, () => {})[p.posix.basename(name)] = file;
    }
    final out = <ImportedBrushData>[];
    final fallback = fileName == null
        ? 'Pincel'
        : p.basenameWithoutExtension(fileName);
    var n = 0;
    for (final entry in groups.entries) {
      final files = entry.value;
      final shape = files['Shape.png'];
      if (shape == null) continue;
      n++;
      final settings = _settings(files['Brush.archive']);
      final name =
          (settings['name'] is String &&
              (settings['name'] as String).trim().isNotEmpty)
          ? (settings['name'] as String).trim()
          : (groups.length > 1 ? '$fallback $n' : fallback);
      final shapePng = _toAlpha(
        _bytes(shape),
        maxSize: _maxTip,
        invert: settings['shapeInverted'] == true,
        square: true,
      );
      if (shapePng == null) continue;
      final grain = files['Grain.png'];
      final grainPng = grain == null
          ? null
          : _toAlpha(
              _bytes(grain),
              maxSize: _maxGrain,
              invert: settings['textureInverted'] == true,
            );
      out.add(
        ImportedBrushData(
          name: name,
          shapePng: shapePng,
          grainPng: grainPng,
          params: _params(settings, hasGrain: grainPng != null),
        ),
      );
    }
    if (out.isEmpty) {
      throw const FormatException('No hay ningún pincel dentro del archivo');
    }
    return out;
  }

  static Uint8List _bytes(ArchiveFile file) =>
      Uint8List.fromList(file.content as List<int>);

  static Map<String, Object?> _settings(ArchiveFile? file) {
    if (file == null) return const {};
    try {
      final root = BinaryPlist.unarchive(BinaryPlist.parse(_bytes(file)));
      return root is Map<String, Object?> ? root : const {};
    } catch (_) {
      return const {};
    }
  }

  static double? _num(Map<String, Object?> s, List<String> keys) {
    for (final key in keys) {
      final v = s[key];
      if (v is num && v.isFinite) return v.toDouble();
    }
    return null;
  }

  /// Ajustes de Procreate que se conocen, pasados a los del motor. Lo que
  /// no está se queda con un valor razonable.
  static Map<String, double> _params(
    Map<String, Object?> s, {
    required bool hasGrain,
  }) {
    final spacing = _num(s, ['plotSpacing']);
    final jitter = _num(s, ['plotJitter']);
    final size = _num(s, ['paintSize', 'maxSize']);
    final opacity = _num(s, ['paintOpacity', 'maxOpacity']);
    final pressureSize = _num(s, ['dynamicsPressureSize']);
    final pressureOpacity = _num(s, ['dynamicsPressureOpacity']);
    final rotation = _num(s, ['shapeRotation']);
    final grainScale = _num(s, ['textureScale']);
    final grainDepth = _num(s, ['textureDepth', 'grainDepth']);
    return {
      'spacing': (spacing ?? 0.1).clamp(0.02, 2.0),
      'scatter': (jitter ?? 0).clamp(0.0, 1.5),
      'defaultWidth': size == null ? 14 : (2 + size * 60).clamp(1.0, 200.0),
      'flow': (opacity ?? 0.7).clamp(0.05, 1.0),
      'pressureSize': (pressureSize ?? 0.4).clamp(0.0, 1.0),
      'pressureOpacity': (pressureOpacity ?? 0.4).clamp(0.0, 1.0),
      'rotationJitter': s['shapeRandomise'] == true ? 1.0 : 0.0,
      'angle': (rotation ?? 0) * 2 * math.pi,
      'grainScale': grainScale == null
          ? 1.4
          : (0.5 + grainScale * 3).clamp(0.3, 4.0),
      'grainDepth': hasGrain ? (grainDepth ?? 0.6).clamp(0.0, 1.0) : 0.0,
    };
  }

  /// Pasa una imagen de Procreate (blanco = pinta) a blanco con alfa. Las
  /// puntas se centran en un cuadrado para que giren sobre su centro.
  static Uint8List? _toAlpha(
    Uint8List png, {
    required int maxSize,
    bool invert = false,
    bool square = false,
  }) {
    var src = img.decodeImage(png);
    if (src == null) return null;
    final longest = math.max(src.width, src.height);
    if (longest > maxSize) {
      src = img.copyResize(
        src,
        width: (src.width * maxSize / longest).round(),
        height: (src.height * maxSize / longest).round(),
        interpolation: img.Interpolation.average,
      );
    }
    final side = math.max(src.width, src.height);
    final out = img.Image(
      width: square ? side : src.width,
      height: square ? side : src.height,
      numChannels: 4,
    );
    final dx = square ? (side - src.width) ~/ 2 : 0;
    final dy = square ? (side - src.height) ~/ 2 : 0;
    for (final px in src) {
      final max = px.maxChannelValue.toDouble();
      final lum = (0.299 * px.r + 0.587 * px.g + 0.114 * px.b) / max;
      final alpha = src.numChannels == 4 ? px.a / max : 1.0;
      final v = (invert ? 1 - lum : lum) * alpha;
      out.setPixelRgba(
        px.x + dx,
        px.y + dy,
        255,
        255,
        255,
        (v.clamp(0.0, 1.0) * 255).round(),
      );
    }
    return Uint8List.fromList(img.encodePng(out));
  }
}
