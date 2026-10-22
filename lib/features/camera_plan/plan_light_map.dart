import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'camera_plan_constants.dart';
import 'camera_plan_element_model.dart';
import 'light/ambient.dart';
import 'light/light_scene.dart';
import 'light_beam.dart';

/// Contra qué se mide el brillo con que se pinta la luz.
enum LightView {
  /// Como la vería la cámara: lo bien expuesto al diafragma de trabajo
  /// sale a media luz, lo que sobra se quema y lo que falta se apaga. Una
  /// práctica y un 5K conservan los stops que los separan.
  camera,

  /// Todo a la vista: lo más iluminado de la planta sale al máximo, sea lo
  /// que sea, y bajo techo el brillo se adapta un poco. Sirve para ver
  /// hasta dónde llega cada luz, no cuánta es.
  all,
}

extension LightViewLabel on LightView {
  String get label => switch (this) {
    LightView.camera => 'Exposición de la cámara',
    LightView.all => 'Ver todo',
  };
}

/// La luz de la planta calculada punto a punto: cuánta llega a cada sitio,
/// sumando todas las fuentes (aparatos, telas, rebotes, sol y cielo) y
/// contando lo que las tapa.
///
/// Es lo que se pinta en el lienzo. A diferencia de dibujar un haz por
/// fuente y sumarlos, aquí la luz que ya es mucha no se pisa a sí misma:
/// el rebote de una pared al sol apenas se nota donde ya da el sol, y la
/// luz blanda de una cortina se ve como lo que es, un degradado que sale
/// de la ventana.
class PlanLightMap {
  /// Zona de la planta que cubre, en unidades del lienzo.
  final Rect rect;
  final int columns;
  final int rows;

  /// Lux en cada cruce de la rejilla, fila a fila.
  final Float32List lux;

  /// Temperatura de color de la mezcla en cada cruce.
  final Float32List cct;

  /// Lux que se pintan con todo el brillo: lo más iluminado de la planta.
  final double keyLux;

  /// Lo mismo bajo techo. Dentro, el ojo se acostumbra a menos luz: con
  /// sol fuera, la luz blanda de una cortina se seguiría viendo.
  final double indoorKeyLux;

  /// Qué cruces de la rejilla están bajo techo.
  final Uint8List indoor;

  /// Lux al aire libre y sin nada delante, para lo que cae fuera de [rect].
  final double openLux;
  final double openCct;

  /// Por debajo de estos lux no se comprobó qué tapa la luz: se dio por
  /// nada.
  final double cutoff;

  PlanLightMap._({
    required this.rect,
    required this.columns,
    required this.rows,
    required this.lux,
    required this.cct,
    required this.keyLux,
    required this.indoorKeyLux,
    required this.indoor,
    required this.openLux,
    required this.openCct,
    required this.cutoff,
  });

  /// Stops por debajo de [keyLux] que todavía se ven.
  static const double rangeStops = 8;

  /// Lo más que tapa la luz al lienzo: por encima, las paredes y los
  /// rótulos (claros) dejarían de leerse.
  static const double maxAlpha = 0.55;

  /// Stops que puede bajar la luz bajo techo, en «Ver todo», respecto a lo
  /// más iluminado de la planta. Sin tope, una lámpara en un cuarto
  /// cerrado se vería tan fuerte como el sol de fuera.
  static const double indoorAdaptStops = 3;

  /// Brillo con el que se pinta una cantidad de luz en «Ver todo», de 0 a
  /// 1: [keyLux] sale al máximo.
  static double brightnessFor(double lux, double keyLux) {
    if (lux <= 0 || keyLux <= 0) return 0;
    final stops = math.log(lux / keyLux) / math.ln2;
    final v = ((stops + rangeStops) / rangeStops).clamp(0.0, 1.0);
    // Curva contrastada: dos stops de caída se ven.
    return math.pow(v, 2.0).toDouble();
  }

  // Exposición de la cámara.

  /// Stops por debajo del diafragma de trabajo que aún se ven: más abajo,
  /// en el monitor ya es negro.
  static const double underStops = 6;

  /// Stops por encima del diafragma de trabajo a los que la luz se quema
  /// del todo.
  static const double clipStops = 3;

