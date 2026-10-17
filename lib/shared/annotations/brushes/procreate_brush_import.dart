import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'bplist.dart';

/// Un pincel leído de un `.brush` o `.brushset` de Procreate, ya convertido
/// a lo que entiende el motor: punta y grano como PNG blancos con alfa, y
/// los ajustes que se han podido leer.
class ImportedBrushData {
  final String name;

  /// Sin punta propia (Procreate usa una de las suyas): punta redonda.
  final Uint8List? shapePng;
  final Uint8List? grainPng;
  final Map<String, double> params;

  /// Se mezcla multiplicando (rotuladores que oscurecen al solaparse).
  final bool multiply;

  /// El trazo no se carga sobre sí mismo (tinta, rotulador).
  final bool wet;

  /// La punta gira con la dirección del trazo.
  final bool followDirection;

  /// Grupo en la biblioteca: el nombre del set, o null en un `.brush`
  /// suelto (lo decide quien importa).
  final String? group;

  /// Posición dentro del set original.
  final int order;

  const ImportedBrushData({
    required this.name,
    this.shapePng,
    this.grainPng,
    this.params = const {},
    this.multiply = false,
    this.wet = false,
    this.followDirection = false,
    this.group,
    this.order = 0,
  });
}

/// Lee pinceles de Procreate. Un `.brush` es un zip con `Brush.archive`
/// (plist binario con los ajustes), `Shape.png` (punta) y `Grain.png`
/// (textura); un `.brushset` lleva varios, uno por carpeta.
abstract final class ProcreateBrushImport {
  static const _maxTip = 256;
  static const _maxGrain = 512;

  /// Lee desde disco sin cargar el archivo entero en memoria (los sets
  /// pueden pesar cientos de MB). Pensado para correr en otro isolate.
  static List<ImportedBrushData> parseFile(String path) {
    final stream = InputFileStream(path);
    try {
      return _parse(
        ZipDecoder().decodeBuffer(stream),
        fileName: p.basename(path),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('El archivo no es un pincel de Procreate');
    } finally {
      stream.close();
    }
  }

  static List<ImportedBrushData> parse(Uint8List bytes, {String? fileName}) {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('El archivo no es un pincel de Procreate');
    }
    return _parse(archive, fileName: fileName);
  }

  static List<ImportedBrushData> _parse(Archive archive, {String? fileName}) {
    // Ficheros agrupados por carpeta (la raíz en un `.brush` suelto).
    final groups = <String, Map<String, ArchiveFile>>{};
    for (final file in archive) {
      if (!file.isFile) continue;
      final name = file.name.replaceAll('\\', '/');
      if (name.startsWith('__MACOSX/')) continue;
      final dir = p.posix.dirname(name);
      groups.putIfAbsent(dir, () => {})[p.posix.basename(name)] = file;
    }
    final brushGroups = groups.entries
        .where(
          (e) =>
              e.value.containsKey('Brush.archive') ||
              e.value.containsKey('Shape.png'),
        )
        .toList();
    // En un `.brushset`, brushset.plist da el nombre y el orden del set.
    final setInfo = _setInfo(groups['.']?['brushset.plist']);
    final order = setInfo.order;
    int rank(String dir) {
      final i = order.indexOf(p.posix.basename(dir));
      return i < 0 ? order.length : i;
    }

    brushGroups.sort((a, b) {
      final byRank = rank(a.key).compareTo(rank(b.key));
      return byRank != 0 ? byRank : a.key.compareTo(b.key);
    });
    final isSet =
        fileName?.toLowerCase().endsWith('.brushset') == true ||
        groups['.']?.containsKey('brushset.plist') == true ||
        brushGroups.length > 1;
    final setName = isSet
        ? (fileName != null ? cleanName(fileName) : setInfo.name) ??
              setInfo.name ??
              'Importados'
        : null;
    final out = <ImportedBrushData>[];
    final seen = <String>{};
    final fallback = fileName == null
        ? 'Pincel'
        : p.basenameWithoutExtension(fileName);
    var n = 0;
    for (final entry in brushGroups) {
      final files = entry.value;
      final settings = _settings(files['Brush.archive']);
      final rawName = settings['name'] is String
          ? (settings['name'] as String).trim()
          : '';
      // Piezas de pinceles dobles y formas auxiliares: sin nombre o «_ 3».
      if (brushGroups.length > 1 &&
          files.containsKey('Brush.archive') &&
          (rawName.isEmpty || rawName.startsWith('_'))) {
        continue;
      }
      final shape = files['Shape.png'];
      final grain = files['Grain.png'];
      if (shape == null && grain == null && settings.isEmpty) continue;
      n++;
      final name = rawName.isNotEmpty
          ? rawName
          : (brushGroups.length > 1 ? '$fallback $n' : fallback);
      final params = _params(settings, hasGrain: grain != null);
      // El mismo pincel repetido en el set (pasa con los «Sampler»).
      final key =
          '$name|${params.entries.map((e) => e.value.toStringAsFixed(3)).join(',')}';
      if (!seen.add(key)) continue;
      final shapePng = shape == null
          ? null
          : _toAlpha(
              _bytes(shape),
              maxSize: _maxTip,
              invert: settings['shapeInverted'] == true,
              square: true,
            );
      final grainPng = grain == null
          ? null
          : _toAlpha(
              _bytes(grain),
              maxSize: _maxGrain,
              invert: settings['textureInverted'] == true,
            );
      final pressureOpacity = params['pressureOpacity'] ?? 0;
      out.add(
        ImportedBrushData(
          name: _unique(name, out),
          shapePng: shapePng,
          grainPng: grainPng,
          params: {...params, if (grainPng == null) 'grainDepth': 0},
          multiply: settings['blendMode'] == 1,
          // Procreate no carga el trazo sobre sí mismo salvo en lápices que
          // aclaran con poca presión: esos se dejan acumular.
          wet: pressureOpacity.abs() < 0.3,
          followDirection: (_num(settings, ['shapeRotation']) ?? 0) > 0.5,
          group: setName,
          order: out.length,
        ),
      );
    }
    if (out.isEmpty) {
      throw const FormatException('No hay ningún pincel dentro del archivo');
    }
    return out;
  }

