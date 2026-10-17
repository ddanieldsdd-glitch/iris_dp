import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/annotations/annotation_brush_catalog.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:iris_dp/shared/annotations/annotation_raster.dart';

/// Onda de izquierda a derecha con la presión subiendo y bajando.
List<AnnotationPoint> _wave(double y, {double amp = 0.025}) => [
  for (var i = 0; i <= 80; i++)
    AnnotationPoint(
      x: 0.32 + i / 80 * 0.62,
      y: y + math.sin(i / 80 * math.pi * 3) * amp,
      pressure: 0.15 + 0.85 * math.sin(i / 80 * math.pi),
    ),
];

/// Sombreado en zigzag, como al rellenar una sombra a lápiz.
List<AnnotationPoint> _zigzag(double y, double h) => [
  for (var i = 0; i <= 24; i++)
    AnnotationPoint(
      x: 0.03 + i / 24 * 0.24,
      y: y + (i.isEven ? -h : h),
      pressure: 0.5 + 0.4 * math.sin(i / 24 * math.pi),
    ),
];

List<AnnotationPoint> _blob(double cx, double cy, double r) => [
  for (var i = 0; i < 40; i++)
    AnnotationPoint(
      x: cx + math.cos(i / 40 * 2 * math.pi) * r * 1.6,
      y: cy + math.sin(i / 40 * 2 * math.pi) * r,
    ),
];

/// Hoja de muestras de un estilo: cada pincel de su estante en una fila.
AnnotationDocument _swatch(SketchStyle style) {
  final strokes = <AnnotationStroke>[];
  final rows = style.shelf.length;
  for (var i = 0; i < rows; i++) {
    final brush = BrushCatalog.byId(style.shelf[i])!;
    final y = (i + 0.6) / (rows + 0.2);
    final dy = 0.4 / (rows + 0.2);
    // Fondo gris para ver la goma, el gel y la luz.
    if (brush.mode != BrushMode.paint || brush.defaultColor == 0xFFFFFFFF) {
      strokes.add(
        AnnotationStroke(
          id: 'base$i',
          tool: AnnotationToolType.fill,
          brushId: 'marker.tone',
          colorArgb: 0xFF7F878D,
          width: 2,
          points: [
            AnnotationPoint(x: 0.3, y: y - dy),
            AnnotationPoint(x: 0.96, y: y - dy),
            AnnotationPoint(x: 0.96, y: y + dy),
            AnnotationPoint(x: 0.3, y: y + dy),
          ],
        ),
      );
    }
    strokes.add(
      AnnotationStroke(
        id: '${brush.id}-$i',
        tool: brush.family,
        brushId: brush.id,
        colorArgb: brush.defaultColor,
        width: brush.defaultWidth,
        opacity: brush.defaultOpacity,
        points: brush.isArea ? _blob(0.62, y, dy * 0.8) : _wave(y),
      ),
    );
    if (!brush.isArea && brush.mode == BrushMode.paint) {
      strokes.add(
        AnnotationStroke(
          id: '${brush.id}-z$i',
          tool: brush.family,
          brushId: brush.id,
          colorArgb: brush.defaultColor,
          width: brush.defaultWidth,
          opacity: brush.defaultOpacity,
          points: _zigzag(y, dy * 0.8),
        ),
      );
    }
    // Repaso cruzado: los húmedos se oscurecen al cruzarse.
    if (brush.wet && !brush.isArea) {
      strokes.add(
        AnnotationStroke(
          id: '${brush.id}-x$i',
          tool: brush.family,
          brushId: brush.id,
          colorArgb: brush.defaultColor,
          width: brush.defaultWidth,
          opacity: brush.defaultOpacity,
          points: [
            AnnotationPoint(x: 0.5, y: y - dy * 0.9),
            AnnotationPoint(x: 0.56, y: y + dy * 0.9),
          ],
        ),
      );
    }
  }
  return AnnotationDocument(strokes: strokes, paper: style.paper);
}

