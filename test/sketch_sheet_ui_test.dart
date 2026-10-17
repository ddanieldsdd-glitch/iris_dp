import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/shared/annotations/annotation_canvas.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:iris_dp/shared/annotations/sketch_sheet_screen.dart';

final _shotKey = GlobalKey();

Future<SketchSheetResult?> Function() _open(
  WidgetTester tester, {
  SketchSheetPurpose purpose = SketchSheetPurpose.storyboard,
  AnnotationDocument document = const AnnotationDocument(),
  ImageProvider? onionSkin,
}) {
  return () async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SketchSheetResult? result;
    var closed = false;
    await tester.pumpWidget(
      RepaintBoundary(
        key: _shotKey,
        child: MaterialApp(
          theme: AppTheme.dark,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async {
                    result = await SketchSheetScreen.open(
                      context,
                      title: 'Plano 12',
                      document: document,
                      purpose: purpose,
                      onionSkin: onionSkin,
                      onionSkinLabel: onionSkin == null ? null : 'Plano 1',
                    );
                    closed = true;
                  },
                  child: const Text('abrir'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    return closed ? result : null;
  };
}

Future<void> _stroke(WidgetTester tester, Offset from, Offset delta) async {
  final g = await tester.startGesture(from, kind: PointerDeviceKind.stylus);
  for (var i = 1; i <= 12; i++) {
    await g.moveTo(from + delta * (i / 12) + Offset(0, (i % 3) * 2.0));
    await tester.pump(const Duration(milliseconds: 16));
  }
  await g.up();
  await tester.pump();
}

Future<void> _shot(WidgetTester tester, String name) async {
  final dir = Platform.environment['SWATCH_DIR'];
  if (dir == null) return;
  await tester.runAsync(() async {
    final boundary =
        _shotKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(png!.buffer.asUint8List());
  });
}

AnnotationCanvasController _controllerOf(WidgetTester tester) =>
    tester.widget<AnnotationCanvas>(find.byType(AnnotationCanvas)).controller;

void main() {
  testWidgets('un storyboard nuevo ofrece estilos y elegir uno pone sus '
      'capas y su papel', (tester) async {
    await _open(tester)();
    expect(find.text('Rotulador gris'), findsOneWidget);
    await _shot(tester, 'ui_inicio');
    await tester.tap(find.text('Rotulador gris'));
    await tester.pumpAndSettle();
    final doc = _controllerOf(tester).document;
    expect(doc.layers.map((l) => l.name), [
      'Lápiz guía',
      'Grises',
      'Línea',
      'Luces',
    ]);
    expect(doc.paper, AnnotationPaper.white);

    // Se dibuja en la capa de inicio con su pincel.
    final sheet = tester.getRect(find.byType(AnnotationCanvas));
    await _stroke(
      tester,
      sheet.center - const Offset(200, 0),
      const Offset(400, 40),
    );
    final stroke = _controllerOf(tester).document.strokes.single;
    expect(stroke.layerId, 'guia');
    expect(stroke.brushId, 'graphite.hb');
    expect(find.text('Rotulador gris'), findsNothing);
  });

  testWidgets('la biblioteca cambia de pincel y la goma usa el suyo', (
    tester,
  ) async {
    await _open(tester)();
    await tester.tap(find.byTooltip('Pincel'));
    await tester.pumpAndSettle();
    expect(find.text('Pinceles'), findsOneWidget);
    await _shot(tester, 'ui_pinceles');
    await tester.tap(find.byKey(const ValueKey('brush-ink.brushpen')));
    await tester.pumpAndSettle();

    final sheet = tester.getRect(find.byType(AnnotationCanvas));
    await _stroke(
      tester,
      sheet.center - const Offset(150, 30),
      const Offset(300, 0),
    );
    expect(
      _controllerOf(tester).document.strokes.single.brushId,
      'ink.brushpen',
    );

    await tester.tap(find.byTooltip('Borrar'));
    await tester.pumpAndSettle();
    await _stroke(
      tester,
      sheet.center - const Offset(100, 30),
      const Offset(200, 0),
    );
    final erase = _controllerOf(tester).document.strokes.last;
    expect(erase.tool, AnnotationToolType.eraseArea);
    expect(erase.brushId, 'eraser.kneaded');
  });

  testWidgets('en una capa oculta no se dibuja y el panel de capas la '
      'vuelve a mostrar', (tester) async {
    await _open(tester)();
    await tester.tap(find.byTooltip('Capas'));
    await tester.pumpAndSettle();
    await _shot(tester, 'ui_capas');
    expect(find.text('Lápiz guía'), findsOneWidget);
    // La capa activa (Lápiz guía) se oculta.
    await tester.tap(find.byTooltip('Ocultar capa').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('oculta'), findsOneWidget);

    final sheet = tester.getRect(find.byType(AnnotationCanvas));
    await _stroke(
      tester,
      sheet.center - const Offset(150, 30),
      const Offset(300, 0),
    );
    expect(_controllerOf(tester).document.strokes, isEmpty);

    await tester.tap(find.byTooltip('Capas'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Mostrar capa'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Capas'));
    await tester.pumpAndSettle();
    await _stroke(
      tester,
      sheet.center - const Offset(150, 30),
      const Offset(300, 0),
    );
    expect(_controllerOf(tester).document.strokes, hasLength(1));
  });

  testWidgets('en la planta, la cámara cae en la capa «Cámaras»', (
    tester,
  ) async {
    await _open(tester, purpose: SketchSheetPurpose.lightingPlan)();
    await tester.tap(find.byTooltip('Sellos'));
    await tester.pumpAndSettle();
    await _shot(tester, 'ui_planta');
    final sheet = tester.getRect(find.byType(AnnotationCanvas));
    await tester.tapAt(sheet.center, kind: PointerDeviceKind.mouse);
    await tester.pump();
    final stamp = _controllerOf(tester).document.stamps.single;
    expect(stamp.layerId, 'camaras');
  });

  testWidgets('con Pencil, un dedo desplaza el folio y no pinta', (
    tester,
  ) async {
    await _open(tester)();
    final sheet = tester.getRect(find.byType(AnnotationCanvas));
    await _stroke(
      tester,
      sheet.center - const Offset(150, 0),
      const Offset(300, 0),
    );
    expect(_controllerOf(tester).document.strokes, hasLength(1));

    final before = tester.getRect(find.byType(AnnotationCanvas));
    final finger = await tester.startGesture(
      sheet.center + const Offset(0, 80),
      kind: PointerDeviceKind.touch,
    );
    for (var i = 1; i <= 10; i++) {
      await finger.moveBy(const Offset(12, 6));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await finger.up();
    await tester.pumpAndSettle();
    final after = tester.getRect(find.byType(AnnotationCanvas));
    expect(after.center.dx, greaterThan(before.center.dx + 60));
    expect(_controllerOf(tester).document.strokes, hasLength(1));
  });

  testWidgets('el papel cebolla empieza apagado y se pone y quita con su '
      'etiqueta', (tester) async {
    final pixel = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQ'
      'DwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
    );
    await _open(tester, onionSkin: MemoryImage(pixel))();
    expect(find.text('Ver Plano 1 debajo'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await tester.tap(find.text('Ver Plano 1 debajo'));
    await tester.pump();
    expect(find.text('Papel cebolla · Plano 1  ✕'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    await tester.tap(find.text('Papel cebolla · Plano 1  ✕'));
    await tester.pump();
    expect(find.byType(Image), findsNothing);
  });
}
