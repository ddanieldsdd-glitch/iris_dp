import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/database/app_database.dart';
import 'package:iris_dp/core/database/database_provider.dart';
import 'package:iris_dp/core/theme/app_colors.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_editor.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';

void main() {
  group('la vista del lienzo', () {
    testWidgets('el zoom avisa al empezar y al parar', (tester) async {
      final view = PlanCanvasView();
      addTearDown(view.dispose);
      var notices = 0;
      view.addListener(() => notices++);

      view.zoomTo(2, const Offset(10, 20));
      expect(view.scale, 2);
      expect(view.offset, const Offset(10, 20));
      expect(view.zooming, isTrue);
      expect(notices, 1);

      await tester.pump(PlanCanvasView.zoomSettle);
      expect(view.zooming, isFalse);
      expect(notices, 2);
    });

    test('mover a donde ya está no repinta', () {
      final view = PlanCanvasView();
      addTearDown(view.dispose);
      var notices = 0;
      view.addListener(() => notices++);
      view.offset = Offset.zero;
      view.scale = 1;
      expect(notices, 0);
    });
  });

  group('lo guardado se ve igual que lo pintado', () {
    Future<Uint8List> render(CameraPlanPainter painter) async {
      const size = Size(400, 300);
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), size);
      // Un segundo pintado reutiliza lo guardado, si lo hay.
      final again = ui.PictureRecorder();
      painter.paint(Canvas(again), size);
      recorder.endRecording().dispose();
      final image = await again.endRecording().toImage(400, 300);
      final bytes = await image.toByteData();
      image.dispose();
      return bytes!.buffer.asUint8List();
    }

    testWidgets('con planta, zonas y selección', (tester) async {
      final elements = [
        PlanElement(
          id: 1,
          type: ElementType.camera,
          position: const Offset(80, 60),
        ),
        PlanElement(
          id: 2,
          type: ElementType.actor,
          position: const Offset(160, 120),
          rotation: 30,
          label: 'Ana',
        ),
        PlanElement(
          id: 3,
          type: ElementType.light,
          position: const Offset(240, 90),
        ),
      ];
      final inherited = [
        PlanElement(
          id: 4,
          type: ElementType.prop,
          position: const Offset(120, 180),
          label: 'Mesa',
        ),
      ];
      const zones = [
        PlanZone(
          rect: Rect.fromLTWH(40, 40, 220, 160),
          color: Color(0xFF26C6DA),
          label: 'Salón',
          active: true,
        ),
      ];
      final view = PlanCanvasView()
        ..offset = const Offset(12, 8)
        ..scale = 1.25;
      addTearDown(view.dispose);

      CameraPlanPainter painter({PlanCanvasView? live}) => CameraPlanPainter(
        elements: elements,
        inheritedElements: inherited,
        zones: zones,
        palette: AppPalette.dark,
        selectedElement: elements[1],
        showNames: true,
        view: live,
        offset: const Offset(12, 8),
        scale: 1.25,
      );

      await tester.runAsync(() async {
        final kept = await render(painter(live: view));
        final direct = await render(painter());
        expect(kept, direct);
      });
    });
  });

  testWidgets('mover la vista no reconstruye el editor', (tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    late int projectId, shotId;
    await tester.runAsync(() async {
      projectId = await db.insertProject(ProjectsCompanion.insert(name: 'P'));
      final scene = await db.insertScene(
        ScenesCompanion.insert(
          projectId: projectId,
          number: 1,
          name: 'E',
          locationCanonical: 'Casa',
          locationPureName: 'Casa',
        ),
      );
      shotId = await db.insertShot(
        ShotsCompanion.insert(
          sceneId: scene,
          projectId: projectId,
          number: 1,
          framing: const Value('PM'),
        ),
      );
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AppTheme.dark,
          home: CameraPlanEditor.shot(
            projectId: projectId,
            shotId: shotId,
            shotLabel: 'Esc 1 · Plano 1',
          ),
        ),
      ),
    );
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final canvas = find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is CameraPlanPainter,
    );
    CameraPlanPainter painter() =>
        tester.widget<CustomPaint>(canvas).painter! as CameraPlanPainter;
    final before = painter();
    final start = before.offset;

    final mouse = await tester.startGesture(
      tester.getCenter(canvas),
      kind: PointerDeviceKind.mouse,
      buttons: kMiddleMouseButton,
    );
    await tester.pump();
    await mouse.moveBy(const Offset(40, 30));
    await tester.pump();
    await mouse.up();
    await tester.pump();

    expect(painter().offset, start + const Offset(40, 30));
    expect(identical(painter(), before), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
