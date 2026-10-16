import 'dart:math' as math;
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:iris_dp/shared/annotations/annotation_brush_catalog.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:iris_dp/shared/annotations/annotation_raster.dart';
import 'package:iris_dp/shared/annotations/brushes/bplist.dart';
import 'package:iris_dp/shared/annotations/brushes/custom_brush_store.dart';
import 'package:iris_dp/shared/annotations/brushes/procreate_brush_import.dart';
import 'package:flutter/material.dart';

/// Escritor mínimo de plist binario para fabricar un `Brush.archive`.
Uint8List _bplist(List<Object> objects, int top) {
  // Cada objeto: String, int, double, bool, PlistUid, List<int> (refs de
  // array) o Map<int,int> (refs de diccionario clave → valor).
  final body = BytesBuilder();
  body.add(ascii.encode('bplist00'));
  final offsets = <int>[];
  for (final o in objects) {
    offsets.add(body.length);
    if (o is bool) {
      body.addByte(o ? 0x09 : 0x08);
    } else if (o is int) {
      body.addByte(0x13);
      body.add((ByteData(8)..setInt64(0, o)).buffer.asUint8List());
    } else if (o is double) {
      body.addByte(0x23);
      body.add((ByteData(8)..setFloat64(0, o)).buffer.asUint8List());
    } else if (o is String) {
      final b = ascii.encode(o);
      if (b.length < 15) {
        body.addByte(0x50 | b.length);
      } else {
        body.add([0x5F, 0x10, b.length]);
      }
      body.add(b);
    } else if (o is PlistUid) {
      body.add([0x80, o.value]);
    } else if (o is List<int>) {
      body.addByte(0xA0 | o.length);
      body.add(o);
    } else if (o is Map<int, int>) {
      body.addByte(0xD0 | o.length);
      body.add(o.keys.toList());
      body.add(o.values.toList());
    }
  }
  final table = body.length;
  for (final off in offsets) {
    body.add([(off >> 8) & 0xFF, off & 0xFF]);
  }
  final trailer = ByteData(32)
    ..setUint8(6, 2)
    ..setUint8(7, 1)
    ..setUint64(8, objects.length)
    ..setUint64(16, top)
    ..setUint64(24, table);
  body.add(trailer.buffer.asUint8List());
  return body.toBytes();
}

/// `Brush.archive` como lo guarda Procreate (NSKeyedArchiver).
Uint8List _brushArchive(String name, {Map<String, Object> extra = const {}}) {
  final objects = <Object>[
    // 0: diccionario raíz {$archiver, $objects, $top}
    <int, int>{1: 4, 2: 5, 3: 6},
    r'$archiver', // 1
    r'$objects', // 2
    r'$top', // 3
    'NSKeyedArchiver', // 4
    <int>[7, 8], // 5: $objects = [$null, pincel]
    <int, int>{9: 10}, // 6: $top = {root: UID(1)}
    r'$null', // 7
    <int, int>{}, // 8: el pincel, se rellena abajo
    'root', // 9
    const PlistUid(1), // 10
  ];
  final brush = <int, int>{};
  void put(String key, Object value) {
    objects.add(key);
    final k = objects.length - 1;
    objects.add(value);
    brush[k] = objects.length - 1;
  }

  put('name', name);
  put('plotSpacing', 0.35);
  put('shapeRandomise', true);
  extra.forEach(put);
  objects[8] = brush;
  return _bplist(objects, 0);
}

Uint8List _png(int size, {required bool disc, bool gray = false}) {
  final image = img.Image(width: size, height: size, numChannels: gray ? 1 : 3);
  for (final px in image) {
    final dx = px.x - size / 2, dy = px.y - size / 2;
    final white = disc
        ? dx * dx + dy * dy < (size / 3) * (size / 3)
        : (px.x * 7 + px.y * 13) % 5 < 2;
    if (gray) {
      px.r = white ? 255 : 0;
    } else {
      px.setRgb(white ? 255 : 0, white ? 255 : 0, white ? 255 : 0);
    }
  }
  return Uint8List.fromList(img.encodePng(image));
}

Uint8List _brushset() {
  final archive = Archive();
  void add(String name, Uint8List data) =>
      archive.addFile(ArchiveFile(name, data.length, data));
  add('A1B2/Brush.archive', _brushArchive('Tinta vieja'));
  add('A1B2/Shape.png', _png(512, disc: true));
  add('A1B2/Grain.png', _png(64, disc: false));
  add('C3D4/Shape.png', _png(64, disc: true));
  add('brushset.plist', Uint8List.fromList([1, 2, 3]));
  return Uint8List.fromList(ZipEncoder().encode(archive)!);
}

