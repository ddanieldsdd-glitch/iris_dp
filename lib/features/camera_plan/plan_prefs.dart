import '../../core/settings/app_prefs.dart';
import 'light/ambient.dart';

/// Ajustes de la planta de cámara: cómo se abre el lienzo y con qué valores
/// empiezan las cámaras y los esquemas de luz nuevos.
abstract final class PlanPrefs {
  static const snap = PrefKey<bool>('plan.snap', true);
  static const otherCameras = PrefKey<bool>('plan.otherCameras', true);
  static const exposureMap = PrefKey<bool>('plan.exposureMap', false);
  static const readings = PrefKey<bool>('plan.readings', true);

  static const iso = PrefKey<double>('plan.iso', 800);
  static const shutterDeg = PrefKey<double>('plan.shutterDeg', 180);
  static const fps = PrefKey<double>('plan.fps', 24);
  static const ndStops = PrefKey<double>('plan.ndStops', 0);
  static const tStop = PrefKey<double>('plan.tStop', 2.8);

  static const ambientDay = PrefKey<bool>('plan.ambient.day', false);
  static const ambientSky = PrefKey<String>('plan.ambient.sky', 'clear');
  static const ambientBounce = PrefKey<bool>('plan.ambient.bounce', true);

  static const all = <PrefKey>[
    snap,
    otherCameras,
    exposureMap,
    readings,
    iso,
    shutterDeg,
    fps,
    ndStops,
    tStop,
    ambientDay,
    ambientSky,
    ambientBounce,
  ];

  /// Lo que manda ahora en [projectId].
  static PlanPrefValues read(int projectId) {
    final p = AppPrefs.instance;
    T v<T extends Object>(PrefKey<T> k) => p.get(k, projectId: projectId);
    return (
      snap: v(snap),
      otherCameras: v(otherCameras),
      exposureMap: v(exposureMap),
      readings: v(readings),
      iso: v(iso),
      shutterDeg: v(shutterDeg),
      fps: v(fps),
      ndStops: v(ndStops),
      tStop: v(tStop),
    );
  }

  /// Ambiente con el que nace un esquema de luz nuevo.
  static PlanAmbient newSetupAmbient(int projectId) {
    final p = AppPrefs.instance;
    return PlanAmbient(
      day: p.get(ambientDay, projectId: projectId),
      condition: SkyCondition.values.firstWhere(
        (c) => c.name == p.get(ambientSky, projectId: projectId),
        orElse: () => SkyCondition.clear,
      ),
      wallBounce: p.get(ambientBounce, projectId: projectId),
    );
  }
}

typedef PlanPrefValues = ({
  bool snap,
  bool otherCameras,
  bool exposureMap,
  bool readings,
  double iso,
  double shutterDeg,
  double fps,
  double ndStops,
  double tStop,
});
