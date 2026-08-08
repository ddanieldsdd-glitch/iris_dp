import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/database/app_database.dart';
import '../../core/utils/media_storage.dart';

/// Límite de imágenes de muestra persistidas en el laboratorio óptico.
const kOpticsLabMaxSamples = 10;

Future<String?> pickAndStoreOpticsLabSample({
  required AppDatabase db,
  required int projectId,
  required BuildContext context,
}) async {
  final count = await db.countOpticsLabSamples(projectId);
  if (count >= kOpticsLabMaxSamples) {
    if (!context.mounted) return null;
    final removed = await _promptRemoveSample(context, db, projectId);
    if (!removed || !context.mounted) return null;
  }

  final result = await FilePicker.platform.pickFiles(type: FileType.image);
  if (result == null || result.files.single.path == null) return null;

  final sourcePath = result.files.single.path!;
  final ext = p.extension(sourcePath);
  final stored = await MediaStorage.copyFileIntoProject(
    projectId: projectId,
    sourcePath: sourcePath,
    subfolder: 'optics_lab/samples',
    fileName:
        'sample_${DateTime.now().millisecondsSinceEpoch}${ext.isEmpty ? '.jpg' : ext}',
  );
  if (stored == null) return null;

  await db.insertOpticsLabSample(
    OpticsLabSamplesCompanion.insert(projectId: projectId, imagePath: stored),
  );
  return stored;
}

Future<bool> _promptRemoveSample(
  BuildContext context,
  AppDatabase db,
  int projectId,
) async {
  final samples = await db.watchOpticsLabSamples(projectId).first;
  if (!context.mounted) return false;

  final deletedId = await showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Límite de 10 imágenes'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Elimina una imagen de muestra para poder añadir otra.'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final sample in samples)
                  _SampleDeleteTile(
                    sample: sample,
                    onDelete: () => Navigator.pop(ctx, sample.id),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
      ],
    ),
  );

  if (deletedId == null) return false;
  await deleteOpticsLabSample(db: db, sampleId: deletedId);
  return true;
}

Future<void> deleteOpticsLabSample({
  required AppDatabase db,
  required int sampleId,
}) async {
  final sample = await db.getOpticsLabSampleById(sampleId);
  if (sample != null) {
    final file = File(sample.imagePath);
    if (file.existsSync()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }
  await db.deleteOpticsLabSample(sampleId);
}

class _SampleDeleteTile extends StatelessWidget {
  final OpticsLabSample sample;
  final VoidCallback onDelete;

  const _SampleDeleteTile({required this.sample, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final file = File(sample.imagePath);
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: file.existsSync()
              ? Image.file(file, width: 72, height: 72, fit: BoxFit.cover)
              : Container(
                  width: 72,
                  height: 72,
                  color: Colors.grey.shade700,
                  child: const Icon(Icons.broken_image_outlined),
                ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onDelete,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.close, size: 16, color: Colors.white),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
