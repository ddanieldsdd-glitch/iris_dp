import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../core/database/app_database.dart';
import '../../../../shared/annotations/annotation_document.dart';
import '../../../../shared/annotations/annotation_raster.dart';
import 'lighting_diagram_editor.dart';

/// Bocetos de luz dibujados a mano, listos para el PDF de la biblia.
abstract final class LightingSketchExport {
  /// PNG por id de setup; solo los que tienen dibujo.
  static Future<Map<int, Uint8List>> loadPngs({
    required AppDatabase db,
    required int projectId,
    required Iterable<int> setupIds,
  }) async {
    final out = <int, Uint8List>{};
    for (final setupId in setupIds) {
      final row = await db.getProjectAnnotationDocument(
        projectId: projectId,
        targetType: 'lighting_setup',
        targetId: setupId.toString(),
      );
      final document = AnnotationDocument.decode(row?.documentJson);
      if (document.isEmpty) continue;
      const width = 900.0;
      out[setupId] = await AnnotationRaster.toPng(
        document,
        size: const Size(
          width,
          width / LightingDiagramEditor.sheetAspectRatio,
        ),
      );
    }
    return out;
  }
}
