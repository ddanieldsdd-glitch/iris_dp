import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/export_center/export_options.dart';
import 'package:iris_dp/shared/pdf_export/pdf_page_count.dart';
import 'package:iris_dp/shared/pdf_export/shoot_day_material.dart';
import 'package:iris_dp/shared/pdf_export/shooting_plan_day_sheet.dart';
import 'package:iris_dp/shared/pdf_export/shooting_plan_pdf.dart';

PlanElement _light(String uid, String? model) => PlanElement(
  id: uid.hashCode,
  type: ElementType.light,
  position: Offset.zero,
  lightType: LightType.fresnelMedium,
  props: {'uid': uid, PlanElement.modelKey: ?model},
);

PlanElement _camera(String letter, {String? model}) => PlanElement(
  id: letter.hashCode,
  type: ElementType.camera,
  position: Offset.zero,
  cameraLetter: letter,
  props: {PlanElement.modelKey: ?model},
);

/// La lista de material de una jornada: lo que juega, cuánto y si está
/// reservado. Datos inventados.
void main() {
  final tubeA = [_light('a1', 'Tubo 15X'), _light('a2', 'Tubo 15X')];
  final shots = [
    MaterialShot(
      tag: '6/1',
      setKey: 1,
      setName: 'BARRA',
      lights: [...tubeA, _light('a3', 'Panel 60')],
      cameras: [_camera('A'), _camera('B')],
      lens: '35mm / 85 mm',
      movement: 'Steady',
      fps: 50,
    ),
    MaterialShot(
      tag: '6/2',
      setKey: 1,
      setName: 'BARRA',
      // El mismo tubo en otro plano del set no cuenta dos veces.
      lights: [tubeA.first, _light('a4', 'Tubo 15X')],
      cameras: [_camera('A')],
      lens: '35 MM',
      movement: 'Trípode',
      shutter: '90',
    ),
    MaterialShot(
      tag: '8/1',
      setKey: 2,
      setName: 'SALÓN',
      lights: [_light('b1', 'Tubo 15X'), _light('b2', null)],
      cameras: [_camera('A')],
      lens: '50mm',
      movement: 'steady',
    ),
  ];

  test('la luz cuenta lo máximo a la vez, set por set', () {
    final m = ShootDayMaterial.of(shots);
    final tube = m.lights.firstWhere((l) => l.name == 'Tubo 15X');
    expect(tube.quantity, 3);
    expect(tube.detail, 'BARRA 3 · SALÓN 1');
    expect(m.lights.map((l) => l.name), contains('Fresnel mediano'));
    expect(m.checked, isFalse);
    expect(tube.stock, MaterialStock.unchecked);
  });

  test('cámaras a la vez, ópticas, soportes y velocidades', () {
    final m = ShootDayMaterial.of(shots);
    expect(m.bodies.single.quantity, 2);
    expect(m.bodies.single.detail, 'A, B');
    expect([for (final l in m.lenses) l.name], ['35mm', '50mm', '85mm']);
    expect(m.lenses.first.detail, '6/1, 6/2');
    expect([for (final s in m.supports) s.name], ['STEADY', 'TRÍPODE']);
    expect(m.supports.first.detail, '6/1, 8/1');
    expect([for (final s in m.speeds) s.name], ['50 fps', 'Obturación 90°']);
  });

  test('con modelo de cámara, cuenta cuerpos por modelo', () {
    final m = ShootDayMaterial.of([
      MaterialShot(
        tag: '1/1',
        cameras: [
          _camera('A', model: 'Alexa Mini'),
          _camera('B', model: 'Alexa Mini'),
        ],
      ),
    ]);
    expect(m.bodies.single.name, 'Alexa Mini');
    expect(m.bodies.single.quantity, 2);
  });

  test('con reservas, marca lo reservado, lo corto y lo que falta', () {
    final m = ShootDayMaterial.of(
      shots,
      stock: [
        (name: 'NANLITE PAVO TUBO 15X II', quantity: 2),
        (name: 'Signature Prime 35MM T1.8', quantity: 1),
        (name: 'Panel 60 Kit', quantity: 1),
      ],
    );
    final byName = {
      for (final l in [...m.lights, ...m.lenses]) l.name: l,
    };
    expect(byName['Tubo 15X']!.stock, MaterialStock.short);
    expect(byName['Tubo 15X']!.reserved, 2);
    expect(byName['Panel 60']!.stock, MaterialStock.reserved);
    expect(byName['35mm']!.stock, MaterialStock.reserved);
    expect(byName['85mm']!.stock, MaterialStock.missing);
    // Un foco sin modelo no se busca.
    expect(byName['Fresnel mediano']!.stock, MaterialStock.unchecked);
    expect(m.missingCount, 3);
  });

  test('la hoja de material va al final, con su línea en el índice', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    ShootingPlanPdf.debugEntryPages = {};
    final day = ShootingPlanDay('Orden', [
      ShootingPlanEntry('ESCENA 6 (1)', [
        const ShootingPlanBlock(sceneLabel: '6', shotNumber: 1, slug: 'BAR'),
      ]),
    ], material: ShootDayMaterial.of(shots));
    final without = await ShootingPlanPdf.compose(
      projectName: 'Prueba',
      days: [day],
      indexParts: const {PlanIndexPart.order},
    );
    final withMaterial = await ShootingPlanPdf.compose(
      projectName: 'Prueba',
      days: [day],
      indexParts: const {PlanIndexPart.material},
    );
    expect(countPdfPages(withMaterial), countPdfPages(without) + 1);
    ShootingPlanPdf.debugEntryPages = null;
  });

  test('el material va por defecto en el índice', () {
    expect(
      const ExportOptions().planIndexParts,
      contains(PlanIndexPart.material),
    );
    expect(
      PlanIndexPart.summaryOf(PlanIndexPart.values.toSet()),
      isNot(contains(PlanIndexPart.material)),
    );
  });
}
