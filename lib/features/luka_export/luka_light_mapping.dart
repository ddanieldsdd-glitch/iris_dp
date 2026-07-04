import '../../core/database/app_database.dart';
import '../camera_plan/camera_plan_constants.dart';
import '../camera_plan/camera_plan_element_model.dart';
import '../camera_plan/plan_element_compat.dart';

/// Opción de fixture para UI / export.
class LukaFixtureOption {
  final String id;
  final String label;
  final bool fromCatalog;

  const LukaFixtureOption({
    required this.id,
    required this.label,
    this.fromCatalog = false,
  });
}

/// Inferencia y resolución de fixtures ARRI LUKA para luces de planta.
class LukaLightMapping {
  LukaLightMapping._();

  static List<({String id, String label})> get lukaFixtures =>
      PlanElementCompat.lukaFixtures;

  static List<LukaFixtureOption> fixtureOptions(List<Light> catalog) {
    final options = <LukaFixtureOption>[];
    final seen = <String>{};

    for (final light in catalog) {
      if (!light.isLukaCompatible || light.lukaFixtureId == null) continue;
      final id = light.lukaFixtureId!;
      if (seen.add(id)) {
        options.add(LukaFixtureOption(
          id: id,
          label: '${light.brand} ${light.model}',
          fromCatalog: true,
        ));
      }
    }

    for (final f in lukaFixtures) {
      if (seen.add(f.id)) {
        options.add(LukaFixtureOption(id: f.id, label: f.label));
      }
    }

    return options;
  }

  static String? labelForFixtureId(
    String? id, {
    List<Light> catalog = const [],
  }) {
    if (id == null) return null;
    for (final light in catalog) {
      if (light.lukaFixtureId == id) {
        return '${light.brand} ${light.model}';
      }
    }
    return PlanElementCompat.labelForLukaFixture(id);
  }

  static void applyDefaults(
    PlanElement element, {
    List<Light> catalog = const [],
    List<Camera> cameras = const [],
    List<Lense> lenses = const [],
  }) {
    PlanElementCompat.applyAutoMapping(
      element,
      catalog: catalog,
      cameras: cameras,
      lenses: lenses,
    );
  }

  /// Resuelve fixture final: prioriza valores guardados en el elemento.
  static ({bool compatible, String? fixtureId, String source}) resolve(
    PlanElement element, {
    List<Light> catalog = const [],
  }) {
    if (element.type != ElementType.light) {
      return (compatible: false, fixtureId: null, source: 'none');
    }

    if (element.lukaCompatible &&
        element.lukaFixtureId != null &&
        element.lukaFixtureId!.isNotEmpty) {
      return (
        compatible: true,
        fixtureId: element.lukaFixtureId,
        source: 'element',
      );
    }

    final profile = PlanElementCompat.resolve(element, catalog: catalog);
    if (element.lukaCompatible && profile.lukaFixtureId != null) {
      return (
        compatible: true,
        fixtureId: profile.lukaFixtureId,
        source: 'inferred',
      );
    }

    if (profile.luka && profile.lukaFixtureId != null) {
      return (
        compatible: true,
        fixtureId: profile.lukaFixtureId,
        source: 'catalog',
      );
    }

    return (compatible: false, fixtureId: null, source: 'none');
  }

  static ({bool compatible, String? fixtureId}) infer(LightType? type) =>
      PlanElementCompat.inferLukaFixture(type);
}

/// Clasifica el movimiento de cámara para Unreal / secuencias.
String movementKind(String? movement) => PlanElementCompat.movementKind(movement);

bool hasCameraMovement(String? movement, int pathPointCount) {
  if (pathPointCount > 0) return true;
  return movementKind(movement) != 'static';
}
