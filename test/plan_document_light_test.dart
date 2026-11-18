import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/light_beam.dart';
import 'package:iris_dp/features/camera_plan/plan_document_light.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/plan_thumbnail.dart';

/// P.4: en la planta de luz del PDF cada foco lleva su haz contorneado, con
/// su apertura y su dirección, en vez de la mancha de luz de la pantalla.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const mpu = defaultMetersPerUnit;

  PlanElement light(
    LightType type, {
    Offset at = const Offset(100, 100),
    double rotation = 90,
    Map<String, dynamic> props = const {},
  }) => PlanElement(
    id: 1,
    type: ElementType.light,
    position: at,
    lightType: type,
    rotation: rotation,
    props: {'intensity': 80, ...props},
  );

  SceneLight sceneOf(PlanElement el) =>
      LightScene.from([el], metersPerUnit: mpu).lights.single;

  test('un fresnel es un cono con su apertura y hacia donde apunta', () {
    final el = light(
      LightType.fresnelMedium,
      props: {LightBeam.spreadKey: 30.0},
    );
    final shape = DocumentLightShape.of(sceneOf(el), metersPerUnit: mpu)!;
    expect(shape.kind, DocumentLightKind.cone);
    // Rotación 90° = hacia la derecha de la planta.
    expect(shape.aim.dx, closeTo(1, 1e-6));
    expect(shape.aim.dy, closeTo(0, 1e-6));
    expect(shape.halfAngle, closeTo(15 * math.pi / 180, 1e-6));
    // Sin nadie delante, con tope.
    expect(
      shape.length * mpu,
      inInclusiveRange(
        DocumentLightShape.minLengthM,
        DocumentLightShape.maxLengthM,
      ),
    );
    // El contorno cubre el eje y no lo de detrás.
    final path = shape.path;
    expect(path.contains(const Offset(150, 100)), isTrue);
    expect(path.contains(const Offset(60, 100)), isFalse);
  });

  test('el cono llega hasta el actor al que alumbra, aunque esté lejos', () {
    final el = light(LightType.fresnelMedium);
    final scene = sceneOf(el);
    // Un actor a 8 m, en el eje, y otro fuera del haz.
    const far = Offset(100 + 8 / mpu, 100);
    const aside = Offset(100, 100 + 3 / mpu);
    final shape = DocumentLightShape.of(
      scene,
      metersPerUnit: mpu,
      targets: const [far, aside],
    )!;
    expect(
      shape.length * mpu,
      closeTo(8 + DocumentLightShape.pastTargetM, 1e-6),
    );
  });

  test('un tubo a 360° es un anillo, sin dirección', () {
    final el = light(
      LightType.floSingle,
      props: {LightBeam.spreadKey: 360.0},
    );
    final shape = DocumentLightShape.of(sceneOf(el), metersPerUnit: mpu)!;
    expect(shape.kind, DocumentLightKind.ring);
    expect(shape.center, el.position);
    expect(
      shape.length * mpu,
      inInclusiveRange(DocumentLightShape.minRingM, DocumentLightShape.maxRingM),
    );
  });

  test('una luz de techo deja su huella en el suelo', () {
    final el = light(
      LightType.practical,
      props: {
        PlanLight.mountKey: PlanLight.mountCeiling,
        PlanLight.heightKey: 2.6,
      },
    );
    final shape = DocumentLightShape.of(sceneOf(el), metersPerUnit: mpu)!;
    expect(shape.kind, DocumentLightKind.footprint);
    expect(shape.length, greaterThan(0));
  });

  test('apagada no lleva haz', () {
    final el = light(
      LightType.fresnelMedium,
      props: {LightBeam.offKey: true},
    );
    final lights = LightScene.from([el], metersPerUnit: mpu).lights;
    final shapes = [
      for (final l in lights) DocumentLightShape.of(l, metersPerUnit: mpu),
    ].nonNulls;
    expect(shapes, isEmpty);
  });

  test('la tinta es el color de la luz: tungsteno cálido, día frío', () {
    final warm = documentLightInk(LightBeam.of(
      light(LightType.fresnelMedium, props: {LightBeam.cctKey: 3200.0}),
    )!);
    final cool = documentLightInk(LightBeam.of(
      light(LightType.fresnelMedium, props: {LightBeam.cctKey: 6500.0}),
    )!);
    expect(warm.r, greaterThan(warm.b));
    expect(cool.b, greaterThan(warm.b));
    // Un RGB oscuro se aclara para verse sobre el negro de la planta.
    final blue = documentLightInk(LightBeam.of(
      light(LightType.lightPanel, props: {LightBeam.rgbKey: 0x000080}),
    )!);
    expect(blue.computeLuminance(), greaterThan(0.1));
    expect(blue.b, greaterThan(blue.r));
  });

  test('el nombre corto lleva el número de la leyenda', () {
    expect(documentLightTag(1, 'Tubo 15X'), '1 · Tubo 15X');
  });

  test('la planta de luz encuadra la sala con los focos dentro', () {
    PlanElement wall(Offset a, Offset b) =>
        PlanSegment.create(start: a, end: b);
    final camera = PlanElement(
      id: 2,
      type: ElementType.camera,
      position: const Offset(500, 500),
      cameraLetter: 'A',
    );
    final far = light(LightType.fresnelMedium, at: const Offset(1200, 500));
    final all = [
      camera,
      far,
      wall(const Offset(300, 380), const Offset(1400, 380)),
    ];
    final stage = PlanThumbnail.stageView(all: all)!;
    expect(stage.contains(far.position), isFalse);
    final lit = PlanThumbnail.stageView(all: all, lights: true)!;
    expect(lit.contains(far.position), isTrue);
    expect(lit.top, lessThanOrEqualTo(380));
  });

  test('la planta de luz con haces, nombres al margen y figuras se pinta',
      () async {
    final elements = [
      light(LightType.fresnelMedium, at: const Offset(20, 20), rotation: 135)
        ..customName = 'Fresnel 650',
      light(
        LightType.floSingle,
        at: const Offset(300, 20),
        props: {LightBeam.spreadKey: 360.0},
      )..customName = 'Tubo 15X',
      PlanElement(
        id: 3,
        type: ElementType.actor,
        position: const Offset(150, 150),
        label: 'ALI',
      ),
      PlanElement(
        id: 4,
        type: ElementType.camera,
        position: const Offset(150, 260),
        cameraLetter: 'A',
      ),
    ];
    const size = Size(220, 220);
    final png = await PlanThumbnail.renderPng(
      elements: elements,
      size: size,
      documentMarks: true,
      documentLightNumbers: true,
      documentLightOnly: true,
      documentGutter: 40,
    );
    expect(png, isNotNull);
  });
}
