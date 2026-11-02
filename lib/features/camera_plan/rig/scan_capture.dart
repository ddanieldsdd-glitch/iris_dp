import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:path/path.dart' as p;

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

  const CaptureFrame({
    required this.file,
    required this.transform,
    required this.intrinsics,
    required this.width,
    required this.height,
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
    );
  }

  /// Columna [c] (0–3) de la matriz: los ejes de la cámara y su posición.
  List<double> column(int c) => transform.sublist(c * 4, c * 4 + 3);
}

/// Una captura guiada: la carpeta con las fotos y su `capture.json`.
class CapturePackage {
  static const manifest = 'capture.json';

  final String dir;
  final List<CaptureFrame> frames;
  final String? device;

  const CapturePackage(this.dir, this.frames, {this.device});

  static bool isCapture(String dir) => File(p.join(dir, manifest)).existsSync();

  static CapturePackage? read(String dir) {
    try {
      final json =
          jsonDecode(File(p.join(dir, manifest)).readAsStringSync()) as Map;
      final frames = [
        for (final f in (json['frames'] as List? ?? const []))
          if (f is Map) ?CaptureFrame.fromJson(f),
      ];
      return CapturePackage(dir, frames, device: json['device'] as String?);
    } catch (_) {
      return null;
    }
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
