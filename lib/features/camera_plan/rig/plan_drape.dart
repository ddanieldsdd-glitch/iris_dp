import 'dart:math' as math;
import 'dart:ui';

import '../camera_plan_element_model.dart';
import '../plan_segment.dart';
import 'catenary.dart';

/// Tela de una pared de tela: cuánto pesa y cuánta luz deja pasar.
class DrapeMaterial {
  final String id;
  final String name;

  /// Gramos por metro cuadrado.
  final double gsm;

  /// Parte de la luz que pasa, de 0 a 1. Orientativo.
  final double transmission;

  /// Color de partida (ARGB).
  final int color;

  const DrapeMaterial(
    this.id,
    this.name,
    this.gsm,
    this.transmission,
    this.color,
  );
}

/// Telas de partida. Valores orientativos.
const kDrapeMaterials = <DrapeMaterial>[
  DrapeMaterial('molleton', 'Molletón negro', 500, 0, 0xFF26262C),
  DrapeMaterial('raso', 'Raso / terciopelo', 320, 0.02, 0xFF8C1D2C),
  DrapeMaterial('lona', 'Lona de caseta', 650, 0.05, 0xFFE9E3D6),
  DrapeMaterial('pvc', 'PVC transparente 0,5 mm', 650, 0.85, 0xFF9FC7D6),
  DrapeMaterial('tul', 'Tul / gasa', 60, 0.7, 0xFFD8D2E6),
];

/// Pared de tela o plástico: un tramo de pared ([PlanSegment]) de tipo
/// `drape` que cuelga entre dos amarres. Puede ir recto o curvo en planta;
/// el borde de arriba sigue una catenaria y el bajo cuelga el largo de la
/// tela, o arrastra si llega al suelo.
///
/// Una versión de IRIS que no conoce las telas la lee como una pared.
class PlanDrape {
  PlanDrape._();

  static const kind = 'drape';

  /// Altura de cada amarre, en metros: `[inicio, final]`.
  static const anchorsKey = 'anchorsZ';

  /// Flecha en el centro, en metros.
  static const sagKey = 'sagM';

  /// Largo de la cuerda, en metros. Si está, manda sobre la flecha.
  static const ropeKey = 'ropeM';

  /// Largo de la tela desde la cuerda, en metros.
  static const lengthKey = 'lengthM';

  /// Frunce: 0 = lisa, 1 = el doble de tela que de luz.
  static const fullnessKey = 'fullness';
  static const materialKey = 'material';
  static const colorKey = 'color';

  static const double defaultAnchorM = 3;
  static const double defaultSagM = 0.3;
  static const double defaultLengthM = 3;
  static const double defaultFullness = 0.5;

  static bool isDrape(PlanElement el) =>
      PlanSegment.isSegment(el) && PlanSegment.kind(el) == kind;

  static PlanElement create(
    Offset start,
    Offset end, {
    double anchorM = defaultAnchorM,
    double sagM = defaultSagM,
    double lengthM = defaultLengthM,
    double fullness = defaultFullness,
    String material = 'molleton',
  }) {
    final el = PlanSegment.create(start: start, end: end);
    el.props.addAll({
      'kind': kind,
      anchorsKey: [anchorM, anchorM],
      sagKey: sagM,
      lengthKey: lengthM,
      fullnessKey: fullness,
      materialKey: material,
    });
    return el;
  }

  static (double, double) anchors(PlanElement el) {
    final raw = el.props[anchorsKey];
    if (raw is List && raw.isNotEmpty) {
      final a = (raw.first as num).toDouble();
      final b = (raw.length > 1 ? raw[1] as num : raw.first as num).toDouble();
      return (a, b);
    }
    return (defaultAnchorM, defaultAnchorM);
  }

  static double lengthM(PlanElement el) =>
      (el.props[lengthKey] as num?)?.toDouble() ?? defaultLengthM;

  static double fullness(PlanElement el) =>
      ((el.props[fullnessKey] as num?)?.toDouble() ?? defaultFullness).clamp(
        0.0,
        2.0,
      );

  static DrapeMaterial material(PlanElement el) => kDrapeMaterials.firstWhere(
    (m) => m.id == el.props[materialKey],
    orElse: () => kDrapeMaterials.first,
  );

  static Color color(PlanElement el) {
    final hex = el.props[colorKey];
    if (hex is String && hex.length >= 7) {
      final v = int.tryParse(hex.substring(1, 7), radix: 16);
      if (v != null) return Color(0xFF000000 | v);
    }
    return Color(material(el).color);
  }

  /// Luz de la cuerda: lo que mide el tramo en planta, en metros.
  static double spanM(PlanElement el, double metersPerUnit) =>
      PlanSegment.length(el) * metersPerUnit;

  /// La catenaria de la cuerda: de la flecha guardada o, si hay largo de
  /// cuerda, de ese largo.
  static Catenary catenary(PlanElement el, double metersPerUnit) {
    final span = spanM(el, metersPerUnit);
    final rope = (el.props[ropeKey] as num?)?.toDouble();
    if (rope != null) return Catenary.fromRope(span, rope);
    return Catenary.fromSag(
      span,
      (el.props[sagKey] as num?)?.toDouble() ?? defaultSagM,
    );
  }

  /// Fija la flecha y borra el largo de cuerda.
  static void setSag(PlanElement el, double sagM) {
    el.props[sagKey] = sagM;
    el.props.remove(ropeKey);
  }

  /// Altura del borde de arriba a `t` (0–1) del tramo.
  static double topAt(PlanElement el, double t, Catenary c) {
    final (a, b) = anchors(el);
    return a + (b - a) * t + c.dropAt(t);
  }

  /// Altura del bajo a `t`: el borde de arriba menos el largo de la tela,
  /// nunca por debajo del suelo.
  static double bottomAt(PlanElement el, double t, Catenary c) =>
      math.max(0, topAt(el, t, c) - lengthM(el));

  /// Lo que se queda arrastrando en el peor punto, en metros (0 si no
  /// toca el suelo).
  static double poolM(PlanElement el, Catenary c) {
    var pool = 0.0;
    for (var i = 0; i <= 40; i++) {
      pool = math.max(pool, lengthM(el) - topAt(el, i / 40, c));
    }
    return pool;
  }

  /// Altura libre más baja bajo la tela (0 si toca el suelo).
  static double clearanceM(PlanElement el, Catenary c) {
    var low = double.infinity;
    for (var i = 0; i <= 40; i++) {
      low = math.min(low, bottomAt(el, i / 40, c));
    }
    return low;
  }

  /// Caída media de la tela, en metros.
  static double meanDropM(PlanElement el, Catenary c) {
    var sum = 0.0;
    for (var i = 0; i <= 40; i++) {
      sum += topAt(el, i / 40, c) - bottomAt(el, i / 40, c);
    }
    return sum / 41;
  }

  /// Tela necesaria, en m², con el frunce.
  static double areaM2(PlanElement el, Catenary c) =>
      meanDropM(el, c) * c.rope * (1 + fullness(el));

  static double weightKg(PlanElement el, Catenary c) =>
      areaM2(el, c) * material(el).gsm / 1000;

  /// Peso de la tela por metro de luz, en kg: lo que carga la cuerda.
  static double loadPerMeterKg(PlanElement el, Catenary c) =>
      c.span <= 0 ? 0 : weightKg(el, c) / c.span;
}
