import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'custom_brush_store.dart';
import 'paper_library.dart';

/// Lo que ha entrado en una pasada de [AutoImport].
class AutoImportResult {
  final int brushes;
  final int papers;
  final int palettes;
  final List<String> failed;

  const AutoImportResult({
    this.brushes = 0,
    this.papers = 0,
    this.palettes = 0,
    this.failed = const [],
  });

  bool get isEmpty =>
      brushes == 0 && papers == 0 && palettes == 0 && failed.isEmpty;

  String describe() => [
    if (brushes > 0) '$brushes ${brushes == 1 ? 'pincel' : 'pinceles'}',
    if (papers > 0) '$papers ${papers == 1 ? 'papel' : 'papeles'}',
    if (palettes > 0) '$palettes ${palettes == 1 ? 'paleta' : 'paletas'}',
  ].join(', ');
}

/// Importa sola lo que se deja en la carpeta de la app
/// `Documents/Importar` (en el iPad: Archivos › En mi iPad › IRIS DP):
/// `Pinceles` (.brushset, .brush), `Papeles` (PNG, JPG) y `Paletas`
/// (.swatches). Lo ya procesado se mueve a `Importar/Hechos`, y lo que no
/// se pudo leer a `Importar/No se pudo`, para no repetirlo.
abstract final class AutoImport {
  static Future<AutoImportResult>? _running;

  static const folders = ['Pinceles', 'Papeles', 'Paletas'];

  /// Una pasada; si ya hay una en marcha, devuelve esa.
  static Future<AutoImportResult> run({
    Future<Directory> Function()? documents,
    CustomBrushStore? brushes,
    PaperLibrary? papers,
  }) {
    final running = _running;
    if (running != null) return running;
    final future = _run(
      documents ?? getApplicationDocumentsDirectory,
      brushes ?? CustomBrushStore.instance,
      papers ?? PaperLibrary.instance,
    ).whenComplete(() => _running = null);
    return _running = future;
  }

  static Future<AutoImportResult> _run(
    Future<Directory> Function() documents,
    CustomBrushStore brushStore,
    PaperLibrary paperLibrary,
  ) async {
    final Directory root;
    try {
      root = Directory(p.join((await documents()).path, 'Importar'));
      // Las carpetas se crean para que se vean en Archivos.
      for (final name in folders) {
        Directory(p.join(root.path, name)).createSync(recursive: true);
      }
    } catch (_) {
      return const AutoImportResult();
    }
    var brushes = 0, papers = 0, palettes = 0;
    final failed = <String>[];

    Future<void> each(
      String folder,
      bool Function(String ext) accepts,
      Future<int> Function(String path, String? group) importer,
    ) async {
      final dir = Directory(p.join(root.path, folder));
      // También en subcarpetas: cada carpeta de kit es un grupo.
      final files =
          dir
              .listSync(recursive: true)
              .whereType<File>()
              .where((f) => accepts(p.extension(f.path).toLowerCase()))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));
      for (final file in files) {
        var ok = false;
        final relative = p.relative(file.parent.path, from: dir.path);
        final group = relative == '.' ? null : p.split(relative).first;
        try {
          final added = await importer(file.path, group);
          ok = true;
          if (folder == 'Pinceles') brushes += added;
          if (folder == 'Papeles') papers += added;
          if (folder == 'Paletas') palettes += added;
        } catch (_) {
          failed.add(p.basename(file.path));
        }
        _moveAway(
          file,
          p.join(root.path, ok ? 'Hechos' : 'No se pudo', folder),
        );
      }
    }

    await each(
      'Pinceles',
      (ext) => ext == '.brushset' || ext == '.brush',
      (path, group) async =>
          (await brushStore.importProcreateFile(path, group: group)).length,
    );
    await each(
      'Papeles',
      (ext) => const ['.png', '.jpg', '.jpeg'].contains(ext),
      (path, group) async {
        await paperLibrary.importPaper(path, group: group);
        return 1;
      },
    );
    await each(
      'Paletas',
      (ext) => ext == '.swatches',
      (path, group) async => (await paperLibrary.importSwatches(path)).length,
    );
    return AutoImportResult(
      brushes: brushes,
      papers: papers,
      palettes: palettes,
      failed: failed,
    );
  }

  static void _moveAway(File file, String toDir) {
    try {
      Directory(toDir).createSync(recursive: true);
      var target = p.join(toDir, p.basename(file.path));
      if (File(target).existsSync()) {
        final stamp = DateTime.now().millisecondsSinceEpoch;
        target = p.join(
          toDir,
          '${p.basenameWithoutExtension(file.path)} $stamp'
          '${p.extension(file.path)}',
        );
      }
      file.renameSync(target);
    } catch (_) {
      // Si no se puede mover, se borra la copia de la carpeta de entrada
      // para no importarla otra vez.
      try {
        file.deleteSync();
      } catch (_) {}
    }
  }
}
