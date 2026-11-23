import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:iris_dp/core/theme/app_theme.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_material.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_material_picker.dart';
import 'package:iris_dp/features/camera_plan/arch/arch_solid.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_opening.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_hall.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_rig.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';
import 'package:iris_dp/features/unreal_link/unreal_asset_tile.dart';
import 'package:iris_dp/features/unreal_link/unreal_library.dart';
import 'package:iris_dp/features/unreal_link/unreal_link.dart';
import 'package:iris_dp/features/unreal_link/unreal_link_hints.dart';
import 'package:iris_dp/features/unreal_link/unreal_stage_payload.dart';

/// Plan AM.U2: vincular piezas y materiales con assets de Unreal (Fab,
/// Megascans o del proyecto). Datos inventados.
void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    UnrealLibrary.instance.clearForTest();
  });

  // 1 unidad del lienzo = 1 cm.
  const mpu = 0.01;
  final doorAsset = UnrealAssetRef.fromPath(
    '/Game/Fab/OldDoor/SM_OldDoor.SM_OldDoor',
  );
  final brickAsset = UnrealAssetRef.fromPath(
    '/Game/Megascans/Surfaces/Red_Brick/MI_Red_Brick.MI_Red_Brick',
    kind: UnrealAssetKind.material,
  );

  PlanElement wall() =>
      PlanSegment.create(start: Offset.zero, end: const Offset(600, 0))
        ..props[PlanSegment.thicknessKey] = 0.2
        ..props[ArchMaterials.key] = 'brick-old';

  PlanElement opening(
    ArchitectureType type,
    Offset at, {
    double width = 100,
    double? sill,
    double head = 2.1,
  }) => PlanElement(
    id: 0,
    type: ElementType.wall,
    position: at,
    label: type.dbValue,
    props: {
      PlanOpening.widthKey: width,
      PlanOpening.headKey: head,
      PlanOpening.sillKey: ?sill,
    },
  );

  Map<String, dynamic> scene(List<PlanElement> els) {
    LightOverrides.ensureUids(els);
    return PlanScene3d.build(els, metersPerUnit: mpu);
  }

  Map assetOf(Map<String, dynamic> sc, String path) =>
      (sc['assets'] as List).cast<Map>().firstWhere(
        (a) => (a['asset'] as Map)['path'] == path,
      );

  group('pieza con asset', () {
    test('una puerta: a lo largo de su pared, ajustada al hueco', () {
      final w = wall();
      final d = opening(ArchitectureType.doorClosed, const Offset(300, 0));
      UnrealAssetRef.set(d, doorAsset);
      final sc = scene([w, d]);
      final a = assetOf(sc, doorAsset.path);
      expect(a['fitM'], [1.0, 0, 2.1]);
      expect(a['z0'], 0);
      expect(a['yawDeg'], 90);
      expect(a['at'], [3.0, 0]);
      // El hueco sigue en la pared; el marco y la hoja no van a Unreal.
      final hole = ((sc['walls'] as List).single['openings'] as List).single;
      expect(hole['linked'], isTrue);
      expect((sc['walls'] as List).single['linked'], isNull);
    });

    test('una ventana empieza en su alféizar', () {
      final win = opening(
        ArchitectureType.window,
        const Offset(300, 0),
        width: 120,
        sill: 0.9,
      );
      UnrealAssetRef.set(win, doorAsset);
      final a = assetOf(scene([wall(), win]), doorAsset.path);
      expect(a['z0'], 0.9);
      expect(a['fitM'], [1.2, 0, 1.2]);
    });

    test('a su tamaño real si se pide', () {
      final d = opening(ArchitectureType.doorClosed, const Offset(300, 0));
      UnrealAssetRef.set(d, doorAsset);
      UnrealAssetRef.setFits(d, false);
      final a = assetOf(scene([wall(), d]), doorAsset.path);
      expect(a.containsKey('fitM'), isFalse);
      expect(a['z0'], 0);
      UnrealAssetRef.setFits(d, true);
      expect(d.props.containsKey(UnrealAssetRef.fitKey), isFalse);
    });

    test('pared, pilar y volumen', () {
      final w = wall()
        ..props[PlanSegment.heightKey] = 2.5
        ..props[PlanSegment.peakKey] = 4.0;
      final p = RigTypeCodec.create(
        RigType.pillar,
        const Offset(100, 300),
        props: {PlanPillar.sizeKey: 0.4, PlanPillar.heightKey: 3.5},
      );
      final v = ArchSolid.rectangle(
        RigType.volume,
        const Offset(400, 200),
        const Offset(600, 300),
        mpu,
      );
      for (final (i, el) in [w, p, v].indexed) {
        UnrealAssetRef.set(el, UnrealAssetRef.fromPath('/Game/A$i.A$i'));
      }
      final sc = scene([w, p, v]);
      expect(assetOf(sc, '/Game/A0.A0')['fitM'], [6.0, 0.2, 4.0]);
      expect(assetOf(sc, '/Game/A1.A1')['fitM'], [0.4, 0.4, 3.5]);
      final vol = assetOf(sc, '/Game/A2.A2');
      // Fondo a lo largo de hacia donde mira, ancho de lado.
      expect(vol['fitM'], [1.0, 2.0, ArchSolid.heightM(v)]);
      expect(vol['at'], [5.0, -2.5]);
      // Ninguna de las tres va además en la estructura.
      expect((sc['walls'] as List).single['linked'], isTrue);
      expect((sc['pillars'] as List).single['linked'], isTrue);
      expect((sc['solids'] as List).single['linked'], isTrue);
    });

    test('a Unreal, en centímetros', () {
      final d = opening(ArchitectureType.doorClosed, const Offset(300, 0));
      UnrealAssetRef.set(d, doorAsset);
      final payload = UnrealStagePayload.build(scene([wall(), d]));
      final a = (payload['assets'] as List).cast<Map>().single;
      expect(a['fitCm'], [100.0, 0.0, 210.0]);
    });
  });

  group('material vinculado', () {
    test('va con la escena y cambia sin rehacer la estructura', () async {
      final w = wall();
      final before = UnrealStagePayload.build(scene([w]));
      expect(before['materials'], isEmpty);
      await UnrealLibrary.instance.linkMaterial('brick-old', brickAsset);
      final sc = scene([w]);
      expect((sc['materials'] as Map)['brick-old']['unreal'], brickAsset.path);
      final now = UnrealStagePayload.build(sc);
      expect(now['materials'], {'brick-old': brickAsset.path});
      final diff = UnrealStagePayload.diff(before, now)!;
      expect(diff['materials'], {'brick-old': brickAsset.path});
      // Sin vincular otra vez: se manda vacío y Unreal vuelve al del GLB.
      await UnrealLibrary.instance.linkMaterial('brick-old', null);
      final again = UnrealStagePayload.build(scene([w]));
      expect(UnrealStagePayload.diff(now, again)!['materials'], isEmpty);
    });

    test('viaja con la biblioteca: gana el último elegido', () async {
      final lib = UnrealLibrary.instance;
      await lib.linkMaterial('brick-old', brickAsset);
      final mine = lib.encode();
      // Otro equipo lo quitó antes: no pisa el vínculo de aquí.
      lib.importJson(
        jsonEncode({
          'entries': [],
          'materials': {
            'brick-old': {'at': '2020-01-01T00:00:00Z'},
            'oak-floor': {
              'ref': UnrealAssetRef.fromPath(
                '/Game/Fab/Oak/MI_Oak.MI_Oak',
                kind: UnrealAssetKind.material,
              ).toJson(),
              'at': '2020-01-01T00:00:00Z',
            },
          },
        }),
      );
      expect(lib.materialLinkOf('brick-old')?.path, brickAsset.path);
      expect(lib.materialLinkOf('oak-floor')?.kind, UnrealAssetKind.material);
      // Quitado después, sí.
      lib.importJson(
        jsonEncode({
          'materials': {
            'brick-old': {'at': '2999-01-01T00:00:00Z'},
          },
        }),
      );
      expect(lib.materialLinkOf('brick-old'), isNull);
      expect(lib.materialPaths.keys, ['oak-floor']);
      // Y lo de aquí se lee igual en otro equipo.
      lib.clearForTest();
      lib.importJson(mine);
      expect(lib.materialLinkOf('brick-old')?.path, brickAsset.path);
      // Un material no sale en la biblioteca de piezas para colocar.
      expect(lib.entries, isEmpty);
    });
  });

  group('ayudas', () {
    test('qué buscar y cuáles se ajustan', () {
      expect(
        UnrealLinkHints.queryFor(
          opening(ArchitectureType.doorClosed, Offset.zero),
        ),
        'door',
      );
      expect(
        UnrealLinkHints.queryFor(opening(ArchitectureType.window, Offset.zero)),
        'window',
      );
      expect(UnrealLinkHints.canFit(wall()), isTrue);
      expect(
        UnrealLinkHints.canFit(
          PlanElement(id: 0, type: ElementType.actor, position: Offset.zero),
        ),
        isFalse,
      );
    });

    test('las iguales: mismas medidas y, en una nave, la misma', () {
      Offset at(double x) => Offset(x, 0);
      final a = opening(ArchitectureType.window, at(100), sill: 0.9);
      final b = opening(ArchitectureType.window, at(300), sill: 0.9);
      final wider = opening(
        ArchitectureType.window,
        at(500),
        width: 160,
        sill: 0.9,
      );
      final door = opening(ArchitectureType.doorClosed, at(700));
      final all = [a, b, wider, door];
      expect(UnrealLinkHints.siblingsOf(a, all), [b]);
      a.props[PlanHall.hallKey] = 'nave-1';
      expect(UnrealLinkHints.siblingsOf(a, all), isEmpty);
      b.props[PlanHall.hallKey] = 'nave-1';
      expect(UnrealLinkHints.siblingsOf(a, all), [b]);
      UnrealAssetRef.set(a, doorAsset);
      UnrealAssetRef.setFits(a, false);
      expect(UnrealLinkHints.copyTo(a, [b]), 1);
      expect(UnrealAssetRef.of(b)?.path, doorAsset.path);
      expect(UnrealAssetRef.fits(b), isFalse);
      expect(UnrealLinkHints.copyTo(a, [b]), 0);
    });
  });

  testWidgets('el panel: ajustar y poner a las iguales', (tester) async {
    final a = opening(ArchitectureType.window, Offset.zero, sill: 0.9);
    final b = opening(ArchitectureType.window, const Offset(300, 0), sill: 0.9);
    final c = opening(
      ArchitectureType.window,
      const Offset(600, 0),
      width: 160,
      sill: 0.9,
    );
    UnrealAssetRef.set(a, doorAsset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (context, setState) => UnrealAssetTile(
                element: a,
                elements: [a, b, c],
                link: UnrealLink.instance,
                onChanged: () async => setState(() {}),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Ajustar a las medidas de la pieza'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('unreal-asset-fit')));
    await tester.pump();
    expect(UnrealAssetRef.fits(a), isFalse);
    expect(find.text('Ponerlo también a la otra igual'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('unreal-asset-siblings')));
    await tester.pump();
    expect(UnrealAssetRef.of(b)?.path, doorAsset.path);
    expect(UnrealAssetRef.has(c), isFalse);
    expect(find.byKey(const ValueKey('unreal-asset-siblings')), findsNothing);
  });

  testWidgets('el material dice con qué se hace en Unreal', (tester) async {
    final brick = ArchMaterials.byId('brick-old')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ArchMaterialField(
            label: 'Material',
            value: brick,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('En Unreal: el mismo (sin vincular)'), findsOneWidget);
    await tester.runAsync(
      () => UnrealLibrary.instance.linkMaterial('brick-old', brickAsset),
    );
    await tester.pump();
    expect(find.text('En Unreal: MI_Red_Brick · Megascans'), findsOneWidget);
  });
}
