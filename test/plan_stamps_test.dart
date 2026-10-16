import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/annotations/annotation_brushes.dart';
import 'package:iris_dp/shared/annotations/annotation_canvas.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:iris_dp/shared/annotations/annotation_raster.dart';

Future<AnnotationCanvasController> _pump(
  WidgetTester tester, {
  required AnnotationToolType tool,
  AnnotationStampKind kind = AnnotationStampKind.camera,
  double? gridStep,
  AnnotationDocument document = const AnnotationDocument(),
}) async {
  final controller = AnnotationCanvasController(document: document);
  await tester.pumpWidget(
    MaterialApp(
      home: Center(
        child: SizedBox(
          width: 800,
          height: 600,
          child: AnnotationCanvas(
            controller: controller,
            enabled: true,
            tool: tool,
            color: Colors.black,
            width: 4,
            stampKind: kind,
            gridStep: gridStep,
          ),
        ),
      ),
    ),
  );
  return controller;
}

void main() {
  test('el ángulo de visión sale de la óptica y el sensor', () {
    // 50 mm en Super 35 ≈ 28°; en full frame ≈ 40°.
    expect(AnnotationBrushes.fieldOfView(50) * 180 / math.pi, closeTo(28, 0.5));
    expect(
      AnnotationBrushes.fieldOfView(50, sensorWidthMm: 36) * 180 / math.pi,
      closeTo(39.6, 0.5),
    );
  });

  test('los sellos nuevos guardan haz y óptica', () {
    const doc = AnnotationDocument(
      stamps: [
        AnnotationStamp(
          id: 'c',
          kind: AnnotationStampKind.crane,
          x: 0.5,
          y: 0.5,
          colorArgb: 0xFF000000,
          spread: 0.4,
          reach: 5,
          lensMm: 35,
        ),
      ],
    );
    final back = AnnotationDocument.decode(doc.encode()).stamps.single;
    expect(back.kind, AnnotationStampKind.crane);
    expect(back.spread, 0.4);
    expect(back.reach, 5);
    expect(back.lensMm, 35);
  });

  testWidgets('con la rejilla, el sello cae en un cruce', (tester) async {
    final controller = await _pump(
      tester,
      tool: AnnotationToolType.stamp,
      gridStep: 1 / 16,
    );
    final rect = tester.getRect(find.byType(AnnotationCanvas));
    await tester.tapAt(
      rect.topLeft + const Offset(203, 158),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    final stamp = controller.document.stamps.single;
    const step = 600 / 16;
    expect(
      (stamp.x * 800 / step - (stamp.x * 800 / step).round()).abs(),
      lessThan(1e-6),
    );
    expect(
      (stamp.y * 600 / step - (stamp.y * 600 / step).round()).abs(),
      lessThan(1e-6),
    );
  });

  testWidgets('el tirador ámbar abre y alarga el haz del foco', (tester) async {
    const light = AnnotationStamp(
      id: 'f',
      kind: AnnotationStampKind.fresnel,
      x: 0.25,
      y: 0.5,
      colorArgb: 0xFF000000,
    );
    final controller = await _pump(
      tester,
      tool: AnnotationToolType.select,
      document: const AnnotationDocument(stamps: [light]),
    );
    controller.selectStamp('f');
    await tester.pump();
    final rect = tester.getRect(find.byType(AnnotationCanvas));
    final handle =
        rect.topLeft + AnnotationBrushes.beamHandle(light, rect.size);
    final center =
        rect.topLeft + AnnotationBrushes.stampCenter(light, rect.size);
    final g = await tester.startGesture(handle, kind: PointerDeviceKind.mouse);
    // Más lejos y más abierto: 30° a cada lado, a 200 px.
    final target = center + Offset.fromDirection(math.pi / 6, 200);
    await g.moveTo(Offset.lerp(handle, target, 0.5)!);
    await g.moveTo(target);
    await g.up();
    await tester.pump();
    final after = controller.document.stamps.single;
    expect(after.spread!, closeTo(math.pi / 3, 0.01));
    final r = AnnotationBrushes.stampRadius(after, rect.size);
    expect(after.reach!, closeTo(200 / r, 0.05));
    controller.undo();
    expect(controller.document.stamps.single.spread, isNull);
  });

  testWidgets('todos los sellos de planta se pintan', (tester) async {
    final kinds = AnnotationStampKind.values
        .where((k) => k != AnnotationStampKind.text)
        .toList();
    final doc = AnnotationDocument(
      paper: AnnotationPaper.white,
      stamps: [
        for (var i = 0; i < kinds.length; i++)
          AnnotationStamp(
            id: kinds[i].name,
            kind: kinds[i],
            x: 0.1 + (i % 5) * 0.2,
            y: 0.12 + (i ~/ 5) * 0.25,
            rotation: -math.pi / 2,
            size: 0.07,
            colorArgb: 0xFF1A1A1A,
            label: kinds[i].name,
          ),
      ],
    );
    final png = await tester.runAsync(
      () => AnnotationRaster.toPng(doc, size: const Size(1200, 900)),
    );
    expect(png!.length, greaterThan(1000));
    final out = Platform.environment['SWATCH_DIR'];
    if (out != null) File('$out/sellos.png').writeAsBytesSync(png);
  });
}
