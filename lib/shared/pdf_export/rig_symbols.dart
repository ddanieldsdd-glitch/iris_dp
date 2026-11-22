import 'dart:math' as math;

import 'package:pdf/pdf.dart';

import '../../features/camera_plan/camera_plan_constants.dart';

/// Familias de aparato con su dibujo en la hoja de luz (LZ.1), como en las
/// hojas de *Dune II*: cada modelo se reconoce por su forma y su color.
enum RigFamily {
  /// Fresnel, HMI, cabeza abierta, PAR, LED de lente: cuerpo y lente.
  can,

  /// Recorte (elipsoidal): cañón largo con boca en cono.
  profile,

  /// Panel LED o de fluorescentes: placa fina.
  panel,

  /// Tubo suelto.
  tube,

  /// Caja de luz, octabox, chimera: tronco de pirámide.
  softbox,

  /// Cuarzo de horizonte o *scoop*: caja ancha y corta.
  cyc,

  /// Práctico, bombilla o farola: un círculo.
  practical,
}

/// Lo que mide un aparato, en metros: a lo largo del haz, de lado y de alto.
typedef RigSize = ({double length, double width, double height});

/// Un trazo del símbolo: puntos en metros, con el haz hacia +x y el lado
/// hacia +y. `fill` dice si va relleno del color del modelo.
typedef RigOutline = ({List<(double, double)> points, bool fill});

/// Cómo se ve el aparato: de lado (planta o alzado) o de frente (un panel
/// colgado mirando al suelo, visto desde arriba).
enum RigView { side, face }

abstract final class RigSymbols {
  static RigFamily familyOf(LightType? type) => switch (type) {
    LightType.ellipsoidal => RigFamily.profile,
    LightType.lightPanel ||
    LightType.led1x1 ||
    LightType.flo2Tubes ||
    LightType.flo4Tubes => RigFamily.panel,
    LightType.floSingle => RigFamily.tube,
    LightType.softbox ||
    LightType.octagon ||
    LightType.chimera => RigFamily.softbox,
    LightType.cyc || LightType.scoop => RigFamily.cyc,
    LightType.practical => RigFamily.practical,
    _ => RigFamily.can,
  };

  /// Medidas de referencia por tipo (aproximadas, para que la escala
  /// cuente: un 18K se ve más grande que un fresnel de 300 W).
  static RigSize sizeOf(LightType? type, {double? tubeM}) => switch (type) {
    LightType.fresnelSmall => (length: 0.30, width: 0.24, height: 0.24),
    LightType.fresnelMedium => (length: 0.45, width: 0.38, height: 0.38),
    LightType.fresnelLarge => (length: 0.70, width: 0.60, height: 0.60),
    LightType.hmi => (length: 0.80, width: 0.62, height: 0.62),
    LightType.openFace => (length: 0.30, width: 0.28, height: 0.28),
    LightType.par => (length: 0.55, width: 0.50, height: 0.50),
    LightType.led => (length: 0.35, width: 0.30, height: 0.30),
    LightType.ellipsoidal => (length: 0.75, width: 0.28, height: 0.28),
    LightType.lightPanel => (length: 0.10, width: 0.70, height: 0.40),
    LightType.led1x1 => (length: 0.08, width: 0.32, height: 0.32),
    LightType.flo4Tubes => (length: 0.12, width: 0.65, height: 0.65),
    LightType.flo2Tubes => (length: 0.10, width: 0.35, height: 0.65),
    LightType.floSingle => (length: 0.05, width: tubeM ?? 1.2, height: 0.05),
    LightType.softbox => (length: 0.50, width: 0.60, height: 0.60),
    LightType.octagon => (length: 0.70, width: 1.50, height: 1.50),
    LightType.chimera => (length: 0.60, width: 0.90, height: 0.70),
    LightType.cyc => (length: 0.30, width: 0.45, height: 0.45),
    LightType.scoop => (length: 0.30, width: 0.45, height: 0.45),
    LightType.practical => (length: 0.25, width: 0.25, height: 0.25),
    _ => (length: 0.40, width: 0.35, height: 0.35),
  };