void main() {
  test('el plist binario de NSKeyedArchiver se lee', () {
    final root = BinaryPlist.unarchive(
      BinaryPlist.parse(_brushArchive('Lápiz'.replaceAll('á', 'a'))),
    );
    expect(root, isA<Map>());
    expect((root! as Map)['name'], 'Lapiz');
    expect((root as Map)['plotSpacing'], 0.35);
  });

  test('un .brushset da un pincel por carpeta con sus ajustes', () {
    final brushes = ProcreateBrushImport.parse(
      _brushset(),
      fileName: 'Vintage.brushset',
    );
    expect(brushes, hasLength(2));
    final first = brushes.firstWhere((b) => b.name == 'Tinta vieja');
    expect(first.params['spacing'], closeTo(0.35, 1e-9));
    expect(first.params['rotationJitter'], 1);
    expect(first.grainPng, isNotNull);
    // La punta se reduce y queda blanca con alfa.
    final tip = img.decodePng(first.shapePng!)!;
    expect(tip.width, 256);
    expect(tip.getPixel(128, 128).a, 255);
    expect(tip.getPixel(2, 2).a, 0);
    // Sin Brush.archive: nombre del archivo.
    expect(brushes.map((b) => b.name), contains('Vintage 2'));
  });

  test('lee lo que importa de los pinceles reales: inclinación, '
      'suavizado, multiplicar y presión inversa; salta piezas y repetidos', () {
    final archive = Archive();
    void add(String name, Uint8List data) =>
        archive.addFile(ArchiveFile(name, data.length, data));
    // Punta en gris de un canal, guardada al revés (negro = pinta).
    add(
      'A/Brush.archive',
      _brushArchive(
        'Pentel',
        extra: {
          'dynamicsTiltSize': 1.0,
          'dynamicsTiltOpacity': 0.5,
          'plotSmoothing': 0.6,
          'shapeInverted': true,
          'dynamicsPressureSize': -0.8,
        },
      ),
    );
    add('A/Shape.png', _png(64, disc: false, gray: true));
    add('B/Brush.archive', _brushArchive('Rotulador', extra: {'blendMode': 1}));
    add('B/Shape.png', _png(64, disc: true, gray: true));
    // El mismo rotulador otra vez (con espacios), una pieza y una sin nombre.
    add(
      'C/Brush.archive',
      _brushArchive('Rotulador  ', extra: {'blendMode': 1}),
    );
    add('C/Shape.png', _png(64, disc: true, gray: true));
    add('D/Brush.archive', _brushArchive('_ 3'));
    add('D/Shape.png', _png(64, disc: true));
    add('E/Brush.archive', _brushArchive('   '));
    add('E/Shape.png', _png(64, disc: true));
    // Solo grano, sin punta.
    add('F/Brush.archive', _brushArchive('Sumi'));
    add('F/Grain.png', _png(64, disc: false));
    final brushes = ProcreateBrushImport.parse(
      Uint8List.fromList(ZipEncoder().encode(archive)!),
    );
    expect(brushes.map((b) => b.name), ['Pentel', 'Rotulador', 'Sumi']);
    final pentel = brushes[0];
    expect(pentel.params['tiltSize'], 1);
    expect(pentel.params['tiltOpacity'], 0.5);
    expect(pentel.params['streamline'], closeTo(0.6, 1e-9));
    expect(pentel.params['pressureSize'], closeTo(-0.8, 1e-9));
    // En gris, el brillo es el canal único: blanco del original = no pinta
    // una vez invertido.
    final tip = img.decodePng(pentel.shapePng!)!;
    final whiteSource = img.decodePng(_png(64, disc: false, gray: true))!;
    for (final (x, y) in [(1, 0), (3, 3), (10, 7)]) {
      final white = whiteSource.getPixel(x, y).r > 128;
      expect(tip.getPixel(x, y).a > 128, !white, reason: '$x,$y');
    }
    expect(brushes[1].multiply, isTrue);
    expect(brushes[2].shapePng, isNull);
    expect(brushes[2].grainPng, isNotNull);
  });

  final real = Platform.environment['REAL_BRUSHES'];
  test(
    'los sets reales se leen sin piezas sueltas',
    () {
      for (final file in Directory(real!).listSync().whereType<File>()) {
        if (!file.path.endsWith('.brushset') && !file.path.endsWith('.brush')) {
          continue;
        }
        final brushes = ProcreateBrushImport.parseFile(file.path);
        // ignore: avoid_print
        print(
          '${file.path.split('/').last}: ${brushes.length} → '
          '${brushes.map((b) => b.name).join(', ')}',
        );
        expect(brushes, isNotEmpty);
        expect(brushes.where((b) => b.name.trim().isEmpty), isEmpty);
        expect(brushes.where((b) => b.name.startsWith('_')), isEmpty);
      }
    },
    skip: real == null ? 'Sin REAL_BRUSHES' : false,
    timeout: const Timeout(Duration(minutes: 5)),
  );

  testWidgets(
    'hoja de muestras de los pinceles reales',
    (tester) async {
      final out = Platform.environment['SWATCH_DIR']!;
      final dir = Directory.systemTemp.createTempSync('iris_reales');
      addTearDown(() => dir.deleteSync(recursive: true));
      final store = CustomBrushStore(root: () async => dir);
      for (final file in Directory(real!).listSync().whereType<File>()) {
        final added = (await tester.runAsync(
          () => store.importProcreateFile(file.path),
        ))!;
        final name = file.path.split('/').last.split('.').first;
        for (var page = 0; page * 24 < added.length; page++) {
          final chunk = added.skip(page * 24).take(24).toList();
          final strokes = <AnnotationStroke>[];
          for (var i = 0; i < chunk.length; i++) {
            final b = chunk[i];
            final col = i % 2;
            final row = i ~/ 2;
            strokes.add(
              AnnotationStroke(
                id: 's$i',
                tool: b.family,
                brushId: b.id,
                colorArgb: 0xFF1A1A1A,
                width: b.defaultWidth.clamp(2.0, 30.0),
                opacity: b.defaultOpacity,
                points: [
                  for (var k = 0; k <= 30; k++)
                    AnnotationPoint(
                      x: 0.04 + col * 0.5 + k / 30 * 0.42,
                      y:
                          (row + 0.5) / 12 +
                          0.02 * math.sin(k / 30 * math.pi * 2),
                      pressure: 0.15 + 0.85 * math.sin(k / 30 * math.pi),
                      tilt: k > 20 ? 1.0 : 0,
                    ),
                ],
              ),
            );
          }
          final png = await tester.runAsync(
            () => AnnotationRaster.toPng(
              AnnotationDocument(strokes: strokes),
              size: const Size(1200, 1400),
            ),
          );
          File('$out/reales_${name}_$page.png').writeAsBytesSync(png!);
          File(
            '$out/reales_${name}_$page.txt',
          ).writeAsStringSync(chunk.map((b) => b.name).join('\n'));
        }
      }
      for (final b in BrushCatalog.custom) {
        BrushCatalog.unregister(b.id);
      }
    },
    skip: real == null || Platform.environment['SWATCH_DIR'] == null,
    timeout: const Timeout(Duration(minutes: 8)),
  );

  test('un archivo que no es pincel avisa', () {
    expect(
      () => ProcreateBrushImport.parse(Uint8List.fromList([1, 2, 3])),
      throwsFormatException,
    );
  });

  testWidgets('importar guarda, registra y pinta con la punta propia', (
    tester,
  ) async {
    final dir = Directory.systemTemp.createTempSync('iris_pinceles');
    addTearDown(() => dir.deleteSync(recursive: true));
    final store = CustomBrushStore(root: () async => dir);
    final added = (await tester.runAsync(
      () => store.importProcreate(_brushset(), fileName: 'Vintage.brushset'),
    ))!;
    expect(added, hasLength(2));
    final brush = added.firstWhere((b) => b.name == 'Tinta vieja');
    expect(BrushCatalog.byId(brush.id), isNotNull);
    expect(BrushCatalog.inCategory(BrushCategory.custom), contains(brush));
    expect(brush.tipImage, isNotNull);

    final png = await tester.runAsync(
      () => AnnotationRaster.toPng(
        AnnotationDocument(
          strokes: [
            AnnotationStroke(
              id: 's',
              tool: brush.family,
              brushId: brush.id,
              colorArgb: 0xFF000000,
              width: 30,
              points: const [
                AnnotationPoint(x: 0.1, y: 0.5),
                AnnotationPoint(x: 0.9, y: 0.5),
              ],
            ),
          ],
        ),
        size: const Size(400, 200),
      ),
    );
    final decoded = img.decodePng(png!)!;
    expect(decoded.getPixel(200, 100).r, lessThan(128));

    // Variante desde el estudio: guarda punta y ajustes nuevos.
    final variant = (await tester.runAsync(
      () => store.saveVariant(
        brush,
        name: 'Más suelta',
        params: {'scatter': 0.8},
      ),
    ))!;
    expect(variant.scatter, 0.8);
    expect(variant.tipImage, isNotNull);

    // Otro arranque lo vuelve a encontrar.
    for (final b in [...added, variant]) {
      BrushCatalog.unregister(b.id);
    }
    final again = CustomBrushStore(root: () async => dir);
    await tester.runAsync(again.ensureLoaded);
    expect(BrushCatalog.byId(variant.id)?.name, 'Más suelta');
    for (final b in BrushCatalog.custom) {
      BrushCatalog.unregister(b.id);
    }
  });
}
