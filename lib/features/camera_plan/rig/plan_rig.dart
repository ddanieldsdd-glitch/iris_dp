import 'dart:math' as math;
import 'dart:ui';

import '../camera_plan_constants.dart';
import '../camera_plan_element_model.dart';
import '../light/plan_light.dart';
import '../light_overrides.dart';

/// Estructuras de una nave: la receta, el truss, sus puntos de cuelgue, los
/// pilares y los escaneos.
///
/// Todos se guardan como `prop` con su tipo en `label`. Así una versión de
/// IRIS que no los conoce los lee como atrezzo y los conserva al guardar.
enum RigType {
  /// Receta de una nave hecha con el constructor ([PlanHall]).
  hall,
  truss,
  motor,
  groundSupport,
  pillar,
  scan,
}

extension RigTypeCodec on RigType {
  String get dbValue => name;

  String get label => switch (this) {
    RigType.hall => 'Nave',
    RigType.truss => 'Truss',
    RigType.motor => 'Motor',
    RigType.groundSupport => 'Ground support',
    RigType.pillar => 'Pilar',
    RigType.scan => 'Escaneo',
  };

  /// El tipo de estructura de un elemento, o `null` si no lo es.
  static RigType? of(PlanElement el) {
    if (el.type != ElementType.prop) return null;
    for (final t in RigType.values) {
      if (t.dbValue == el.label) return t;
    }
    return null;
  }

  static PlanElement create(
    RigType type,
    Offset position, {
    Map<String, dynamic>? props,
  }) => PlanElement(
    id: 0,
    type: ElementType.prop,
    position: position,
    label: type.dbValue,
    props: props,
  );
}

/// Cota del suelo sobre el que está un elemento, en metros. Deja preparada
/// una entreplanta o un escenario a otro nivel: todas las alturas del
/// elemento (cuelgue, alféizar, cuerda inferior) se miden desde aquí.
class PlanLevel {
  PlanLevel._();

  static const key = 'levelM';

  static double of(PlanElement el) => (el.props[key] as num?)?.toDouble() ?? 0;

  static void set(PlanElement el, double meters) {
    if (meters == 0) {
      el.props.remove(key);
    } else {
      el.props[key] = meters;
    }
  }
}

/// Pilar suelto: redondo o cuadrado, con su altura. Tapa la luz.
class PlanPillar {
  PlanPillar._();

  static const shapeKey = 'shape';
  static const round = 'round';
  static const square = 'square';

  /// Diámetro o lado, en metros.
  static const sizeKey = 'sizeM';
  static const heightKey = 'heightM';

  static const double defaultSizeM = 0.3;
  static const double defaultHeightM = 3;

  static bool isPillar(PlanElement el) => RigTypeCodec.of(el) == RigType.pillar;

  static PlanElement create(
    Offset position, {
    String shape = square,
    double sizeM = defaultSizeM,
    double heightM = defaultHeightM,
  }) => RigTypeCodec.create(
    RigType.pillar,
    position,
    props: {shapeKey: shape, sizeKey: sizeM, heightKey: heightM},
  );

  static bool isRound(PlanElement el) => el.props[shapeKey] == round;

  static double sizeM(PlanElement el) =>
      (el.props[sizeKey] as num?)?.toDouble() ?? defaultSizeM;

  static double heightM(PlanElement el) =>
      (el.props[heightKey] as num?)?.toDouble() ?? defaultHeightM;
}

/// Perfil de un truss.
enum TrussProfile { square, triangle, ladder }

/// Truss: un tramo recto a una altura. Su inicio es `position` y su final
/// va relativo en `props` (`dx`, `dy`), como un tramo de pared; así moverlo
/// mueve el tramo entero. Para una esquina se usan dos truss.
class PlanTruss {
  PlanTruss._();

  static const profileKey = 'profile';

  /// Tamaño nominal en centímetros: 30, 40 o 52.
  static const sizeKey = 'sizeCm';

  /// Altura de la cuerda inferior sobre el suelo de su nivel, en metros.
  static const lowKey = 'lowM';

  /// Tramos en metros, si no son los que salen solos (ver [pieces]).
  static const piecesKey = 'pieces';

  /// Triangular con el vértice hacia abajo.
  static const apexDownKey = 'apexDown';

  static const double defaultLowM = 5;
  static const int defaultSizeCm = 30;

  /// Largos de tramo de catálogo, del más largo al más corto.
  static const standardPieces = <double>[4, 3, 2.5, 2, 1.5, 1, 0.5];

