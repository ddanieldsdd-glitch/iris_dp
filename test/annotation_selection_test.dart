import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/annotations/annotation_canvas.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';

AnnotationStroke _line(String id, double y, {String? layer}) =>
    AnnotationStroke(
      id: id,
      tool: AnnotationToolType.pencil,
      brushId: 'graphite.hb',
      colorArgb: 0xFF000000,
      width: 4,
      layerId: layer,
      points: [
        for (var i = 0; i <= 10; i++) AnnotationPoint(x: 0.2 + i * 0.02, y: y),
      ],
    );

Future<AnnotationCanvasController> _pump(
  WidgetTester tester,
  AnnotationDocument doc,
) async {
  tester.view.physicalSize = const Size(1200, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final controller = AnnotationCanvasController(document: doc);
  await tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 1000,
          height: 600,
          child: AnnotationCanvas(
            controller: controller,
            enabled: true,
            tool: AnnotationToolType.select,
            color: Colors.black,
            width: 4,
          ),
        ),
      ),
    ),
  );
  return controller;
}

Future<void> _drag(WidgetTester tester, List<Offset> path) async {
  final g = await tester.startGesture(
    path.first,
    kind: PointerDeviceKind.mouse,
  );
  for (final p in path.skip(1)) {
    await g.moveTo(p);
    await tester.pump();
  }
  await g.up();
  await tester.pump();
}

void main() {
  testWidgets('tocar un trazo con «Mover» y arrastrarlo lo mueve; deshacer '
      'lo devuelve', (tester) async {
    final controller = await _pump(
      tester,
      AnnotationDocument(strokes: [_line('a', 0.3), _line('b', 0.7)]),
    );
    // Sobre el trazo «a» (x 0.3 → 300 px, y 0.3 → 180 px).
    await _drag(tester, const [
      Offset(300, 180),
      Offset(340, 200),
      Offset(400, 240),
    ]);
    final a = controller.document.strokes.firstWhere((s) => s.id == 'a');
    expect(a.points.first.x, closeTo(0.2 + 100 / 1000, 1e-6));
    expect(a.points.first.y, closeTo(0.3 + 60 / 600, 1e-6));
    final b = controller.document.strokes.firstWhere((s) => s.id == 'b');
    expect(b.points.first.y, 0.7);
    controller.undo();
    expect(controller.document.strokes.first.points.first.x, 0.2);
  });

  testWidgets('el lazo coge varios trazos y sellos y se mueven juntos en un '
      'solo paso de deshacer', (tester) async {
    final controller = await _pump(
      tester,
      AnnotationDocument(
        strokes: [_line('a', 0.3), _line('b', 0.4), _line('lejos', 0.9)],
        stamps: const [
          AnnotationStamp(
            id: 'cam',
            kind: AnnotationStampKind.camera,
            x: 0.6,
            y: 0.35,
            colorArgb: 0xFF000000,
          ),
        ],
      ),
    );
    // Lazo alrededor de x 0.15–0.7, y 0.2–0.5 (empieza en vacío).
    await _drag(tester, const [
      Offset(120, 100),
      Offset(720, 100),
      Offset(720, 320),
      Offset(120, 320),
      Offset(121, 101),
    ]);
    expect(controller.selectedStrokeIds, {'a', 'b'});
    expect(controller.selectedStampIds, {'cam'});

    // Arrastrar desde dentro de la selección.
    await _drag(tester, const [
      Offset(350, 210),
      Offset(380, 210),
      Offset(450, 210),
    ]);
    final doc = controller.document;
    expect(
      doc.strokes.firstWhere((s) => s.id == 'a').points.first.x,
      closeTo(0.3, 1e-6),
    );
    expect(
      doc.strokes.firstWhere((s) => s.id == 'b').points.first.x,
      closeTo(0.3, 1e-6),
    );
    expect(doc.strokes.firstWhere((s) => s.id == 'lejos').points.first.x, 0.2);
    expect(doc.stamps.single.x, closeTo(0.7, 1e-6));

    controller.undo();
    expect(controller.document.stamps.single.x, 0.6);
    expect(controller.document.strokes.first.points.first.x, 0.2);
  });

  testWidgets('borrar la selección quita todo lo seleccionado', (tester) async {
    final controller = await _pump(
      tester,
      AnnotationDocument(strokes: [_line('a', 0.3), _line('b', 0.7)]),
    );
    controller.setSelection(strokes: ['a', 'b'], stamps: const []);
    controller.deleteSelection();
    expect(controller.document.strokes, isEmpty);
    controller.undo();
    expect(controller.document.strokes, hasLength(2));
  });

  testWidgets('no se cogen trazos de una capa bloqueada', (tester) async {
    final controller = await _pump(
      tester,
      AnnotationDocument(
        layers: const [AnnotationLayer(id: 'x', name: 'X', locked: true)],
        strokes: [_line('a', 0.3, layer: 'x')],
      ),
    );
    await _drag(tester, const [Offset(300, 180), Offset(400, 240)]);
    expect(controller.document.strokes.single.points.first.x, 0.2);
  });
}
