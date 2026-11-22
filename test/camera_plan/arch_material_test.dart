import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_material.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_material_picker.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/light_scene.dart';
import 'package:iris_dp/features/camera_plan/light/surfaces.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_drape.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('biblioteca de materiales (AM.1)', () {
    test('los id son únicos', () {
      final ids = [for (final m in ArchMaterials.all) m.id];
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('las paredes de siempre conservan lo que devuelven', () {
      for (final MapEntry(key: old, value: id)
          in ArchMaterials.wallLegacy.entries) {
        final before = SurfaceMaterial.byId(old, kWallMaterials);
        expect(before.id, old);
        final now = ArchMaterials.byId(id)!;
        expect(now.reflectance, before.reflectance, reason: old);
        expect(now.miredShift, before.miredShift, reason: old);
        expect(now.beamDeg, before.beamDeg, reason: old);
        // El color que va al 3D y a Unreal es el mismo.
        expect(now.albedoRgb, before.albedoRgb, reason: old);
      }
    });

    test('los suelos de siempre también', () {
      for (final MapEntry(key: old, value: id)
          in ArchMaterials.floorLegacy.entries) {
        final before = SurfaceMaterial.byId(old, kFloorMaterials);
        expect(before.id, old);
        final now = ArchMaterials.byId(id)!;
        expect(now.reflectance, before.reflectance, reason: old);
        expect(now.miredShift, before.miredShift, reason: old);
      }
    });

    test('las telas de colgar tienen su PBR', () {
      for (final d in kDrapeMaterials) {
        expect(ArchMaterials.byId('drape-${d.id}'), isNotNull, reason: d.id);
      }
    });

    test('con textura y sin números, la luz sale de su color medio', () {
      final sand = ArchMaterials.byId('sand')!;
      final (r, g, b) = sand.texture!.mean;
      expect(
        sand.reflectance,
        closeTo(0.2126 * r + 0.7152 * g + 0.0722 * b, 1e-9),
      );
      // Arena: cálida.
      expect(sand.miredShift, greaterThan(20));
      // Y la textura no se tiñe más de la cuenta.
      for (final t in sand.tint) {
        expect(t, closeTo(1, 0.25));
      }
      // El ladrillo de siempre se tiñe para casar con sus números.
      final brick = ArchMaterials.byId('brick-old')!;
      expect(brick.reflectance, 0.25);
    });

    test('cada textura está en la app y es CC0', () {
      for (final m in ArchMaterials.all) {
        final t = m.texture;
        if (t == null) continue;
        for (final kind in [
          'albedo',
          'normal',
          'rough',
          if (t.metalMap) 'metal',
        ]) {
          expect(
            File('${ArchTexture.folder}/${t.file}_$kind.jpg').existsSync(),
            isTrue,
            reason: '${t.file}_$kind',
          );
        }
        expect(t.widthM, greaterThan(0));
        expect(t.heightM, greaterThan(0));
      }
      expect(ArchMaterials.licenses, isNotEmpty);
      expect(
        ArchMaterials.licenses.every((l) => l['license'] == 'CC0 1.0'),
        isTrue,
      );
      // El pubspec las incluye.
      expect(
        File('pubspec.yaml').readAsStringSync(),
        contains('assets/viewer3d/textures/'),
      );
    });
  });

  group('material de una pared', () {
    PlanElement wall() =>
        PlanSegment.create(start: Offset.zero, end: const Offset(100, 0))
          ..id = 1;

    test('sin material, nada', () {
      expect(ArchMaterials.ofWall(wall()), isNull);
    });

    test('el de siempre se lee en la biblioteca', () {
      final w = wall()..props[LightScene.materialKey] = 'brick';
      expect(ArchMaterials.ofWall(w)!.id, 'brick-old');
    });

    test('el de la biblioteca manda', () {
      final w = wall()
        ..props[LightScene.materialKey] = 'brick'
        ..props[ArchMaterials.key] = 'stone-marble';
      expect(ArchMaterials.ofWall(w)!.id, 'stone-marble');
      expect(
        ArchMaterials.wallSurface(w, 'brick').reflectance,
        ArchMaterials.byId('stone-marble')!.reflectance,
      );
    });

    test('en la escena 3D: su material, su clase y la biblioteca', () {
      final w = wall()..props[ArchMaterials.key] = 'brick-tan';
      final plain =
          PlanSegment.create(
              start: const Offset(0, 100),
              end: const Offset(100, 100),
            )
            ..id = 2;
      final scene = PlanScene3d.build([w, plain], metersPerUnit: 0.02);
      final walls = (scene['walls'] as List).cast<Map>();
      final brick = walls.firstWhere((x) => x['mat'] != null);
      expect(brick['mat'], 'brick-tan');
      expect(brick['cls'], 'architecture');
      expect(brick['rgb'], ArchMaterials.byId('brick-tan')!.albedoRgb);
      expect(walls.where((x) => x['mat'] == null), hasLength(1));
      final mats = scene['materials'] as Map;
      expect(mats.keys, ['brick-tan']);
      final def = mats['brick-tan'] as Map;
      expect(def['tex']['file'], 'Bricks105');
      expect(def['tex']['w'], 2.4);
      expect(def['rough'], isA<double>());
    });

    test('una tela lleva su material de tela', () {
      final d = PlanDrape.create(const Offset(0, 0), const Offset(100, 0))
        ..id = 3;
      final scene = PlanScene3d.build([d], metersPerUnit: 0.02);
      final drape = (scene['drapes'] as List).single as Map;
      expect(drape['mat'], 'drape-molleton');
      expect((scene['materials'] as Map).keys, ['drape-molleton']);
    });
  });

  testWidgets('el selector enseña las familias y devuelve el elegido', (
    tester,
  ) async {
    ArchMaterial? picked;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => ArchMaterialField(
              label: 'Material de la pared',
              value: picked,
              onChanged: (m) => setState(() => picked = m),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Sin material'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('arch-material-field')));
    await tester.pumpAndSettle();
    expect(find.text('Ladrillo'), findsOneWidget);
    expect(find.byKey(const ValueKey('arch-material-drape-molleton')),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('arch-material-paint-white')));
    await tester.pumpAndSettle();
    expect(picked?.id, 'paint-white');
    expect(find.text('Pintura blanca · Yeso y pintura'), findsOneWidget);
  });
}
