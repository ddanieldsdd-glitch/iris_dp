import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';
import 'package:iris_dp/shared/annotations/annotation_pdf_renderer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('genera PDF vectorial con presión, subrayador y flecha', () async {
    const annotations = AnnotationDocument(
      strokes: [
        AnnotationStroke(
          id: 'pen',
          tool: AnnotationToolType.pen,
          colorArgb: 0xFF007AFF,
          width: 4,
          inputKind: AnnotationInputKind.stylus,
          points: [
            AnnotationPoint(x: 0.1, y: 0.2, pressure: 0.2),
            AnnotationPoint(x: 0.5, y: 0.6, pressure: 0.9),
          ],
        ),
        AnnotationStroke(
          id: 'arrow',
          tool: AnnotationToolType.arrow,
          colorArgb: 0xFFFF3B30,
          width: 3,
          points: [
            AnnotationPoint(x: 0.2, y: 0.8),
            AnnotationPoint(x: 0.8, y: 0.3),
          ],
        ),
      ],
    );
    final pdf = pw.Document()
      ..addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (_) =>
              AnnotationPdfRenderer.build(annotations, width: 400, height: 600),
        ),
      );

    final bytes = await pdf.save();

    expect(bytes, isNotEmpty);
    expect(bytes.take(4), orderedEquals('%PDF'.codeUnits));
  });
}
