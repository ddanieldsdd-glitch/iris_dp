import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/shared/annotations/sheet/sheet_guides.dart';

void main() {
  const size = Size(1600, 900);

  test('una recta casi hacia el punto de fuga se ajusta a él', () {
    const guide = PerspectiveGuide(points: 1, vp1: Offset(0.5, 0.5));
    const start = Offset(200, 800);
    // Hacia (800, 450), algo desviada.
    final end = guide.snap(start, const Offset(500, 640), size)!;
    final toVp = const Offset(800, 450) - start;
    final drawn = end - start;
    expect(
      (drawn.dx * toVp.dy - drawn.dy * toVp.dx).abs() / toVp.distance,
      lessThan(0.5),
    );
  });

  test('una recta casi vertical se pone vertical; una cualquiera no', () {
    const guide = PerspectiveGuide(points: 2);
    final end = guide.snap(
      const Offset(300, 100),
      const Offset(310, 500),
      size,
    )!;
    expect(end.dx, closeTo(300, 0.01));
    expect(
      guide.snap(const Offset(300, 100), const Offset(600, -150), size),
      isNull,
    );
  });

  test('el marco 2.39 deja bandas arriba y abajo en un 16:9', () {
    final rect = FrameGuidePainter.frameRect(size, 2.39);
    expect(rect.width, size.width);
    expect(rect.height, closeTo(1600 / 2.39, 0.01));
    expect(rect.top, closeTo((900 - 1600 / 2.39) / 2, 0.01));
  });
}
