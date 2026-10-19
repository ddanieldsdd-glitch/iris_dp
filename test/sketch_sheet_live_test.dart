import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:iris_dp/shared/annotations/live_drawing_link.dart';
import 'package:iris_dp/shared/annotations/sketch_sheet_screen.dart';

/// El otro equipo, a mano: dice quién dibuja y manda el dibujo.
class FakeLink implements LiveDrawingLink {
  @override
  final ValueNotifier<String?> otherDrawer = ValueNotifier<String?>('iPad');
  @override
  final ValueNotifier<bool> mine = ValueNotifier<bool>(false);
  @override
  final ValueNotifier<AnnotationDocument?> remoteDocument =
      ValueNotifier<AnnotationDocument?>(null);
  @override
  final ValueNotifier<AnnotationStroke?> remoteStroke =
      ValueNotifier<AnnotationStroke?>(null);
  final published = <AnnotationDocument>[];
  var disposed = false;

  @override
  void claim() {
    if (otherDrawer.value == null) mine.value = true;
  }

  @override
  void publish(AnnotationDocument document) => published.add(document);

  @override
  void publishStroke(AnnotationStroke? stroke) {}

  @override
  void dispose() => disposed = true;
}

AnnotationStroke stroke(String id) => AnnotationStroke(
  id: id,
  tool: AnnotationToolType.pen,
  colorArgb: 0xFF000000,
  width: 3,
  inputKind: AnnotationInputKind.stylus,
  points: const [
    AnnotationPoint(x: 0.1, y: 0.1, pressure: 0.5),
    AnnotationPoint(x: 0.5, y: 0.5, pressure: 0.5),
  ],
);

void main() {
  testWidgets('mientras dibuja el iPad se mira; al soltarlo se puede dibujar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final link = FakeLink();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: SketchSheetScreen(
          title: 'Plano 3',
          initialDocument: const AnnotationDocument(),
          purpose: SketchSheetPurpose.storyboard,
          aspectRatio: 16 / 9,
          live: link,
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Dibuja iPad · lo ves en vivo'), findsOneWidget);
    // Mirando, no se guarda ni se elige estilo.
    final done = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Hecho'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(done.onPressed, isNull);

    link.remoteDocument.value = AnnotationDocument(strokes: [stroke('a')]);
    await tester.pump();
    expect(link.published, isEmpty);

    link.otherDrawer.value = null;
    await tester.pump();
    expect(find.text('iPad ha soltado el folio'), findsOneWidget);
    await tester.tap(find.text('Dibujar yo'));
    await tester.pump();
    expect(find.textContaining('lo ves en vivo'), findsNothing);
    // Al tomarlo, los demás reciben lo que hay (con lo que llegó del iPad).
    expect(link.published.last.strokes.map((s) => s.id), ['a']);

    await tester.pumpWidget(const SizedBox());
    expect(link.disposed, isTrue);
  });
}
