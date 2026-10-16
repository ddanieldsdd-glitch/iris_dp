import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/shared/annotations/annotation_canvas.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:iris_dp/shared/annotations/annotation_raster.dart';
import 'package:iris_dp/shared/annotations/annotation_shape_recognizer.dart';
import 'package:iris_dp/shared/annotations/sketch_sheet_screen.dart';

/// Trazo con temblor de mano (determinista).
List<Offset> _wobbly(List<Offset> path, {double jitter = 2, int steps = 20}) {
  final rnd = math.Random(7);
  final out = <Offset>[];
  for (var i = 1; i < path.length; i++) {
    for (var s = 0; s < steps; s++) {
      final t = s / steps;
      final p = Offset.lerp(path[i - 1], path[i], t)!;
      out.add(
        p +
            Offset(
              (rnd.nextDouble() - 0.5) * jitter,
              (rnd.nextDouble() - 0.5) * jitter,
            ),
      );
    }
  }
  out.add(path.last);
  return out;
}

void main() {
  group('folio', _sheetTests);

  group('enderezado al mantener', () {
    test('un trazo casi recto se vuelve recta y se ajusta a horizontal', () {
      final shape = AnnotationShapeRecognizer.recognize(
        _wobbly([const Offset(10, 100), const Offset(400, 108)], jitter: 4),
      )!;
      expect(shape.kind, RecognizedShapeKind.line);
      expect(shape.points, hasLength(2));
      expect(shape.points.last.dy, closeTo(shape.points.first.dy, 0.001));
    });

    test('una L se vuelve dos tramos rectos', () {
      final shape = AnnotationShapeRecognizer.recognize(
        _wobbly([
          const Offset(0, 0),
          const Offset(300, 0),
          const Offset(300, 200),
        ]),
      )!;
      expect(shape.kind, RecognizedShapeKind.polyline);
      expect(shape.points, hasLength(3));
      expect(shape.points[1].dx, closeTo(300, 8));
      expect(shape.points[2].dx, closeTo(shape.points[1].dx, 0.001));
    });

    test('un recuadro cerrado se vuelve rectángulo', () {
      final shape = AnnotationShapeRecognizer.recognize(
        _wobbly([
          const Offset(0, 0),
          const Offset(300, 0),
          const Offset(300, 200),
          const Offset(0, 200),
          const Offset(2, 4),
        ]),
      )!;
      expect(shape.kind, RecognizedShapeKind.rectangle);
      expect(shape.closed, isTrue);
      expect(shape.points, hasLength(4));
      final xs = shape.points.map((p) => p.dx).toList()..sort();
      expect(xs.last - xs.first, closeTo(300, 12));
    });

    test('un círculo a mano se vuelve círculo', () {
      final pts = <Offset>[];
      final rnd = math.Random(3);
      for (var i = 0; i <= 60; i++) {
        final a = i / 60 * 2 * math.pi;
        final r = 100 + (rnd.nextDouble() - 0.5) * 6;
        pts.add(Offset(200 + r * math.cos(a), 200 + r * math.sin(a)));
      }
      final shape = AnnotationShapeRecognizer.recognize(pts)!;
      expect(shape.kind, RecognizedShapeKind.ellipse);
      for (final p in shape.points) {
        expect((p - const Offset(200, 200)).distance, closeTo(100, 8));
      }
    });

    test('un punto no se endereza', () {
      expect(
        AnnotationShapeRecognizer.recognize(const [Offset(1, 1), Offset(2, 2)]),
        isNull,
      );
    });
  });

  group('documento v2', () {
    test('guarda y recupera sellos, opacidad y formas cerradas', () {
      const doc = AnnotationDocument(
        strokes: [
          AnnotationStroke(
            id: 'a',
            tool: AnnotationToolType.wash,
            colorArgb: 0xFF3E6E9C,
            width: 40,
            opacity: 0.5,
            closed: true,
            points: [
              AnnotationPoint(x: 0.1, y: 0.1),
              AnnotationPoint(x: 0.5, y: 0.1),
              AnnotationPoint(x: 0.3, y: 0.4),
            ],
          ),
        ],
        stamps: [
          AnnotationStamp(
            id: 'cam',
            kind: AnnotationStampKind.camera,
            x: 0.4,
            y: 0.6,
            rotation: -math.pi / 2,
            colorArgb: 0xFF111111,
            label: 'A',
          ),
        ],
      );
      final back = AnnotationDocument.decode(doc.encode());
      expect(back.schemaVersion, AnnotationDocument.currentSchemaVersion);
      expect(back.strokes.single.tool, AnnotationToolType.wash);
      expect(back.strokes.single.opacity, 0.5);
      expect(back.strokes.single.closed, isTrue);
      expect(back.stamps.single.kind, AnnotationStampKind.camera);
      expect(back.stamps.single.label, 'A');
      expect(back.stamps.single.rotation, closeTo(-math.pi / 2, 1e-9));
    });

    test('lee documentos v1 sin sellos', () {
      final back = AnnotationDocument.decode(
        '{"schemaVersion":1,"strokes":[{"id":"x","tool":"pen",'
        '"colorArgb":4278190080,"width":3,"points":[{"x":0.1,"y":0.2}]}],'
        '"notes":[]}',
      );
      expect(back.strokes.single.opacity, 1);
      expect(back.stamps, isEmpty);
    });

    test('borrar un sello y deshacer lo recupera', () {
      final controller = AnnotationCanvasController();
      controller.addStamp(
        const AnnotationStamp(
          id: 's',
          kind: AnnotationStampKind.actor,
          x: 0.5,
          y: 0.5,
          colorArgb: 0xFF000000,
        ),
      );
      expect(
        controller.hitTestStamp(const Offset(500, 500), const Size(1000, 1000)),
        's',
      );
      controller.removeStamp('s');
      expect(controller.document.stamps, isEmpty);
      controller.undo();
      expect(controller.document.stamps, hasLength(1));
    });

    test('la goma de trazos acierta en mitad de una recta de 2 puntos', () {
      final controller = AnnotationCanvasController()
        ..addStroke(
          const AnnotationStroke(
            id: 'line',
            tool: AnnotationToolType.line,
            colorArgb: 0xFF000000,
            width: 4,
            points: [
              AnnotationPoint(x: 0.1, y: 0.5),
              AnnotationPoint(x: 0.9, y: 0.5),
            ],
          ),
        );
      expect(controller.hitTestStroke(0.5, 0.505), 'line');
    });
  });

  testWidgets('todos los pinceles y sellos se pasan a PNG', (tester) async {
    final strokes = [
      for (final tool in AnnotationToolType.values)
        AnnotationStroke(
          id: tool.name,
          tool: tool,
          colorArgb: 0xFF224466,
          width: 12,
          points: const [
            AnnotationPoint(x: 0.1, y: 0.1, pressure: 0.4),
            AnnotationPoint(x: 0.5, y: 0.3, pressure: 1),
            AnnotationPoint(x: 0.2, y: 0.6, pressure: 0.7),
          ],
        ),
    ];
    final stamps = [
      for (final kind in AnnotationStampKind.values)
        AnnotationStamp(
          id: kind.name,
          kind: kind,
          x: 0.5,
          y: 0.5,
          colorArgb: 0xFF111111,
          label: kind.name,
        ),
    ];
    final png = await tester.runAsync(
      () => AnnotationRaster.toPng(
        AnnotationDocument(strokes: strokes, stamps: stamps),
        size: const Size(320, 180),
      ),
    );
    expect(png, isNotNull);
    expect(png!.length, greaterThan(100));
  });
}