  /// Brillo de lo que está justo bien expuesto. Lo que sobra va de aquí a
  /// 1, y además se blanquea: así lo quemado no se confunde con lo bueno.
  static const double exposedLevel = 0.62;

  /// Lo más que tapa la luz quemada. Lo bien expuesto se queda en
  /// [exposedLevel] × esto, por debajo del tope de «Ver todo».
  static const double maxExposedAlpha = 0.6;

  /// Brillo con el que se pinta una cantidad de luz a la exposición de la
  /// cámara, de 0 a 1. [keyLux] son los lux que dan el diafragma de
  /// trabajo.
  static double exposedBrightness(double lux, double keyLux) {
    final stops = stopsOver(lux, keyLux);
    if (stops == null || stops <= -underStops) return 0;
    if (stops <= 0) {
      final v = (stops + underStops) / underStops;
      return math.pow(v, 1.5).toDouble() * exposedLevel;
    }
    return exposedLevel +
        (1 - exposedLevel) * (stops / clipStops).clamp(0.0, 1.0);
  }

  /// Cuánto se blanquea la luz por sobrar, de 0 (bien expuesta o menos) a
  /// 1 (quemada).
  static double burnFor(double lux, double keyLux) {
    final stops = stopsOver(lux, keyLux);
    if (stops == null || stops <= 0) return 0;
    return (stops / clipStops).clamp(0.0, 1.0);
  }

  static double? stopsOver(double lux, double keyLux) {
    if (lux <= 0 || keyLux <= 0) return null;
    return math.log(lux / keyLux) / math.ln2;
  }

  /// Lo que se da por nada al pintar a la exposición de la cámara.
  static double cutoffForExposure(double keyLux) =>
      keyLux / math.pow(2, underStops + 1);

  double luxAt(int column, int row) => lux[row * (columns + 1) + column];

  /// Puntos que tiene la rejilla como poco: con menos, lo más iluminado de
  /// la planta saldría a saltos.
  static const int minPoints = 200;

  /// Calcula el mapa de [rect] con una rejilla tan fina como deje
  /// [budget]: el número de comprobaciones rayo–obstáculo que se permiten.
  /// Cada punto cuesta un rayo por fuente (tres si es ancha y hace
  /// penumbra), dieciséis por el cielo y uno por el sol, y cada rayo, una
  /// comprobación por obstáculo.
  ///
  /// Con [exposureKeyLux] (los lux bien expuestos de la cámara) se mira la
  /// luz hasta donde la cámara aún la ve, aunque sea muy poca al lado de la
  /// fuente más fuerte.
  static PlanLightMap compute(
    LightScene scene,
    Rect rect, {
    required int budget,
    double? exposureKeyLux,
  }) {
    final env = scene.ambient;
    final sunny = env != null && env.hasSun;
    final skyLit = env != null && env.hasSky && env.day;
    var rays = (sunny ? 1 : 0) + (skyLit ? 16 : 0);
    for (final light in scene.lights) {
      final wide =
          light.overheadM == null &&
          light.source.sizeM / scene.metersPerUnit / 2 >= 5;
      rays += wide ? 3 : 1;
    }
    final obstacles = scene.blockers.length + scene.apertures.length + 1;
    final points = (budget / math.max(1, rays * obstacles)).clamp(
      minPoints.toDouble(),
      30000.0,
    );
    final aspect = rect.width / math.max(1.0, rect.height);
    final rows = math.max(8, math.sqrt(points / aspect).round());
    final columns = math.max(8, (rows * aspect).round());

    final count = (columns + 1) * (rows + 1);
    final lux = Float32List(count);
    final cct = Float32List(count);
    final indoor = Uint8List(count);

    // Lo que se da por nada: muy por debajo de la fuente más fuerte.
    var strongest = sunny ? env.condition.sunLux : 0.0;
    for (final light in scene.lights) {
      strongest = math.max(strongest, light.source.illuminance(2));
    }
    var cutoff = strongest / math.pow(2, rangeStops + 2);
    if (exposureKeyLux != null && exposureKeyLux > 0) {
      cutoff = math.min(cutoff, cutoffForExposure(exposureKeyLux));
    }

    final dx = rect.width / columns;
    final dy = rect.height / rows;
    var i = 0;
    for (var r = 0; r <= rows; r++) {
      for (var c = 0; c <= columns; c++, i++) {
        final at = Offset(rect.left + c * dx, rect.top + r * dy);
        final sample = scene.sampleAt(at, cutoff: cutoff);
        if (scene.isRoofed(at)) indoor[i] = 1;
        lux[i] = sample.lux;
        cct[i] = sample.cct;
      }
    }

    // Lo más iluminado manda: el brillo se reparte desde ahí hacia abajo.
    double keyOf(bool Function(int i) take, double fallback) {
      final lit = [
        for (var i = 0; i < count; i++)
          if (take(i) && lux[i] > cutoff) lux[i],
      ]..sort();
      return lit.isEmpty ? fallback : lit[((lit.length - 1) * 0.92).floor()];
    }

    final key = math.max(keyOf((_) => true, math.max(strongest, 1.0)), 1e-3);
    // Bajo techo, a medio camino entre lo más iluminado de la planta y lo
    // más iluminado de dentro, sin bajar más de [indoorAdaptStops].
    final inside = keyOf((i) => indoor[i] == 1, key);
    final indoorKey = math.max(
      math.sqrt(key * math.min(key, inside)),
      key / math.pow(2, indoorAdaptStops),
    );
    final open = env == null
        ? 0.0
        : (sunny ? env.condition.sunLux : 0.0) + (skyLit ? env.skyLux : 0.0);
    return PlanLightMap._(
      rect: rect,
      columns: columns,
      rows: rows,
      lux: lux,
      cct: cct,
      keyLux: key,
      indoorKeyLux: math.max(indoorKey, 1e-3),
      indoor: indoor,
      openLux: open,
      openCct: sunny ? env.condition.sunCct : (env?.skyCct ?? 5600),
      cutoff: cutoff,
    );
  }

