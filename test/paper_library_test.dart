import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:iris_dp/shared/annotations/annotation_raster.dart';
import 'package:iris_dp/shared/annotations/brushes/paper_library.dart';

/// Papel de prueba: marrón con vetas claras.
File _paperFile(Directory dir) {
  final image = img.Image(width: 3000, height: 2000);
  for (final px in image) {
    final vein = (px.x ~/ 7) % 3 == 0 ? 60 : 0;
    px.setRgb(150 + vein, 110 + vein, 70 + vein);
  }
  return File('${dir.path}/Papel_viejo.png')
    ..writeAsBytesSync(img.encodePng(image));
}

AnnotationDocument _pencilOn(String? paperImage) => AnnotationDocument(
  paper: AnnotationPaper.ivory,
  paperImage: paperImage,
  strokes: [
    AnnotationStroke(
      id: 'grafito',
      tool: AnnotationToolType.pencil,
      brushId: 'graphite.8b',
      colorArgb: 0xFF111111,
      width: 40,
      points: [
        for (var i = 0; i <= 20; i++)
          AnnotationPoint(x: 0.1 + i * 0.04, y: 0.5, pressure: 0.5),
      ],
    ),
  ],
);

void main() {
  tearDown(PaperLibrary.clearForTest);

  test('nombres limpios y colección por el nombre', () {
    expect(
      PaperLibrary.cleanName('/x/Leonardo_s Sketchbook.JPG'),
      "Leonardo's Sketchbook",
    );
    expect(PaperLibrary.cleanName('/x/Worn_Paper.PNG'), 'Worn Paper');
    expect(PaperLibrary.guessGroup('Grungy Canvas'), 'Lienzos');
    expect(PaperLibrary.guessGroup('Aged Parchment'), 'Pergaminos');
    expect(
      PaperLibrary.guessGroup('Brown Paper Recycled Toothy'),
      'Kraft y reciclados',
    );
    expect(PaperLibrary.guessGroup('Smooth Notebook Paper'), 'Papeles');
  });

  testWidgets('un papel favorito sale el primero', (tester) async {
    final dir = Directory.systemTemp.createTempSync('iris_papel_fav');
    addTearDown(() => dir.deleteSync(recursive: true));
    final library = PaperLibrary(root: () async => dir);
    final a = (await tester.runAsync(
      () => library.importPaper(_paperFile(dir).path, group: 'Mis papeles'),
    ))!;
    expect(a.group, 'Mis papeles');
    final other = File('${dir.path}/Aged_Parchment.png')
      ..writeAsBytesSync(img.encodePng(img.Image(width: 40, height: 30)));
    final b = (await tester.runAsync(() => library.importPaper(other.path)))!;
    expect(b.group, 'Pergaminos');
    await tester.runAsync(() => library.toggleFavorite(b.id));
    expect(PaperLibrary.papers.first.id, b.id);
    expect(PaperLibrary.papers.first.favorite, isTrue);
  });

  test('el documento guarda la clave del papel', () {
    final back = AnnotationDocument.decode(_pencilOn('papel_abc').encode());
    expect(back.paperImage, 'papel_abc');
    expect(back.paper, AnnotationPaper.ivory);
  });

  testWidgets('importar un papel lo reduce, saca su grano y se pinta de '
      'fondo; la clave es la misma al importarlo otra vez', (tester) async {
    final dir = Directory.systemTemp.createTempSync('iris_papel');
    addTearDown(() => dir.deleteSync(recursive: true));
    final library = PaperLibrary(root: () async => dir);
    final source = _paperFile(dir);
    final paper = (await tester.runAsync(
      () => library.importPaper(source.path),
    ))!;
    expect(paper.name, 'Papel viejo');
    expect(paper.background.width, PaperLibrary.backgroundSize);
    expect(paper.grain.width, PaperLibrary.grainSize);
    final again = (await tester.runAsync(
      () => library.importPaper(source.path),
    ))!;
    expect(again.id, paper.id);

    final png = await tester.runAsync(
      () => AnnotationRaster.toPng(
        _pencilOn(paper.id),
        size: const Size(600, 400),
      ),
    );
    final out = img.decodePng(png!)!;
    // Fuera del trazo se ve el papel (marrón), no el marfil de reserva.
    final bg = out.getPixel(20, 20);
    expect(bg.r, lessThan(225));
    expect(bg.b, lessThan(bg.r - 40));

    // Otro arranque lo encuentra en disco.
    PaperLibrary.clearForTest();
    await tester.runAsync(PaperLibrary(root: () async => dir).ensureLoaded);
    expect(PaperLibrary.paper(paper.id)?.name, 'Papel viejo');
  });

  test('una paleta .swatches se lee como colores', () {
    final dir = Directory.systemTemp.createTempSync('iris_paleta');
    addTearDown(() => dir.deleteSync(recursive: true));
    final json = jsonEncode({
      'name': 'Zuecos',
      'swatches': [
        {'hue': 0.0, 'saturation': 1.0, 'brightness': 1.0, 'alpha': 1},
        null,
        {'hue': 1 / 3, 'saturation': 1.0, 'brightness': 0.5, 'alpha': 1},
      ],
    });
    final data = Uint8List.fromList(utf8.encode(json));
    final archive = Archive()
      ..addFile(ArchiveFile('Swatches.json', data.length, data));
    final file = File('${dir.path}/z.swatches')
      ..writeAsBytesSync(ZipEncoder().encode(archive)!);
    final palette = PaperLibrary.parseSwatches(file.path).single;
    expect(palette.name, 'Zuecos');
    expect(palette.colors, [0xFFFF0000, 0xFF008000]);
  });

  final real = Platform.environment['REAL_PAPERS'];
  testWidgets(
    'papeles y paleta reales',
    (tester) async {
      final dir = Directory.systemTemp.createTempSync('iris_papeles_reales');
      addTearDown(() => dir.deleteSync(recursive: true));
      final library = PaperLibrary(root: () async => dir);
      final out = Platform.environment['SWATCH_DIR'];
      for (final file in Directory(real!).listSync().whereType<File>()) {
        final name = file.path.split('/').last;
        if (name.endsWith('.swatches')) {
          final palettes = (await tester.runAsync(
            () => library.importSwatches(file.path),
          ))!;
          // ignore: avoid_print
          print('$name → ${palettes.first.colors.length} colores');
          continue;
        }
        final paper = (await tester.runAsync(
          () => library.importPaper(file.path),
        ))!;
        final doc = _pencilOn(paper.id);
        final png = await tester.runAsync(
          () => AnnotationRaster.toPng(doc, size: const Size(900, 600)),
        );
        // ignore: avoid_print
        print(
          '$name → ${paper.id} (${File('${dir.path}/papeles/${paper.id}.jpg').lengthSync() ~/ 1024} KB)',
        );
        if (out != null) {
          File('$out/papel_${paper.name}.png').writeAsBytesSync(png!);
        }
      }
      expect(math.max(1, PaperLibrary.papers.length), greaterThan(0));
    },
    skip: real == null,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
