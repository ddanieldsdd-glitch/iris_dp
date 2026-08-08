import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';

void main() {
  test('conserva presión, herramienta, entrada y notas al serializar', () {
    const original = AnnotationDocument(
      strokes: [
        AnnotationStroke(
          id: 'stroke-1',
          tool: AnnotationToolType.highlighter,
          colorArgb: 0xFFFFCC00,
          width: 12,
          inputKind: AnnotationInputKind.stylus,
          points: [
            AnnotationPoint(x: 0.1, y: 0.2, pressure: 0.25),
            AnnotationPoint(x: 0.8, y: 0.7, pressure: 0.9),
          ],
        ),
      ],
      notes: [
        AnnotationNote(
          id: 'note-1',
          text: 'Mover la cámara',
          x: 0.2,
          y: 0.3,
          width: 0.25,
          height: 0.15,
          colorArgb: 0xFFFFE082,
        ),
      ],
    );

    final decoded = AnnotationDocument.decode(original.encode());

    expect(decoded.schemaVersion, AnnotationDocument.currentSchemaVersion);
    expect(decoded.strokes, hasLength(1));
    expect(decoded.strokes.single.tool, AnnotationToolType.highlighter);
    expect(decoded.strokes.single.inputKind, AnnotationInputKind.stylus);
    expect(decoded.strokes.single.points.last.pressure, 0.9);
    expect(decoded.notes.single.text, 'Mover la cámara');
  });

  test('un documento corrupto se recupera como vacío', () {
    final decoded = AnnotationDocument.decode('{no es json');

    expect(decoded.isEmpty, isTrue);
  });
}
