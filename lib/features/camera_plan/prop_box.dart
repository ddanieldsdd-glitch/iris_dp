import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light/light_scene.dart';

/// Formas del «Rectángulo» (CA.7, CA.8): una caja a medida, un poyete,
/// la barra de un bar o una estantería con botellas de cristal. Todas son
/// una caja para la luz; en el 3D y en Unreal se dibujan con su forma.
class PropBox {
  PropBox._();

  static const shapeKey = 'boxShape';
  static const bottlesKey = 'bottles';

  static const box = 'box';
  static const ledge = 'ledge';
  static const bar = 'bar';
  static const shelf = 'shelf';

  /// Nombre, forma, ancho, fondo, alto y si lleva botellas.
  static const presets = <(String, String, double, double, double, bool)>[
    ('Caja', box, 1, 1, 1, false),
    ('Poyete', ledge, 1, 1, 1, false),
    ('Barra de bar', bar, 3, 0.6, 1.1, false),
    ('Estantería con botellas', shelf, 2, 0.3, 2, true),
  ];

  /// Medidas máximas en el panel: un poyete o una barra pueden ser largos.
  static const double maxLengthM = 30;

  static bool isBox(PlanElement el) =>
      el.type == ElementType.prop && el.propType == PropType.rectangle;

  static String shapeOf(PlanElement el) => el.props[shapeKey] as String? ?? box;

  static bool hasBottles(PlanElement el) => el.props[bottlesKey] == true;

  /// Pone la forma [shape] con sus medidas de partida y su nombre (si no
  /// tenía uno propio o era el de otra forma).
  static void apply(PlanElement el, String shape) {
    final p = presets.firstWhere((p) => p.$2 == shape);
    final names = {for (final q in presets) q.$1};
    el.props
      ..[shapeKey] = shape
      ..[LightScene.widthKey] = p.$3
      ..[LightScene.depthKey] = p.$4
      ..[LightScene.heightKey] = p.$5
      ..[bottlesKey] = p.$6;
    final own = el.customName;
    if (own == null || names.contains(own)) {
      el.customName = shape == box ? null : p.$1;
    }
  }
}
