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
Uint8List _brushArchive(String name) => _bplist([
  // 0: diccionario raíz {$archiver, $objects, $top}
  <int, int>{1: 4, 2: 5, 3: 6},
  r'$archiver', // 1
  r'$objects', // 2
  r'$top', // 3
  'NSKeyedArchiver', // 4
  <int>[7, 8], // 5: $objects = [$null, pincel]
  <int, int>{9: 10}, // 6: $top = {root: UID(1)}
  r'$null', // 7
  <int, int>{11: 12, 13: 14, 15: 16}, // 8: el pincel
  'root', // 9
  const PlistUid(1), // 10
  'name', // 11
  name, // 12
  'plotSpacing', // 13
  0.35, // 14
  'shapeRandomise', // 15
  true, // 16
], 0);

Uint8List _png(int size, {required bool disc}) {
  final image = img.Image(width: size, height: size);
  for (final px in image) {
    final dx = px.x - size / 2, dy = px.y - size / 2;
    final white = disc
        ? dx * dx + dy * dy < (size / 3) * (size / 3)
        : (px.x * 7 + px.y * 13) % 5 < 2;
    px.setRgb(white ? 255 : 0, white ? 255 : 0, white ? 255 : 0);
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
    final tip = img.decodePng(first.shapePng)!;
    expect(tip.width, 256);
    expect(tip.getPixel(128, 128).a, 255);
    expect(tip.getPixel(2, 2).a, 0);
    // Sin Brush.archive: nombre del archivo.
    expect(brushes.map((b) => b.name), contains('Vintage 2'));
  });

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