  static int _argb(
    double lux,
    double cct,
    double keyLux,
    bool exposed, [
    double strength = 1,
  ]) {
    final b = exposed
        ? exposedBrightness(lux, keyLux)
        : brightnessFor(lux, keyLux);
    if (b <= 0.002) return 0;
    var tint = LightBeam.colorForCct(cct <= 0 ? 5600 : cct);
    if (exposed) {
      // Lo quemado se va a blanco: se ve que sobra, no solo que hay luz.
      final burn = burnFor(lux, keyLux);
      if (burn > 0) {
        tint = Color.lerp(tint, const Color(0xFFFFFFFF), burn * 0.75)!;
      }
    }
    final top = exposed ? maxExposedAlpha : maxAlpha;
    final a = (b * top * strength * 255).round().clamp(0, 255);
    return (a << 24) |
        ((tint.r * 255).round() << 16) |
        ((tint.g * 255).round() << 8) |
        (tint.b * 255).round();
  }

  /// Color con el que se pinta una cantidad de luz de una temperatura,
  /// medida contra [key]. Con [exposed], [key] son los lux bien expuestos
  /// de la cámara y lo que sobra se blanquea; sin él, «Ver todo».
  static Color colorFor(
    double lux,
    double cct,
    double key, {
    bool exposed = false,
    double strength = 1,
  }) => Color(_argb(lux, cct, key, exposed, strength));

  /// Color con el que se pinta lo que queda fuera del mapa, al aire libre.
  /// Con [exposureKeyLux], a la exposición de la cámara.
  Color openColor([double? exposureKeyLux]) => Color(
    _argb(openLux, openCct, exposureKeyLux ?? keyLux, exposureKeyLux != null),
  );

  ui.Vertices? _vertices;
  double? _verticesKey;

