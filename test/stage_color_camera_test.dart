import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/light_beam.dart';
import 'package:iris_dp/features/camera_plan/plan_cad_export.dart';
import 'package:iris_dp/features/unreal_link/unreal_stage_payload.dart';

void main() {
  group('RGB (UN.1)', () {
    Map<String, dynamic> fixture({int? rgb}) => {
      'id': 'L',
      'name': 'Foco',
      'pos': [0, 0, 3],
      'aim': [1, 0, 0],
      'on': true,
      'rgb': ?rgb,
      'source': {'cd': 100, 'beamDeg': 40, 'cct': 5600, 'sizeM': 0.1},
    };

    test('el color de un aparato RGB llega a Unreal', () {
      expect(UnrealStagePayload.light(fixture(rgb: 0xFF0040))!['rgb'], 0xFF0040);
      expect(UnrealStagePayload.light(fixture())!.containsKey('rgb'), isFalse);
    });

    test('la luz rebotada de un RGB también lleva su color', () {
      final soft = UnrealStagePayload.softLight({
        'id': 'S',
        'pos': [0, 0, 1],
        'dir': [1, 0, 0],
        'rgb': 0x00FF00,
      });
      expect(soft!['rgb'], 0x00FF00);
    });

    test('el MVR da el color en CIE xyY', () {
      final red = PlanCadExport.cieOfRgb(0xFF0000).split(',');
      expect(double.parse(red[0]), closeTo(0.64, 0.001));
      expect(double.parse(red[1]), closeTo(0.33, 0.001));
      expect(double.parse(red[2]), closeTo(21.27, 0.01));
      final white = PlanCadExport.cieOfRgb(0xFFFFFF).split(',');
      expect(double.parse(white[0]), closeTo(0.3127, 0.001));
      expect(double.parse(white[1]), closeTo(0.329, 0.001));
      expect(PlanCadExport.cieOfRgb(0).split(',').last, '0.000000');
    });
  });

  group('cámara (UN.2)', () {
    Map<String, dynamic> cam(Map<String, dynamic> extra) => {
      'id': 'C',
      'name': 'A',
      'at': [0, 0],
      'dir': [0, 1],
      'z': 1.5,
      ...extra,
    };

    double hfov(double frameMm, double focal) =>
        2 * math.atan(frameMm / (2 * focal)) * 180 / math.pi;

    test('manda el alto real del sensor', () {
      final sent = UnrealStagePayload.camera(
        cam({
          'sensorMm': 28.25,
          'sensorHeightMm': 18.17,
          'hfovDeg': hfov(28.25, 35),
        }),
      )!;
      expect(sent['sensorMm'], closeTo(28.3, 0.11));
      expect(sent['sensorHeightMm'], closeTo(18.2, 0.04));
    });

    test('sin el dato no inventa el alto', () {
      final sent = UnrealStagePayload.camera(cam({'hfovDeg': 40}))!;
      expect(sent.containsKey('sensorHeightMm'), isFalse);
    });

    test('anamórfica: encuadre desprimido y la focal de la lente', () {
      final frame = cameraFrameWidthMm({
        'sensorWidthMm': 24.89,
        kLensSqueezeKey: 2.0,
      });
      expect(frame, closeTo(49.78, 0.01));
      final sent = UnrealStagePayload.camera(
        cam({
          'sensorMm': 24.89,
          'sensorHeightMm': 18.66,
          'squeeze': 2.0,
          'hfovDeg': hfov(frame, 50),
        }),
      )!;
      expect(sent['sensorMm'], closeTo(49.8, 0.05));
      expect(sent['sensorHeightMm'], closeTo(18.7, 0.05));
      expect(sent['focalMm'], closeTo(50, 0.1));
    });

    test('sin lente anamórfica no cambia nada', () {
      expect(cameraFrameWidthMm({'sensorWidthMm': 36.0}), 36);
      expect(cameraFrameWidthMm({}), 24.89);
    });
  });

  group('actores (UN.2)', () {
    Map<String, dynamic> person(String pose, double h) => {
      'id': 'A',
      'name': 'Ana',
      'at': [1, 2],
      'z0': 0,
      'yawDeg': 90,
      'pose': pose,
      'heightM': h,
    };

    test('van a Unreal como bloque, a su altura y mirando donde miran', () {
      final standing = UnrealStagePayload.actor(person('stand', 1.75))!;
      expect((standing['sizeCm'] as List)[2], 175);
      expect(standing['type'], 'actor');
      expect(
        standing['rot'],
        UnrealStagePayload.rotToward(1, math.cos(math.pi / 2), 0),
      );
      expect((UnrealStagePayload.actor(person('sit', 1.3))!['sizeCm'] as List)[2], 130);
    });

    test('tumbado, el bloque va a lo largo', () {
      final lying = UnrealStagePayload.actor(person('lie', 0.35))!;
      expect(lying['sizeCm'], [175.0, 50.0, 35.0]);
    });

    test('con modelo de Unreal no se duplica', () {
      final built = UnrealStagePayload.build({
        'people': [person('stand', 1.75)],
        'assets': [
          {
            'id': 'A',
            'at': [1, 2],
            'asset': {'path': '/Game/Ana'},
          },
        ],
      });
      expect(built['props'], isEmpty);
      expect((built['assets'] as List).single['id'], 'A');
    });

    test('al ganar modelo no se borra de Unreal', () {
      final before = UnrealStagePayload.build({
        'people': [person('stand', 1.75)],
      });
      final now = UnrealStagePayload.build({
        'people': [person('stand', 1.75)],
        'assets': [
          {
            'id': 'A',
            'at': [1, 2],
            'asset': {'path': '/Game/Ana'},
          },
        ],
      });
      final diff = UnrealStagePayload.diff(before, now)!;
      expect(diff['remove'], isNull);
      expect((diff['assets'] as List).single['id'], 'A');
    });

    test('al quitarlo de la planta sí se borra', () {
      final before = UnrealStagePayload.build({
        'people': [person('stand', 1.75)],
      });
      final diff = UnrealStagePayload.diff(before, UnrealStagePayload.build({}))!;
      expect(diff['remove'], ['A']);
    });
  });
}
