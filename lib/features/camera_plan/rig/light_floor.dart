import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui';

import 'package:image/image.dart' as img;

import '../camera_plan_element_model.dart';
import '../light/ambient.dart';
import '../light/light_scene.dart';
import '../light_beam.dart';
import '../plan_light_map.dart';
import '../plan_segment.dart';

/// La luz calculada por IRIS (la misma del mapa de la planta) como una
/// imagen para el suelo del 3D: cuánta luz llega a cada sitio y de qué
/// color, contando lo que la tapa.
class LightFloor {
  LightFloor._();

  /// Puntos de cálculo: menos que en la planta, que el 3D no necesita
  /// tanto detalle y se rehace a menudo.
  static const int budget = 40000;

  /// Lado máximo de la zona, en metros.
  static const double maxSpanM = 90;

  /// La imagen en PNG (base64) y dónde va, en metros con los ejes del
  /// visor; `null` si no hay nada que alumbrar. Se calcula aparte para no
  /// parar la pantalla.
  static Future<Map<String, dynamic>?> build(
    List<PlanElement> elements, {
    required double metersPerUnit,
    PlanAmbient? ambient,
  }) => Isolate.run(
    () => compute(elements, metersPerUnit: metersPerUnit, ambient: ambient),
  );

  static Map<String, dynamic>? compute(
    List<PlanElement> elements, {
    required double metersPerUnit,
    PlanAmbient? ambient,
  }) {
    final mpu = metersPerUnit;
    Rect? box;
    for (final el in elements) {
      final at = Rect.fromCircle(center: el.position, radius: 1);
      box = box?.expandToInclude(at) ?? at;
      if (PlanSegment.isSegment(el)) {
        box = box.expandToInclude(
          Rect.fromCircle(center: PlanSegment.end(el), radius: 1),
        );
      }
    }
    if (box == null) return null;
    final limit = maxSpanM / mpu;
    final rect = Rect.fromCenter(
      center: box.center,
      width: math.min(box.width + 6 / mpu, limit),
      height: math.min(box.height + 6 / mpu, limit),
    );
    final scene = LightScene.from(
      elements,
      metersPerUnit: mpu,
      ambient: ambient,
    );
    if (scene.lights.isEmpty && !(ambient?.hasSun ?? false)) return null;
    final map = PlanLightMap.compute(scene, rect, budget: budget);
    final w = map.columns + 1, h = map.rows + 1;
    final image = img.Image(width: w, height: h, numChannels: 4);
    for (var r = 0; r < h; r++) {
      for (var c = 0; c < w; c++) {
        final i = r * w + c;
        final key = map.indoor[i] == 1 ? map.indoorKeyLux : map.keyLux;
        final b = PlanLightMap.brightnessFor(map.lux[i], key);
        final color = LightBeam.colorForCct(map.cct[i]);
        image.setPixelRgba(
          c,
          r,
          (color.r * 255 * b).round(),
          (color.g * 255 * b).round(),
          (color.b * 255 * b).round(),
          (255 * b).round(),
        );
      }
    }
    return {
      'png': base64Encode(img.encodePng(image)),
      // Fila 0 de la imagen = borde de arriba del lienzo = y más alta.
      'x0': rect.left * mpu,
      'x1': rect.right * mpu,
      'yTop': -rect.top * mpu,
      'yBottom': -rect.bottom * mpu,
      'keyLux': map.keyLux,
    };
  }
}
