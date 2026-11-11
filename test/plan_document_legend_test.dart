import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_painter.dart';
import 'package:iris_dp/features/camera_plan/plan_thumbnail.dart';
import 'package:iris_dp/shared/pdf_export/shooting_plan_pdf.dart';

PlanElement _light(int id, Offset at, {String name = 'PavoTube 15X'}) =>
    PlanElement(
      id: id,
      type: ElementType.light,
      position: at,
      lightType: LightType.fresnelMedium,
      props: {'uid': 'L$id', 'intensity': 75},
    )..customName = name;

PlanElement _actor(int id, Offset at, List<Offset> path) => PlanElement(
  id: id,
  type: ElementType.actor,
  position: at,
  label: 'ALI',
  pathPoints: path,
  props: {'uid': 'A$id'},
);

/// La planta de rodaje se leía mal: el decorado salía diminuto y cada luz
/// llevaba su rótulo con una línea encima de la planta. Ahora la planta llena
/// su hueco, cada luz lleva un número y el texto va en la leyenda.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('leyenda de luces', () {
    test('las luces iguales comparten número y se cuentan', () {
      final legend = CameraPlanPainter.documentLightLegend([
        _light(1, const Offset(0, 0)),
        _light(2, const Offset(0, 300)),
        _light(3, const Offset(100, 100), name: 'amaran F22c'),
      ]);
      expect(legend, hasLength(2));
      expect(legend.first.number, 1);
      expect(legend.first.count, 2);
      expect(legend.first.label, endsWith('×2'));
      expect(legend.last.text, startsWith('amaran F22c'));
    });

    test('se numeran de arriba abajo y de izquierda a derecha', () {
      final legend = CameraPlanPainter.documentLightLegend([
        _light(1, const Offset(0, 500), name: 'C'),
        _light(2, const Offset(200, 0), name: 'B'),
        _light(3, const Offset(0, 0), name: 'A'),
      ]);
      expect(
        [for (final e in legend) e.text.split(' ').first],
        ['A', 'B', 'C'],
      );
    });

    test('lo que no es una luz no entra', () {
      final legend = CameraPlanPainter.documentLightLegend([
        _actor(9, Offset.zero, const []),
        _light(1, Offset.zero),
      ]);
      expect(legend, hasLength(1));
    });
  });

  group('encuadre de documento', () {
    // Un decorado estrecho y alto, como el kebab: 4 × 10 m.
    final elements = [
      _light(1, const Offset(0, 0)),
      _light(2, const Offset(200, 500)),
      _actor(3, const Offset(100, 250), const [Offset(120, 300)]),
    ];
    const size = Size(302, 241);

    test('en un documento la planta llena el alto de su hueco', () {
      final (:scale, :offset) = PlanThumbnail.frame(
        size,
        all: elements,
        focus: null,
        zones: const [],
        drawn: null,
        maxScale: PlanThumbnail.documentMaxScale,
      );
      final top = offset.dy + 0 * scale;
      final bottom = offset.dy + 500 * scale;
      expect((bottom - top) / size.height, greaterThan(0.8));
    });

    test('en pantalla no se acerca más que su tamaño', () {
      final (:scale, offset: _) = PlanThumbnail.frame(
        const Size(3000, 3000),
        all: elements,
        focus: null,
        zones: const [],
        drawn: null,
      );
      expect(scale, 1.0);
    });

    test('la planta numerada se pinta', () async {
      final png = await PlanThumbnail.renderPng(
        elements: elements,
        size: size,
        documentMarks: true,
        documentLightNumbers: true,
      );
      expect(png, isNotNull);
    });
  });

  test('la leyenda llega al PDF de la planta', () async {
    final plan = Uint8List.fromList(
      img.encodeJpg(
        img.Image(width: 30, height: 24)..clear(img.ColorRgb8(0, 0, 0)),
      ),
    );
    final bytes = await ShootingPlanPdf.compose(
      projectName: 'Prueba',
      days: [
        ShootingPlanDay('Orden', [
          ShootingPlanEntry('ESCENA 6 (1)', [
            ShootingPlanBlock(
              sceneLabel: '6',
              shotNumber: 1,
              slug: 'INT KEBAB NOCHE',
              lens: '24mm',
              support: 'SEGUIMIENTO',
              angle: 'Normal',
              stop: '2.1',
              plan: plan,
              legend: const [
                ShootingPlanLegendLine(1, 'Nanlite PavoTube II 15X · 3300K'),
                ShootingPlanLegendLine(2, 'Práctica · 2800K · 75% ×6'),
              ],
            ),
          ]),
        ]),
      ],
    );
    expect(bytes, isNotEmpty);
    expect(latin1.decode(bytes), contains('/Subtype'));
  });
}
