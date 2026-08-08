import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/annotations/annotation_canvas.dart';
import 'package:iris_dp/shared/annotations/annotation_document.dart';

void main() {
  test('updateNote and removeNote mutan el documento con historial', () {
    final controller = AnnotationCanvasController(
      document: const AnnotationDocument(
        notes: [
          AnnotationNote(
            id: 'n1',
            text: 'prueba',
            x: 0.2,
            y: 0.3,
            width: 0.2,
            height: 0.1,
            colorArgb: 0xFFFF0000,
          ),
        ],
      ),
    );

    controller.updateNote('n1', x: 0.35, y: 0.4, text: 'luz de kicker');
    expect(controller.document.notes.single.x, 0.35);
    expect(controller.document.notes.single.text, 'luz de kicker');

    controller.removeNote('n1');
    expect(controller.document.notes, isEmpty);
    expect(controller.canUndo, isTrue);
  });

  test('note drag commits single undo step', () {
    final controller = AnnotationCanvasController(
      document: const AnnotationDocument(
        notes: [
          AnnotationNote(
            id: 'n1',
            text: 'prueba',
            x: 0.2,
            y: 0.3,
            width: 0.2,
            height: 0.1,
            colorArgb: 0xFFFF0000,
          ),
        ],
      ),
    );

    controller.beginNoteDrag();
    controller.updateNote('n1', x: 0.25, y: 0.35, commit: false);
    controller.updateNote('n1', x: 0.3, y: 0.4, commit: false);
    expect(controller.canUndo, isFalse);
    controller.endNoteDrag();
    expect(controller.document.notes.single.x, 0.3);
    expect(controller.canUndo, isTrue);
    controller.undo();
    expect(controller.document.notes.single.x, 0.2);
  });

  test('eraser removes stroke by hit test', () {
    final controller = AnnotationCanvasController(
      document: AnnotationDocument(
        strokes: [
          AnnotationStroke(
            id: 's1',
            tool: AnnotationToolType.pen,
            colorArgb: 0xFF0000FF,
            width: 3,
            points: const [
              AnnotationPoint(x: 0.5, y: 0.5),
              AnnotationPoint(x: 0.55, y: 0.55),
            ],
          ),
        ],
      ),
    );

    final hit = controller.hitTestStroke(0.5, 0.5);
    expect(hit, 's1');
    controller.removeStroke(hit!);
    expect(controller.document.strokes, isEmpty);
  });
}
