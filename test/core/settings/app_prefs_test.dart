import 'package:flutter_test/flutter_test.dart';
import 'package:iris_dp/core/settings/app_prefs.dart';
import 'package:iris_dp/features/camera_plan/light/ambient.dart';
import 'package:iris_dp/features/camera_plan/plan_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const snap = PrefKey<bool>('test.snap', true);
  const iso = PrefKey<double>('test.iso', 800);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await AppPrefs.reloadForTest();
  });

  final prefs = AppPrefs.instance;

  test('sin nada guardado, manda el valor de fábrica', () {
    expect(prefs.get(snap), isTrue);
    expect(prefs.get(snap, projectId: 1), isTrue);
    expect(prefs.hasOverride(snap, 1), isFalse);
  });

  test('el valor general llega a todos los proyectos', () async {
    await prefs.setIn(snap, const SettingsScope.global(), false);
    expect(prefs.get(snap), isFalse);
    expect(prefs.get(snap, projectId: 1), isFalse);
    expect(prefs.get(snap, projectId: 2), isFalse);
  });

  test('la excepción de un proyecto no toca a los demás', () async {
    await prefs.setIn(iso, const SettingsScope.project(1), 1600);
    expect(prefs.get(iso, projectId: 1), 1600);
    expect(prefs.get(iso, projectId: 2), 800);
    expect(prefs.get(iso), 800);
    expect(prefs.overrideCount([snap, iso], 1), 1);

    // Cambiar el general no pisa la excepción.
    await prefs.setIn(iso, const SettingsScope.global(), 400);
    expect(prefs.get(iso, projectId: 1), 1600);
    expect(prefs.get(iso, projectId: 2), 400);
  });

  test('borrar la excepción vuelve al valor general', () async {
    await prefs.setIn(snap, const SettingsScope.global(), false);
    await prefs.setIn(snap, const SettingsScope.project(1), true);
    expect(prefs.get(snap, projectId: 1), isTrue);
    await prefs.clearOverride(snap, 1);
    expect(prefs.hasOverride(snap, 1), isFalse);
    expect(prefs.get(snap, projectId: 1), isFalse);
  });

  test('avisa a quien escucha al cambiar', () async {
    var calls = 0;
    void listener() => calls++;
    prefs.addListener(listener);
    await prefs.setIn(snap, const SettingsScope.global(), false);
    await prefs.clearOverride(snap, 1);
    prefs.removeListener(listener);
    expect(calls, 2);
  });

  test('un double guardado como entero se lee bien', () async {
    SharedPreferences.setMockInitialValues({
      AppPrefs.storageKey(iso.id): 1280,
    });
    await AppPrefs.reloadForTest();
    expect(prefs.get(iso), 1280.0);
  });

  test('la planta lee sus valores y el ambiente de un esquema nuevo', () async {
    await prefs.setIn(PlanPrefs.snap, const SettingsScope.project(7), false);
    await prefs.setIn(PlanPrefs.ambientDay, const SettingsScope.global(), true);
    await prefs.setIn(
      PlanPrefs.ambientSky,
      const SettingsScope.global(),
      SkyCondition.overcast.name,
    );
    final values = PlanPrefs.read(7);
    expect(values.snap, isFalse);
    expect(values.iso, 800);
    expect(PlanPrefs.read(8).snap, isTrue);

    final ambient = PlanPrefs.newSetupAmbient(7);
    expect(ambient.day, isTrue);
    expect(ambient.condition, SkyCondition.overcast);
    expect(ambient.wallBounce, isTrue);
  });
}