  /// La rejilla como malla: el color se funde solo entre un cruce y el
  /// siguiente. Con [exposureKeyLux], a la exposición de la cámara; sin
  /// él, «Ver todo».
  ui.Vertices vertices([double? exposureKeyLux]) {
    final cached = _vertices;
    if (cached != null && _verticesKey == exposureKeyLux) return cached;
    final exposed = exposureKeyLux != null;
    final stride = columns + 1;
    final positions = Float32List((columns + 1) * (rows + 1) * 2);
    final colors = Int32List((columns + 1) * (rows + 1));
    final dx = rect.width / columns;
    final dy = rect.height / rows;
    var i = 0;
    for (var r = 0; r <= rows; r++) {
      for (var c = 0; c <= columns; c++, i++) {
        positions[i * 2] = rect.left + c * dx;
        positions[i * 2 + 1] = rect.top + r * dy;
        colors[i] = _argb(
          lux[i],
          cct[i],
          exposureKeyLux ?? (indoor[i] == 1 ? indoorKeyLux : keyLux),
          exposed,
        );
      }
    }
    final indices = Uint16List(columns * rows * 6);
    var k = 0;
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < columns; c++) {
        final a = r * stride + c;
        final b = a + 1;
        final d = a + stride;
        final e = d + 1;
        indices[k++] = a;
        indices[k++] = b;
        indices[k++] = d;
        indices[k++] = b;
        indices[k++] = e;
        indices[k++] = d;
      }
    }
    _verticesKey = exposureKeyLux;
    return _vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      colors: colors,
      indices: indices,
    );
  }

  /// Pinta el mapa. Con [exposureKeyLux], a la exposición de la cámara.
  void paint(Canvas canvas, Rect view, {double? exposureKeyLux}) {
    // Fuera del mapa: lo que hay al aire libre sin nada delante.
    final open = openColor(exposureKeyLux);
    if (open.a > 0) {
      canvas.save();
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(view.inflate(2))
          ..addRect(rect),
      );
      canvas.drawRect(view.inflate(2), Paint()..color = open);
      canvas.restore();
    }
    // Un desenfoque de medio cruce funde el escalonado de la rejilla en
    // los bordes de las sombras.
    final cell = math.max(rect.width / columns, rect.height / rows);
    canvas.saveLayer(
      rect.inflate(cell),
      Paint()
        ..imageFilter = ui.ImageFilter.blur(
          sigmaX: cell * 0.55,
          sigmaY: cell * 0.55,
          tileMode: TileMode.decal,
        ),
    );
    canvas.drawVertices(vertices(exposureKeyLux), BlendMode.dst, Paint());
    canvas.restore();
  }
}

/// La luz de la planta grabada en sus coordenadas, antes de pasarla a
/// imagen.
class PlanLightRecording {
  final ui.Picture picture;

  /// Hasta dónde llega lo que se ha pintado: haces, sombras y manchas.
  final Rect bounds;

  /// Lo que importa ver con detalle: la planta y algo de margen. Lo que
  /// queda más allá (un haz que sale por una ventana, el rebote del sol en
  /// una fachada) es luz que cae despacio y se rasteriza con grano grueso.
  final Rect focus;

  /// Color de lo que queda fuera de [bounds], al aire libre: el sol o el
  /// cielo sin nada delante. `null` = nada.
  final Color? open;

  const PlanLightRecording({
    required this.picture,
    required this.bounds,
    required this.focus,
    this.open,
  });
}

/// Un trozo de la luz rasterizado: la imagen y lo que cubre.
class PlanLightTile {
  final ui.Image image;

  /// Lo que cubre la imagen, en unidades del lienzo.
  final Rect rect;

  const PlanLightTile(this.image, this.rect);

  /// [rect] medio píxel hacia dentro: así el borde no se funde con el vacío
  /// de fuera de la imagen.
  Rect get inner => rect.deflate(rect.width / image.width / 2);

  void paint(Canvas canvas) => canvas.drawImageRect(
    image,
    Rect.fromLTRB(0.5, 0.5, image.width - 0.5, image.height - 0.5),
    inner,
    Paint()..filterQuality = FilterQuality.medium,
  );
}

/// La luz de la planta como imagen, lista para pintarse con la vista: con
/// detalle en la planta ([fine]) y, si llega más allá, con grano grueso
/// alrededor ([far]).
class PlanLightLayer {
  final PlanLightTile fine;
  final PlanLightTile? far;

  /// Grano con el que se pidió [fine].
  final double unitsPerPixel;

  /// Color de fuera de todo (ver [PlanLightRecording.open]).
  final Color? open;

  const PlanLightLayer({
    required this.fine,
    required this.unitsPerPixel,
    this.far,
    this.open,
  });

  void dispose() {
    fine.image.dispose();
    far?.image.dispose();
  }

