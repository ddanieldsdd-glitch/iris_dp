import 'dart:io';
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
Future<String> importShotReferenceImage({
  required AppDatabase db,
  required Shot shot,
  String? sourcePath,
  Uint8List? sourceBytes,
  String? fileName,
  required String source,
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

  final existing = await db.watchReferencesForShot(shot.id).first;
  await db.insertShotReference(
    ShotReferencesCompanion.insert(
      shotId: shot.id,
      imagePath: stored,
      source: Value(source),
      sortOrder: Value(existing.length),
    ),
  );

  await db.updateShot(shot.copyWith(referenceImagePath: Value(stored)));

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
