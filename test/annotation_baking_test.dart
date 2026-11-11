import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/annotations/annotation_canvas.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:iris_dp/shared/annotations/annotation_layers.dart';
import 'package:iris_dp/shared/annotations/live_drawing_link.dart';

const _size = Size(100, 100);

AnnotationStroke _rect(
  String id,
  double l,
  double r, {
  int color = 0xFF000000,
}) => AnnotationStroke(
  id: id,
  tool: AnnotationToolType.fill,
  brushId: 'ink.fill',
  colorArgb: color,
  width: 2,
  points: [
    AnnotationPoint(x: l, y: 0),
    AnnotationPoint(x: r, y: 0),
    AnnotationPoint(x: r, y: 1),
    AnnotationPoint(x: l, y: 1),
  ],
);

AnnotationStroke _smudge(String id, double y) => AnnotationStroke(
  id: id,
  tool: AnnotationToolType.airbrush,
  brushId: 'smudge.stump',
  colorArgb: 0xFF000000,
  width: 60,
  points: [
    for (var i = 0; i <= 10; i++) AnnotationPoint(x: 0.3 + i * 0.03, y: y),
  ],
);

Future<Uint8List> _pixels(
  AnnotationDocument doc, {
  AnnotationCompositor? compositor,
}) async {
  await BakedLayerImages.ensure(doc);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Offset.zero & _size, Paint()..color = Colors.white);
  (compositor ?? AnnotationCompositor()).paint(canvas, _size, doc);
  final image = await recorder.endRecording().toImage(100, 100);
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return data!.buffer.asUint8List();
}

/// Mayor diferencia de canal entre dos imágenes.
int _maxDiff(Uint8List a, Uint8List b) {
  var worst = 0;
  for (var i = 0; i < a.length; i++) {
    final d = (a[i] - b[i]).abs();
    if (d > worst) worst = d;
  }
  return worst;
}

Future<void> _until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  testWidgets('muchos difuminos: una sola imagen grande por capa', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final compositor = AnnotationCompositor();
      final doc = AnnotationDocument(
        strokes: [
          _rect('negro', 0, 0.5),
          for (var i = 0; i < 60; i++) _smudge('d$i', 0.1 + (i % 9) * 0.1),
        ],
      );
      final px = await _pixels(doc, compositor: compositor);
      expect(compositor.rasterizations, 1);
      expect(compositor.fullImages, 1);
      // Los difuminos siguen arrastrando el negro hacia lo blanco.
      const i = (50 * 100 + 54) * 4;
      expect(px[i], lessThan(240));
      compositor.dispose();
    });
  });

  testWidgets('al pasar de 60 trazos se aplanan los antiguos y se ve igual', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final c = AnnotationCanvasController()
        ..bakeOldStrokes = true
        ..lastSize = _size;
      for (var i = 0; i <= AnnotationCanvasController.bakeAbove; i++) {
        c.addStroke(
          _rect(
            's$i',
            (i % 20) / 20,
            (i % 20) / 20 + 0.04,
            color: i.isEven ? 0xFF000000 : 0xFF3366CC,
          ),
        );
      }
      final before = c.document;
      expect(before.hasBaked, isFalse);
      await _until(() => c.document.hasBaked);

      final after = c.document;
      expect(after.hasBaked, isTrue);
      expect(after.strokes, hasLength(AnnotationCanvasController.keepEditable));
      // Los que quedan sueltos son los últimos.
      expect(after.strokes.last.id, 's${AnnotationCanvasController.bakeAbove}');
      expect(
        _maxDiff(await _pixels(before), await _pixels(after)),
        lessThanOrEqualTo(2),
      );

      // Aplanar no es un paso de deshacer: deshacer quita el último trazo.
      c.undo();
      expect(c.document.strokes.any((s) => s.id == 's60'), isFalse);

      // Borrar todo quita también lo aplanado.
      c.redo();
      c.clear();
      expect(c.document.isEmpty, isTrue);
      c.dispose();
    });
  });

  testWidgets('fusionar capas con parte aplanada junta las imágenes', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final c = AnnotationCanvasController()..lastSize = _size;
      c.addStroke(_rect('a', 0, 0.5));
      final top = c.addLayer(name: 'Arriba');
      c.addStroke(
        AnnotationStroke(
          id: 'b',
          tool: AnnotationToolType.fill,
          brushId: 'ink.fill',
          colorArgb: 0xFFCC0000,
          width: 2,
          layerId: top,
          points: const [
            AnnotationPoint(x: 0.5, y: 0),
            AnnotationPoint(x: 1, y: 0),
            AnnotationPoint(x: 1, y: 1),
            AnnotationPoint(x: 0.5, y: 1),
          ],
        ),
      );
      // Se aplana a mano la capa de arriba.
      final png = await c.compositor.bake(
        c.document,
        top,
        c.document.strokes.where((s) => s.layerId == top).toList(),
        _size,
      );
      c.replaceDocument(
        c.document.copyWith(
          strokes: c.document.strokes.where((s) => s.layerId != top).toList(),
          layers: [
            for (final l in c.document.layers)
              l.id == top ? l.copyWith(baked: png) : l,
          ],
        ),
      );
      final before = await _pixels(c.document);
      c.mergeDown(top);
      await _until(() => c.layers.length == 1);
      expect(c.layers, hasLength(1));
      expect(c.document.strokes, isEmpty);
      expect(c.layers.single.baked, isNotNull);
      expect(_maxDiff(before, await _pixels(c.document)), lessThanOrEqualTo(2));
      c.dispose();
    });
  });

  test('la parte aplanada va y vuelve en JSON; lo antiguo carga igual', () {
    const doc = AnnotationDocument(
      layers: [AnnotationLayer(id: 'base', name: 'Capa 1', baked: 'iVBOR')],
    );
    expect(doc.isEmpty, isFalse);
    final back = AnnotationDocument.decode(doc.encode());
    expect(back.layers.single.baked, 'iVBOR');
    expect(back.isEmpty, isFalse);

    final old = AnnotationDocument.decode(
      '{"schemaVersion":3,"strokes":[],"notes":[],'
      '"layers":[{"id":"base","name":"Capa 1"}]}',
    );
    expect(old.layers.single.baked, isNull);
    expect(old.isEmpty, isTrue);
  });

  test('en vivo, la parte aplanada solo se manda cuando cambia', () {
    final encoder = DrawingDeltaEncoder();
    final decoder = DrawingDeltaDecoder();
    AnnotationDocument withBaked(String png) => AnnotationDocument(
      layers: [AnnotationLayer(id: 'base', name: 'Capa 1', baked: png)],
    );

    final first = encoder.encode(withBaked('AAAA'));
    expect((first['doc']['layers'] as List).single['baked'], 'AAAA');
    expect(decoder.apply(first)!.layers.single.baked, 'AAAA');

    final second = encoder.encode(withBaked('AAAA'));
    final layer = (second['doc']['layers'] as List).single as Map;
    expect(layer.containsKey('baked'), isFalse);
    expect(layer['bakedRef'], isTrue);
    expect(decoder.apply(second)!.layers.single.baked, 'AAAA');

    final third = encoder.encode(withBaked('BBBB'));
    expect((third['doc']['layers'] as List).single['baked'], 'BBBB');
    expect(decoder.apply(third)!.layers.single.baked, 'BBBB');

    // Quien llega tarde y no tiene la imagen pide el dibujo entero.
    expect(
      DrawingDeltaDecoder().apply(encoder.encode(withBaked('BBBB'))),
      isNull,
    );
  });
}