  /// El símbolo, centrado en el aparato. En [RigView.side] el ancho es el
  /// lado que se ve (en planta, `width`; en alzado, `height`).
  static List<RigOutline> outline(
    RigFamily family,
    RigSize size, {
    RigView view = RigView.side,
    bool elevation = false,
  }) {
    final l = size.length;
    final w = elevation ? size.height : size.width;
    if (view == RigView.face) return _face(family, size);
    switch (family) {
      case RigFamily.can:
        // Cuerpo que se estrecha hacia atrás y lente delante, como una
        // tulipa; con la horquilla a los lados.
        final lens = l * 0.18;
        return [
          (
            points: [
              (-l / 2, -w * 0.32),
              (l / 2 - lens, -w / 2),
              (l / 2, -w / 2),
              (l / 2, w / 2),
              (l / 2 - lens, w / 2),
              (-l / 2, w * 0.32),
            ],
            fill: true,
          ),
          (
            points: [(l / 2 - lens, -w / 2), (l / 2 - lens, w / 2)],
            fill: false,
          ),
          (
            points: [(-l * 0.05, -w * 0.62), (-l * 0.05, w * 0.62)],
            fill: false,
          ),
        ];
      case RigFamily.profile:
        final barrel = l * 0.55;
        return [
          (
            points: [
              (-l / 2, -w / 2),
              (-l / 2 + barrel, -w / 2),
              (l / 2, -w * 0.3),
              (l / 2, w * 0.3),
              (-l / 2 + barrel, w / 2),
              (-l / 2, w / 2),
            ],
            fill: true,
          ),
          (
            points: [(-l / 2 + barrel, -w / 2), (-l / 2 + barrel, w / 2)],
            fill: false,
          ),
        ];
      case RigFamily.panel:
      case RigFamily.tube:
        // De canto: una placa fina con su cara hacia delante.
        final d = math.max(l, w * 0.12);
        return [
          (
            points: [
              (-d / 2, -w / 2),
              (d / 2, -w / 2),
              (d / 2, w / 2),
              (-d / 2, w / 2),
            ],
            fill: true,
          ),
          (
            points: [(d / 2 + d * 0.6, -w * 0.3), (d / 2 + d * 0.6, w * 0.3)],
            fill: false,
          ),
        ];
      case RigFamily.softbox:
        return [
          (
            points: [
              (-l / 2, -w * 0.2),
              (l / 2, -w / 2),
              (l / 2, w / 2),
              (-l / 2, w * 0.2),
            ],
            fill: true,
          ),
        ];
      case RigFamily.cyc:
        return [
          (
            points: [
              (-l / 2, -w / 2),
              (l / 2, -w / 2),
              (l / 2, w / 2),
              (-l / 2, w / 2),
            ],
            fill: true,
          ),
          (points: [(-l / 2, -w / 2), (l / 2, w / 2)], fill: false),
        ];
      case RigFamily.practical:
        return [(points: _circle(w / 2), fill: true)];
    }
  }

  /// Visto de frente: la cara que emite.
  static List<RigOutline> _face(RigFamily family, RigSize size) {
    final w = size.width, h = size.height;
    switch (family) {
      case RigFamily.can || RigFamily.profile || RigFamily.practical:
        return [
          (points: _circle(w / 2), fill: true),
          (points: _circle(w * 0.3), fill: false),
        ];
      case RigFamily.softbox when size.width == size.height:
        // El octabox: un octógono.
        return [
          (
            points: [
              for (var i = 0; i < 8; i++)
                (
                  w / 2 * math.cos((i + 0.5) * math.pi / 4),
                  w / 2 * math.sin((i + 0.5) * math.pi / 4),
                ),
            ],
            fill: true,
          ),
        ];
      case RigFamily.tube:
        final t = math.max(h, w * 0.04);
        return [
          (
            points: [
              (-t / 2, -w / 2),
              (t / 2, -w / 2),
              (t / 2, w / 2),
              (-t / 2, w / 2),
            ],
            fill: true,
          ),
        ];
      case RigFamily.panel || RigFamily.softbox || RigFamily.cyc:
        return [
          (
            points: [
              (-h / 2, -w / 2),
              (h / 2, -w / 2),
              (h / 2, w / 2),
              (-h / 2, w / 2),
            ],
            fill: true,
          ),
          if (family == RigFamily.panel)
            (points: [(-h / 2, 0.0), (h / 2, 0.0)], fill: false),
        ];
    }
  }

  static List<(double, double)> _circle(double r) => [
    for (var i = 0; i < 20; i++)
      (r * math.cos(i * math.pi / 10), r * math.sin(i * math.pi / 10)),
  ];

  /// Colores por modelo que se distinguen bien en papel: relleno claro y
  /// trazo oscuro del mismo tono, como en las hojas de *Dune II*.
  static const palette = <(PdfColor fill, PdfColor stroke)>[
    (PdfColor.fromInt(0xFF9ED9A0), PdfColor.fromInt(0xFF2F7A39)),
    (PdfColor.fromInt(0xFFF2B8C0), PdfColor.fromInt(0xFFA8364A)),
    (PdfColor.fromInt(0xFFF6C08E), PdfColor.fromInt(0xFFB35F14)),
    (PdfColor.fromInt(0xFFB9C3D6), PdfColor.fromInt(0xFF4A5670)),
    (PdfColor.fromInt(0xFFF3E08A), PdfColor.fromInt(0xFF8C7310)),
    (PdfColor.fromInt(0xFF9FD8E3), PdfColor.fromInt(0xFF237484)),
    (PdfColor.fromInt(0xFFCDB6E8), PdfColor.fromInt(0xFF5E418C)),
    (PdfColor.fromInt(0xFFD9BFA3), PdfColor.fromInt(0xFF70502F)),
    (PdfColor.fromInt(0xFFCFE38C), PdfColor.fromInt(0xFF5E7A14)),
    (PdfColor.fromInt(0xFFF0A6D9), PdfColor.fromInt(0xFF8C2F6E)),
    (PdfColor.fromInt(0xFF8FD1C2), PdfColor.fromInt(0xFF22705F)),
    (PdfColor.fromInt(0xFFF5A99A), PdfColor.fromInt(0xFFA0402C)),
  ];

  /// El color del modelo `i` de la leyenda; después del 12.º se repiten
  /// con la forma, que ya distingue.
  static (PdfColor, PdfColor) colorAt(int i) => palette[i % palette.length];
}