void main() {
  test('pocos pinceles, y los retirados se pintan con el más parecido', () {
    final paint = BrushCatalog.all.where((b) => b.mode == BrushMode.paint);
    expect(paint.length, inInclusiveRange(8, 12));
    for (final entry in BrushCatalog.retired.entries) {
      expect(BrushCatalog.byId(entry.key)?.id, entry.value, reason: entry.key);
    }
  });

  test('el catálogo no repite ids y los estantes existen', () {
    final ids = BrushCatalog.all.map((b) => b.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    for (final style in BrushCatalog.styles) {
      for (final id in style.shelf) {
        expect(BrushCatalog.byId(id), isNotNull, reason: id);
      }
      expect(style.layers.map((l) => l.id), contains(style.startLayerId));
    }
  });

  test('v3 guarda capas, papel, pincel e inclinación', () {
    const doc = AnnotationDocument(
      paper: AnnotationPaper.kraft,
      layers: [
        AnnotationLayer(id: 'a', name: 'Encaje', opacity: 0.4),
        AnnotationLayer(
          id: 'b',
          name: 'Sombra',
          blend: AnnotationLayerBlend.multiply,
          alphaLock: true,
          visible: false,
        ),
      ],
      strokes: [
        AnnotationStroke(
          id: 's',
          tool: AnnotationToolType.charcoal,
          brushId: 'charcoal.vine',
          layerId: 'b',
          seed: 42,
          colorArgb: 0xFF000000,
          width: 8,
          points: [AnnotationPoint(x: 0.1, y: 0.2, tilt: 0.8, azimuth: 1.2)],
        ),
      ],
    );
    final json = doc.toJson();
    // Una app anterior solo mira `tool`: sigue siendo una familia conocida.
    expect((json['strokes'] as List).single['tool'], 'charcoal');
    final back = AnnotationDocument.decode(doc.encode());
    expect(back.schemaVersion, 3);
    expect(back.paper, AnnotationPaper.kraft);
    expect(back.layers.map((l) => l.id), ['a', 'b']);
    expect(back.layers.first.opacity, 0.4);
    expect(back.layers.last.blend, AnnotationLayerBlend.multiply);
    expect(back.layers.last.alphaLock, isTrue);
    expect(back.layers.last.visible, isFalse);
    final stroke = back.strokes.single;
    expect(stroke.brushId, 'charcoal.vine');
    expect(stroke.layerId, 'b');
    expect(stroke.seed, 42);
    expect(stroke.points.single.tilt, 0.8);
    expect(back.strokeLayerId(stroke), 'b');
  });

  test('un documento sin capas lo pinta todo en «Capa 1»', () {
    const doc = AnnotationDocument(
      strokes: [
        AnnotationStroke(
          id: 'x',
          tool: AnnotationToolType.pen,
          layerId: 'no-existe',
          colorArgb: 0xFF000000,
          width: 2,
          points: [AnnotationPoint(x: 0, y: 0)],
        ),
      ],
    );
    expect(doc.effectiveLayers.single.name, 'Capa 1');
    expect(doc.strokeLayerId(doc.strokes.single), 'base');
  });

  testWidgets('cada estilo se pinta y el mismo trazo da la misma imagen', (
    tester,
  ) async {
    final out = Platform.environment['SWATCH_DIR'];
    for (final style in BrushCatalog.styles) {
      final doc = _swatch(style);
      final a = await tester.runAsync(
        () => AnnotationRaster.toPng(doc, size: const Size(900, 1100)),
      );
      final b = await tester.runAsync(
        () => AnnotationRaster.toPng(doc, size: const Size(900, 1100)),
      );
      expect(a!.length, greaterThan(1000));
      expect(md5.convert(a), md5.convert(b!));
      if (out != null) {
        File('$out/muestras_${style.id}.png').writeAsBytesSync(a);
      }
    }
  });
}
