import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// RealityScan (o RealityCapture, su nombre anterior) instalado en este PC.
class RealityScanInstall {
  final String exe;
  const RealityScanInstall(this.exe);

  String get name => p.basenameWithoutExtension(exe);

  static const _exeNames = ['RealityScan.exe', 'RealityCapture.exe'];

  /// Busca el ejecutable en las carpetas de la lista del Epic Games Launcher
  /// y en las de por defecto. `AppProxy.exe` no vale: es solo el instalador.
  static RealityScanInstall? find({
    List<String> roots = const [
      r'C:\Program Files\Epic Games',
      r'C:\Program Files\Capturing Reality',
    ],
    String launcherFile =
        r'C:\ProgramData\Epic\UnrealEngineLauncher\LauncherInstalled.dat',
  }) {
    final dirs = <String>{};
    try {
      final json = jsonDecode(File(launcherFile).readAsStringSync()) as Map;
      for (final item in (json['InstallationList'] as List? ?? const [])) {
        final location = (item as Map)['InstallLocation'] as String?;
        if (location != null) dirs.add(location);
      }
    } catch (_) {}
    for (final root in roots) {
      final d = Directory(root);
      if (!d.existsSync()) continue;
      dirs.addAll(d.listSync().whereType<Directory>().map((e) => e.path));
    }
    // RealityScan antes que RealityCapture, y la versión más alta primero.
    final sorted =
        dirs
            .where(
              (d) => RegExp(
                'Reality(Scan|Capture)',
                caseSensitive: false,
              ).hasMatch(p.basename(d)),
            )
            .toList()
          ..sort((a, b) => p.basename(b).compareTo(p.basename(a)));
    for (final d in sorted) {
      for (final exe in _exeNames) {
        final f = File(p.join(d, exe));
        if (f.existsSync()) return RealityScanInstall(f.path);
      }
    }
    return null;
  }
}

/// ffmpeg, para sacar fotogramas de un vídeo: en el PATH o donde lo deja
/// winget.
String? findFfmpeg({Map<String, String>? environment}) {
  final env = environment ?? Platform.environment;
  final dirs = [
    ...(env['PATH'] ?? env['Path'] ?? '').split(';'),
    if (env['LOCALAPPDATA'] case final local?)
      p.join(local, 'Microsoft', 'WinGet', 'Links'),
  ];
  for (final d in dirs) {
    if (d.trim().isEmpty) continue;
    final f = File(p.join(d.trim(), 'ffmpeg.exe'));
    if (f.existsSync()) return f.path;
  }
  return null;
}

/// Ajustes del escaneo. Los triángulos de la versión de IRIS la dejan por
/// debajo de los 50 MB que viajan por la nube con texturas de 4K.
class ScanBuildSettings {
  /// Malla que se queda en el PC para Unreal (Nanite la aguanta).
  final int highTriangles;

  /// Malla que va a la planta, el 3D y la nube.
  final int irisTriangles;

  /// Fotogramas por segundo que se sacan de un vídeo.
  final double videoFps;

  const ScanBuildSettings({
    this.highTriangles = 3000000,
    this.irisTriangles = 400000,
    this.videoFps = 2,
  });
}

/// Fotos que acepta RealityScan.
const scanPhotoFormats = ['jpg', 'jpeg', 'png', 'tif', 'tiff', 'dng'];

/// Vídeos que se pueden usar.
const scanVideoFormats = ['mp4', 'mov', 'm4v', 'mkv', 'avi'];

bool isScanPhoto(String path) => scanPhotoFormats.contains(
  p.extension(path).replaceFirst('.', '').toLowerCase(),
);

/// Los argumentos de RealityScan sin interfaz: alinear, malla, limpiar,
/// texturizar, exportar la malla alta para Unreal, simplificar y exportar
/// la de IRIS. Los dos GLB llevan las texturas dentro.
///
/// Los nombres de los comandos son los de la línea de comandos de
/// RealityCapture 1.x, que RealityScan 2 mantiene.
List<String> realityScanArgs({
  required String imagesDir,
  required String highGlb,
  required String irisGlb,
  required String projectFile,
  ScanBuildSettings settings = const ScanBuildSettings(),
}) => [
  '-headless',
  '-newScene',
  '-addFolder',
  imagesDir,
  '-align',
  '-selectMaximalComponent',
  '-setReconstructionRegionAuto',
  '-calculateNormalModel',
  '-selectMarginalTriangles',
  '-removeSelectedTriangles',
  '-simplify',
  '${settings.highTriangles}',
  '-calculateTexture',
  '-exportSelectedModel',
  highGlb,
  '-simplify',
  '${settings.irisTriangles}',
  '-calculateTexture',
  '-exportSelectedModel',
  irisGlb,
  '-save',
  projectFile,
  '-quit',
];

