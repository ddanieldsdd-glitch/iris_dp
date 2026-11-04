import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:path/path.dart' as p;

import 'scan_structure.dart';

/// Una foto de una captura guiada del iPhone (F6.20 E6): su archivo y dónde
/// estaba la cámara según ARKit, en metros.
class CaptureFrame {
  final String file;

  /// Matriz 4×4 de la cámara al mundo de ARKit, por columnas (como
  /// `simd_float4x4`): mundo con Y arriba; cámara con X a la derecha, Y
  /// arriba y mirando hacia −Z.
  final List<double> transform;

  /// fx, fy, cx, cy en píxeles de la foto.
  final List<double> intrinsics;
  final int width;
  final int height;

  /// La luz que estimó ARKit al hacer la foto (ES.1b): intensidad (1000 =
  /// luz neutra de interior) y temperatura de color. Null en capturas viejas.
  final double? lightIntensity, kelvin;

  /// Exposición de la cámara, en segundos.
  final double? exposure;

  /// Con la linterna encendida: su luz no es la de la localización.
  final bool torch;

  const CaptureFrame({
    required this.file,
    required this.transform,
    required this.intrinsics,
    required this.width,
    required this.height,
    this.lightIntensity,
    this.kelvin,
    this.exposure,
    this.torch = false,
  });

  static CaptureFrame? fromJson(Map json) {
    final t = json['transform'], k = json['intrinsics'];
    final w = json['width'], h = json['height'], file = json['file'];
    if (t is! List || t.length != 16 || k is! List || k.length != 4) {
      return null;
    }
    if (w is! num || h is! num || file is! String) return null;
    // Solo un nombre: nada fuera de la carpeta de la captura.
    if (file.contains('/') || file.contains(r'\') || file.contains('..')) {
      return null;
    }
    return CaptureFrame(
      file: file,
      transform: [for (final v in t) (v as num).toDouble()],
      intrinsics: [for (final v in k) (v as num).toDouble()],
      width: w.toInt(),
      height: h.toInt(),
      lightIntensity: _num(json['light'], 'intensity'),
      kelvin: _num(json['light'], 'kelvin'),
      exposure: _num(json['exposure'], 'duration'),
      torch: json['torch'] == true,
    );
  }

  static double? _num(Object? map, String key) =>
      map is Map && map[key] is num ? (map[key] as num).toDouble() : null;

  /// Columna [c] (0–3) de la matriz: los ejes de la cámara y su posición.
  List<double> column(int c) => transform.sublist(c * 4, c * 4 + 3);
}

/// Un plano que ARKit detectó durante la captura (ES.1, `capture.json` v2).
class CapturePlane {
  final String id;
  final bool vertical;

  /// wall, floor, ceiling, door, window, table, seat o none.
  final String classification;

  /// Del ancla al mundo, por columnas.
  final List<double> transform;

  /// Centro en el sistema del ancla y lados (x, z) del plano.
  final List<double> center;
  final List<double> extent;

  const CapturePlane({
    required this.id,
    required this.vertical,
    required this.classification,
    required this.transform,
    required this.center,
    required this.extent,
  });

  static CapturePlane? fromJson(Map json) {
    final t = json['transform'], c = json['center'], e = json['extent'];
    if (t is! List || t.length != 16 || c is! List || c.length != 3) {
      return null;
    }
    if (e is! List || e.length != 2) return null;
    return CapturePlane(
      id: json['id'] as String? ?? '',
      vertical: json['alignment'] == 'vertical',
      classification: json['classification'] as String? ?? 'none',
      transform: [for (final v in t) (v as num).toDouble()],
      center: [for (final v in c) (v as num).toDouble()],
      extent: [for (final v in e) (v as num).toDouble()],
    );
  }

  /// Un punto del sistema del ancla, en el mundo de ARKit.
  List<double> toWorld(double x, double y, double z) => [
    for (var r = 0; r < 3; r++)
      transform[r] * x +
          transform[4 + r] * y +
          transform[8 + r] * z +
          transform[12 + r],
  ];

  /// Los dos extremos de la cara, a lo ancho (x del ancla), en el mundo.
  (List<double>, List<double>) faceEnds() {
    final half = extent[0] / 2;
    return (
      toWorld(center[0] - half, center[1], center[2]),
      toWorld(center[0] + half, center[1], center[2]),
    );
  }

