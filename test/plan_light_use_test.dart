import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_constants.dart';
import 'package:iris_dp/features/camera_plan/camera_plan_element_model.dart';
import 'package:iris_dp/features/camera_plan/light_beam.dart';
import 'package:iris_dp/features/camera_plan/light_overrides.dart';
import 'package:iris_dp/features/camera_plan/plan_gear_list.dart';

PlanElement _light(String uid, {bool off = false}) => PlanElement(
  id: uid.hashCode,
  type: ElementType.light,
  position: const Offset(10, 20),
  lightType: LightType.fresnelMedium,
  props: {'uid': uid, if (off) LightBeam.offKey: true},
);

/// PL.1: un foco del set que un plano no usa.
void main() {
  test('un foco no usado desaparece del plano, salvo en el editor', () {
    final set = [_light('a'), _light('b')];
    final unused = LightOverrides.clone(set.first);
    LightOverrides.setUnused(unused, true);
    final json = LightOverrides.encode({'a': unused});

    final shown = LightOverrides.apply(set, json);
    expect([for (final el in shown) LightOverrides.uidOf(el)], ['b']);

    final editor = LightOverrides.apply(set, json, keepUnused: true);
    expect(editor, hasLength(2));
    expect(LightOverrides.isUnused(editor.first), isTrue);
    expect(LightOverrides.unusedIn(json), {'a'});
  });

  test('una versión anterior lo ve apagado, sin perder nada', () {
    final el = _light('a');
    LightOverrides.setUnused(el, true);
    expect(LightBeam.of(el)!.off, isTrue);
    final back = LightOverrides.decode(LightOverrides.encode({'a': el}));
    expect(back['a']!.position, const Offset(10, 20));
    expect(LightOverrides.isUnused(back['a']!), isTrue);
  });

  test('al volver a usarlo, se enciende como está en el set', () {
    final on = _light('a');
    final copy = LightOverrides.clone(on);
    LightOverrides.setUnused(copy, true);
    LightOverrides.setUnused(copy, false);
    expect(LightBeam.of(copy)!.off, isFalse);
    expect(LightOverrides.sameAs(copy, on), isTrue);

    final off = _light('b', off: true);
    final again = LightOverrides.clone(off);
    LightOverrides.setUnused(again, true);
    LightOverrides.setUnused(again, false, setOff: true);
    expect(LightOverrides.sameAs(again, off), isTrue);
  });

  test('un ajuste que cambia algo más no es igual al del set', () {
    final el = _light('a');
    final moved = LightOverrides.clone(el)..position = const Offset(50, 50);
    expect(LightOverrides.sameAs(moved, el), isFalse);
  });

  test('un foco no usado no lleva número de unidad', () {
    final used = _light('a');
    final unused = _light('b');
    LightOverrides.setUnused(unused, true);
    final numbers = lightUnitNumbers([unused, used]);
    expect(numbers, {used: 1});
  });
}
