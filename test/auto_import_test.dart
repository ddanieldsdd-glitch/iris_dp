import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:iris_dp/shared/annotations/annotation_brush_catalog.dart';
import 'package:iris_dp/shared/annotations/brushes/auto_import.dart';
import 'package:iris_dp/shared/annotations/brushes/custom_brush_store.dart';
import 'package:iris_dp/shared/annotations/brushes/paper_library.dart';

Uint8List _png(int size) {
  final image = img.Image(width: size, height: size);
  for (final px in image) {
    final v = (px.x * 7 + px.y * 3) % 255;
    px.setRgb(v, v, v);
  }
  return Uint8List.fromList(img.encodePng(image));
}

void main() {
  tearDown(() {
    PaperLibrary.clearForTest();
    for (final b in BrushCatalog.custom) {
      BrushCatalog.unregister(b.id);
    }
  });

  testWidgets('lo que hay en Importar entra y se aparta a Hechos; lo que '
      'no se puede leer, a «No se pudo»', (tester) async {
    final docs = Directory.systemTemp.createTempSync('iris_docs');
    final data = Directory.systemTemp.createTempSync('iris_datos');
    addTearDown(() {
      docs.deleteSync(recursive: true);
      data.deleteSync(recursive: true);
    });
    final inbox = '${docs.path}/Importar';
    Directory('$inbox/Pinceles').createSync(recursive: true);
    Directory('$inbox/Papeles').createSync(recursive: true);
    Directory('$inbox/Paletas').createSync(recursive: true);
    final shape = _png(32);
    final brush = Archive()
      ..addFile(ArchiveFile('Shape.png', shape.length, shape));
    File(
      '$inbox/Pinceles/Tinta.brush',
    ).writeAsBytesSync(ZipEncoder().encode(brush)!);
    File('$inbox/Papeles/Papel.png').writeAsBytesSync(_png(64));
    File('$inbox/Paletas/rota.swatches').writeAsStringSync('no es un zip');
    File('$inbox/Pinceles/nota.txt').writeAsStringSync('se ignora');

    final result = (await tester.runAsync(
      () => AutoImport.run(
        documents: () async => docs,
        brushes: CustomBrushStore(root: () async => data),
        papers: PaperLibrary(root: () async => data),
      ),
    ))!;
    expect(result.brushes, 1);
    expect(result.papers, 1);
    expect(result.palettes, 0);
    expect(result.failed, ['rota.swatches']);
    expect(File('$inbox/Hechos/Pinceles/Tinta.brush').existsSync(), isTrue);
    expect(File('$inbox/Hechos/Papeles/Papel.png').existsSync(), isTrue);
    expect(
      File('$inbox/No se pudo/Paletas/rota.swatches').existsSync(),
      isTrue,
    );
    expect(File('$inbox/Pinceles/nota.txt').existsSync(), isTrue);
    expect(BrushCatalog.custom.single.name, 'Tinta');

    // Una segunda pasada no repite nada.
    final again = (await tester.runAsync(
      () => AutoImport.run(
        documents: () async => docs,
        brushes: CustomBrushStore(root: () async => data),
        papers: PaperLibrary(root: () async => data),
      ),
    ))!;
    expect(again.isEmpty, isTrue);
  });

  testWidgets('un .brush en la carpeta de un kit va a su grupo y a Hechos '
      'dentro de esa carpeta', (tester) async {
    final docs = Directory.systemTemp.createTempSync('iris_docs_kit');
    final data = Directory.systemTemp.createTempSync('iris_datos_kit');
    addTearDown(() {
      docs.deleteSync(recursive: true);
      data.deleteSync(recursive: true);
    });
    final kit = Directory('${docs.path}/Importar/Pinceles/Ito Shinsui')
      ..createSync(recursive: true);
    final shape = _png(32);
    final brush = Archive()
      ..addFile(ArchiveFile('Shape.png', shape.length, shape));
    File(
      '${kit.path}/Orpheus.brush',
    ).writeAsBytesSync(ZipEncoder().encode(brush)!);
    final store = CustomBrushStore(root: () async => data);
    final result = (await tester.runAsync(
      () => AutoImport.run(
        documents: () async => docs,
        brushes: store,
        papers: PaperLibrary(root: () async => data),
      ),
    ))!;
    expect(result.brushes, 1);
    expect(store.groups.single.id, 'Ito Shinsui');
    expect(
      File(
        '${docs.path}/Importar/Hechos/Pinceles/Ito Shinsui/Orpheus.brush',
      ).existsSync(),
      isTrue,
    );
    expect(kit.existsSync(), isFalse);
    expect(Directory('${docs.path}/Importar/Pinceles').existsSync(), isTrue);
  });

  test('las estrellas de favoritos se guardan', () async {
    final data = Directory.systemTemp.createTempSync('iris_fav');
    addTearDown(() => data.deleteSync(recursive: true));
    final store = CustomBrushStore(root: () async => data);
    await store.toggleFavorite('graphite.hb');
    await store.toggleFavorite('marker.chisel');
    await store.toggleFavorite('marker.chisel');
    final again = CustomBrushStore(root: () async => data);
    await again.ensureLoaded();
    expect(again.favorites, {'graphite.hb'});
  });
}