  /// La pinta en su sitio. Lo de fuera, al aire libre, va liso.
  void paint(Canvas canvas, Rect view) {
    final outer = far?.inner ?? fine.inner;
    final fill = open;
    if (fill != null && fill.a > 0) {
      canvas.save();
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(view.inflate(2))
          ..addRect(outer),
      );
      canvas.drawRect(view.inflate(2), Paint()..color = fill);
      canvas.restore();
    }
    final around = far;
    if (around != null) {
      canvas.save();
      canvas.clipPath(
        Path()
          ..fillType = PathFillType.evenOdd
          ..addRect(around.inner)
          ..addRect(fine.inner),
      );
      around.paint(canvas);
      canvas.restore();
    }
    fine.paint(canvas);
  }
}

/// Huellas de una planta: cambian cuando cambia lo que miden. Los elementos
/// se modifican en su sitio (al arrastrar, al tocar un ajuste), así que no
/// basta con comparar las listas: hay que mirar lo que llevan dentro.
abstract final class PlanLightKey {
  /// Propiedades que no cambian la luz: los ajustes de la cámara (la
  /// exposición va aparte), su óptica y su rótulo, y el identificador.
  static const _unlit = {
    'uid',
    'iso',
    'shutterDeg',
    'fps',
    'nd',
    'tStop',
    'sensorWidthMm',
    'lensName',
    'cameraName',
    'shotTag',
    'pathRot',
    'name',
  };

  /// Un valor de las propiedades, con listas y mapas mirados por dentro.
  static int _deep(Object? value) => switch (value) {
    final List<Object?> list => Object.hashAll(list.map(_deep)),
    final Map<Object?, Object?> map => Object.hashAllUnordered([
      for (final e in map.entries) Object.hash(e.key, _deep(e.value)),
    ]),
    _ => value.hashCode,
  };

  static int _props(
    Map<String, dynamic> props, {
    Set<String> skip = const {},
  }) => Object.hashAllUnordered([
    for (final e in props.entries)
      if (!skip.contains(e.key)) Object.hash(e.key, _deep(e.value)),
  ]);

  /// Lo que afecta a la luz: dónde está cada cosa, hacia dónde mira, qué es
  /// y cómo está ajustada. No cuentan los nombres, el recorrido de la
  /// cámara ni sus ajustes de exposición.
  static int light(
    Iterable<PlanElement> elements, {
    required double metersPerUnit,
    PlanAmbient? ambient,
  }) => Object.hash(
    metersPerUnit,
    ambient,
    Object.hashAll([
      for (final el in elements)
        Object.hash(
          el.type,
          el.position,
          el.rotation,
          el.lightType,
          // El rótulo dice qué es una pieza de arquitectura o de atrezo.
          el.type == ElementType.wall || el.type == ElementType.prop
              ? el.label
              : null,
          _props(el.props, skip: _unlit),
        ),
    ]),
  );

  /// La luz y además los nombres de lo que emite: salen en el fotómetro.
  static int scene(
    Iterable<PlanElement> elements, {
    required double metersPerUnit,
    PlanAmbient? ambient,
  }) => Object.hash(
    light(elements, metersPerUnit: metersPerUnit, ambient: ambient),
    Object.hashAll([
      for (final el in elements)
        if (el.type == ElementType.light) el.props['name'],
    ]),
  );

  /// Todo lo que se dibuja de cada elemento, y qué está seleccionado.
  static int drawing(
    Iterable<PlanElement> elements, [
    Iterable<PlanElement> selected = const [],
  ]) => Object.hash(
    Object.hashAll([
      for (final el in elements)
        Object.hash(
          el.id,
          el.type,
          el.position,
          el.rotation,
          el.label,
          el.lens,
          el.stabilization,
          el.cameraNumber,
          el.cameraLetter,
          el.lightType,
          el.lukaCompatible,
          el.actorColor,
          Object.hashAll(el.pathPoints),
          _props(el.props),
          el.layer,
          el.shotOverride,
        ),
    ]),
    Object.hashAllUnordered([for (final el in selected) el.id]),
  );
}