Future<AnnotationDocument?> _pumpSheet(
  WidgetTester tester,
  SketchSheetPurpose purpose,
  Future<void> Function(Rect sheet) draw,
) async {
  tester.view.physicalSize = const Size(1600, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SketchSheetResult? result;
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                result = await SketchSheetScreen.open(
                  context,
                  title: 'Prueba',
                  document: const AnnotationDocument(),
                  purpose: purpose,
                );
              },
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('abrir'));
  await tester.pumpAndSettle();
  final sheet = tester.getRect(find.byType(AnnotationCanvas));
  await draw(sheet);
  await tester.tap(find.text('Hecho'));
  await tester.pumpAndSettle();
  return result?.document;
}

void _sheetTests() {
  testWidgets('en el folio, mantener al acabar endereza el trazo', (
    tester,
  ) async {
    final doc = await _pumpSheet(tester, SketchSheetPurpose.storyboard, (
      sheet,
    ) async {
      final start = sheet.topLeft + const Offset(80, 200);
      final gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.stylus,
      );
      for (var i = 1; i <= 30; i++) {
        await gesture.moveTo(
          start + Offset(i * 15.0, (i.isEven ? 3 : -3) + i * 0.2),
        );
        await tester.pump(const Duration(milliseconds: 16));
      }
      // Quieto: se endereza.
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.up();
      await tester.pump();
    });
    final stroke = doc!.strokes.single;
    expect(stroke.tool, AnnotationToolType.pencil);
    expect(stroke.points, hasLength(2));
    expect(stroke.points.first.y, closeTo(stroke.points.last.y, 1e-6));
  });

  testWidgets('en la planta, un sello de cámara se orienta al arrastrar', (
    tester,
  ) async {
    final doc = await _pumpSheet(tester, SketchSheetPurpose.lightingPlan, (
      sheet,
    ) async {
      await tester.tap(find.byTooltip('Sellos'));
      await tester.pumpAndSettle();
      final at = sheet.center;
      final gesture = await tester.startGesture(at);
      await gesture.moveTo(at + const Offset(0, 40));
      await gesture.moveTo(at + const Offset(0, 80));
      await gesture.up();
      await tester.pump();
    });
    final stamp = doc!.stamps.single;
    expect(stamp.kind, AnnotationStampKind.camera);
    // Arrastrar hacia abajo = mira hacia abajo (π/2).
    expect(stamp.rotation, closeTo(math.pi / 2, 1e-6));
  });
}