  /// Un plano de pared: vertical y no puerta, ventana ni mueble.
  bool get isWall =>
      vertical && (classification == 'wall' || classification == 'none');
}

/// Un toque de precisión en la captura, en el mundo de ARKit: esquina,
/// puerta, ventana, suelo, techo, borde de escaparate (`storefront`) o luz
/// práctica (`light`, con su tipo en [label]: farola, fluorescente…).
class CaptureMark {
  final String kind;
  final List<double> position;
  final String? label;

  const CaptureMark(this.kind, this.position, {this.label});

  static CaptureMark? fromJson(Map json) {
    final pos = json['position'], kind = json['kind'];
    if (pos is! List || pos.length != 3 || kind is! String) return null;
    return CaptureMark(kind, [
      for (final v in pos) (v as num).toDouble(),
    ], label: json['label'] as String?);
  }
}

/// Una captura guiada: la carpeta con las fotos y su `capture.json`.
class CapturePackage {
  static const manifest = 'capture.json';

  final String dir;
  final List<CaptureFrame> frames;
  final String? device;

  /// 1 sin estructura; 2 con [planes], [marks] y [points] (ES.1).
  final int version;
  final List<CapturePlane> planes;
  final List<CaptureMark> marks;

  /// Nube dispersa de ARKit: x, y, z seguidos.
  final List<double> points;

  /// Una calle o un patio (`exterior`) o un local (`interior`, por defecto).
  final bool exterior;

  const CapturePackage(
    this.dir,
    this.frames, {
    this.device,
    this.version = 1,
    this.planes = const [],
    this.marks = const [],
    this.points = const [],
    this.exterior = false,
  });

  /// La temperatura de color de la localización: la mediana de las fotos
  /// sin linterna. Null si la captura no la trae.
  double? get kelvin {
    final k = [
      for (final f in frames)
        if (!f.torch && f.kelvin != null) f.kelvin!,
    ]..sort();
    return k.isEmpty ? null : k[k.length ~/ 2];
  }

  /// Cuánta luz había: la mediana de la intensidad de ARKit sin linterna.
  double? get lightIntensity {
    final v = [
      for (final f in frames)
        if (!f.torch && f.lightIntensity != null) f.lightIntensity!,
    ]..sort();
    return v.isEmpty ? null : v[v.length ~/ 2];
  }

  static bool isCapture(String dir) => File(p.join(dir, manifest)).existsSync();

  static CapturePackage? read(String dir) {
    try {
      final json =
          jsonDecode(File(p.join(dir, manifest)).readAsStringSync()) as Map;
      return fromJson(dir, json);
    } catch (_) {
      return null;
    }
  }

  static CapturePackage fromJson(String dir, Map json) {
    List<T> list<T>(String key, T? Function(Map) parse) => [
      for (final v in (json[key] as List? ?? const []))
        if (v is Map) ?parse(v),
    ];
    final points = json['points'];
    return CapturePackage(
      dir,
      list('frames', CaptureFrame.fromJson),
      device: json['device'] as String?,
      version: (json['version'] as num?)?.toInt() ?? 1,
      planes: list('planes', CapturePlane.fromJson),
      marks: list('marks', CaptureMark.fromJson),
      points: points is List && points.length % 3 == 0
          ? [for (final v in points) (v as num).toDouble()]
          : const [],
      exterior: json['setting'] == 'exterior',
    );
  }

  bool get hasStructure => planes.isNotEmpty || marks.isNotEmpty;

  /// Los puntos de la estructura en el mundo de ARKit (x, y, z seguidos),
  /// para llevarlos a la planta con la colocación del escaneo
  /// (`iris.scanToPlan`). [hintsFrom] los lee en el mismo orden.
  List<double> hintPoints() => [
    for (final pl in planes.where((pl) => pl.isWall)) ...[
      ...pl.faceEnds().$1,
      ...pl.faceEnds().$2,
    ],
    for (final m in marks) ...m.position,
  ];