/// Guarda el mapa de luz de la planta que se está viendo y lo rehace
/// cuando cambia. Mientras se arrastra algo lo calcula deprisa y a grano
/// grueso; al parar, lo afina.
class PlanLightMapCache extends ChangeNotifier {
  /// Comprobaciones rayo–obstáculo para el mapa rápido (mientras se
  /// arrastra) y para el fino (al parar). Del mapa solo sale contra qué se
  /// mide el brillo en «Ver todo»: con unos cientos de puntos basta.
  final int coarseBudget;
  final int fineBudget;

  PlanLightMapCache({this.coarseBudget = 400000, this.fineBudget = 1600000});

  int? _key;
  PlanLightMap? _map;
  bool _disposed = false;

  /// Las últimas plantas vistas por la luz, de la más antigua a la más
  /// reciente. Hay más de una porque el lienzo cuenta las cámaras de los
  /// otros planos y el fotómetro no.
  final _scenes = <int, LightScene>{};
  static const _keptScenes = 4;

  /// La planta vista por la luz. Se construye una vez por cada estado de la
  /// planta y la comparten el lienzo, el fotómetro, los recintos y el
  /// alzado.
  ///
  /// En borrador ([draft]) va sin rebotes de pared: es lo que más fuentes
  /// añade y lo que menos cambia lo que se ve mientras se arrastra.
  LightScene scene(
    List<PlanElement> elements, {
    required double metersPerUnit,
    PlanAmbient? ambient,
    bool draft = false,
  }) {
    final key = Object.hash(
      PlanLightKey.scene(
        elements,
        metersPerUnit: metersPerUnit,
        ambient: ambient,
      ),
      draft,
    );
    final kept = _scenes.remove(key);
    if (kept != null) return _scenes[key] = kept;
    final built = LightScene.from(
      elements,
      metersPerUnit: metersPerUnit,
      ambient: ambient,
      wallBounce: !draft,
    );
    _scenes[key] = built;
    while (_scenes.length > _keptScenes) {
      _scenes.remove(_scenes.keys.first);
    }
    return built;
  }

  /// El mapa de una planta. [key] cambia cuando cambia algo que afecta a
  /// la luz. Con [exposureKeyLux] el mapa mira la luz hasta donde la ve la
  /// cámara: si se abre el diafragma y hace falta ver menos luz, se rehace.
  /// En borrador ([draft]) se calcula con el presupuesto grueso.
  PlanLightMap resolve(
    LightScene scene,
    int key,
    Rect rect, {
    double? exposureKeyLux,
    bool draft = false,
  }) {
    final current = _map;
    final needed = exposureKeyLux == null
        ? double.infinity
        : PlanLightMap.cutoffForExposure(exposureKeyLux);
    final wanted = Object.hash(key, draft);
    if (current != null && _key == wanted && current.cutoff <= needed * 1.001) {
      return current;
    }
    // Se mira algo más abajo de lo que hace falta: así un cambio pequeño de
    // ISO o de diafragma no obliga a rehacerlo.
    final reach = exposureKeyLux == null ? null : exposureKeyLux / 2;
    _key = wanted;
    return _map = PlanLightMap.compute(
      scene,
      rect,
      budget: draft ? coarseBudget : fineBudget,
      exposureKeyLux: reach,
    );
  }

  /// Tras cuánto tiempo sin cambios se afina la luz.
  static const settleDelay = Duration(milliseconds: 280);

  int? _seenKey;

  /// Corre desde el último cambio de la luz: mientras corre, otro cambio
  /// es parte de una serie.
  Timer? _quiet;
  bool _drafting = false;
  int? _settledKey;
  Timer? _settle;

  /// Si la luz de [key] se pinta en borrador: con menos detalle y sin
  /// rebotes de pared, para que arrastrar vaya fluido.
  ///
  /// Va en borrador mientras se arrastra algo ([interacting]) o mientras
  /// la luz cambia sin parar (un deslizador). A los [settleDelay] sin
  /// cambios se afina sola: avisa a quien escucha y el lienzo se repinta.
  bool draft(int key, {bool interacting = false}) {
    if (key == _settledKey) return false;
    if (key == _seenKey) {
      if (!_drafting) return false;
      if (interacting) return true;
      // Se soltó antes de que saltara el temporizador: se afina ya.
      _settle?.cancel();
      _settledKey = key;
      return _drafting = false;
    }
    final continuous = _quiet?.isActive ?? false;
    _seenKey = key;
    _quiet?.cancel();
    _quiet = Timer(settleDelay, () {});
    _settle?.cancel();
    _drafting = interacting || continuous;
    if (!_drafting) {
      _settledKey = key;
      return false;
    }
    _settle = Timer(settleDelay, () {
      if (_disposed || _seenKey != key) return;
      _settledKey = key;
      _drafting = false;
      notifyListeners();
    });
    return true;
  }

