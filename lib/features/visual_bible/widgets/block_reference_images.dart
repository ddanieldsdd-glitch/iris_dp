import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/media_storage.dart';
import '../bible_paste_helpers.dart';
import 'bible_paste_zone.dart';

/// Añade imágenes de referencia a bloques de color/exposición/iluminación.
Future<void> pickBlockReferenceImage({
  required int projectId,
  required void Function(String path) onSaved,
}) async {
  final result = await FilePicker.platform.pickFiles(type: FileType.image);
  if (result == null || result.files.isEmpty) return;
  final path = result.files.single.path;
  if (path == null) return;
  final ext = path.contains('.') ? '.${path.split('.').last}' : '.jpg';
  final stored = await MediaStorage.copyFileIntoProject(
    projectId: projectId,
    sourcePath: path,
    subfolder: 'bible_blocks',
    fileName: 'ref_${DateTime.now().millisecondsSinceEpoch}$ext',
  );
  if (stored != null) onSaved(stored);
}

Widget blockReferenceImagesRow({
  required int projectId,
  required List<String> paths,
  required VoidCallback onAdd,
  required Future<void> Function(String path) onSaved,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (paths.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...paths.map(
              (p) => ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: File(p).existsSync()
                    ? Image.file(
                        File(p),
                        width: 72,
                        height: 48,
                        fit: BoxFit.cover,
                      )
                    : const SizedBox(width: 72, height: 48),
              ),
            ),
          ],
        ),
      if (paths.isNotEmpty) const SizedBox(height: 8),
      BibleTargetZone(
        hint: 'Clic aquí → ⌘V para pegar referencia visual',
        minHeight: 48,
        onPaste: (payload) async {
          final stored = await BiblePasteHelpers.savePayloadToProject(
            projectId: projectId,
            subfolder: 'bible_blocks',
            payload: payload,
            prefix: 'ref',
          );
          if (stored != null) await onSaved(stored);
        },
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
        label: const Text('Ref. visual'),
      ),
    ],
  );
}