/// Los argumentos de ffmpeg para sacar [fps] fotogramas por segundo, en JPG
/// de calidad alta, a [outDir].
List<String> ffmpegArgs(String video, String outDir, double fps) => [
  '-hide_banner',
  '-loglevel',
  'error',
  '-i',
  video,
  '-vf',
  'fps=$fps',
  '-q:v',
  '2',
  p.join(outDir, 'f_%05d.jpg'),
];

/// Nitidez de una imagen: varianza del laplaciano sobre la imagen en gris
/// reducida a 640 px de ancho. Una foto movida da un valor bajo.
double sharpness(img.Image image) {
  final small = image.width > 640 ? img.copyResize(image, width: 640) : image;
  final w = small.width, h = small.height;
  if (w < 3 || h < 3) return 0;
  final gray = Float64List(w * h);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final px = small.getPixel(x, y);
      gray[y * w + x] = 0.299 * px.r + 0.587 * px.g + 0.114 * px.b;
    }
  }
  var sum = 0.0, sumSq = 0.0;
  var n = 0;
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      final i = y * w + x;
      final lap =
          gray[i - 1] + gray[i + 1] + gray[i - w] + gray[i + w] - 4 * gray[i];
      sum += lap;
      sumSq += lap * lap;
      n++;
    }
  }
  final mean = sum / n;
  return sumSq / n - mean * mean;
}

/// Los fotogramas que se quedan: fuera los que tienen menos de [ratio] de
/// la nitidez mediana (movidos o desenfocados).
List<String> keepSharp(Map<String, double> scores, {double ratio = 0.4}) {
  if (scores.length < 3) return scores.keys.toList()..sort();
  final values = scores.values.toList()..sort();
  final median = values[values.length ~/ 2];
  return [
    for (final e in scores.entries)
      if (e.value >= median * ratio) e.key,
  ]..sort();
}

/// En qué va la creación del escaneo.
enum ScanBuildStage { frames, sharpness, reconstructing, done, error }

class ScanBuildProgress {
  final ScanBuildStage stage;
  final String message;

  /// De 0 a 1 cuando se sabe; `null` si no (RealityScan no lo dice).
  final double? fraction;
  final ScanBuildResult? result;

  const ScanBuildProgress(
    this.stage,
    this.message, {
    this.fraction,
    this.result,
  });
}

class ScanBuildResult {
  /// GLB para IRIS: se importa a la planta como cualquier escaneo.
  final String irisGlb;

  /// GLB con todo el detalle, para Unreal. Se queda en el PC.
  final String highGlb;

  /// Carpeta del trabajo (fotogramas, proyecto de RealityScan y mallas).
  final String folder;
  final int images;
  final int discarded;

  const ScanBuildResult({
    required this.irisGlb,
    required this.highGlb,
    required this.folder,
    required this.images,
    required this.discarded,
  });
}

/// De una carpeta de fotos o un vídeo a un escaneo (F6.20 E1–E2), sin abrir
/// RealityScan.
///
/// 1. Vídeo: ffmpeg saca los fotogramas y se descartan los movidos. Fotos:
///    se usan todas (quien fotografía ya elige).
/// 2. RealityScan alinea, hace la malla, la texturiza y exporta dos GLB: el
///    alto para Unreal y el ligero para IRIS.
///
/// Todo queda en `Documentos\IRIS Escaneos\<nombre>`.
class ScanBuildJob {
  ScanBuildJob({
    required this.source,
    required this.name,
    required this.realityScan,
    this.ffmpeg,
    this.settings = const ScanBuildSettings(),
    this.outputRoot,
  });

  /// Carpeta de fotos o archivo de vídeo.
  final String source;
  final String name;
  final RealityScanInstall realityScan;
  final String? ffmpeg;
  final ScanBuildSettings settings;

  /// Para pruebas; si no, `Documentos\IRIS Escaneos`.
  final String? outputRoot;

  /// Pocas fotos: RealityScan alinea mal por debajo de esto.
  static const minImages = 20;

  Process? _process;
  bool _cancelled = false;

  bool get isVideo => FileSystemEntity.isFileSync(source);

  void cancel() {
    _cancelled = true;
    _process?.kill();
  }

  /// Nombre de carpeta seguro a partir del nombre que pone el usuario.
  static String folderName(String name, DateTime now) {
    final clean = name
        .trim()
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    String two(int v) => v.toString().padLeft(2, '0');
    final stamp =
        '${now.year}${two(now.month)}${two(now.day)}-${two(now.hour)}${two(now.minute)}';
    return '${clean.isEmpty ? 'Escaneo' : clean} $stamp';
  }