  int? _layerKey;
  PlanLightRecording? _recording;

  int? _draftKey;
  ui.Picture? _draftPicture;

  /// Lo que ve cada muestra de cada fuente, por lo que tapa la luz, dónde
  /// está la muestra y hasta dónde llega. Mover un aparato solo recalcula lo
  /// suyo: las paredes no se han movido y sus rebotes ven lo mismo.
  final _visible = <int, ({Path path, int pass, bool draft})>{};
  var _finePass = 0;
  var _draftPass = 0;
  bool _recordingDraft = false;

  /// Cuánto se redondea hacia arriba el alcance de una fuente al guardar
  /// lo que ve: un rebote que recibe algo más o menos luz no lo recalcula.
  static const double _reachStep = 1.25;

  /// [LightScene.visibleArea], guardado.
  ///
  /// Se calcula hasta un alcance algo mayor que [reach]: dentro del círculo
  /// de [reach] es la misma zona, y lo que se pinta con ella como recorte
  /// (los haces, de ese radio) no pasa de ahí. Una fuente colgada pinta un
  /// óvalo que puede salirse, así que va con su alcance justo.
  Path visibleArea(
    LightScene scene,
    Offset origin,
    double reach, {
    LightBlocker? ignore,
    bool fromAbove = false,
    double? z,
    int rays = 240,
  }) {
    final far = fromAbove
        ? reach
        : math
              .pow(_reachStep, (math.log(reach) / math.log(_reachStep)).ceil())
              .toDouble();
    final key = Object.hash(
      scene.obstacleKey,
      origin,
      ignore == null ? -1 : scene.blockers.indexOf(ignore),
      fromAbove,
      z,
      far,
      rays,
    );
    final pass = _recordingDraft ? _draftPass : _finePass;
    final kept = _visible[key];
    final path =
        kept?.path ??
        scene.visibleArea(
          origin,
          far,
          ignore: ignore,
          fromAbove: fromAbove,
          z: z,
          rays: rays,
        );
    _visible[key] = (path: path, pass: pass, draft: _recordingDraft);
    return path;
  }

  /// Cada haz grabado, por cómo es la fuente, lo que la tapa y contra qué se
  /// mide su brillo.
  final _beams =
      <int, ({ui.Picture picture, Rect? bounds, int pass, bool draft})>{};

  /// El haz de una fuente, grabado aparte. Mientras la fuente siga igual
  /// (mismo sitio, misma luz, mismos obstáculos) se reutiliza: al mover un
  /// aparato solo se graban de nuevo el suyo y los rebotes a los que llega.
  ({ui.Picture picture, Rect? bounds}) beam(
    int key,
    ({ui.Picture picture, Rect? bounds}) Function() record,
  ) {
    final pass = _recordingDraft ? _draftPass : _finePass;
    final kept = _beams[key];
    final beam = kept == null
        ? record()
        : (picture: kept.picture, bounds: kept.bounds);
    _beams[key] = (
      picture: beam.picture,
      bounds: beam.bounds,
      pass: pass,
      draft: _recordingDraft,
    );
    return beam;
  }

  /// Graba con [record] y luego olvida lo visto y los haces que no se usaron
  /// ni en esta grabación ni en la anterior del mismo tipo (borrador o
  /// afinada).
  T _recordWith<T>(bool draft, T Function() record) {
    _recordingDraft = draft;
    final pass = draft ? ++_draftPass : ++_finePass;
    final watch = Stopwatch()..start();
    final result = record();
    lastRecording = watch.elapsed;
    _visible.removeWhere((_, v) => v.draft == draft && v.pass < pass - 1);
    _beams.removeWhere((_, b) {
      final stale = b.draft == draft && b.pass < pass - 1;
      if (stale) b.picture.dispose();
      return stale;
    });
    return result;
  }

