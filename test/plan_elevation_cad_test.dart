import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/plan_light.dart';
import 'package:iris_dp/features/camera_plan/plan_cad_export.dart';
import 'package:iris_dp/features/camera_plan/plan_elevation.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';

void main() {
  // 50 unidades por metro.
  const mpu = 0.02;
  var id = 0;
  // Pared de 8 m de oeste a este en y = 0, con una ventana a 2 m.
  final wall = PlanSegment.create(
    start: Offset.zero,
    end: const Offset(400, 0),
  );
  final window = PlanElement(
    id: ++id,
    type: ElementType.wall,
    position: const Offset(100, 0),
    label: ArchitectureType.window.dbValue,
  );
  final m18 = PlanElement(
    id: ++id,
    type: ElementType.light,
    position: const Offset(300, 200),
    rotation: 270, // apunta al oeste
    lightType: LightType.hmi,
    props: {'name': 'ARRI M18', 'watts': 1800, 'intensity': 100, 'spread': 40},
  );
  final topLight = PlanElement(
    id: ++id,
    type: ElementType.light,
    position: const Offset(200, 150),
    lightType: LightType.lightPanel,
    props: {
      'name': 'SkyPanel S60-C',
      'watts': 475,
      'intensity': 100,
      PlanLight.mountKey: PlanLight.mountCeiling,
      PlanLight.heightKey: 3.2,
    },
  );
  final ana = PlanElement(
    id: ++id,
    type: ElementType.actor,
    position: const Offset(150, 200),
    label: 'Ána',
  );
  final cam = PlanElement(
    id: ++id,
    type: ElementType.camera,
    position: const Offset(150, 350),
  );
  final plan = [wall, window, m18, topLight, ana, cam];

  group('alzado y perfil', () {
    test('en el alzado cada pieza cae a su ancho y a su altura', () {
      final e = PlanElevation.of(
        plan,
        metersPerUnit: mpu,
        side: ElevationSide.front,
      );
      ElevationItem of(ElevationKind k) =>
          e.items.firstWhere((i) => i.kind == k);
      final w = of(ElevationKind.wall);
      expect(w.from, closeTo(0, 0.01));
      expect(w.to, closeTo(8, 0.05));
      expect(w.top, 2.5);
      final win = of(ElevationKind.opening);
      expect(win.bottom, 0.9);
      expect(win.top, 2.1);
      expect(win.centre, closeTo(2, 0.05));
      final person = of(ElevationKind.actor);
      expect(person.top, PlanElevation.personM);
      // La de techo cuelga a 3,2 m y mira abajo; la M18, en pie a 2 m,
      // apunta a la izquierda (el oeste).
      final lights = e.items.where((i) => i.kind == ElevationKind.light);
      final hung = lights.firstWhere((i) => i.element == topLight);
      expect((hung.top + hung.bottom) / 2, closeTo(3.2, 1e-9));
      expect(hung.aim, closeTo(-1.5708, 1e-3));
      final stand = lights.firstWhere((i) => i.element == m18);
      expect((stand.top + stand.bottom) / 2, closeTo(2, 1e-9));
      expect(stand.aim, closeTo(3.1416, 1e-3));
      // La pared, al fondo, se pinta antes que la cámara, delante.
      expect(
        e.items.indexOf(w),
        lessThan(e.items.indexWhere((i) => i.kind == ElevationKind.camera)),
      );
    });

    test('de perfil, la M18 que mira al oeste apunta hacia el que mira', () {
      final e = PlanElevation.of(
        plan,
        metersPerUnit: mpu,
        side: ElevationSide.side,
      );
      final stand = e.items.firstWhere((i) => i.element == m18);
      expect(stand.aim, isNull);
      // La pared, vista de canto, es estrecha.
      final w = e.items.firstWhere((i) => i.kind == ElevationKind.wall);
      expect(w.to - w.from, lessThan(0.1));
    });
  });

  group('DXF', () {
    test('la planta en metros, con el norte arriba y sus capas', () {
      final dxf = PlanCadExport.planDxf(plan, mpu);
      expect(dxf, startsWith('0\nSECTION\n2\nHEADER'));
      expect(dxf, endsWith('0\nEOF\n'));
      for (final layer in ['MUROS', 'HUECOS', 'LUCES', 'HACES', 'CAMARAS']) {
        expect(dxf, contains('2\n$layer\n'));
      }
      // La pared: de (0, 0) a (8, 0) en la capa MUROS.
      expect(
        dxf,
        contains(
          'LINE\n8\nMUROS\n10\n0.0000\n20\n0.0000\n30\n0.0000\n'
          '11\n8.0000\n21\n0.0000',
        ),
      );
      // La M18, 4 m al sur de la pared: y = -4.
      expect(dxf, contains('CIRCLE\n8\nLUCES\n10\n6.0000\n20\n-4.0000'));
      // Rótulo con su unidad y sin acentos.
      expect(dxf, contains('U1 - ARRI M18 - 1,8 kW - 5600K'));
      expect(dxf, contains('1\nAna\n'));
      // Cada código va solo en su línea: pares código / valor.
      final lines = dxf.trimRight().split('\n');
      expect(lines.length.isEven, isTrue);
    });

    test('el alzado en DXF: ancho en X, altura en Y', () {
      final dxf = PlanCadExport.elevationDxf(
        PlanElevation.of(plan, metersPerUnit: mpu, side: ElevationSide.front),
      );
      // El hueco de la ventana, de 0,9 a 2,1 m.
      expect(dxf, contains('20\n0.9000'));
      expect(dxf, contains('20\n2.1000'));
      expect(dxf, contains('2\nHACES\n'));
    });
  });

  group('MVR', () {
    final mvr = PlanCadExport.planMvr(plan, mpu, layerName: 'Casa');
    final archive = ZipDecoder().decodeBytes(mvr);
    final file = archive.findFile('GeneralSceneDescription.xml')!;
    final doc = XmlDocument.parse(utf8.decode(file.content as List<int>));

    test('un .zip con la escena y una luz por aparato', () {
      final root = doc.rootElement;
      expect(root.name.local, 'GeneralSceneDescription');
      expect(root.getAttribute('verMajor'), '1');
      final layer = doc.findAllElements('Layer').single;
      expect(layer.getAttribute('name'), 'Casa');
      final fixtures = doc.findAllElements('Fixture').toList();
      expect(fixtures, hasLength(2));
      final uuids = fixtures.map((f) => f.getAttribute('uuid')).toSet();
      expect(uuids, hasLength(2));
      final uuid = RegExp(
        r'^[0-9A-F]{8}-[0-9A-F]{4}-4[0-9A-F]{3}-[89AB][0-9A-F]{3}-[0-9A-F]{12}$',
      );
      for (final u in uuids) {
        expect(u, matches(uuid));
      }
    });

    test('cada luz, con su posición en milímetros, su altura y su tipo', () {
      final m = doc
          .findAllElements('Fixture')
          .firstWhere((f) => f.getAttribute('name') == 'ARRI M18');
      expect(m.getElement('GDTFSpec')!.innerText, 'ARRI@M18.gdtf');
      expect(m.getElement('FixtureID')!.innerText, '1');
      expect(
        m.getElement('Matrix')!.innerText,
        endsWith('{6000.0,-4000.0,2000.0}'),
      );
      final top = doc
          .findAllElements('Fixture')
          .firstWhere((f) => f.getAttribute('name') == 'SkyPanel S60-C');
      expect(top.getElement('Matrix')!.innerText, endsWith(',3200.0}'));
      expect(top.getElement('GDTFSpec')!.innerText, 'SkyPanel@S60-C.gdtf');
      // El color, en CIE xyY: 5600 K cae cerca de x = 0,33.
      final xy = m.getElement('Color')!.innerText.split(',');
      expect(double.parse(xy[0]), closeTo(0.33, 0.01));
    });
  });
}
