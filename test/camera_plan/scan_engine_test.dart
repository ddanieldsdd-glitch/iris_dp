import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:iris_dp/features/camera_plan/arch/arch_material.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_solid.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_stair.dart';
import 'package:iris_dp/features/camera_plan/arch/plan_levels.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_rig.dart';
import 'package:iris_dp/features/camera_plan/rig/scan_engine.dart';
import 'package:iris_dp/features/camera_plan/rig/scan_review.dart';
import 'package:iris_dp/features/camera_plan/rig/scan_structure.dart';

/// Datos inventados: un local de 5 × 4 m con techo a 2,8 m.
List<ScanWall> _room() => [
  ScanWall(const Offset(0, 0), const Offset(5, 0), thickness: 0.12),
  // Una al revés y fuera de orden: el contorno las encadena igual.
  ScanWall(const Offset(0, 4), const Offset(5, 4), thickness: 0.12),
  ScanWall(const Offset(5, 0), const Offset(5, 4), thickness: 0.12),
  ScanWall(const Offset(0, 4), const Offset(0, 0), thickness: 0.12),
];

/// Cómo saldría en una foto (sRGB de 0 a 1) el material [id] con más o
/// menos luz.
(double, double, double) _photoOf(String id, {double exposure = 1}) {
  final a = ArchMaterials.byId(id)!.albedoRgb;
  double srgb(int c) {
    final v = math.min(1.0, c / 255 * exposure);
    return v <= 0.0031308 ? v * 12.92 : 1.055 * math.pow(v, 1 / 2.4) - 0.055;
  }

  return (srgb((a >> 16) & 255), srgb((a >> 8) & 255), srgb(a & 255));
}

double _area(List<Offset> poly) {
  var a = 0.0;
  for (var i = 0; i < poly.length; i++) {
    final p = poly[i], q = poly[(i + 1) % poly.length];
    a += p.dx * q.dy - q.dx * p.dy;
  }
  return a.abs() / 2;
}

/// Una rejilla cenital de 6 × 4 m a 10 cm con el suelo a [floorY] y lo que
/// diga [height] (metros sobre el suelo) en cada punto.
ScanGrid _grid(double floorY, double Function(double x, double y) height) {
  const cell = 0.1, cols = 60, rows = 40;
  return ScanGrid(
    x0: 0,
    y0: 0,
    cell: cell,
    cols: cols,
    rows: rows,
    top: List.filled(cols * rows, null),
    bottom: [
      for (var j = 0; j < rows; j++)
        for (var i = 0; i < cols; i++)
          floorY + height((i + 0.5) * cell, (j + 0.5) * cell),
    ],
  );
}

