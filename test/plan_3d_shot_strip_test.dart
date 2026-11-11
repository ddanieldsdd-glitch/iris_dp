import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/plan_target.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_3d_shots.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_3d_view.dart';

/// ED.3: tocar un plano en la tira del 3D mira por su cámara (y pasa a la
/// siguiente si tiene dos); sin cámara aquí, abre su planta.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  const nav = Plan3dNav(
    title: 'Set barra',
    shots: [
      Plan3dShot(
        target: PlanTarget.shot(1, 'Esc 4 · Plano 1'),
        tag: '4·1',
        letters: ['A', 'B'],
        cameraIds: ['camA', 'camB'],
        open: false,
      ),
      Plan3dShot(
        target: PlanTarget.shot(2, 'Esc 4 · Plano 2'),
        tag: '4·2',
        letters: [],
        cameraIds: [],
        open: false,
      ),
    ],
    sets: [
      Plan3dJump(
        PlanTarget.lightSetup(7, 'Set barra'),
        'Set barra',
        current: true,
      ),
      Plan3dJump(PlanTarget.lightSetup(8, 'Set terraza'), 'Set terraza'),
    ],
  );

  testWidgets('salta a las cámaras, abre plantas y cambia de set', (
    tester,
  ) async {
    var view = 'iso';
    final opened = <PlanTarget>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => Plan3dShotStrip(
              nav: nav,
              view: view,
              onView: (v) => setState(() => view = v),
              onNavigate: opened.add,
            ),
          ),
        ),
      ),
    );
    expect(find.text('4·1 AB'), findsOneWidget);

    await tester.tap(find.text('4·1 AB'));
    await tester.pump();
    expect(view, 'cam:camA');
    await tester.tap(find.text('4·1 AB'));
    await tester.pump();
    expect(view, 'cam:camB');

    await tester.tap(find.text('4·2'));
    await tester.pump();
    expect(opened.single, const PlanTarget.shot(2, ''));

    await tester.longPress(find.text('4·1 AB'));
    await tester.pump();
    expect(opened.last, const PlanTarget.shot(1, ''));

    await tester.tap(find.byKey(const ValueKey('strip3d-jump')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(CheckedPopupMenuItem<PlanTarget>, 'Set terraza'),
    );
    await tester.pumpAndSettle();
    expect(opened.last, const PlanTarget.lightSetup(8, ''));
  });
}
