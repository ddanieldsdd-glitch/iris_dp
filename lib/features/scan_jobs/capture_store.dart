import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/database/app_database.dart';
import '../../core/sync/realtime_hub.dart';

/// Estados de una captura, en el orden en que pasa por ellos.
abstract final class CaptureStatus {
  /// Hecha, esperando a coincidir en la Wi‑Fi con el PC.
  static const onPhone = 'en_iphone';
  static const sending = 'enviando';

  /// Recibida en el PC, en la cola.
  static const onPc = 'en_pc';
  static const building = 'construyendo';
  static const done = 'listo';
  static const failed = 'error';

  static String label(String status) => switch (status) {
    onPhone => 'En el iPhone · se envía al coincidir con el PC',
    sending => 'Enviando al PC',
    onPc => 'En el PC · en la cola',
    building => 'Construyendo en el PC',
    done => 'Escaneo listo',
    failed => 'Error',
    _ => status,
  };
}

/// Dónde vive el zip de cada captura en este equipo: `Documentos/IRIS
/// Capturas/<uid>.iriscapture.zip`, en el iPhone (la deja el plugin de la
/// captura) y en el PC (la deja el receptor).
abstract final class CaptureStore {
  static Directory? debugRoot;

  static Future<Directory> root() async {
    final base = debugRoot ?? await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'IRIS Capturas'));
    await dir.create(recursive: true);
    return dir;
  }

  static Future<File> zipFor(String uid) async =>
      File(p.join((await root()).path, '$uid.iriscapture.zip'));

  /// Registra lo que devuelve la captura guiada ([path]: el .zip o, si el
  /// sistema no pudo comprimir, la carpeta) como una captura del proyecto
  /// enlazada a su set o localización. Deja el zip con su uid y borra la
  /// carpeta suelta, que ocupa lo mismo otra vez.
  static Future<LocationCapture> register(
    AppDatabase db, {
    required int projectId,
    required String path,
    required String name,
    int? siteId,
    int? setId,
  }) async {
    var zipPath = path;
    String? folder;
    if (await Directory(path).exists()) {
      folder = path;
      zipPath = '$path.zip';
      final encoder = ZipFileEncoder()..create(zipPath);
      await encoder.addDirectory(Directory(path), includeDirName: false);
      await encoder.close();
    } else if (path.endsWith('.zip')) {
      final sibling = path.substring(0, path.length - '.zip'.length);
      if (await Directory(sibling).exists()) folder = sibling;
    }
    final photos = await _photoCount(folder, zipPath);

    final id = await db.insertCapture(
      LocationCapturesCompanion.insert(
        projectId: projectId,
        siteId: Value(siteId),
        setId: Value(setId),
        name: name,
        photoCount: Value(photos),
        bytes: Value(await File(zipPath).length()),
        originInstallId: Value(await InstallId.get()),
      ),
    );
    final row = (await db.watchCapturesForProject(projectId).first).firstWhere(
      (c) => c.id == id,
    );
    final dest = await zipFor(row.uid!);
    await _move(File(zipPath), dest);
    if (folder != null) {
      try {
        await Directory(folder).delete(recursive: true);
      } on FileSystemException {
        // Se queda: solo ocupa sitio.
      }
    }
    return row;
  }

  /// Fotos de la captura según su `capture.json` (o, si no lo hay, las
  /// imágenes que lleva).
  static Future<int> _photoCount(String? folder, String zipPath) async {
    if (folder != null) {
      final manifest = File(p.join(folder, 'capture.json'));
      if (await manifest.exists()) {
        try {
          final json = jsonDecode(await manifest.readAsString()) as Map;
          return (json['frames'] as List).length;
        } on Object {
          // Se cuentan abajo.
        }
      }
      return Directory(folder).listSync().where((f) => _isImage(f.path)).length;
    }
    try {
      final input = InputFileStream(zipPath);
      final archive = ZipDecoder().decodeBuffer(input);
      final count = archive.files.where((f) => _isImage(f.name)).length;
      await input.close();
      return count;
    } on Object {
      return 0;
    }
  }

  static bool _isImage(String name) {
    final ext = p.extension(name).toLowerCase();
    return ext == '.jpg' || ext == '.jpeg' || ext == '.heic' || ext == '.png';
  }

  static Future<void> _move(File from, File to) async {
    if (from.path == to.path) return;
    try {
      await from.rename(to.path);
    } on FileSystemException {
      await from.copy(to.path);
      await from.delete();
    }
  }

  /// Borra el zip de este equipo (la fila sigue: es del proyecto).
  static Future<void> deleteLocal(String uid) async {
    final file = await zipFor(uid);
    if (await file.exists()) await file.delete();
  }
}
