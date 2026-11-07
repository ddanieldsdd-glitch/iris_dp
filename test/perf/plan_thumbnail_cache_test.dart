import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/plan_thumbnail.dart';

void main() {
  setUp(PlanThumbnailCache.clear);

  PlanElement camera(Offset at) =>
      PlanElement(id: 1, type: ElementType.camera, position: at);

  Widget thumbnail(List<PlanElement> elements) => MaterialApp(
    theme: AppTheme.dark,
    home: Center(
      child: SizedBox(
        width: 120,
        height: 84,
        child: PlanThumbnail(elements: elements),
      ),
    ),
  );

  testWidgets('la misma planta se pinta una sola vez', (tester) async {
    final elements = [camera(const Offset(10, 10))];
    await tester.pumpWidget(thumbnail(elements));
    expect(PlanThumbnailCache.length, 1);

    await tester.pumpWidget(thumbnail([camera(const Offset(10, 10))]));
    expect(PlanThumbnailCache.length, 1);
    expect(find.byType(RawImage), findsOneWidget);
  });

  testWidgets('una planta distinta se pinta de nuevo', (tester) async {
    await tester.pumpWidget(thumbnail([camera(const Offset(10, 10))]));
    await tester.pumpWidget(
      thumbnail([camera(const Offset(10, 10))..rotation = 45]),
    );
    expect(PlanThumbnailCache.length, 2);
  });

  test('la caché no pasa de su memoria', () {
    const size = Size(1000, 1000);
    final count = PlanThumbnailCache.maxBytes ~/ (1000 * 1000 * 4) + 8;
    final shown = <ui.Image>[];
    for (var i = 0; i < count; i++) {
      shown.add(
        PlanThumbnailCache.image(i, size, 1, (canvas, size) {}).clone(),
      );
    }
    expect(PlanThumbnailCache.length, lessThan(count));
    // Lo que se enseña sigue vivo aunque salga de la caché.
    expect(shown.first.debugDisposed, isFalse);
    for (final image in shown) {
      image.dispose();
    }
  });
}
