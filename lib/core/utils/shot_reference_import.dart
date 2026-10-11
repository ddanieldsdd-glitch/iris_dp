import 'dart:io';
import 'dart:convert';
import 'dart:math' show max;
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;

import '../database/app_database.dart';
import '../sync/media_sync_bridge.dart';
import 'export_file_saver.dart';
import 'media_storage.dart';

/// Origen de una imagen de referencia de plano.
abstract final class ShotReferenceSource {
  static const manual = 'manual';
  static const artemisCapture = 'artemis_capture';
  static const unrealRender = 'unreal_render';
}

/// Importa una imagen y la vincula al plano (miniatura + registro en [ShotReferences]).
/// Con [keepPrimary], la imagen se añade a las que ya tenga el plano sin
/// quitarle el puesto a la principal.
Future<String> importShotReferenceImage({
  required AppDatabase db,
  required Shot shot,
  String? sourcePath,
  Uint8List? sourceBytes,
  String? fileName,
  required String source,
  bool keepPrimary = false,
}) async {
  final String stored;
  if (sourceBytes != null) {
    stored = await MediaStorage.writeShotReferenceBytes(
      projectId: shot.projectId,
      shotId: shot.id,
      bytes: sourceBytes,
      fileName: fileName ?? 'referencia.jpg',
    );
  } else if (sourcePath != null) {
    stored = await MediaStorage.copyShotReference(
      projectId: shot.projectId,
      shotId: shot.id,
      sourcePath: sourcePath,
    );
  } else {
    throw ArgumentError('Se requiere sourcePath o sourceBytes');
  }

  // La principal de antes puede no tener fila propia (datos antiguos).
  final existing = await ensureShotReferencesSynced(db: db, shot: shot);
  await db.insertShotReference(
    ShotReferencesCompanion.insert(
      shotId: shot.id,
      imagePath: stored,
      source: Value(source),
      sortOrder: Value(
        existing.isEmpty ? 0 : existing.map((r) => r.sortOrder).reduce(max) + 1,
      ),
    ),
  );

  final primary = shot.referenceImagePath;
  final hasPrimary = primary != null && File(primary).existsSync();
  if (!keepPrimary || !hasPrimary) {
    await db.updateShotFields(
      shot.id,
      ShotsCompanion(referenceImagePath: Value(stored)),
    );
  }

  final queue = MediaSyncBridge.uploadQueue;
  if (queue != null) {
    await queue.scanAndEnqueueProject(shot.projectId);
  }

  return stored;
}

/// Abre el selector de imagen e importa al plano (sandbox macOS).
Future<String?> pickAndImportShotReference({
  required AppDatabase db,
  required Shot shot,
  required String source,
  String? dialogTitle,
  bool keepPrimary = false,
}) async {
  final file = await UserFilePicker.pickImage(
    dialogTitle: dialogTitle ?? 'Referencia · Plano ${shot.number}',
  );
  if (file == null) return null;

  final bytes = file.bytes;
  if (bytes == null || bytes.isEmpty) {
    throw StateError('No se pudo leer la imagen seleccionada');
  }

  return importShotReferenceImage(
    db: db,
    shot: shot,
    sourceBytes: bytes,
    fileName: file.name,
    source: source,
    keepPrimary: keepPrimary,
  );
}

/// Asegura que [referenceImagePath] tenga fila en [ShotReferences] (datos legacy).
Future<List<ShotReference>> ensureShotReferencesSynced({
  required AppDatabase db,
  required Shot shot,
}) async {
  var refs = await db.watchReferencesForShot(shot.id).first;
  final path = shot.referenceImagePath;
  if (path == null || !File(path).existsSync()) return refs;
  if (refs.any((r) => r.imagePath == path)) return refs;

  await db.insertShotReference(
    ShotReferencesCompanion.insert(
      shotId: shot.id,
      imagePath: path,
      source: const Value(ShotReferenceSource.manual),
      sortOrder: Value(refs.length),
    ),
  );
  return db.watchReferencesForShot(shot.id).first;
}

/// Marca una referencia existente como imagen principal del plano.
Future<void> setPrimaryShotReference({
  required AppDatabase db,
  required Shot shot,
  required String imagePath,
}) async {
  final refs = await db.watchReferencesForShot(shot.id).first;
  if (!refs.any((r) => r.imagePath == imagePath)) return;
  if (shot.referenceImagePath == imagePath) return;
  await db.updateShot(shot.copyWith(referenceImagePath: Value(imagePath)));
}

/// Elimina una referencia y actualiza la imagen principal si hace falta.
Future<void> deleteShotReferenceEntry({
  required AppDatabase db,
  required Shot shot,
  required ShotReference reference,
}) async {
  await db.deleteShotReference(reference.id);

  if (shot.referenceImagePath != reference.imagePath) return;

  final remaining = await db.watchReferencesForShot(shot.id).first;
  await db.updateShot(
    shot.copyWith(
      referenceImagePath: remaining.isEmpty
          ? const Value(null)
          : Value(remaining.first.imagePath),
    ),
  );
}

/// Imágenes de referencia propias del plano, en su orden: un plano con
/// varios encuadres lleva una por encuadre. Solo las que existen en disco.
List<String> referenceImagesOf(Shot shot, List<ShotReference> references) {
  final primary = shot.referenceImagePath;
  return [
    // Una principal antigua, sin fila propia, va la primera.
    if (primary != null && !references.any((r) => r.imagePath == primary))
      primary,
    for (final reference in references) reference.imagePath,
  ].where((path) => File(path).existsSync()).toList();
}

