import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/theme/app_colors.dart';
import 'package:iris_dp/features/camera_plan/plan_view_picker.dart';

void main() {
  const scale = 0.5;
  const start = Rect.fromLTWH(200, 200, 400, 400);

  Future<ValueNotifier<Rect?>> pumpCanvas(WidgetTester tester) async {
    final selection = ValueNotifier<Rect?>(start);
    addTearDown(selection.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: const [AppPalette.dark]),
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            height: 500,
            child: PlanSectionCanvas(
              selection: selection,
              fallback: start,
              scale: scale,
              offset: Offset.zero,
              child: const ColoredBox(color: Colors.black),
            ),
          ),
        ),
      ),
    );
    return selection;
  }

  testWidgets('los movimientos de un mismo fotograma se suman', (tester) async {
    final selection = await pumpCanvas(tester);
    // El centro del recuadro, en pantalla.
    final gesture = await tester.startGesture(const Offset(200, 200));
    await gesture.moveBy(const Offset(10, 0));
    await gesture.moveBy(const Offset(10, 0));
    await gesture.moveBy(const Offset(0, 5));
    await gesture.up();
    expect(selection.value, start.shift(const Offset(40, 10)));
  });

  testWidgets('una esquina también suma cada movimiento', (tester) async {
    final selection = await pumpCanvas(tester);
    // Esquina inferior derecha: (600, 600) en planta.
    final gesture = await tester.startGesture(const Offset(300, 300));
    await gesture.moveBy(const Offset(10, 0));
    await gesture.moveBy(const Offset(10, 0));
    await gesture.up();
    expect(selection.value, const Rect.fromLTRB(200, 200, 640, 600));
  });

  testWidgets('fuera del recuadro marca una sección nueva', (tester) async {
    final selection = await pumpCanvas(tester);
    final gesture = await tester.startGesture(const Offset(400, 50));
    await gesture.moveBy(const Offset(100, 100));
    await gesture.up();
    expect(selection.value, const Rect.fromLTRB(800, 100, 1000, 300));
  });
}