void main() {
  group('Contorno', () {
    test('encadena las paredes en un recinto cerrado', () {
      final o = ScanEngine.outline(_room())!;
      expect(o, hasLength(4));
      expect(_area(o), closeTo(20, 1e-6));
    });

    test('si no cierran, la envolvente de sus puntas', () {
      final o = ScanEngine.outline(_room().sublist(0, 3))!;
      expect(_area(o), closeTo(20, 1e-6));
    });

    test('sin paredes no hay contorno', () {
      expect(ScanEngine.outline(const []), isNull);
    });
  });

  group('Niveles', () {
    test('un segundo suelo a 2,9 m es otro nivel; el de abajo no', () {
      const bin = 0.1, floorY = -1.2;
      final up = List<double>.filled(60, 0.2);
      int k(double h) => ((h + floorY + 1.5) / bin).floor();
      up[k(0)] = 20; // el suelo
      up[k(2.9)] = 6; // la entreplanta
      up[k(0.75)] = 2; // una mesa: poca superficie
      final p = ScanProfile(
        bin: bin,
        y0: -1.5,
        up: up,
        down: List.filled(60, 0),
        heights: const [],
        slices: const [],
      );
      final f = ScanEngine.floors(p, floorY);
      expect(f, hasLength(1));
      expect(f.single, closeTo(2.9, 0.06));
      // Bajo el techo, o nada.
      expect(ScanEngine.floors(p, floorY, ceilingM: 3.0), isEmpty);
    });
  });

  group('Escaleras y rampas', () {
    test('ocho peldaños de 17,5 × 28 cm: una escalera de 1 m', () {
      final g = _grid(0.3, (x, y) {
        if (y < 1 || y > 2 || x < 1) return 0;
        final step = ((x - 1) / 0.28).floor() + 1;
        return step > 8 ? 0 : step * 0.175;
      });
      final st = ScanEngine.stairs(g, 0.3);
      expect(st, hasLength(1));
      final s = st.single;
      expect(s.ramp, isFalse);
      expect(s.widthM, closeTo(1.0, 0.15));
      expect(s.runM, closeTo(8 * 0.28, 0.2));
      // Sube con un peldaño más que la última huella.
      expect(s.riseM, closeTo(9 * 0.175, 0.05));
      // Arranca abajo y sube hacia +x.
      expect(s.to.dx, greaterThan(s.from.dx));
      expect(s.from.dy, closeTo(1.5, 0.15));
    });

    test('la escalera llega al nivel que tiene a mano', () {
      final g = _grid(0, (x, y) {
        if (y < 1 || y > 2 || x < 1) return 0;
        final step = ((x - 1) / 0.28).floor() + 1;
        return step > 8 ? 0 : step * 0.175;
      });
      expect(
        ScanEngine.stairs(g, 0, levels: [1.6]).single.riseM,
        closeTo(1.6, 1e-9),
      );
    });

    test('una rampa del 8 % de 3 m', () {
      final g = _grid(0, (x, y) {
        if (y < 0.5 || y > 1.7 || x < 1 || x > 4) return 0;
        return 0.08 * (x - 1);
      });
      final st = ScanEngine.stairs(g, 0);
      expect(st, hasLength(1));
      expect(st.single.ramp, isTrue);
      expect(st.single.runM, closeTo(3, 0.2));
    });

    test('un mueble o un escalón suelto no son escaleras', () {
      final g = _grid(0, (x, y) {
        if (x > 2 && x < 3.5 && y > 1 && y < 2) return 0.45; // un banco
        if (x > 4 && y > 3) return 0.12; // una tarima
        return 0;
      });
      expect(ScanEngine.stairs(g, 0), isEmpty);
    });
  });

  group('Material por el color', () {
    Uint8List png(int r, int g, int b, {int w = 64, int h = 48}) {
      final im = img.Image(width: w, height: h);
      img.fill(im, color: img.ColorRgb8(20, 20, 20));
      img.fillRect(
        im,
        x1: 8,
        y1: 8,
        x2: w - 9,
        y2: h - 9,
        color: img.ColorRgb8(r, g, b),
      );
      return img.encodePng(im);
    }

    test('el color medio de lo que cae dentro', () {
      final c = ScanEngine.meanColor(png(200, 100, 50), const [
        Offset(8, 8),
        Offset(55, 8),
        Offset(55, 39),
        Offset(8, 39),
      ])!;
      expect(c.$1, closeTo(200 / 255, 0.02));
      expect(c.$2, closeTo(100 / 255, 0.02));
      expect(c.$3, closeTo(50 / 255, 0.02));
    });

    test('el ladrillo se reconoce aunque la foto esté más clara', () {
      expect(
        ScanEngine.nearestMaterial(
          _photoOf('brick-tan', exposure: 1.4),
          ScanEngine.wallFamilies,
        ).family,
        ArchFamily.brick,
      );
      expect(
        ScanEngine.nearestMaterial(
          _photoOf('wood-floor-oak'),
          ScanEngine.floorFamilies,
        ).id,
        'wood-floor-oak',
      );
      expect(
        ScanEngine.nearestMaterial(
          _photoOf('paint-white', exposure: 0.8),
          ScanEngine.ceilingFamilies,
        ).family,
        ArchFamily.plaster,
      );
    });

    test('en segundo plano, con la foto a otra escala', () async {
      final dir = await Directory.systemTemp.createTemp('iris_scan_engine');
      addTearDown(() => dir.delete(recursive: true));
      final f = File('${dir.path}/foto.png')
        ..writeAsBytesSync(
          png(
            (_photoOf('brick-tan').$1 * 255).round(),
            (_photoOf('brick-tan').$2 * 255).round(),
            (_photoOf('brick-tan').$3 * 255).round(),
            w: 128,
            h: 96,
          ),
        );
      final ids = await ScanEngine.materialsFromPhotos([
        (
          path: f.path,
          // La captura mide la foto a la mitad.
          frameSize: const Size(64, 48),
          pixels: const [
            Offset(8, 8),
            null,
            Offset(55, 8),
            Offset(55, 39),
            Offset(8, 39),
          ],
          families: ScanEngine.wallFamilies,
        ),
        (
          path: '${dir.path}/no-esta.png',
          frameSize: const Size(64, 48),
          pixels: const [Offset(0, 0), Offset(1, 0), Offset(1, 1)],
          families: ScanEngine.wallFamilies,
        ),
      ]);
      expect(ArchMaterials.byId(ids[0])!.family, ArchFamily.brick);
      expect(ids[1], isNull);
    });
  });

  group('Revisión → piezas del motor', () {
    ScanStructure structure({bool estimated = false}) => ScanStructure(
      floorY: 0,
      heightM: 2.8,
      heightEstimated: estimated,
      axisDeg: 0,
      walls: _room(),
      openings: const [],
      objects: const [
        ScanObject(
          center: Offset(2, 2),
          width: 1.2,
          depth: 0.6,
          rotationDeg: 30,
          heightM: 0.9,
          confidence: 0.8,
        ),
        ScanObject(
          center: Offset(4, 3),
          width: 2,
          depth: 0.9,
          rotationDeg: 0,
          heightM: 0.8,
          confidence: 0.8,
        ),
      ],
      floors: const [2.6],
      stairs: const [
        ScanStair(
          from: Offset(1, 3.5),
          to: Offset(3.24, 3.5),
          widthM: 0.9,
          riseM: 1.58,
          ramp: false,
          confidence: 0.7,
        ),
      ],
    );

    test('suelo, techo, nivel y escalera entran en la revisión', () {
      final items = reviewItems(structure());
      ReviewItem of(ReviewKind k) => items.firstWhere((it) => it.kind == k);
      expect(of(ReviewKind.floor).accepted, isTrue);
      expect(of(ReviewKind.ceiling).accepted, isTrue);
      expect(of(ReviewKind.level).label, 'Planta 1');
      expect(of(ReviewKind.stair).label, 'Escalera');
      // Un techo que no se vio no va sin mirarlo.
      final guess = reviewItems(structure(estimated: true));
      expect(
        guess.firstWhere((it) => it.kind == ReviewKind.ceiling).accepted,
        isFalse,
      );
      // Puntos para buscarles foto.
      for (final it in items) {
        expect(reviewPoints(structure(), it), isNotEmpty);
      }
    });

    test('salen forjados, escalera, volumen y mueble con su material', () {
      const mpu = 0.05;
      final s = structure();
      final items = reviewItems(s);
      items.firstWhere((it) => it.kind == ReviewKind.wall).materialId =
          'brick-old';
      items.firstWhere((it) => it.kind == ReviewKind.floor).materialId =
          'wood-floor-oak';
      final objects = items.where((it) => it.kind == ReviewKind.object);
      objects.last.propType = PropType.sofa;
      final els = reviewElements(s, items, mpu);

      final slabs = els.where((e) => RigTypeCodec.of(e) == RigType.slab);
      expect(slabs, hasLength(3));
      final tops = [
        for (final e in slabs) (e.props[ArchSolid.topKey] as num).toDouble(),
      ]..sort();
      // Suelo a 0, nivel a 2,6 y techo con su cara de abajo a 2,8.
      expect(tops, [0.0, 2.6, 3.0]);
      final floor = slabs.firstWhere((e) => e.props[ArchSolid.topKey] == 0.0);
      expect(floor.props[ArchMaterials.key], 'wood-floor-oak');
      expect(_area(ArchSolid.outlineM(floor)), closeTo(20, 1e-6));
      expect(
        slabs.where((e) => e.props[PlanLevels.nameKey] == 'Planta 1'),
        hasLength(1),
      );

      final stair = els.singleWhere((e) => RigTypeCodec.of(e) == RigType.stair);
      expect(stair.props[ArchStair.riseKey], 1.58);
      expect(stair.props[ArchStair.widthKey], 0.9);
      expect(stair.position, const Offset(1, 3.5) / mpu);

      final vol = els.singleWhere((e) => RigTypeCodec.of(e) == RigType.volume);
      expect(vol.rotation, 30);
      expect(vol.props[ArchSolid.heightKey], 0.9);
      expect(vol.position, const Offset(2, 2) / mpu);

      final wall = els.firstWhere((e) => e.props[kScanThicknessKey] != null);
      expect(wall.props[ArchMaterials.key], 'brick-old');

      // El sofá sigue siendo mueble; sin biblioteca, sin asset.
      expect(
        els
            .where(
              (e) => e.type == ElementType.prop && RigTypeCodec.of(e) == null,
            )
            .length,
        1,
      );
      for (final e in els) {
        expect(e.layer, PlanLayer.environment);
        expect(e.props[kScanSourceKey], kScanSourceValue);
      }
    });

    test('un mueble sin tipo puede entrar como mueble, no volumen', () {
      final s = structure();
      final items = reviewItems(s);
      for (final it in items.where((it) => it.kind == ReviewKind.object)) {
        it.asVolume = false;
      }
      final els = reviewElements(s, items, 0.05);
      expect(els.where((e) => RigTypeCodec.of(e) == RigType.volume), isEmpty);
    });

    test('en la calle no hay suelo ni techo', () {
      final s = structure();
      final street = ScanStructure(
        floorY: 0,
        heightM: s.heightM,
        heightEstimated: true,
        axisDeg: 0,
        walls: s.walls,
        openings: const [],
        objects: const [],
        exterior: true,
      );
      expect(
        reviewItems(street).where(
          (it) => it.kind == ReviewKind.floor || it.kind == ReviewKind.ceiling,
        ),
        isEmpty,
      );
    });
  });
}
