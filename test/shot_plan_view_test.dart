import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/plan_thumbnail.dart';
import 'package:iris_dp/features/camera_plan/shot_plan_view.dart';

void main() {
  test('la sección del plano va y vuelve', () {
    const rect = Rect.fromLTWH(100, 200, 300, 150);
    expect(decodeShotPlanView(encodeShotPlanView(rect)), rect);
    expect(encodeShotPlanView(null), isNull);
    expect(decodeShotPlanView(null), isNull);
    expect(decodeShotPlanView('roto'), isNull);
    expect(decodeShotPlanView('{"x":0,"y":0,"w":0,"h":10}'), isNull);
  });

  test('una sección pequeña se acerca más que el encuadre normal', () {
    const size = Size(400, 300);
    const crop = Rect.fromLTWH(1000, 1000, 100, 75);
    final (:scale, :offset) = PlanThumbnail.frame(
      size,
      all: const [],
      focus: null,
      zones: const [],
      drawn: Rect.zero,
      crop: crop,
    );
    expect(scale, 4);
    // El centro de la sección cae en el centro de la casilla.
    expect(crop.center * scale + offset, size.center(Offset.zero));
  });
}