  /// Las pistas para el solucionador, con [mapped] = [hintPoints] ya en la
  /// planta (x, altura, y de la planta).
  CaptureHints hintsFrom(List<double> mapped) {
    Offset at(int i) => Offset(mapped[i * 3], mapped[i * 3 + 2]);
    final walls = planes.where((pl) => pl.isWall).length;
    if (mapped.length != (walls * 2 + marks.length) * 3) {
      return const CaptureHints();
    }
    final corners = <Offset>[], storefronts = <Offset>[];
    final lights = <ScanLight>[];
    final floors = <double>[], ceilings = <double>[];
    for (var i = 0; i < marks.length; i++) {
      final k = walls * 2 + i;
      switch (marks[i].kind) {
        case 'corner':
          corners.add(at(k));
        case 'floor':
          floors.add(mapped[k * 3 + 1]);
        case 'ceiling':
          ceilings.add(mapped[k * 3 + 1]);
        case 'storefront':
          storefronts.add(at(k));
        case 'light':
          lights.add(
            ScanLight(at(k), mapped[k * 3 + 1], marks[i].label ?? 'práctica'),
          );
      }
    }
    double? mean(List<double> v) =>
        v.isEmpty ? null : v.reduce((a, b) => a + b) / v.length;
    return CaptureHints(
      wallPlanes: [for (var i = 0; i < walls; i++) (at(i * 2), at(i * 2 + 1))],
      corners: corners,
      floorY: mean(floors),
      ceilingY: mean(ceilings),
      storefronts: storefronts,
      lights: lights,
      exterior: exterior,
    );
  }

  /// Escribe junto a cada foto su `.xmp` para RealityScan. Devuelve cuántas
  /// fotos lo tienen.
  int writeSidecars() {
    var n = 0;
    for (final f in frames) {
      if (!File(p.join(dir, f.file)).existsSync()) continue;
      File(
        p.join(dir, '${p.basenameWithoutExtension(f.file)}.xmp'),
      ).writeAsStringSync(xmpFor(f));
      n++;
    }
    return n;
  }
}

/// La pose de una foto en la convención de RealityScan: [rotation] (3×3 por
/// filas) lleva del mundo a la cámara, con la cámara mirando a +Z y la Y
/// hacia abajo; [position] es el centro de la cámara. El mundo de
/// RealityScan tiene Z arriba: (x, y, z) de ARKit pasa a (x, −z, y).
({List<double> rotation, List<double> position}) realityScanPose(
  CaptureFrame f,
) {
  List<double> toWorld(List<double> v) => [v[0], -v[2], v[1]];
  final right = toWorld(f.column(0));
  final up = toWorld(f.column(1));
  final back = toWorld(f.column(2));
  return (
    rotation: [
      ...right,
      ...[for (final v in up) -v],
      ...[for (final v in back) -v],
    ],
    position: toWorld(f.column(3)),
  );
}

/// El XMP de RealityScan para una foto (`Help\en-US\tools\xmpalign.htm`).
/// `PosePrior="initial"`: la posición es de partida y la alineación la
/// afina, pero se queda en metros y con la vertical de la gravedad.
String xmpFor(CaptureFrame f) {
  final pose = realityScanPose(f);
  final side = math.max(f.width, f.height).toDouble();
  String n(double v) => v.toStringAsFixed(9);
  final focal35 = f.intrinsics[0] / side * 36;
  final ppu = (f.intrinsics[2] - f.width / 2) / side;
  final ppv = (f.intrinsics[3] - f.height / 2) / side;
  return '<x:xmpmeta xmlns:x="adobe:ns:meta/">\n'
      '  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">\n'
      '    <rdf:Description xmlns:xcr="http://www.capturingreality.com/ns/xcr/1.1#"\n'
      '       xcr:Version="3" xcr:PosePrior="initial" xcr:Coordinates="absolute"\n'
      '       xcr:Rotation="${pose.rotation.map(n).join(' ')}"\n'
      '       xcr:DistortionModel="division" xcr:DistortionCoeficients="0 0 0 0 0 0"\n'
      '       xcr:FocalLength35mm="${n(focal35)}" xcr:Skew="0" xcr:AspectRatio="1"\n'
      '       xcr:PrincipalPointU="${n(ppu)}" xcr:PrincipalPointV="${n(ppv)}"\n'
      '       xcr:CalibrationPrior="initial" xcr:CalibrationGroup="-1"\n'
      '       xcr:DistortionGroup="-1" xcr:InTexturing="1" xcr:InMeshing="1">\n'
      '      <xcr:Position>${pose.position.map(n).join(' ')}</xcr:Position>\n'
      '    </rdf:Description>\n'
      '  </rdf:RDF>\n'
      '</x:xmpmeta>\n';
}