  /// Peso orientativo por metro, en kg. La ficha del fabricante manda.
  static double kgPerMeter(TrussProfile profile, int sizeCm) =>
      switch ((profile, sizeCm >= 40)) {
        (TrussProfile.triangle, false) => 3.9,
        (TrussProfile.triangle, true) => 5.1,
        (TrussProfile.ladder, _) => 2.6,
        (_, false) => 5.0,
        (_, true) => 6.6,
      };

  /// Medida exterior real, en metros (un 30 mide 29 cm entre ejes).
  static double outerM(int sizeCm) => (sizeCm - 1) / 100;

  static bool isTruss(PlanElement el) => RigTypeCodec.of(el) == RigType.truss;

  static PlanElement create(
    Offset start,
    Offset end, {
    TrussProfile profile = TrussProfile.square,
    int sizeCm = defaultSizeCm,
    double lowM = defaultLowM,
  }) => RigTypeCodec.create(
    RigType.truss,
    start,
    props: {
      'dx': end.dx - start.dx,
      'dy': end.dy - start.dy,
      profileKey: profile.name,
      sizeKey: sizeCm,
      lowKey: lowM,
    },
  );

  static TrussProfile profile(PlanElement el) => TrussProfile.values.firstWhere(
    (p) => p.name == el.props[profileKey],
    orElse: () => TrussProfile.square,
  );

  static int sizeCm(PlanElement el) =>
      (el.props[sizeKey] as num?)?.toInt() ?? defaultSizeCm;

  static double lowM(PlanElement el) =>
      (el.props[lowKey] as num?)?.toDouble() ?? defaultLowM;

  /// Alto de la sección, en metros.
  static double depthM(PlanElement el) {
    final outer = outerM(sizeCm(el));
    return switch (profile(el)) {
      TrussProfile.triangle => outer * math.sqrt(3) / 2,
      TrussProfile.ladder => 0.05,
      TrussProfile.square => outer,
    };
  }

  static Offset start(PlanElement el) => el.position;

  static Offset end(PlanElement el) =>
      el.position +
      Offset(
        (el.props['dx'] as num?)?.toDouble() ?? 0,
        (el.props['dy'] as num?)?.toDouble() ?? 0,
      );

  static void setEnd(PlanElement el, Offset end) {
    el.props['dx'] = end.dx - el.position.dx;
    el.props['dy'] = end.dy - el.position.dy;
  }

  static Offset pointAt(PlanElement el, double t) =>
      Offset.lerp(start(el), end(el), t)!;

  static double length(PlanElement el) => (end(el) - start(el)).distance;

  /// Distancia del lienzo de un punto al eje del truss.
  static double distanceTo(PlanElement el, Offset p) {
    final a = start(el), ab = end(el) - a;
    final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
    if (len2 == 0) return (p - a).distance;
    final t = (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(
      0.0,
      1.0,
    );
    return (p - (a + ab * t)).distance;
  }

  /// Pone el largo del truss en metros sin cambiar su inicio ni su
  /// dirección.
  static void setLengthM(PlanElement el, double meters, double metersPerUnit) {
    final d = end(el) - start(el);
    final dir = d.distance == 0 ? const Offset(1, 0) : d / d.distance;
    setEnd(el, start(el) + dir * (meters / metersPerUnit));
  }

  /// Tramos en metros: los guardados o, si no hay, los de catálogo que
  /// cubren el largo de mayor a menor. `rest` es lo que queda sin cubrir.
  static ({List<double> pieces, double rest}) pieces(
    PlanElement el,
    double metersPerUnit,
  ) {
    final stored = el.props[piecesKey];
    final lengthM = length(el) * metersPerUnit;
    if (stored is List && stored.isNotEmpty) {
      final list = [for (final p in stored) (p as num).toDouble()];
      final sum = list.fold<double>(0, (a, b) => a + b);
      return (pieces: list, rest: math.max(0, lengthM - sum));
    }
    return breakdown(lengthM);
  }

  /// Parte un largo en tramos de catálogo, de mayor a menor.
  static ({List<double> pieces, double rest}) breakdown(double lengthM) {
    final out = <double>[];
    var rest = lengthM + 1e-6;
    for (final p in standardPieces) {
      while (rest >= p) {
        out.add(p);
        rest -= p;
      }
    }
    return (pieces: out, rest: rest < 0.01 ? 0 : rest);
  }
}

/// Motor de cadena o torre de ground support que sujeta un truss.
class PlanRigPoint {
  PlanRigPoint._();

