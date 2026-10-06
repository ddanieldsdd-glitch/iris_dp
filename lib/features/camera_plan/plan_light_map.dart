import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'light/ambient.dart';
import 'light/light_scene.dart';
import 'light_beam.dart';

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
  });

  /// Stops por debajo de [keyLux] que todavía se ven.
  static const double rangeStops = 10;

  /// Lo más que tapa la luz al lienzo: por encima, las paredes y los
  /// rótulos (claros) dejarían de leerse.
  static const double maxAlpha = 0.5;

  /// Brillo con el que se pinta una cantidad de luz, de 0 a 1.
  static double brightnessFor(double lux, double keyLux) {
    if (lux <= 0 || keyLux <= 0) return 0;
    final stops = math.log(lux / keyLux) / math.ln2;
    final v = ((stops + rangeStops) / rangeStops).clamp(0.0, 1.0);
    return math.pow(v, 1.6).toDouble();
  }

  double luxAt(int column, int row) => lux[row * (columns + 1) + column];

  /// Calcula el mapa de [rect] con una rejilla tan fina como deje
  /// [budget]: el número de comprobaciones punto–fuente que se permiten.
  static PlanLightMap compute(
    LightScene scene,
    Rect rect, {
    required int budget,
  }) {
    final env = scene.ambient;
    final sunny = env != null && env.hasSun;
    final skyLit = env != null && env.hasSky && env.day;
    // El cielo cuesta como dieciséis fuentes: mira alrededor.
    final perPoint = scene.lights.length + (sunny ? 1 : 0) + (skyLit ? 16 : 0);
    final points = (budget / math.max(1, perPoint)).clamp(400.0, 30000.0);
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
    final cutoff = strongest / math.pow(2, rangeStops + 2);

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
    // más iluminado de dentro.
    final inside = keyOf((i) => indoor[i] == 1, key);
    final indoorKey = math.sqrt(key * math.min(key, inside));
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
    );
  }

  static int _argb(double lux, double cct, double keyLux) {
    final b = brightnessFor(lux, keyLux);
    if (b <= 0.002) return 0;
    final tint = LightBeam.colorForCct(cct <= 0 ? 5600 : cct);
    final a = (b * maxAlpha * 255).round().clamp(0, 255);
    return (a << 24) |
        ((tint.r * 255).round() << 16) |
        ((tint.g * 255).round() << 8) |
        (tint.b * 255).round();
  }

  /// Color con el que se pinta lo que queda fuera del mapa, al aire libre.
  Color get openColor => Color(_argb(openLux, openCct, keyLux));

  ui.Vertices? _vertices;

  /// La rejilla como malla: el color se funde solo entre un cruce y el
  /// siguiente.
  ui.Vertices get vertices {
    final cached = _vertices;
    if (cached != null) return cached;
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
          indoor[i] == 1 ? indoorKeyLux : keyLux,
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
    return _vertices = ui.Vertices.raw(
      ui.VertexMode.triangles,
      positions,
      colors: colors,
      indices: indices,
    );
  }

  void paint(Canvas canvas, Rect view) {
    // Fuera del mapa: lo que hay al aire libre sin nada delante.
    final open = openColor;
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
    canvas.drawVertices(vertices, BlendMode.dst, Paint());
    canvas.restore();
  }
}

/// Guarda el mapa de luz de la planta que se está viendo y lo rehace
/// cuando cambia. Mientras se arrastra algo lo calcula deprisa y a grano
/// grueso; al parar, lo afina.
class PlanLightMapCache extends ChangeNotifier {
  /// Comprobaciones punto–fuente para el mapa rápido y para el fino.
  final int coarseBudget;
  final int fineBudget;

  PlanLightMapCache({this.coarseBudget = 60000, this.fineBudget = 900000});

  int? _key;
  PlanLightMap? _map;
  Timer? _refine;
  bool _disposed = false;

  /// El mapa de una planta. [key] cambia cuando cambia algo que afecta a
  /// la luz.
  PlanLightMap resolve(LightScene scene, int key, Rect rect) {
    final current = _map;
    if (current != null && _key == key) return current;
    final quick = PlanLightMap.compute(scene, rect, budget: coarseBudget);
    _key = key;
    _map = quick;
    _refine?.cancel();
    _refine = Timer(const Duration(milliseconds: 280), () {
      if (_disposed || _key != key) return;
      _map = PlanLightMap.compute(scene, rect, budget: fineBudget);
      notifyListeners();
    });
    return quick;
  }

  @override
  void dispose() {
    _disposed = true;
    _refine?.cancel();
    super.dispose();
  }
}