  /// La luz en borrador, grabada y sin pasar a imagen: cambia en cada
  /// fotograma mientras se arrastra, y rasterizarla aparte costaría más.
  ui.Picture draftPicture(int key, ui.Picture Function() record) {
    final current = _draftPicture;
    if (current != null && _draftKey == key) return current;
    current?.dispose();
    _draftKey = key;
    final picture = _recordWith(true, record);
    _draftPicture = picture;
    return picture;
  }

  /// Lo que tardó en grabarse la última luz: lo que paga el hilo de la
  /// interfaz. El rasterizado va después, en el de la GPU.
  @visibleForTesting
  Duration? lastRecording;
  PlanLightLayer? _layer;

  /// Lado más largo y píxeles que puede tener la imagen de la luz.
  static const int maxLayerSide = 4096;
  static const int maxLayerPixels = 12 << 20;

  /// Grano de lo que queda lejos de la planta, en metros por píxel, y lado
  /// más largo de su imagen.
  static const double farGrainM = 0.25;
  static const int maxFarSide = 1024;

  /// La luz ya dibujada, en una imagen. Mientras no cambie nada que afecte
  /// a la luz ([key]) se reutiliza: mover la vista, hacer zoom o
  /// seleccionar no la recalcula ni la vuelve a desenfocar. Si el zoom pide
  /// otro grano ([unitsPerPixel]), se rasteriza de nuevo lo ya grabado.
  PlanLightLayer layer(
    int key, {
    required double unitsPerPixel,
    required double metersPerUnit,
    required PlanLightRecording Function() record,
  }) {
    if (_layerKey != key || _recording == null) {
      _recording?.picture.dispose();
      _layer?.dispose();
      _layer = null;
      _layerKey = key;
      _recording = _recordWith(false, record);
    }
    final current = _layer;
    if (current != null && current.unitsPerPixel == unitsPerPixel) {
      return current;
    }
    current?.dispose();
    final recording = _recording!;
    final bounds = recording.bounds;
    final focus = bounds.intersect(recording.focus);
    final fine = _rasterize(
      recording.picture,
      focus.isEmpty ? bounds : focus,
      unitsPerPixel,
    );
    final far = focus.isEmpty || _covers(focus, bounds)
        ? null
        : _rasterize(
            recording.picture,
            bounds,
            math.max(
              farGrainM / metersPerUnit,
              math.max(bounds.width, bounds.height) / maxFarSide,
            ),
          );
    return _layer = PlanLightLayer(
      fine: fine,
      far: far,
      unitsPerPixel: unitsPerPixel,
      open: recording.open,
    );
  }

  static bool _covers(Rect outer, Rect inner) =>
      outer.left <= inner.left &&
      outer.top <= inner.top &&
      outer.right >= inner.right &&
      outer.bottom >= inner.bottom;

  /// [picture] en una imagen de [area], con [grain] unidades por píxel (o
  /// más, si saliera demasiado grande).
  static PlanLightTile _rasterize(ui.Picture picture, Rect area, double grain) {
    var upp = math.max(grain, math.max(area.width, area.height) / maxLayerSide);
    upp = math.max(upp, math.sqrt(area.width * area.height / maxLayerPixels));
    final width = math.max(1, (area.width / upp).ceil());
    final height = math.max(1, (area.height / upp).ceil());
    final rect = Rect.fromLTWH(area.left, area.top, width * upp, height * upp);
    final recorder = ui.PictureRecorder();
    Canvas(recorder)
      ..scale(1 / upp)
      ..translate(-rect.left, -rect.top)
      ..drawPicture(picture);
    final framed = recorder.endRecording();
    final image = framed.toImageSync(width, height);
    framed.dispose();
    return PlanLightTile(image, rect);
  }

  @override
  void dispose() {
    _disposed = true;
    _recording?.picture.dispose();
    _layer?.dispose();
    _draftPicture?.dispose();
    for (final b in _beams.values) {
      b.picture.dispose();
    }
    _settle?.cancel();
    _quiet?.cancel();
    super.dispose();
  }
}
