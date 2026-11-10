import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/plan_document_labels.dart';

DocumentLabel _label(
  double x,
  double y, {
  double w = 90,
  bool optional = false,
}) => DocumentLabel(
  anchors: [Offset(x, y)],
  size: Size(w, 10),
  radius: 6,
  optional: optional,
);

void _expectClean(List<PlacedDocumentLabel> placed, Size canvas) {
  final area = Offset.zero & canvas;
  for (final (i, a) in placed.indexed) {
    expect(area.contains(a.rect.topLeft), isTrue, reason: '${a.rect}');
    expect(area.contains(a.rect.bottomRight), isTrue, reason: '${a.rect}');
    for (final b in placed.skip(i + 1)) {
      expect(a.rect.overlaps(b.rect), isFalse, reason: '${a.rect} ${b.rect}');
    }
  }
}

void main() {
  const canvas = Size(420, 240);

  test('un rótulo con sitio se queda junto a su marca', () {
    final result = layoutDocumentLabels([_label(210, 100)], canvas);
    expect(result.overflow, isFalse);
    expect(result.placed.single.leader, isFalse);
    expect(result.placed.single.rect.top, greaterThan(100));
  });

  test('una planta estrecha y llena no pisa ningún rótulo', () {
    // Como un local alargado: todas las marcas en una franja central.
    final labels = [
      for (var i = 0; i < 26; i++) _label(190 + (i % 4) * 12.0, 8 + i * 8.5),
    ];
    final marks = [
      for (final l in labels)
        Rect.fromCircle(center: l.anchors.single, radius: 6),
    ];
    final result = layoutDocumentLabels(labels, canvas, marks: marks);
    expect(result.overflow, isFalse);
    expect(result.placed, hasLength(26));
    _expectClean(result.placed, canvas);
    for (final p in result.placed.where((p) => p.leader)) {
      for (final m in marks) {
        expect(p.rect.overlaps(m), isFalse);
      }
    }
  });

  test('avisa cuando ni en columnas caben', () {
    final labels = [
      for (var i = 0; i < 60; i++)
        DocumentLabel(
          anchors: [Offset(210, i * 4.0)],
          size: const Size(80, 10),
          radius: 6,
        ),
    ];
    final marks = [
      for (final l in labels)
        Rect.fromCircle(center: l.anchors.single, radius: 6),
    ];
    expect(layoutDocumentLabels(labels, canvas, marks: marks).overflow, isTrue);
  });

  test('lo opcional que no cabe se omite', () {
    final blocker = _label(210, 100);
    final optional = _label(210, 100, optional: true);
    final result = layoutDocumentLabels(
      [blocker, optional],
      canvas,
      marks: [Rect.fromCircle(center: const Offset(210, 100), radius: 6)],
    );
    expect(result.placed.map((p) => p.label), [blocker]);
  });

  test('aparatos iguales comparten un rótulo con líneas', () {
    final shared = DocumentLabel(
      anchors: const [Offset(200, 100), Offset(220, 110)],
      size: const Size(90, 10),
      radius: 6,
    );
    final result = layoutDocumentLabels([shared], canvas);
    expect(result.placed.single.leader, isTrue);
  });
}