/// Imagen que se enseña como referencia del plano: la suya o, si no tiene,
/// la del storyboard.
String? referenceImageOf(Shot shot) =>
    shot.referenceImagePath ?? shot.storyboardImagePath;

/// Imagen que se enseña en el storyboard: la suya o, si no tiene, la de
/// referencia.
String? storyboardImageOf(Shot shot) =>
    shot.storyboardImagePath ?? shot.referenceImagePath;

/// Guarda una imagen propia para el storyboard del plano, distinta de la de
/// referencia.
Future<String> importShotStoryboardImage({
  required AppDatabase db,
  required Shot shot,
  String? sourcePath,
  Uint8List? sourceBytes,
  String? fileName,
}) async {
  final String stored;
  if (sourceBytes != null) {
    stored = await MediaStorage.writeShotReferenceBytes(
      projectId: shot.projectId,
      shotId: shot.id,
      bytes: sourceBytes,
      fileName: fileName ?? 'storyboard.jpg',
    );
  } else if (sourcePath != null) {
    stored = await MediaStorage.copyShotReference(
      projectId: shot.projectId,
      shotId: shot.id,
      sourcePath: sourcePath,
    );
  } else {
    throw ArgumentError('Se requiere sourcePath o sourceBytes');
  }

  await db.updateShotFields(
    shot.id,
    ShotsCompanion(storyboardImagePath: Value(stored)),
  );

  final queue = MediaSyncBridge.uploadQueue;
  if (queue != null) {
    await queue.scanAndEnqueueProject(shot.projectId);
  }
  return stored;
}

/// Bocetos de la planta del plano: imágenes (una foto de la libreta, un
/// esquema de otra película) que hacen de planta mientras no está dibujada.
/// Se guardan en `cameraPlanImagePath`: una ruta o una lista en JSON. Solo
/// los que existen en disco.
List<String> planSketchesOf(Shot shot) =>
    _storedPlanSketches(shot).where((path) => File(path).existsSync()).toList();

List<String> _storedPlanSketches(Shot shot) {
  final raw = shot.cameraPlanImagePath?.trim();
  if (raw == null || raw.isEmpty) return [];
  if (!raw.startsWith('[')) return [raw];
  try {
    return [
      for (final path in jsonDecode(raw) as List)
        if (path is String && path.isNotEmpty) path,
    ];
  } catch (_) {
    return [];
  }
}

Future<void> _savePlanSketches(AppDatabase db, int shotId, List<String> paths) {
  return db.updateShotFields(
    shotId,
    ShotsCompanion(
      cameraPlanImagePath: Value(paths.isEmpty ? null : jsonEncode(paths)),
    ),
  );
}

/// Añade un boceto de planta al plano, detrás de los que ya tenga.
Future<String> importShotPlanSketch({
  required AppDatabase db,
  required Shot shot,
  String? sourcePath,
  Uint8List? sourceBytes,
  String? fileName,
}) async {
  final String stored;
  if (sourceBytes != null) {
    stored = await MediaStorage.writeShotReferenceBytes(
      projectId: shot.projectId,
      shotId: shot.id,
      bytes: sourceBytes,
      fileName: fileName ?? 'planta.jpg',
    );
  } else if (sourcePath != null) {
    stored = await MediaStorage.copyShotReference(
      projectId: shot.projectId,
      shotId: shot.id,
      sourcePath: sourcePath,
    );
  } else {
    throw ArgumentError('Se requiere sourcePath o sourceBytes');
  }

  final current = await db.getShotById(shot.id) ?? shot;
  await _savePlanSketches(db, shot.id, [
    ..._storedPlanSketches(current).where((path) => path != stored),
    stored,
  ]);

  final queue = MediaSyncBridge.uploadQueue;
  if (queue != null) {
    await queue.scanAndEnqueueProject(shot.projectId);
  }
  return stored;
}

/// Quita un boceto de planta del plano.
Future<void> removeShotPlanSketch({
  required AppDatabase db,
  required Shot shot,
  required String path,
}) async {
  final current = await db.getShotById(shot.id) ?? shot;
  await _savePlanSketches(db, shot.id, [
    for (final other in _storedPlanSketches(current))
      if (other != path) other,
  ]);
}

/// Cambia de sitio un boceto de planta: [from] pasa al puesto [to].
Future<void> reorderShotPlanSketches({
  required AppDatabase db,
  required Shot shot,
  required String path,
  required int to,
}) async {
  final current = await db.getShotById(shot.id) ?? shot;
  final paths = _storedPlanSketches(current);
  if (!paths.remove(path)) return;
  paths.insert(to.clamp(0, paths.length), path);
  await _savePlanSketches(db, shot.id, paths);
}

/// Cambia de sitio una referencia del plano: pasa al puesto [to]. La que
/// queda primera es la principal.
Future<void> reorderShotReference({
  required AppDatabase db,
  required Shot shot,
  required ShotReference reference,
  required int to,
}) async {
  final refs = await db.watchReferencesForShot(shot.id).first;
  final ordered = [...refs]..removeWhere((r) => r.id == reference.id);
  if (ordered.length == refs.length) return;
  ordered.insert(to.clamp(0, ordered.length), reference);
  await db.updateShotFields(
    shot.id,
    ShotsCompanion(referenceImagePath: Value(ordered.first.imagePath)),
  );
  await db.setShotReferenceOrder([for (final r in ordered) r.id]);
}