  /// `uid` del truss que sujeta.
  static const trussKey = 'trussUid';

  /// Metros desde el inicio del truss.
  static const alongKey = 'alongM';

  /// Carga máxima de trabajo, en kg.
  static const wllKey = 'wllKg';

  static double wllKg(PlanElement el) =>
      (el.props[wllKey] as num?)?.toDouble() ??
      (RigTypeCodec.of(el) == RigType.groundSupport ? 750 : 500);

  static bool isRigPoint(PlanElement el) => switch (RigTypeCodec.of(el)) {
    RigType.motor || RigType.groundSupport => true,
    _ => false,
  };

  static PlanElement create(
    RigType type,
    PlanElement truss,
    double t,
    double metersPerUnit,
  ) {
    LightOverrides.ensureUids([truss]);
    return RigTypeCodec.create(
      type,
      PlanTruss.pointAt(truss, t),
      props: {
        trussKey: LightOverrides.uidOf(truss),
        alongKey: t * PlanTruss.length(truss) * metersPerUnit,
      },
    );
  }
}

/// Carga de cada punto de cuelgue, en kg: el peso del truss por tramos
/// entre puntos y el de cada luz colgada, repartido por palanca entre los
/// dos puntos que la rodean. Orientativo: la carga real la da el rigger.
class RigLoads {
  RigLoads._();

  /// Peso de una luz colgada, si la ficha no lo dice.
  static const weightKey = 'weightKg';
  static const double defaultLightKg = 10;

  /// `uid` del punto → kg.
  static Map<String, double> of(
    List<PlanElement> elements,
    double metersPerUnit,
  ) {
    final loads = <String, double>{};
    for (final truss in elements.where(PlanTruss.isTruss)) {
      final uid = LightOverrides.uidOf(truss);
      if (uid == null) continue;
      final lengthM = PlanTruss.length(truss) * metersPerUnit;
      final points = [
        for (final el in elements)
          if (PlanRigPoint.isRigPoint(el) &&
              el.props[PlanRigPoint.trussKey] == uid &&
              LightOverrides.uidOf(el) != null)
            (
              LightOverrides.uidOf(el)!,
              (el.props[PlanRigPoint.alongKey] as num?)?.toDouble() ?? 0,
            ),
      ]..sort((a, b) => a.$2.compareTo(b.$2));
      if (points.isEmpty) continue;
      for (final p in points) {
        loads.putIfAbsent(p.$1, () => 0);
      }
      final kgm = PlanTruss.kgPerMeter(
        PlanTruss.profile(truss),
        PlanTruss.sizeCm(truss),
      );
      void spread(double along, double kg) {
        if (points.length == 1) {
          loads[points.first.$1] = loads[points.first.$1]! + kg;
          return;
        }
        var j = 0;
        while (j < points.length - 2 && along > points[j + 1].$2) {
          j++;
        }
        final a = points[j], b = points[j + 1];
        final span = b.$2 - a.$2;
        final s = span <= 0 ? 0.5 : ((along - a.$2) / span).clamp(0.0, 1.0);
        loads[a.$1] = loads[a.$1]! + kg * (1 - s);
        loads[b.$1] = loads[b.$1]! + kg * s;
      }

      // El truss, por trozos de 0,5 m.
      final pieces = math.max(1, (lengthM / 0.5).ceil());
      for (var k = 0; k < pieces; k++) {
        spread((k + 0.5) * lengthM / pieces, kgm * lengthM / pieces);
      }
      for (final light in elements) {
        if (light.type != ElementType.light) continue;
        final rig = TrussMagnet.rigOf(light);
        if (rig == null || rig[PlanRigPoint.trussKey] != uid) continue;
        spread(
          (rig[PlanRigPoint.alongKey] as num?)?.toDouble() ?? 0,
          (light.props[weightKey] as num?)?.toDouble() ?? defaultLightKg,
        );
      }
    }
    return loads;
  }
}

/// Engancha luces a un truss: al soltar una luz cerca de un truss queda
/// colgada de él, a la altura que da el truss.
///
/// La luz sigue siendo una luz colgada normal (`mount: ceiling` con su
/// `height`), así que el motor de luz la calcula como siempre. En `rig`
/// guarda de qué truss cuelga y dónde, para seguirlo si el truss se mueve.
class TrussMagnet {
  TrussMagnet._();

  static const rigKey = 'rig';

  /// Lo que cuelga el aparato por debajo de la cuerda inferior: garra y
  /// horquilla, en metros.
  static const double defaultDropM = 0.35;