  /// Nombre limpio a partir de un archivo: «W.H_The_Pen.brushset» →
  /// «W.H The Pen».
  static String? cleanName(String fileName) {
    var name = p.basenameWithoutExtension(fileName);
    name = name.replaceAll(RegExp(r'[_]+'), ' ');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    return name.isEmpty ? null : name;
  }

  /// Nombre y orden de pinceles del `brushset.plist` (XML).
  static ({String? name, List<String> order}) _setInfo(ArchiveFile? file) {
    if (file == null) return (name: null, order: const []);
    try {
      final xml = String.fromCharCodes(_bytes(file));
      final name = RegExp(
        r'<key>name</key>\s*<string>([^<]*)</string>',
      ).firstMatch(xml)?.group(1)?.trim();
      final array = RegExp(
        r'<key>brushes</key>\s*<array>(.*?)</array>',
        dotAll: true,
      ).firstMatch(xml)?.group(1);
      final order = array == null
          ? const <String>[]
          : [
              for (final m in RegExp(
                r'<string>([^<]*)</string>',
              ).allMatches(array))
                m.group(1)!.trim(),
            ];
      return (name: name == null || name.isEmpty ? null : name, order: order);
    } catch (_) {
      return (name: null, order: const []);
    }
  }

  /// «Dense marker», «Dense marker 2»… si quedan dos con el mismo nombre.
  static String _unique(String name, List<ImportedBrushData> done) {
    if (!done.any((b) => b.name == name)) return name;
    var i = 2;
    while (done.any((b) => b.name == '$name $i')) {
      i++;
    }
    return '$name $i';
  }

  static Uint8List _bytes(ArchiveFile file) {
    final content = file.content;
    return content is Uint8List
        ? content
        : Uint8List.fromList(content as List<int>);
  }

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
    // El tamaño es el deslizador (paintSize) dentro de sus límites.
    final minSize = _num(s, ['minSize']) ?? 0;
    final maxSize = _num(s, ['maxSize']);
    final paintSize = _num(s, ['paintSize']);
    final sizeFraction = maxSize == null
        ? null
        : minSize + (paintSize ?? 0.5) * (maxSize - minSize);
    final pressureSize = _num(s, ['dynamicsPressureSize']);
    final pressureOpacity = _num(s, ['dynamicsPressureOpacity']);
    final tiltSize = _num(s, ['dynamicsTiltSize']);
    final tiltOpacity = _num(s, ['dynamicsTiltOpacity']);
    final smoothing = _num(s, ['plotSmoothing']);
    final grainScale = _num(s, ['textureScale']);
    final grainDepth = _num(s, ['grainDepth', 'textureDepth']);
    final taperSize = _num(s, ['taperSize']) ?? 0;
    final taperStart = _num(s, ['taperStartLength']) ?? 0;
    final taperEnd = _num(s, ['taperEndLength']) ?? 0;
    return {
      'spacing': (spacing ?? 0.1).clamp(0.02, 2.0),
      'scatter': (jitter ?? 0).clamp(0.0, 1.5),
      'defaultWidth': sizeFraction == null
          ? 14
          : (sizeFraction * 120).clamp(1.0, 200.0),
      'flow': hasGrain ? 0.6 : 0.8,
      'pressureSize': (pressureSize ?? 0.4).clamp(-1.0, 1.0),
      'pressureOpacity': (pressureOpacity ?? 0).clamp(-1.0, 1.0),
      'tiltSize': (tiltSize ?? 0).clamp(0.0, 1.0),
      'tiltOpacity': (tiltOpacity ?? 0).clamp(0.0, 1.0),
      'streamline': (smoothing ?? 0).clamp(0.0, 1.0),
      'taperStart': (taperStart * taperSize * 10).clamp(0.0, 8.0),
      'taperEnd': (taperEnd * taperSize * 10).clamp(0.0, 8.0),
      'rotationJitter': s['shapeRandomise'] == true ? 1.0 : 0.0,
      'grainScale': grainScale == null
          ? 1.4
          : (0.5 + grainScale * 1.2).clamp(0.3, 6.0),
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
    final channels = src.numChannels;
    for (final px in src) {
      final max = px.maxChannelValue.toDouble();
      // En gris (uno o dos canales) el brillo es el primer canal.
      final lum = channels <= 2
          ? px.r / max
          : (0.299 * px.r + 0.587 * px.g + 0.114 * px.b) / max;
      final alpha = channels == 4
          ? px.a / max
          : channels == 2
          ? px.g / max
          : 1.0;
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
