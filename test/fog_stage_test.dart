import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light/ambient.dart';
import 'package:iris_dp/features/camera_plan/rig/plan_scene3d.dart';
import 'package:iris_dp/features/unreal_link/unreal_stage_payload.dart';

/// Niebla y humo del esquema de luz (F6.21.2).
void main() {
  const mpu = 0.01;

  PlanElement fresnel() => PlanElement(
    id: 1,
    type: ElementType.light,
    position: Offset.zero,
    lightType: LightType.fresnelMedium,
    props: {'uid': 'L', 'intensity': 100},
  );

  Map<String, dynamic> payload(PlanAmbient a) => UnrealStagePayload.build(
    PlanScene3d.build([fresnel()], metersPerUnit: mpu, ambient: a),
  );

  test('la niebla se guarda con el esquema; sin ella, el JSON de siempre', () {
    const smoke = PlanAmbient(fogPct: 40, fogKind: FogKind.smoke);
    final back = PlanAmbient.fromJson(smoke.toJson());
    expect(back, smoke);
    expect(back.hasFog, isTrue);
    expect(const PlanAmbient().toJson().containsKey('fogPct'), isFalse);
    // Lo guardado antes no tiene niebla.
    expect(PlanAmbient.fromJson({'day': true}).hasFog, isFalse);
  });

  test('la niebla llega a la escena y a Unreal, y se manda al cambiar', () {
    final none = payload(const PlanAmbient());
    expect(none['fog'], isNull);
    final haze = payload(const PlanAmbient(fogPct: 30));
    expect(haze['fog']['pct'], 30);
    expect(haze['fog']['kind'], 'haze');

    final more = payload(const PlanAmbient(fogPct: 70));
    final diff = UnrealStagePayload.diff(haze, more)!;
    expect(diff['fog']['pct'], 70);
    expect(diff['lights'], isEmpty);
    // Quitarla manda la niebla vacía, para que Unreal la quite.
    final off = UnrealStagePayload.diff(more, none)!;
    expect(off.containsKey('fog'), isTrue);
    expect(off['fog'], isNull);
  });
}
