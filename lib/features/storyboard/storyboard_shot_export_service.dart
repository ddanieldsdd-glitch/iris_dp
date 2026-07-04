import 'dart:io';

import '../../core/utils/export_file_saver.dart';

import '../../core/database/app_database.dart';
import 'storyboard_export_helpers.dart';
import 'storyboard_export_style.dart';
import 'storyboard_shot_export_meta.dart';
import 'storyboard_shot_image_exporter.dart';
import 'storyboard_shot_sheet_pdf.dart';

/// Exporta un único plano del storyboard según el estilo elegido.
class StoryboardShotExportService {
  static Future<String?> exportSingle({
    required Project project,
    required Scene scene,
    required Shot shot,
    required StoryboardExportStyle style,
    AppDatabase? db,
  }) async {
    final safeProject =
        project.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final base = safeProject.isEmpty ? 'proyecto' : safeProject;
    final suffix = '_Sc${scene.number}_${shot.number}_${style.artemisFileSuffix}';

    if (style == StoryboardExportStyle.clean) {
      final copied = await _exportCleanOriginal(shot, base, suffix);
      if (copied != null) return copied;
    }

    StoryboardShotExportMeta? meta;
    if (db != null &&
        (style.singleShotUsesPdf || style == StoryboardExportStyle.basic)) {
      meta = await StoryboardShotExportMeta.resolve(
        db: db,
        project: project,
        scene: scene,
        shot: shot,
      );
    }

    if (style.singleShotUsesPdf) {
      final resolved = meta ??
          StoryboardShotExportMeta(
            cameraHeader: 'Cámara del proyecto',
            orientationHeader: '1° (U) 46° (NE)',
            lensSeriesHeader: shot.lens ?? 'Óptica',
            sensorWidthMm: kDefaultSensorWidthMm,
            shotIndex: shot.number,
            totalShotsInScene: shot.number,
          );
      return ExportFileSaver.saveGenerated(
        dialogTitle: 'Exportar plano ${shot.number}',
        fileName: '$base$suffix',
        extension: 'pdf',
        build: () => StoryboardShotSheetPdf.buildBytes(
          project: project,
          scene: scene,
          shot: shot,
          style: style,
          meta: resolved,
          db: db,
        ),
      );
    }

    return ExportFileSaver.saveGenerated(
      dialogTitle: 'Exportar plano ${shot.number}',
      fileName: '$base$suffix',
      extension: 'png',
      build: () async {
        final png = await StoryboardShotImageExporter.render(
          shot: shot,
          scene: scene,
          style: style,
          sensorWidthMm: meta?.sensorWidthMm ?? kDefaultSensorWidthMm,
        );
        if (png == null) {
          throw StateError('No se pudo renderizar el plano');
        }
        return png;
      },
    );
  }

  /// Copia la referencia original sin re-render (RAW).
  static Future<String?> _exportCleanOriginal(
    Shot shot,
    String base,
    String suffix,
  ) async {
    final path = shot.referenceImagePath;
    if (path == null || !File(path).existsSync()) return null;

    final ext = path.split('.').last.toLowerCase();
    final useExt = switch (ext) {
      'jpg' || 'jpeg' => 'jpg',
      'png' => 'png',
      'webp' => 'webp',
      _ => 'png',
    };

    return ExportFileSaver.saveLocalFile(
      sourcePath: path,
      dialogTitle: 'Exportar plano ${shot.number}',
      fileName: '$base$suffix',
      extension: useExt,
    );
  }
}