  Stream<ScanBuildProgress> run() async* {
    try {
      final root =
          outputRoot ??
          p.join(
            (await getApplicationDocumentsDirectory()).path,
            'IRIS Escaneos',
          );
      final folder = Directory(p.join(root, folderName(name, DateTime.now())));
      await folder.create(recursive: true);

      var imagesDir = source;
      var discarded = 0;
      if (isVideo) {
        final ff = ffmpeg;
        if (ff == null) {
          yield const ScanBuildProgress(
            ScanBuildStage.error,
            'Para usar un vídeo hace falta ffmpeg. Instálalo con '
            '«winget install ffmpeg» y vuelve a abrir IRIS, o usa una '
            'carpeta de fotos.',
          );
          return;
        }
        final frames = Directory(p.join(folder.path, 'fotogramas'));
        await frames.create();
        yield const ScanBuildProgress(
          ScanBuildStage.frames,
          'Sacando fotogramas del vídeo…',
        );
        _process = await Process.start(
          ff,
          ffmpegArgs(source, frames.path, settings.videoFps),
        );
        final err = StringBuffer();
        _process!.stderr.transform(utf8.decoder).listen(err.write);
        _process!.stdout.drain<void>();
        final code = await _process!.exitCode;
        if (_cancelled) return;
        if (code != 0) {
          yield ScanBuildProgress(
            ScanBuildStage.error,
            'ffmpeg no ha podido leer el vídeo. ${err.toString().trim()}',
          );
          return;
        }
        final files = frames
            .listSync()
            .whereType<File>()
            .map((f) => f.path)
            .where(isScanPhoto)
            .toList();
        final scores = <String, double>{};
        for (var i = 0; i < files.length; i++) {
          if (_cancelled) return;
          if (i % 4 == 0) {
            yield ScanBuildProgress(
              ScanBuildStage.sharpness,
              'Descartando fotogramas movidos (${i + 1} de ${files.length})…',
              fraction: i / files.length,
            );
          }
          final path = files[i];
          scores[path] = await Isolate.run(() {
            final image = img.decodeImage(File(path).readAsBytesSync());
            return image == null ? 0.0 : sharpness(image);
          });
        }
        final keep = keepSharp(scores).toSet();
        for (final f in files) {
          if (!keep.contains(f)) {
            await File(f).delete();
            discarded++;
          }
        }
        imagesDir = frames.path;
      }

      final count = Directory(
        imagesDir,
      ).listSync().whereType<File>().where((f) => isScanPhoto(f.path)).length;
      if (count < minImages) {
        yield ScanBuildProgress(
          ScanBuildStage.error,
          'Solo hay $count imágenes útiles; hacen falta al menos $minImages '
          '(mejor 200 o más, con solape).',
        );
        return;
      }

      final highGlb = p.join(folder.path, 'unreal.glb');
      final irisGlb = p.join(folder.path, 'iris.glb');
      yield ScanBuildProgress(
        ScanBuildStage.reconstructing,
        'RealityScan está creando el escaneo con $count imágenes. Puede '
        'tardar de 15 minutos a varias horas.',
      );
      _process = await Process.start(
        realityScan.exe,
        realityScanArgs(
          imagesDir: imagesDir,
          highGlb: highGlb,
          irisGlb: irisGlb,
          projectFile: p.join(
            folder.path,
            realityScan.name == 'RealityCapture'
                ? 'escaneo.rcproj'
                : 'escaneo.rsproj',
          ),
          settings: settings,
        ),
      );
      _process!.stdout.drain<void>();
      _process!.stderr.drain<void>();
      final code = await _process!.exitCode;
      if (_cancelled) return;
      if (!File(irisGlb).existsSync()) {
        yield ScanBuildProgress(
          ScanBuildStage.error,
          'RealityScan ha terminado (código $code) sin dar el escaneo. '
          'Abre ${p.basename(folder.path)} en RealityScan para ver qué no '
          'ha alineado; suele ser poco solape o superficies lisas.',
        );
        return;
      }
      final result = ScanBuildResult(
        irisGlb: irisGlb,
        highGlb: highGlb,
        folder: folder.path,
        images: count,
        discarded: discarded,
      );
      yield ScanBuildProgress(
        ScanBuildStage.done,
        'Escaneo listo.',
        fraction: 1,
        result: result,
      );
    } catch (e) {
      if (_cancelled) return;
      yield ScanBuildProgress(ScanBuildStage.error, 'No se ha podido: $e');
    }
  }
}
