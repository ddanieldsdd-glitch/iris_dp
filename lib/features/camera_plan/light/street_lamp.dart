import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import '../light_beam.dart';
import 'photometry.dart';
import 'plan_light.dart';
import 'wall_mount.dart';

/// Farola de la calle (CA.5): una luz práctica de la localización, no un
/// aparato de rodaje. De brazo pegada a la fachada (lo típico en el Raval)
/// o de báculo, a 4–5 m, cálida y con el kelvin que tenga de verdad.
class StreetLamp {
  StreetLamp._();

  static const fixtureKey = 'fixture';
  static const fixtureValue = 'streetLamp';

  /// `arm` (brazo en la fachada) o `pole` (báculo).
  static const styleKey = 'lampStyle';
  static const styleArm = 'arm';
  static const stylePole = 'pole';

  static const double defaultHeightM = 4.5;
  static const double defaultKelvin = 2700;

  /// Unos 6000 lm: un LED de alumbrado de calle estrecha.
  static const double defaultWatts = 60;

  /// Lo que suele haber en la calle.
  static const kelvinPresets = <(String, double)>[
    ('Sodio', 2000),
    ('LED cálido', 3000),
    ('LED neutro', 4000),
  ];

  /// Nombres en la paleta.
  static const armName = 'Farola de brazo';
  static const poleName = 'Farola de báculo';

  static bool isOn(PlanElement el) =>
      el.type == ElementType.light && el.props[fixtureKey] == fixtureValue;

  static bool isPole(PlanElement el) => el.props[styleKey] == stylePole;

  /// El estilo que corresponde a un nombre de la paleta, o null.
  static String? styleForName(String? name) => switch (name) {
    armName => styleArm,
    poleName => stylePole,
    _ => null,
  };

  /// Convierte [el] en farola en su sitio: práctica, a 4,5 m, mirando al
  /// suelo con un haz ancho y, la de brazo, pegada a la pared.
  static void apply(PlanElement el, {String style = styleArm}) {
    el.lightType = LightType.practical;
    // Su nombre, salvo que ya tenga uno propio.
    final own = el.customName;
    if (own == null || own == armName || own == poleName) {
      el.customName = style == stylePole ? poleName : armName;
    }
    el.props
      ..[fixtureKey] = fixtureValue
      ..[styleKey] = style
      ..[PlanLight.heightKey] = defaultHeightM
      ..[PlanLight.wattsKey] = defaultWatts
      ..[PlanLight.techKey] = LightTech.led.name
      ..[LightBeam.cctKey] = defaultKelvin
      ..[LightBeam.spreadKey] = 140.0
      ..remove(PlanLight.sizeKey);
    PlanLight.setElevation(el, -90);
    if (style == styleArm) {
      el.props[PlanLight.mountKey] = PlanLight.mountWall;
    } else {
      el.props.remove(PlanLight.mountKey);
      el.props.remove(LightWallMount.tubeAxisKey);
    }
  }
}
