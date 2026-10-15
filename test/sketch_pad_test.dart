import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iris_dp/shared/annotations/annotation_canvas.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:iris_dp/shared/annotations/sketch_pad.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('«Dibujar» abre el folio: se dibuja con el ratón y cerrar sin '
      'guardar avisa', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SketchResult? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async =>
                  result = await showSketchPad(context, title: 'Referencia'),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Referencia'), findsOneWidget);
    for (final tool in ['Lápiz', 'Rotulador', 'Flecha', 'Goma', 'Aguada']) {
      expect(find.byTooltip(tool), findsOneWidget);
    }

    final center = tester.getCenter(find.byType(AnnotationCanvas));
    final mouse = await tester.startGesture(
      center - const Offset(120, 40),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveBy(const Offset(120, 60));
    await mouse.moveBy(const Offset(120, -30));
    await mouse.up();
    await tester.pump();
    // Hay algo que deshacer: se ha dibujado.
    expect(
      tester
          .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.undo))
          .onPressed,
      isNotNull,
    );

    // Con algo dibujado, cerrar avisa antes de perderlo.
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Salir sin guardar?'), findsOneWidget);
    await tester.tap(find.text('Descartar'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    expect(find.text('abrir'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('el dibujo se pasa a una imagen PNG sobre blanco', () async {
    const document = AnnotationDocument(
      strokes: [
        AnnotationStroke(
          id: 'a',
          tool: AnnotationToolType.pen,
          colorArgb: 0xFF111111,
          width: 6,
          points: [
            AnnotationPoint(x: 0.1, y: 0.1),
            AnnotationPoint(x: 0.5, y: 0.6),
          ],
        ),
      ],
    );
    final png = await renderSketchPng(document, size: const Size(320, 180));
    expect(png.sublist(1, 4), ascii.encode('PNG'));
    expect(png.length, greaterThan(200));
  });

  test('los trazos se guardan junto a la imagen y se vuelven a leer', () async {
    final tmp = Directory.systemTemp.createTempSync('iris_dibujo');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final path = '${tmp.path}/dibujo.png';
    const document = AnnotationDocument(
      strokes: [
        AnnotationStroke(
          id: 'a',
          tool: AnnotationToolType.pen,
          colorArgb: 0xFF111111,
          width: 6,
          points: [
            AnnotationPoint(x: 0.1, y: 0.1),
            AnnotationPoint(x: 0.5, y: 0.6),
          ],
        ),
      ],
    );
    expect(isEditableSketch(path), isFalse);
    expect(readSketchDocument(path).isEmpty, isTrue);
    await writeSketchDocument(path, document);
    expect(isEditableSketch(path), isTrue);
    expect(readSketchDocument(path).strokes.single.points, hasLength(2));
  });
}
