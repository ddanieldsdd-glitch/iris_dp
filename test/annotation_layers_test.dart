import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/annotations/annotation_canvas.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:iris_dp/shared/annotations/annotation_layers.dart';

const _size = Size(100, 100);

AnnotationStroke _rect(
  String id,
  double l,
  double r, {
  String? layer,
  int color = 0xFF000000,
  bool alphaLocked = false,
}) => AnnotationStroke(
  id: id,
  tool: AnnotationToolType.fill,
  brushId: 'ink.fill',
  colorArgb: color,
  width: 2,
  layerId: layer,
  alphaLocked: alphaLocked,
  points: [
    AnnotationPoint(x: l, y: 0),
    AnnotationPoint(x: r, y: 0),
    AnnotationPoint(x: r, y: 1),
    AnnotationPoint(x: l, y: 1),
  ],
);

/// Pinta el documento sobre blanco y devuelve los píxeles RGBA.
Future<(Uint8List, int)> _pixels(
  WidgetTester tester,
  AnnotationDocument doc, {
  AnnotationCompositor? compositor,
}) async {
  final result = await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & _size, Paint()..color = Colors.white);
    (compositor ?? AnnotationCompositor()).paint(canvas, _size, doc);
    final image = await recorder.endRecording().toImage(100, 100);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return data!.buffer.asUint8List();
  });
  return (result!, 100);
}

List<int> _at((Uint8List, int) px, int x, int y) {
  final i = (y * px.$2 + x) * 4;
  return px.$1.sublist(i, i + 3);
}

void main() {
  testWidgets('una capa oculta no se ve y la opacidad aclara', (tester) async {
    final hidden = await _pixels(
      tester,
      AnnotationDocument(
        layers: const [AnnotationLayer(id: 'a', name: 'A', visible: false)],
        strokes: [_rect('s', 0, 1, layer: 'a')],
      ),
    );
    expect(_at(hidden, 50, 50), [255, 255, 255]);

    final half = await _pixels(
      tester,
      AnnotationDocument(
        layers: const [AnnotationLayer(id: 'a', name: 'A', opacity: 0.5)],
        strokes: [_rect('s', 0, 1, layer: 'a')],
      ),
    );
    expect(_at(half, 50, 50)[0], closeTo(128, 4));
  });

  testWidgets('el bloqueo de alfa pinta solo encima de lo pintado', (
    tester,
  ) async {
    final px = await _pixels(
      tester,
      AnnotationDocument(
        strokes: [
          _rect('base', 0, 0.5),
          _rect('rojo', 0, 1, color: 0xFFFF0000, alphaLocked: true),
        ],
      ),
    );
    expect(_at(px, 25, 50), [255, 0, 0]);
    expect(_at(px, 75, 50), [255, 255, 255]);
  });

  testWidgets('la máscara de recorte se limita a la capa de abajo', (
    tester,
  ) async {
    final px = await _pixels(
      tester,
      AnnotationDocument(
        layers: const [
          AnnotationLayer(id: 'a', name: 'A'),
          AnnotationLayer(id: 'b', name: 'B', clip: true),
        ],
        strokes: [
          _rect('base', 0, 0.5, layer: 'a'),
          _rect('rojo', 0, 1, layer: 'b', color: 0xFFFF0000),
        ],
      ),
    );
    expect(_at(px, 25, 50), [255, 0, 0]);
    expect(_at(px, 75, 50), [255, 255, 255]);
  });

  testWidgets('multiplicar oscurece lo de debajo', (tester) async {
    final px = await _pixels(
      tester,
      AnnotationDocument(
        layers: const [
          AnnotationLayer(id: 'a', name: 'A'),
          AnnotationLayer(
            id: 'b',
            name: 'B',
            blend: AnnotationLayerBlend.multiply,
          ),
        ],
        strokes: [
          _rect('gris', 0, 1, layer: 'a', color: 0xFF808080),
          _rect('gris2', 0, 1, layer: 'b', color: 0xFF808080),
        ],
      ),
    );
    expect(_at(px, 50, 50)[0], closeTo(64, 4));
  });

  testWidgets('el difumino arrastra el negro hacia lo blanco', (tester) async {
    final px = await _pixels(
      tester,
      AnnotationDocument(
        strokes: [
          _rect('negro', 0, 0.5),
          AnnotationStroke(
            id: 'dedo',
            tool: AnnotationToolType.airbrush,
            brushId: 'smudge.stump',
            colorArgb: 0xFF000000,
            width: 120,
            points: [
              for (var i = 0; i <= 20; i++)
                AnnotationPoint(x: 0.3 + i * 0.015, y: 0.5),
            ],
          ),
        ],
      ),
    );
    expect(_at(px, 54, 50)[0], lessThan(240));
  });

  testWidgets('al añadir un trazo solo se rasteriza una vez su capa', (
    tester,
  ) async {
    final compositor = AnnotationCompositor();
    final strokes = [
      for (var i = 0; i < 300; i++)
        _rect('s$i', (i % 10) / 10, (i % 10) / 10 + 0.05),
    ];
    var doc = AnnotationDocument(strokes: strokes);
    await _pixels(tester, doc, compositor: compositor);
    expect(compositor.rasterizations, 1);
    await _pixels(tester, doc, compositor: compositor);
    expect(compositor.rasterizations, 1);
    doc = doc.copyWith(strokes: [...strokes, _rect('nuevo', 0.9, 1)]);
    await _pixels(tester, doc, compositor: compositor);
    expect(compositor.rasterizations, 2);
    compositor.dispose();
  });

  test('capas: añadir, mover, duplicar, fusionar y deshacer', () {
    final c = AnnotationCanvasController();
    c.addStroke(_rect('a', 0, 0.5));
    expect(c.layers.single.id, 'base');
    final top = c.addLayer(name: 'Sombra');
    expect(c.layers.map((l) => l.name), ['Capa 1', 'Sombra']);
    c.addStroke(_rect('b', 0.5, 1, layer: top));
    c.updateLayer(top, opacity: 0.5);

    final copy = c.duplicateLayer(top)!;
    expect(c.layers, hasLength(3));
    expect(c.document.strokes.where((s) => s.layerId == copy), hasLength(1));

    c.moveLayer('base', 2);
    expect(c.layers.last.id, 'base');
    // El trazo sin capa sigue en «Capa 1» aunque ya no sea la de abajo.
    expect(c.document.strokeLayerId(c.document.strokes.first), 'base');

    c.mergeDown(copy);
    expect(c.layers, hasLength(2));
    expect(
      c.document.strokes.where((s) => s.layerId == top).map((s) => s.opacity),
      [1, 0.5],
    );

    c.removeLayer(top);
    expect(c.layers.single.id, 'base');
    expect(c.document.strokes.single.id, 'a');
    c.undo();
    expect(c.layers, hasLength(2));
  });
}
