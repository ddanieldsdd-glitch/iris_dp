import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Un papel con imagen: el fondo que se ve y el grano que usan los
/// pinceles de lápiz, carbón y aguada.
class PaperTexture {
  final String id;
  final String name;
  final ui.Image background;
  final ui.Image grain;

  const PaperTexture({
    required this.id,
    required this.name,
    required this.background,
    required this.grain,
  });
}

/// Una paleta importada (`.swatches` de Procreate).
class ImportedPalette {
  final String id;
  final String name;
  final List<int> colors;

  const ImportedPalette({
    required this.id,
    required this.name,
    required this.colors,
  });
}

/// Papel ya convertido (fuera del hilo de la interfaz).
class _PreparedPaper {
  final String id;
  final Uint8List backgroundJpg;
  final Uint8List grainPng;

  const _PreparedPaper(this.id, this.backgroundJpg, this.grainPng);
}

/// Papeles y paletas propios de este dispositivo. Como los pinceles
/// importados, no van en el proyecto: el documento guarda solo la clave
/// del papel, que sale del contenido del archivo original, así que el
/// mismo papel importado en el Mac y en el iPad tiene la misma clave.
class PaperLibrary {
  PaperLibrary({Future<Directory> Function()? root})
    : _root = root ?? _defaultRoot;

  static final PaperLibrary instance = PaperLibrary();

  static const backgroundSize = 2048;
  static const grainSize = 1024;

  final Future<Directory> Function() _root;
  Future<void>? _loading;

  static final Map<String, PaperTexture> _papers = {};
  static final Map<String, ImportedPalette> _palettes = {};

  static Future<Directory> _defaultRoot() async =>
      Directory((await getApplicationSupportDirectory()).path);

  static PaperTexture? paper(String? id) => id == null ? null : _papers[id];

  static List<PaperTexture> get papers => _papers.values.toList();

  static List<ImportedPalette> get palettes => _palettes.values.toList();

  Future<void> ensureLoaded() => _loading ??= _load();

  Future<Directory> _dir(String name) async =>
      Directory(p.join((await _root()).path, name));

  Future<void> _load() async {
    try {
      final papers = await _dir('papeles');
      if (papers.existsSync()) {
        for (final meta in papers.listSync().whereType<File>()) {
          if (!meta.path.endsWith('.json')) continue;
          try {
            await _loadPaper(meta);
          } catch (_) {
            // Un papel roto no impide cargar los demás.
          }
        }
      }
      final palettes = await _dir('paletas');
      if (palettes.existsSync()) {
        for (final file in palettes.listSync().whereType<File>()) {
          try {
            final json =
                jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
            final palette = ImportedPalette(
              id: json['id'] as String,
              name: json['name'] as String,
              colors: [for (final c in json['colors'] as List) c as int],
            );
            _palettes[palette.id] = palette;
          } catch (_) {}
        }
      }
    } catch (_) {
      // Sin carpeta de datos (pruebas): no hay nada propio.
    }
  }

  Future<PaperTexture> _loadPaper(File meta) async {
    final json = jsonDecode(meta.readAsStringSync()) as Map<String, dynamic>;
    final id = json['id'] as String;
    final dir = meta.parent.path;
    final paper = PaperTexture(
      id: id,
      name: json['name'] as String,
      background: await _decode(File(p.join(dir, '$id.jpg'))),
      grain: await _decode(File(p.join(dir, '$id.grano.png'))),
    );
    _papers[id] = paper;
    return paper;
  }

  static Future<ui.Image> _decode(File file) async {
    final codec = await ui.instantiateImageCodec(await file.readAsBytes());
    final frame = await codec.getNextFrame();
    codec.dispose();
    return frame.image;
  }

  /// Importa una imagen de papel (PNG o JPG): se reduce, se guarda en los
  /// datos del usuario y se saca su grano.
  Future<PaperTexture> importPaper(String path) async {
    await ensureLoaded();
    final name = p.basenameWithoutExtension(path).replaceAll('_', ' ');
    final prepared = await Isolate.run(() => _prepare(path));
    final existing = _papers[prepared.id];
    if (existing != null) return existing;
    final dir = await _dir('papeles');
    dir.createSync(recursive: true);
    File(
      p.join(dir.path, '${prepared.id}.jpg'),
    ).writeAsBytesSync(prepared.backgroundJpg);
    File(
      p.join(dir.path, '${prepared.id}.grano.png'),
    ).writeAsBytesSync(prepared.grainPng);
    final meta = File(p.join(dir.path, '${prepared.id}.json'))
      ..writeAsStringSync(jsonEncode({'id': prepared.id, 'name': name}));
    return _loadPaper(meta);
  }

  Future<void> deletePaper(String id) async {
    final dir = await _dir('papeles');
    for (final suffix in ['.jpg', '.grano.png', '.json']) {
      final f = File(p.join(dir.path, '$id$suffix'));
      if (f.existsSync()) f.deleteSync();
    }
    _papers.remove(id);
  }

