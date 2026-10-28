import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/floor_plan_json.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_category.dart';
import 'package:iris_dp/features/camera_plan/plan_element_external_mapping.dart';
import 'package:iris_dp/features/camera_plan/plan_segment.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';
import 'package:iris_dp/features/unreal_link/unreal_asset_tile.dart';
import 'package:iris_dp/features/unreal_link/unreal_link.dart';
import 'package:iris_dp/features/unreal_link/unreal_stage_payload.dart';

PlanElement _el(
  ElementType type, {
  String? label,
  Map<String, dynamic>? props,
  LightType? light,
}) => PlanElement(
  id: 0,
  type: type,
  position: const Offset(100, 100),
  label: label,
  lightType: light,
  props: props ?? {},
);

void main() {
  group('F6.20 B1 · un solo modelo', () {
    test('se guarda en props["unreal"] y también en la clave de antes', () {
      final el = _el(ElementType.prop, label: PropType.sofa.dbValue);
      UnrealAssetRef.set(
        el,
        UnrealAssetRef.fromPath(
          '/Game/Fab/Sofa/SM_Sofa.SM_Sofa',
          sizeCm: [200, 90, 85],
        ),
      );
      expect(el.props['unrealAsset'], '/Game/Fab/Sofa/SM_Sofa.SM_Sofa');
      final ref = UnrealAssetRef.of(el)!;
      expect(ref.name, 'SM_Sofa');
      expect(ref.source, UnrealAssetSource.fab);
      expect(ref.sizeCm, [200, 90, 85]);
      // Sobrevive a guardar y cargar.
      final back = FloorPlanJson.decode(FloorPlanJson.encode([el])).single;
      expect(UnrealAssetRef.of(back)?.path, ref.path);
      UnrealAssetRef.set(el, null);
      expect(UnrealAssetRef.has(el), isFalse);
      expect(el.props.containsKey('unrealAsset'), isFalse);
    });

    test('lee lo de antes: unrealAsset y un unrealMeshPath propio', () {
      final old = _el(
        ElementType.prop,
        props: {'unrealAsset': '/Game/Megascans/Rock.Rock'},
      );
      expect(UnrealAssetRef.of(old)?.source, UnrealAssetSource.megascans);
      final mapped = _el(ElementType.wall)
        ..externalMapping = PlanElementExternalMapping(
          unrealMeshPath: '/Game/Set/SM_Pared.SM_Pared',
        );
      expect(UnrealAssetRef.of(mapped)?.name, 'SM_Pared');
    });

    test('los cubos que se ponían solos no cuentan como asset', () {
      final auto = _el(ElementType.wall)
        ..externalMapping = PlanElementExternalMapping(
          unrealMeshPath: '/Engine/BasicShapes/Cube',
        );
      expect(UnrealAssetRef.has(auto), isFalse);
      expect(PlanCategory.hasUnrealAsset(auto), isFalse);
    });

    test('el origen sale de la carpeta', () {
      expect(UnrealAssetSource.ofPath('/Game/Fab/X.X'), UnrealAssetSource.fab);
      expect(
        UnrealAssetSource.ofPath('/Game/Quixel/X.X'),
        UnrealAssetSource.megascans,
      );
      expect(
        UnrealAssetSource.ofPath('/Engine/X.X'),
        UnrealAssetSource.engine,
      );
      expect(
        UnrealAssetSource.ofPath('/Game/Mio/X.X'),
        UnrealAssetSource.project,
      );
    });
  });

  group('F6.20 B2 · assets para todos los tipos', () {
    UnrealAssetRef ref(String path, [UnrealAssetKind k = UnrealAssetKind.mesh]) =>
        UnrealAssetRef.fromPath(path, kind: k);

    test('focos, cámaras y atrezzo llevan su asset; lo demás va en «assets»', () {
      final light = _el(ElementType.light, light: LightType.hmi);
      final cam = _el(ElementType.camera);
      final sofa = _el(ElementType.prop, label: PropType.sofa.dbValue);
      final actor = _el(ElementType.actor, label: 'ADIL');
      final bare = _el(ElementType.actor, label: 'LUCÍA');
      UnrealAssetRef.set(light, ref('/Game/Fab/HMI.HMI'));
      UnrealAssetRef.set(cam, ref('/Game/Fab/Alexa.Alexa'));
      UnrealAssetRef.set(sofa, ref('/Game/Fab/Sofa.Sofa'));
      UnrealAssetRef.set(
        actor,
        ref('/Game/MetaHumans/Ada/BP_Ada.BP_Ada', UnrealAssetKind.metahuman),
      );
      final els = [light, cam, sofa, actor, bare];
      LightOverrides.ensureUids(els);
      final scene = PlanScene3d.build(els, metersPerUnit: 0.01);
      expect(scene['fixtures'][0]['asset']['path'], '/Game/Fab/HMI.HMI');
      expect(scene['cameras'][0]['asset']['path'], '/Game/Fab/Alexa.Alexa');
      expect(scene['props'][0]['asset']['path'], '/Game/Fab/Sofa.Sofa');
      final assets = scene['assets'] as List;
      expect(assets, hasLength(1), reason: 'el actor sin asset no va');
      expect(assets.single['asset']['kind'], 'metahuman');

      final payload = UnrealStagePayload.build(scene);
      expect(payload['lights'][0]['asset']['path'], '/Game/Fab/HMI.HMI');
      expect(payload['cameras'][0]['asset']['path'], '/Game/Fab/Alexa.Alexa');
      expect(payload['props'][0]['asset']['path'], '/Game/Fab/Sofa.Sofa');
      // Lienzo (100, 100) → escena (1, −1) → Unreal (100, 100): la y cambia
      // de signo dos veces.
      expect(payload['assets'].single['loc'], [100, 100, 0]);
    });

    test('una pared con asset va en el centro del tramo, orientada con él', () {
      final wall = PlanSegment.create(
        start: Offset.zero,
        end: const Offset(400, 0),
      );
      UnrealAssetRef.set(wall, ref('/Game/Set/SM_Pared.SM_Pared'));
      LightOverrides.ensureUids([wall]);
      final scene = PlanScene3d.build([wall], metersPerUnit: 0.01);
      final a = (scene['assets'] as List).single as Map;
      expect(a['at'], [2.0, 0.0]);
      expect(a['yawDeg'], 90);
      expect(a['lengthM'], 4.0);
    });

    test('un cambio de asset se manda a Unreal como cambio', () {
      final sofa = _el(ElementType.prop, label: PropType.sofa.dbValue);
      LightOverrides.ensureUids([sofa]);
      Map<String, dynamic> now() => UnrealStagePayload.build(
        PlanScene3d.build([sofa], metersPerUnit: 0.01),
      );
      final before = now();
      UnrealAssetRef.set(sofa, ref('/Game/Fab/Sofa.Sofa'));
      final patch = UnrealStagePayload.diff(before, now())!;
      expect(patch['props'].single['asset']['path'], '/Game/Fab/Sofa.Sofa');
    });

    test('el selector ofrece personajes a los actores y mallas al resto', () {
      expect(
        UnrealAssetTile.kindsFor(_el(ElementType.actor)),
        contains(UnrealAssetKind.metahuman),
      );
      expect(
        UnrealAssetTile.kindsFor(_el(ElementType.light)),
        isNot(contains(UnrealAssetKind.skeletal)),
      );
    });

    test('asignar a un mueble le da sus medidas; a una luz, no', () {
      final sofa = _el(ElementType.prop, label: PropType.sofa.dbValue);
      final light = _el(ElementType.light, light: LightType.hmi);
      const asset = UnrealAsset(
        path: '/Game/Fab/Sofa.Sofa',
        name: 'Sofa',
        folder: '/Game/Fab',
        sizeCm: [210, 95, 80],
      );
      UnrealAssetTile.assign(sofa, asset);
      UnrealAssetTile.assign(light, asset);
      expect(sofa.props['size'], 2.1);
      expect(sofa.props['height'], 0.8);
      expect(light.props.containsKey('size'), isFalse);
      expect(UnrealAssetRef.of(light)?.path, '/Game/Fab/Sofa.Sofa');
    });
  });
}