  /// Distancia del lienzo a la que una luz se engancha al soltarla.
  static const double snapDistance = 50;

  static Map<String, dynamic>? rigOf(PlanElement el) {
    final rig = el.props[rigKey];
    return rig is Map ? Map<String, dynamic>.from(rig) : null;
  }

  static String? trussUidOf(PlanElement light) =>
      rigOf(light)?[PlanRigPoint.trussKey] as String?;

  /// El truss más cercano a un punto y dónde cae sobre él.
  static ({PlanElement truss, double t, Offset point, double distance})?
  nearest(
    Offset p,
    Iterable<PlanElement> elements, {
    double within = snapDistance,
  }) {
    ({PlanElement truss, double t, Offset point, double distance})? best;
    for (final el in elements) {
      if (!PlanTruss.isTruss(el)) continue;
      final a = PlanTruss.start(el), ab = PlanTruss.end(el) - a;
      final len2 = ab.dx * ab.dx + ab.dy * ab.dy;
      final t = len2 == 0
          ? 0.0
          : (((p.dx - a.dx) * ab.dx + (p.dy - a.dy) * ab.dy) / len2).clamp(
              0.0,
              1.0,
            );
      final foot = a + ab * t;
      final d = (p - foot).distance;
      if (d <= within && (best == null || d < best.distance)) {
        best = (truss: el, t: t, point: foot, distance: d);
      }
    }
    return best;
  }

  /// Cuelga la luz del truss en `t` (0–1).
  static void hang(
    PlanElement light,
    PlanElement truss,
    double t,
    double metersPerUnit, {
    double? dropM,
  }) {
    LightOverrides.ensureUids([truss]);
    final drop = dropM ?? (rigOf(light)?['dropM'] as num?)?.toDouble();
    light
      ..position = PlanTruss.pointAt(truss, t)
      ..props[rigKey] = {
        PlanRigPoint.trussKey: LightOverrides.uidOf(truss),
        PlanRigPoint.alongKey: t * PlanTruss.length(truss) * metersPerUnit,
        'dropM': ?drop,
      }
      ..props[PlanLight.mountKey] = PlanLight.mountCeiling
      ..props[PlanLight.heightKey] =
          PlanTruss.lowM(truss) - (drop ?? defaultDropM);
    PlanLevel.set(light, PlanLevel.of(truss));
  }

  /// Engancha la luz al truss más cercano. Devuelve si se ha enganchado;
  /// si no, y estaba colgada de un truss, la descuelga (queda colgada a la
  /// misma altura, ya sin truss).
  static bool snap(
    PlanElement light,
    Iterable<PlanElement> elements,
    double metersPerUnit,
  ) {
    if (light.type != ElementType.light) return false;
    final hit = nearest(light.position, elements);
    if (hit == null) {
      light.props.remove(rigKey);
      return false;
    }
    hang(light, hit.truss, hit.t, metersPerUnit);
    return true;
  }

  /// Vuelve a colocar lo que cuelga de un truss después de moverlo o
  /// cambiarle la altura: luces, motores y torres. Lo que cuelga de un
  /// truss que ya no existe se suelta.
  static void follow(List<PlanElement> elements, double metersPerUnit) {
    final trusses = <String, PlanElement>{
      for (final el in elements)
        if (PlanTruss.isTruss(el) && LightOverrides.uidOf(el) != null)
          LightOverrides.uidOf(el)!: el,
    };
    for (final el in elements) {
      if (el.type == ElementType.light) {
        final rig = rigOf(el);
        if (rig == null) continue;
        final truss = trusses[rig[PlanRigPoint.trussKey]];
        if (truss == null) {
          el.props.remove(rigKey);
          continue;
        }
        hang(el, truss, _tOf(truss, rig, metersPerUnit), metersPerUnit);
      } else if (PlanRigPoint.isRigPoint(el)) {
        final truss = trusses[el.props[PlanRigPoint.trussKey]];
        if (truss == null) continue;
        el.position = PlanTruss.pointAt(
          truss,
          _tOf(truss, el.props, metersPerUnit),
        );
      }
    }
  }

  static double _tOf(
    PlanElement truss,
    Map<String, dynamic> rig,
    double metersPerUnit,
  ) {
    final lengthM = PlanTruss.length(truss) * metersPerUnit;
    if (lengthM <= 0) return 0;
    final along = (rig[PlanRigPoint.alongKey] as num?)?.toDouble() ?? 0;
    return (along / lengthM).clamp(0.0, 1.0);
  }
}
