import '../../core/database/app_database.dart';
import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light/plan_light.dart';
import 'plan_data.dart';

/// Lo que dice de un vistazo qué set es (SV): sus luces, sus cámaras y
/// cuándo se rueda (INT/EXT, DÍA/NOCHE).
class SetSummary {
  /// Luces del set (las suyas y las de su grupo).
  final int lights;

  /// Las principales, agrupadas: «Tubo 5600K ×2».
  final List<String> mainLights;

  /// Letras de sus cámaras (A, B…).
  final List<String> cameras;

  /// «INT · NOCHE»; nulo si sus escenas no lo dicen.
  final String? when;

  /// Planos del set y cuántos no tienen cámara.
  final int shots;
  final int shotsWithoutCamera;

  const SetSummary({
    required this.lights,
    required this.mainLights,
    required this.cameras,
    required this.when,
    required this.shots,
    required this.shotsWithoutCamera,
  });

  /// «3 luces · Tubo 5600K ×2, Nanlite 60B», o «sin luz».
  String get lightText {
    if (lights == 0) return 'sin luz';
    final count = lights == 1 ? '1 luz' : '$lights luces';
    return mainLights.isEmpty ? count : '$count · ${mainLights.join(', ')}';
  }

  String get cameraText => switch (cameras.length) {
    0 => 'sin cámaras',
    1 => '1 cámara',
    final n => '$n cámaras',
  };

  static SetSummary of(PlanProjectData data, LightSetup setup) {
    final elements = [...data.groupLightOf(setup), ...data.ownOfSetup(setup)];
    final lights = [
      for (final e in elements)
        if (e.type == ElementType.light) e,
    ];
    final names = <String, int>{};
    for (final l in lights) {
      final name = lightName(l);
      names[name] = (names[name] ?? 0) + 1;
    }
    final sorted = names.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final shots = data.shotsOfSetup(setup.id);
    final cameras = <String>{
      for (final e in elements)
        if (e.type == ElementType.camera) e.cameraLetter,
      for (final s in shots) ...data.camerasOfShot(s),
    }.toList()..sort();
    final scenes = data.scenesOfSetup(setup.id);
    String? join(Iterable<String?> values) {
      final set = {
        for (final v in values)
          if (v != null && v.trim().isNotEmpty) v.trim().toUpperCase(),
      };
      return set.isEmpty ? null : set.join('/');
    }

    final when = [
      join(scenes.map((s) => s.intExt)),
      join(scenes.map((s) => s.dayNight)),
    ].whereType<String>().join(' · ');
    return SetSummary(
      lights: lights.length,
      mainLights: [
        for (final e in sorted.take(3))
          e.value > 1 ? '${e.key} ×${e.value}' : e.key,
      ],
      cameras: cameras,
      when: when.isEmpty ? null : when,
      shots: shots.length,
      shotsWithoutCamera: shots
          .where((s) => data.camerasOfShot(s).isEmpty)
          .length,
    );
  }

  /// «Tubo 5600K»: su nombre (o modelo, o tipo) y su temperatura.
  static String lightName(PlanElement light) {
    final base = light.customName ?? light.model ?? light.lightType?.label;
    final tone = PlanLight.of(light)?.colorLabel;
    return [
      if (base != null && base.isNotEmpty) base else 'Luz',
      ?tone,
    ].join(' ');
  }
}
