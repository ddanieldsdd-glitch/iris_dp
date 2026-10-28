import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iris_dp/core/sync/unreal_thumb_store.dart';
import 'package:iris_dp/core/theme/app_colors.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';
import 'package:iris_dp/features/unreal_link/unreal_link.dart';

PlanElement _sofaWithThumbs() {
  final sofa = PlanElement(
    id: 1,
    type: ElementType.prop,
    position: const Offset(200, 200),
    rotation: 30,
    label: PropType.sofa.dbValue,
  );
  const path = '/Game/Fab/Sofa/SM_Sofa.SM_Sofa';
  UnrealAssetRef.set(
    sofa,
    UnrealAssetRef.fromPath(path, sizeCm: [200, 90, 85]).copyWith(
      thumbTop: UnrealThumbStore.keyFor(path, UnrealThumbView.top),
      thumb34: UnrealThumbStore.keyFor(path, UnrealThumbView.threeQuarter),
      topSpanCm: 216,
    ),
  );
  return sofa;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('las claves y el ancho de la cenital se guardan con el asset', () {
    final sofa = _sofaWithThumbs();
    final ref = UnrealAssetRef.of(sofa)!;
    expect(ref.thumbTop, endsWith('_top'));
    expect(ref.thumb34, endsWith('_34'));
    expect(ref.topSpanCm, 216);
    expect(UnrealThumbStore.isKey(ref.thumbTop!), isTrue);
  });

  test('el 3D recibe la miniatura 3/4 del atrezzo', () {
    final sofa = _sofaWithThumbs();
    LightOverrides.ensureUids([sofa]);
    final scene = PlanScene3d.build([sofa], metersPerUnit: 0.01);
    expect(scene['props'][0]['thumb'], UnrealAssetRef.of(sofa)!.thumb34);
  });

  testWidgets('la vista de assets dibuja la cenital y quita el símbolo', (
    tester,
  ) async {
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawRect(
      const Rect.fromLTWH(0, 0, 8, 8),
      Paint()..color = const Color(0xFF4FB3A9),
    );
    final image = await tester.runAsync(
      () => recorder.endRecording().toImage(8, 8),
    );
    final asked = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: CustomPaint(
          size: const Size(600, 400),
          painter: CameraPlanPainter(
            elements: [_sofaWithThumbs()],
            palette: AppPalette.dark,
            metersPerUnit: 0.01,
            assetView: true,
            thumbOf: (key) {
              asked.add(key);
              return image;
            },
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(asked, contains(endsWith('_top')));
  });
}
