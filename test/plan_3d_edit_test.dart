import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_3d_edit.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_3d_view.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_transform.dart';

/// ED.2: añadir desde el 3D (se elige y se toca el suelo), duplicar,
/// borrar y deshacer.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('el punto del suelo del visor cae en su sitio de la planta', () {
    const mpu = 0.05;
    final el = PlanElement(
      id: 0,
      type: ElementType.prop,
      position: const Offset(140, -60),
    );
    final (:x, :y) = PlanTransform.xyM(el, mpu);
    final at = Plan3dEditing.canvasAt(x, y, mpu);
    expect(at.dx, closeTo(140, 1e-9));
    expect(at.dy, closeTo(-60, 1e-9));
  });

  test(
    'then avisa al terminar cada acción y deja fuera las que faltan',
    () async {
      var done = 0, added = <Offset>[];
      final edit = Plan3dEditing(
        items: [
          Plan3dAddItem(
            group: 'Luces',
            label: 'Fresnel',
            icon: Icons.highlight,
            add: (at) async => added.add(at),
          ),
        ],
        undo: () async {},
      ).then(() => done++);
      await edit.items.single.add(const Offset(1, 2));
      await edit.undo!();
      expect(added, [const Offset(1, 2)]);
      expect(done, 2);
      expect(edit.delete, isNull);
      expect(edit.duplicate, isNull);
    },
  );

  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: Align(alignment: Alignment.topLeft, child: child),
      ),
    ),
  );

  testWidgets('la barra elige qué añadir y solo borra con selección', (
    tester,
  ) async {
    Plan3dAddItem? picked;
    var deleted = 0, undone = 0;
    final edit = Plan3dEditing(
      items: [
        for (final (g, l) in [
          ('Cámara y reparto', 'Cámara'),
          ('Luces', 'Fresnel'),
          ('Atrezzo', 'Mesa'),
        ])
          Plan3dAddItem(group: g, label: l, icon: Icons.add, add: (_) async {}),
      ],
      delete: () async => deleted++,
      undo: () async => undone++,
    );
    await pump(
      tester,
      Plan3dEditBar(
        editing: edit,
        hasSelection: false,
        placing: null,
        onPick: (i) => picked = i,
        onCancel: () {},
      ),
    );
    await tester.tap(find.byKey(const ValueKey('edit3d-delete')));
    expect(deleted, 0);
    await tester.tap(find.byKey(const ValueKey('edit3d-undo')));
    expect(undone, 1);
    // Rehacer no está.
    final redo = tester.widget<IconButton>(
      find.byKey(const ValueKey('edit3d-redo')),
    );
    expect(redo.onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('edit3d-add')));
    await tester.pumpAndSettle();
    expect(find.text('Luces'), findsOneWidget);
    await tester.tap(find.text('Fresnel'));
    await tester.pumpAndSettle();
    expect(picked?.label, 'Fresnel');

    await pump(
      tester,
      Plan3dEditBar(
        editing: edit,
        hasSelection: true,
        placing: picked,
        onPick: (_) {},
        onCancel: () => picked = null,
      ),
    );
    expect(find.text('Toca el suelo donde va «Fresnel»'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('edit3d-delete')));
    expect(deleted, 1);
    await tester.tap(find.byKey(const ValueKey('edit3d-cancel')));
    expect(picked, isNull);
  });
}
