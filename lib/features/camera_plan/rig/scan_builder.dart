import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/settings/app_prefs.dart';
import 'scan_glb.dart';

/// RealityScan (o RealityCapture, su nombre anterior) instalado en este PC.
class RealityScanInstall {
  final String exe;
  const RealityScanInstall(this.exe);

  String get name => p.basenameWithoutExtension(exe);

  static const _exeNames = ['RealityScan.exe', 'RealityCapture.exe'];

  /// El ejecutable elegido a mano, si RealityScan está donde no se busca.
  static const pathKey = PrefKey<String>('scanBuilder.realityScan', '');

  /// Lo elegido a mano, si sigue ahí; si no, lo que encuentre [find].
  static RealityScanInstall? located() {
    final saved = AppPrefs.instance.get(pathKey);
    if (saved.isNotEmpty && File(saved).existsSync()) {
      return RealityScanInstall(saved);
    }
    return find();
  }

  static Future<void> remember(String exe) =>
      AppPrefs.instance.setIn(pathKey, const SettingsScope.global(), exe);

  /// Busca el ejecutable:
  /// - en los manifiestos del Epic Games Launcher (RealityScan 2 se apunta
  ///   ahí, en el disco que se eligiera al instalarlo);
  /// - en la lista de lo instalado del launcher;
  /// - en las carpetas de por defecto.
  ///
  /// `AppProxy.exe` no vale: es solo el instalador.
  static RealityScanInstall? find({
    List<String> roots = const [
      r'C:\Program Files\Epic Games',
      r'C:\Program Files\Capturing Reality',
    ],
    String launcherFile =
        r'C:\ProgramData\Epic\UnrealEngineLauncher\LauncherInstalled.dat',
    String manifestsDir =
        r'C:\ProgramData\Epic\EpicGamesLauncher\Data\Manifests',
  }) {
    final dirs = <String>{};
    try {
      for (final f in Directory(manifestsDir).listSync().whereType<File>()) {
        if (!f.path.toLowerCase().endsWith('.item')) continue;
        try {
          final json = jsonDecode(f.readAsStringSync()) as Map;
          final location = json['InstallLocation'] as String?;
          if (location != null) dirs.add(location);
        } catch (_) {}
      }
    } catch (_) {}
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
/// la de IRIS. Los dos GLB llevan las texturas dentro: una de 8K para
/// Unreal y una de 4K para IRIS.
///
/// Comprobados con la ayuda de RealityScan 2.2 (`Help\en-US\appbasics\
/// allcommands.htm`). Sin diálogos (`-silent`), sale si algo falla y apunta
/// el progreso en [progressFile] cada 5 s.
///
/// Con [video] (cuando no hay ffmpeg), RealityScan saca él mismo un
/// fotograma cada `1 / videoFps` segundos a [imagesDir], sin descartar los
/// movidos.
List<String> realityScanArgs({
  required String imagesDir,
  required String highGlb,
  required String irisGlb,
  required String projectFile,
  String? exportXml,
  String? progressFile,
  String? crashDir,
  String? video,
  ScanBuildSettings settings = const ScanBuildSettings(),
}) => [
  '-headless',
  if (crashDir != null) ...['-silent', crashDir],
  '-set',
  'appQuitOnError=true',
  if (progressFile != null) ...['-writeProgress', progressFile, '5'],
  '-newScene',
  if (video != null) ...[
    '-importVideo',
    video,
    imagesDir,
    '${1 / settings.videoFps}',
  ] else ...[
    '-addFolder',
    imagesDir,
  ],
  '-set',
  'unwrapStyle=MaxTexturesCount',
  '-set',
  'unwrapMaximalTexCount=1',
  '-align',
  '-selectMaximalComponent',
  '-setReconstructionRegionAuto',
  // El suelo en el plano de la rejilla: el escaneo sale con el suelo a 0.
  '-setGroundPlaneFromReconstructionRegion',
  '-calculateNormalModel',
  '-selectMarginalTriangles',
  '-removeSelectedTriangles',
  '-simplify',
  '${settings.highTriangles}',
  '-set',
  'unwrapMaxTexResolution=8192',
  '-calculateTexture',
  '-exportSelectedModel',
  highGlb,
  ?exportXml,
  '-simplify',
  '${settings.irisTriangles}',
  '-set',
  'unwrapMaxTexResolution=4096',
  '-calculateTexture',
  '-exportSelectedModel',
  irisGlb,
  ?exportXml,
  '-save',
  projectFile,
  '-quit',
];

/// Ajustes del exporte de RealityScan: GLB con la textura dentro, en JPG.
/// Sin esto deja la textura en un PNG aparte, y a IRIS (que copia un solo
/// archivo) le llegaría el escaneo sin color. Es el mismo formato que el
/// `.rsInfo` que escribe RealityScan junto a cada exporte.
const realityScanExportXml = r'''
<ModelExport exportBinary="1" exportInfoFile="1" exportVertices="1" exportVertexColors="0"
   exportVertexColorSpace="0" exportVertexNormals="0" exportTriangles="1"
   exportTriangleStrips="0" meshColor="1 1 1" tileType="1" exportTextureAlpha="0"
   exportToOneTexture="0" embedTextures="1" shrinkTextures="0" oneTextureMaxSide="8192"
   oneTextureUsePow2TexSide="1" exportCoordinateSystemType="0" settingsAnchor="0 0 0"
   settingsRotation="0 0 0" settingsScale="1 1 1" normalSpace="2" normalRange="0"
   normalFlip="0 0 0" formatAndVersionUID="glb 000 " exportModelByParts="0"
   exportRandomPartColor="0" exportCameras="0" exportCamerasAsModelPart="0"
   exportMaterials="0" numberAsciiFormatting="5" authorComment="" exportedLayerCount="1"
   classificationLayer="-1" moreDetails="">
  <Header magic="5786949" version="6"/>
  <Layer0 type="1" textureLayerIndex="0" textureWicContainerFormat="{19E4A5AA-5662-4FC5-A0C0-1758028E1057}"
     textureWicPixelFormat="{6FDDC324-4E03-4BFE-B185-3D77768DC90F}" textureExtension="jpg"
     mapQualityToColor="0"/>
</ModelExport>
''';

/// Una línea del archivo de `-writeProgress`:
/// `algId progreso duración estimación #evento`, con el progreso de 0 a 1 y
/// los tiempos en segundos.
class RealityScanProgress {
  final int algId;
  final double fraction;
  final double remainingS;

  const RealityScanProgress(this.algId, this.fraction, this.remainingS);

  /// La última línea válida del archivo, o `null`.
  static RealityScanProgress? lastOf(String text) {
    for (final line in text.split('\n').reversed) {
      final w = line.trim().split(RegExp(r'\s+'));
      if (w.length < 4) continue;
      final id = int.tryParse(w[0]);
      final f = double.tryParse(w[1]), r = double.tryParse(w[3]);
      if (id == null || f == null || r == null) continue;
      return RealityScanProgress(id, f.clamp(0, 1).toDouble(), r);
    }
    return null;
  }

  /// En qué está, por su número de proceso (`tutorials\processids.htm`;
  /// 65536 y 65537 no están ahí, pero son los de alinear en RealityScan 2.2).
  String get stage => switch (algId) {
    65536 || 65537 => 'Alineando las fotos',
    8208 => 'Mapas de profundidad',
    8240 || 8242 || 20561 || 20562 || 20560 => 'Creando la malla',
    7 || 8 => 'Texturizando',
    11 || 44 => 'Simplificando',
    6 => 'Exportando',
    20533 || 20534 => 'Guardando',
    10 => 'Limpiando la malla',
    _ => 'Procesando',
  };

  String get remaining {
    final s = remainingS.round();
    if (s <= 0) return '';
    if (s < 60) return 'quedan $s s';
    if (s < 3600) return 'quedan ${(s / 60).round()} min';
    return 'quedan ${s ~/ 3600} h ${(s % 3600) ~/ 60} min';
  }
}

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
      // Sin ffmpeg, el vídeo lo trocea RealityScan (sin descartar movidos).
      String? rsVideo;
      final ff = ffmpeg;
      if (isVideo && ff == null) {
        imagesDir = p.join(folder.path, 'fotogramas');
        await Directory(imagesDir).create();
        rsVideo = source;
      } else if (isVideo && ff != null) {
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

      final count = rsVideo != null
          ? null
          : Directory(imagesDir)
                .listSync()
                .whereType<File>()
                .where((f) => isScanPhoto(f.path))
                .length;
      if (count != null && count < minImages) {
        yield ScanBuildProgress(
          ScanBuildStage.error,
          'Solo hay $count imágenes útiles; hacen falta al menos $minImages '
          '(mejor 200 o más, con solape).',
        );
        return;
      }

      final highGlb = p.join(folder.path, 'unreal.glb');
      final irisGlb = p.join(folder.path, 'iris.glb');
      final intro = count == null
          ? 'RealityScan está creando el escaneo con los fotogramas del vídeo.'
          : 'RealityScan está creando el escaneo con $count imágenes.';
      yield ScanBuildProgress(
        ScanBuildStage.reconstructing,
        '$intro Puede tardar de 15 minutos a varias horas.',
      );
      final progressFile = File(p.join(folder.path, 'progreso.txt'));
      final exportXml = File(p.join(folder.path, 'exporte.xml'));
      await exportXml.writeAsString(realityScanExportXml);
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
          exportXml: exportXml.path,
          progressFile: progressFile.path,
          crashDir: p.join(folder.path, 'errores'),
          video: rsVideo,
          settings: settings,
        ),
      );
      _process!.stdout.drain<void>();
      _process!.stderr.drain<void>();
      int? code;
      unawaited(_process!.exitCode.then((c) => code = c));
      // Mientras trabaja, lo que apunta en el archivo de progreso.
      while (code == null) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (_cancelled) return;
        if (!progressFile.existsSync()) continue;
        String text;
        try {
          text = progressFile.readAsStringSync();
        } catch (_) {
          continue;
        }
        final last = RealityScanProgress.lastOf(text);
        if (last == null) continue;
        yield ScanBuildProgress(
          ScanBuildStage.reconstructing,
          '$intro\n${last.stage}'
          '${last.remaining.isEmpty ? '' : ' · ${last.remaining}'}',
          fraction: last.fraction,
        );
      }
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
      // RealityScan da Z arriba; glTF, Y arriba.
      yield const ScanBuildProgress(
        ScanBuildStage.reconstructing,
        'Poniendo el escaneo de pie…',
      );
      for (final path in [irisGlb, highGlb]) {
        if (!File(path).existsSync()) continue;
        await Isolate.run(() {
          final fixed = glbZUpToYUp(File(path).readAsBytesSync());
          if (fixed != null) File(path).writeAsBytesSync(fixed);
        });
      }
      final result = ScanBuildResult(
        irisGlb: irisGlb,
        highGlb: highGlb,
        folder: folder.path,
        images:
            count ??
            Directory(imagesDir)
                .listSync()
                .whereType<File>()
                .where((f) => isScanPhoto(f.path))
                .length,
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
