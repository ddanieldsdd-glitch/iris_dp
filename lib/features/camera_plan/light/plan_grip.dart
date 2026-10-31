import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import 'light_scene.dart';
import 'plan_light.dart';

/// Formato de un marco o un palio (F6.22.1): el marco (1×1 o 2×1, de
/// madera, con gelatina o tela de difusión) y el palio (2×2 a 6×6, el único
/// que lleva telas grandes o rebotes como el Cinebounce).
enum GripFormat {
  frame1x1('Marco 1×1', 1, 1, palio: false),
  frame2x1('Marco 2×1', 2, 1, palio: false),
  palio2('Palio 2×2', 2, 2),
  palio3('Palio 3×3', 3, 3),
  palio4('Palio 4×4', 4, 4),
  palio6('Palio 6×6', 6, 6);

  final String label;
  final double widthM;
  final double heightM;
  final bool palio;
  const GripFormat(this.label, this.widthM, this.heightM, {this.palio = true});

  static GripFormat? parse(Object? name) =>
      values.where((f) => f.name == name).firstOrNull;
}

/// Medidas y altura del grip: negro, corte, rebote, marco o palio. Sin
/// medidas propias, las de siempre, para que una planta de antes mida y se
/// vea igual.
abstract final class PlanGrip {
  static const formatKey = 'gripFormat';

  /// Alto de la tela, en metros.
  static const heightKey = 'gripH';

  /// Altura del centro de la tela sobre el suelo, en metros.
  static const centreKey = 'gripZ';

  /// Inclinación de la tela, en grados: 0 vertical (de pie), 90 horizontal
  /// (un palio sobre las cabezas). Se inclina hacia su cara delantera.
  static const tiltKey = 'gripTilt';

  static double tiltDeg(PlanElement el) =>
      ((el.props[tiltKey] as num?)?.toDouble() ?? 0).clamp(0.0, 90.0);

  /// A partir de 1° se calcula como panel inclinado, en 3D.
  static bool isTilted(PlanElement el) => tiltDeg(el) >= 1;

  /// Si se puede inclinar: marcos, palios, rebotes y negros.
  static bool canTilt(PlanElement el) => switch (el.lightType) {
    LightType.diffusionFrame ||
    LightType.bounce ||
    LightType.flag ||
    LightType.cutter => true,
    _ => false,
  };

  /// Altura del centro de la tela sobre su suelo.
  static double centreM(PlanElement el, double metersPerUnit) {
    final s = span(el, metersPerUnit);
    if (el.props[centreKey] case final num c) return c.toDouble();
    return (s.bottom + s.top) / 2;
  }

  static bool isGrip(PlanElement el) =>
      el.type == ElementType.light &&
      switch (el.lightType) {
        LightType.flag ||
        LightType.cutter ||
        LightType.bounce ||
        LightType.diffusionFrame ||
        LightType.net ||
        LightType.gel => true,
        _ => false,
      };

  /// Si lleva tela o rebote, que es lo único que puede ser un palio.
  static bool takesFormat(PlanElement el) =>
      el.lightType == LightType.diffusionFrame ||
      el.lightType == LightType.bounce;

  static GripFormat? formatOf(PlanElement el) =>
      GripFormat.parse(el.props[formatKey]);

  /// Si el usuario le ha dado medidas o altura: entonces se usan tal cual.
  static bool hasOwnSize(PlanElement el) =>
      el.props[heightKey] is num || el.props[centreKey] is num;

  static double widthM(PlanElement el, double metersPerUnit) =>
      LightScene.lengthOf(el) * metersPerUnit;

  /// Alto de la tela. Sin medida propia: cuadrada en marcos y rebotes; los
  /// negros, de 2,5 m como siempre.
  static double heightM(PlanElement el, double metersPerUnit) {
    if (el.props[heightKey] case final num h) return h.toDouble();
    return switch (el.lightType) {
      LightType.diffusionFrame || LightType.bounce => widthM(el, metersPerUnit),
      _ => LightScene.wallHeightM,
    };
  }

  /// Desde dónde y hasta dónde tapa, en metros sobre su suelo.
  static ({double bottom, double top}) span(
    PlanElement el,
    double metersPerUnit,
  ) {
    final h = heightM(el, metersPerUnit);
    if (el.props[centreKey] case final num c) {
      final bottom = (c.toDouble() - h / 2).clamp(0.0, 50.0);
      return (bottom: bottom, top: bottom + h);
    }
    if (hasOwnSize(el) || el.lightType == LightType.diffusionFrame) {
      // Centrado a la altura de la cara, sin bajar del suelo.
      final bottom = (PlanLight.subjectHeightM - h / 2).clamp(0.0, 50.0);
      return (bottom: bottom, top: bottom + h);
    }
    // Negros, cortes y rebotes de antes: desde el suelo hasta 2,5 m.
    return (bottom: 0.0, top: LightScene.wallHeightM);
  }

  /// Le pone el formato [f]: ancho (el largo en planta) y alto.
  static void applyFormat(
    PlanElement el,
    GripFormat f,
    double metersPerUnit,
  ) {
    el.props[formatKey] = f.name;
    el.props[LightScene.lenKey] = f.widthM / metersPerUnit;
    el.props[heightKey] = f.heightM;
  }
}
