import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/plan_marks.dart';
import 'package:iris_dp/features/camera_plan/plan_renderer.dart';
import 'package:iris_dp/features/export_center/export_options.dart';
import 'package:iris_dp/shared/pdf_export/shooting_plan_pdf.dart';

PlanElement _actor(int id, List<Offset> stops, {List<double?>? rot}) =>
    PlanElement(
      id: id,
      type: ElementType.actor,
      position: stops.first,
      label: 'A$id',
      pathPoints: stops.skip(1).toList(),
      props: {'uid': 'A$id', if (rot != null) PlanMarks.rotKey: rot},
    );

/// Las viñetas por tramo: cada una enseña un solo movimiento.
void main() {
  test('pocos tramos no llevan viñetas; muchos, sí', () {
    final calm = PlanPicture(
      elements: [
        _actor(1, const [Offset(0, 0), Offset(100, 0)]),
      ],
    );
    expect(PlanRenderer.wantsSteps(calm), isFalse);
    final busy = PlanPicture(
      elements: [
        _actor(1, const [Offset(0, 0), Offset(100, 0), Offset(100, 100)]),
        _actor(2, const [Offset(0, 50), Offset(80, 50), Offset(80, 150)]),
      ],
    );
    expect(PlanRenderer.stepCount(busy), 2);
    expect(PlanRenderer.wantsSteps(busy), isTrue);
    final long = PlanPicture(
      elements: [
        _actor(1, const [
          Offset(0, 0),
          Offset(100, 0),
          Offset(100, 100),
          Offset(0, 100),
        ]),
      ],
    );
    expect(PlanRenderer.wantsSteps(long), isTrue);
  });

  test('el tramo k va de la marca k+1 a la k+2, con su giro', () {
    final actor = _actor(
      1,
      const [Offset(0, 0), Offset(100, 0), Offset(100, 100)],
      rot: [90, 180],
    );
    final picture = PlanPicture(elements: [actor]);
    final second = PlanRenderer.stepOf(picture, 1).elements.single;
    expect(second.position, const Offset(100, 0));
    expect(second.rotation, 90);
    expect(second.pathPoints, [const Offset(100, 100)]);
    expect(second.props[PlanMarks.rotKey], [180]);
    expect(second.props[PlanMarks.fromKey], 1);
    // El original no se toca.
    expect(actor.pathPoints, hasLength(2));
    expect(actor.position, Offset.zero);
  });

  test('quien ya acabó su recorrido se queda quieto en su última marca', () {
    final picture = PlanPicture(
      elements: [
        _actor(1, const [Offset(0, 0), Offset(100, 0)]),
        _actor(2, const [Offset(0, 50), Offset(50, 50), Offset(50, 90)]),
      ],
    );
    final step = PlanRenderer.stepOf(picture, 1).elements;
    expect(step[0].position, const Offset(100, 0));
    expect(step[0].pathPoints, isEmpty);
    expect(step[1].position, const Offset(50, 50));
    expect(step[1].pathPoints, [const Offset(50, 90)]);
  });

  test('todas las viñetas se encuadran igual', () {
    final rect = PlanRenderer.actionOf(
      PlanPicture(
        elements: [
          _actor(1, const [Offset(0, 0), Offset(300, 0)]),
        ],
      ),
    )!;
    expect(rect.left, lessThan(0));
    expect(rect.right, greaterThan(300));
  });

  test('las viñetas van en la página del plano', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Uint8List tile(int shade) => Uint8List.fromList(
      img.encodeJpg(
        img.Image(width: 16, height: 11)
          ..clear(img.ColorRgb8(shade, shade, shade)),
      ),
    );
    final bytes = await ShootingPlanPdf.compose(
      projectName: 'Prueba',
      days: [
        ShootingPlanDay('Orden', [
          ShootingPlanEntry('ESCENA 1 (1)', [
            ShootingPlanBlock(
              sceneLabel: '1',
              shotNumber: 1,
              slug: 'CALLE',
              fullPage: true,
              steps: [for (var i = 0; i < 7; i++) tile(20 + i * 30)],
            ),
          ]),
        ]),
      ],
    );
    final raw = latin1.decode(bytes);
    expect(RegExp(r'/Subtype\s*/Image').allMatches(raw).length, 7);
  });

  test('la opción de viñetas se recuerda', () {
    const off = ExportOptions(planSteps: false);
    expect(ExportOptions.fromJson(off.toJson()).planSteps, isFalse);
    expect(const ExportOptions().planSteps, isTrue);
  });
}
