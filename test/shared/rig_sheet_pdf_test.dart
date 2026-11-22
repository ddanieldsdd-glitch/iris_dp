import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_hall.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_rig.dart';
import 'package:iris_dp/shared/pdf_export/rig_sheet_pdf.dart';
import 'package:iris_dp/shared/pdf_export/rig_symbols.dart';

const mpu = 0.02; // 50 unidades por metro.

/// Una caseta de feria inventada: nave de 16 × 10 m con su rejilla de
/// truss, paneles colgados, recortes, dos HMI en pie, tubos y un marco.
List<PlanElement> caseta() {
  final hall = PlanHall.create(
    Offset.zero,
    HallRecipe.rectangle(width: 16, depth: 10),
  );
  final elements = <PlanElement>[hall, ...PlanHall.build(hall, mpu)];
  final trusses = elements.where(PlanTruss.isTruss).toList();
  var id = 1000;
  PlanElement light(
    String name,
    LightType type,
    double watts,
    Offset at, {
    double rotation = 0,
    Map<String, dynamic> props = const {},
  }) => PlanElement(
    id: ++id,
    type: ElementType.light,
    position: at,
    rotation: rotation,
    lightType: type,
    props: {'name': name, 'watts': watts, 'intensity': 100, ...props},
  );

  for (final (i, truss) in trusses.take(3).indexed) {
    for (final t in [0.2, 0.4, 0.6, 0.8]) {
      final l = light(
        i == 1 ? 'Recorte 750' : 'Panel LED 8',
        i == 1 ? LightType.ellipsoidal : LightType.lightPanel,
        i == 1 ? 750 : 650,
        PlanTruss.pointAt(truss, t),
        rotation: 180,
      );
      TrussMagnet.snap(l, elements, mpu);
      elements.add(l);
    }
  }
  final centre = trusses
      .map((t) => PlanTruss.pointAt(t, .5))
      .reduce((a, b) => a + b)
      .scale(1 / trusses.length, 1 / trusses.length);
  elements.addAll([
    light(
      'HMI 18K',
      LightType.hmi,
      18000,
      centre + const Offset(-450, 0),
      rotation: 90,
      props: {PlanLight.heightKey: 4.0, PlanLight.tiltKey: 15},
    ),
    light(
      'HMI 18K',
      LightType.hmi,
      18000,
      centre + const Offset(450, 0),
      rotation: 270,
      props: {PlanLight.heightKey: 4.0, PlanLight.tiltKey: 15},
    ),
    for (final dx in [-100.0, 0.0, 100.0])
      light(
        'Tubo 4 pies',
        LightType.floSingle,
        72,
        centre + Offset(dx, 200),
        props: {PlanLight.heightKey: 1.6},
      ),
    PlanElement(
      id: ++id,
      type: ElementType.light,
      position: centre + const Offset(0, -200),
      lightType: LightType.diffusionFrame,
      props: {PlanElement.nameKey: '20×20 Ultrabounce'},
    ),
    PlanElement(
      id: ++id,
      type: ElementType.prop,
      position: centre,
      label: PropType.table.dbValue,
    ),
  ]);
  return elements;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  test('cada familia tiene su dibujo, de lado y de frente', () {
    for (final type in LightType.values) {
      final family = RigSymbols.familyOf(type);
      final size = RigSymbols.sizeOf(type);
      for (final view in RigView.values) {
        final outline = RigSymbols.outline(family, size, view: view);
        expect(outline, isNotEmpty, reason: '$type $view');
        expect(
          outline.every((o) => o.points.length >= 2),
          isTrue,
          reason: '$type $view',
        );
      }
    }
    expect(RigSymbols.familyOf(LightType.ellipsoidal), RigFamily.profile);
    expect(RigSymbols.familyOf(LightType.lightPanel), RigFamily.panel);
    // Un 18K se dibuja más grande que un fresnel pequeño.
    expect(
      RigSymbols.sizeOf(LightType.hmi).width,
      greaterThan(RigSymbols.sizeOf(LightType.fresnelSmall).width),
    );
  });

  test('cada modelo tiene su color, distinto de los demás', () {
    final colors = {for (var i = 0; i < 12; i++) RigSymbols.colorAt(i).$1};
    expect(colors, hasLength(12));
  });

  test('planta en una hoja y alzados en otra; o todo en una', () async {
    final elements = caseta();
    expect(RigSheetPdf.pageCount(elements, metersPerUnit: mpu), 2);
    expect(
      RigSheetPdf.pageCount(
        elements,
        metersPerUnit: mpu,
        options: const RigSheetOptions(layout: RigSheetLayout.compact),
      ),
      1,
    );
    final info = RigSheetInfo(
      project: 'Caseta de prueba',
      set: 'Caseta',
      scheme: 'Noche',
      scenes: '12, 13A',
      shootDay: 'Jornada 3',
      gaffer: 'Gaffer de prueba',
      date: DateTime(2026, 11, 22),
    );
    for (final options in const [
      RigSheetOptions(),
      RigSheetOptions(layout: RigSheetLayout.compact),
      RigSheetOptions(paper: RigSheetPaper.a4, numbers: RigSheetNumbers.none),
    ]) {
      final bytes = await RigSheetPdf.build(
        elements,
        metersPerUnit: mpu,
        info: info,
        options: options,
      );
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
      // Para mirarla: IRIS_RIG_SHEET_OUT=/ruta/carpeta flutter test …
      final out = Platform.environment['IRIS_RIG_SHEET_OUT'];
      if (out != null) {
        File(
          '$out/hoja_${options.layout.name}_${options.paper.name}.pdf',
        ).writeAsBytesSync(bytes);
      }
    }
  });

  test('con muchos modelos, la leyenda sigue en su propia hoja', () {
    final elements = <PlanElement>[
      for (var i = 0; i < 25; i++)
        PlanElement(
          id: i + 1,
          type: ElementType.light,
          position: Offset(i * 50.0, 0),
          lightType: LightType.fresnelMedium,
          props: {'name': 'Modelo $i', 'watts': 650, 'intensity': 100},
        ),
    ];
    expect(RigSheetPdf.pageCount(elements, metersPerUnit: mpu), 3);
  });
}