  static _PreparedPaper _prepare(String path) {
    final bytes = File(path).readAsBytesSync();
    final id = 'papel_${sha1.convert(bytes).toString().substring(0, 12)}';
    var image = img.decodeImage(bytes);
    if (image == null) {
      throw const FormatException('No se puede leer la imagen del papel');
    }
    image = _fit(image, backgroundSize);
    final background = Uint8List.fromList(img.encodeJpg(image, quality: 85));
    return _PreparedPaper(id, background, _grainOf(_fit(image, grainSize)));
  }

  static img.Image _fit(img.Image image, int max) {
    final longest = math.max(image.width, image.height);
    if (longest <= max) return image;
    return img.copyResize(
      image,
      width: (image.width * max / longest).round(),
      height: (image.height * max / longest).round(),
      interpolation: img.Interpolation.average,
    );
  }

  /// Grano: el relieve del papel como alfa. Las crestas (claras) cogen
  /// pigmento y los valles (oscuros) se quedan sin él; se estira el
  /// contraste para que un papel suave también se note.
  static Uint8List _grainOf(img.Image image) {
    final n = image.width * image.height;
    final lum = Float64List(n);
    var sum = 0.0;
    var i = 0;
    for (final px in image) {
      final max = px.maxChannelValue.toDouble();
      final v = image.numChannels <= 2
          ? px.r / max
          : (0.299 * px.r + 0.587 * px.g + 0.114 * px.b) / max;
      lum[i++] = v;
      sum += v;
    }
    final mean = sum / n;
    var variance = 0.0;
    for (final v in lum) {
      variance += (v - mean) * (v - mean);
    }
    final std = math.max(0.01, math.sqrt(variance / n));
    final out = img.Image(
      width: image.width,
      height: image.height,
      numChannels: 4,
    );
    i = 0;
    for (final px in out) {
      final a = (0.55 + (lum[i++] - mean) / (3 * std)).clamp(0.0, 1.0);
      px.setRgba(255, 255, 255, (a * 255).round());
    }
    return Uint8List.fromList(img.encodePng(out));
  }

  // ─── Paletas ───────────────────────────────────────────────────────────────

  /// Importa un `.swatches` de Procreate (zip con `Swatches.json`).
  Future<List<ImportedPalette>> importSwatches(String path) async {
    await ensureLoaded();
    final palettes = await Isolate.run(() => parseSwatches(path));
    final dir = await _dir('paletas');
    dir.createSync(recursive: true);
    for (final palette in palettes) {
      File(p.join(dir.path, '${palette.id}.json')).writeAsStringSync(
        jsonEncode({
          'id': palette.id,
          'name': palette.name,
          'colors': palette.colors,
        }),
      );
      _palettes[palette.id] = palette;
    }
    return palettes;
  }

  static List<ImportedPalette> parseSwatches(String path) {
    final bytes = File(path).readAsBytesSync();
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const FormatException('El archivo no es una paleta de Procreate');
    }
    final file = archive.files.where(
      (f) => f.isFile && f.name.endsWith('Swatches.json'),
    );
    if (file.isEmpty) {
      throw const FormatException('El archivo no es una paleta de Procreate');
    }
    final json = jsonDecode(
      utf8.decode(file.first.content as List<int>, allowMalformed: true),
    );
    final entries = json is List ? json : [json];
    final out = <ImportedPalette>[];
    final hash = sha1.convert(bytes).toString().substring(0, 10);
    for (var k = 0; k < entries.length; k++) {
      final entry = entries[k];
      if (entry is! Map) continue;
      final colors = <int>[];
      for (final s in entry['swatches'] as List? ?? const []) {
        if (s is! Map) continue;
        final h = (s['hue'] as num?)?.toDouble();
        final sat = (s['saturation'] as num?)?.toDouble();
        final b = (s['brightness'] as num?)?.toDouble();
        if (h == null || sat == null || b == null) continue;
        colors.add(_hsb(h, sat, b));
      }
      if (colors.isEmpty) continue;
      out.add(
        ImportedPalette(
          id: 'paleta_${hash}_$k',
          name: (entry['name'] as String?)?.trim().isNotEmpty == true
              ? (entry['name'] as String).trim()
              : p.basenameWithoutExtension(path),
          colors: colors,
        ),
      );
    }
    if (out.isEmpty) {
      throw const FormatException('La paleta no tiene colores');
    }
    return out;
  }

  /// HSB de 0 a 1 a ARGB.
  static int _hsb(double h, double s, double v) {
    final hh = (h % 1) * 6;
    final i = hh.floor();
    final f = hh - i;
    final pp = v * (1 - s);
    final q = v * (1 - s * f);
    final t = v * (1 - s * (1 - f));
    final (r, g, b) = switch (i % 6) {
      0 => (v, t, pp),
      1 => (q, v, pp),
      2 => (pp, v, t),
      3 => (pp, q, v),
      4 => (t, pp, v),
      _ => (v, pp, q),
    };
    int c(double x) => (x.clamp(0.0, 1.0) * 255).round();
    return 0xFF000000 | (c(r) << 16) | (c(g) << 8) | c(b);
  }

  /// Solo para pruebas.
  static void clearForTest() {
    _papers.clear();
    _palettes.clear();
  }

  void resetForTest() => _loading = null;
}
