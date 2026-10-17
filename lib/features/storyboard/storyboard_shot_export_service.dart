import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/export_file_saver.dart';
import 'shot_sheet_data.dart';
import 'storyboard_export_style.dart';
import 'storyboard_shot_sheet_pdf.dart';

/// Exporta un único plano del storyboard en PDF, en el nivel elegido.
class StoryboardShotExportService {
  static String fileName(
    Project project,
    Scene scene,
    Shot shot,
    StoryboardExportStyle style,
  ) {
    final safe = project.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final base = safe.isEmpty ? 'proyecto' : safe;
    return '${base}_Sc${scene.number}_${shot.number}_${style.artemisFileSuffix}';
  }

  static Future<Uint8List> buildBytes({
    required AppDatabase db,
    required Project project,
    required Scene scene,
    required Shot shot,
    required StoryboardExportStyle style,
    ShotImageSource imageSource = ShotImageSource.storyboard,
  }) async {
    final data = await ShotSheetData.resolve(
      db: db,
      project: project,
      scene: scene,
      shot: shot,
      imageSource: imageSource,
      withPlanAndSun: style == StoryboardExportStyle.shotPlan,
    );
    return StoryboardShotSheetPdf.buildBytes(data, style);
  }

  /// Guarda el PDF (Mac: «Guardar como…»; iPad/iPhone: hoja de compartir,
  /// que necesita [shareOrigin] para salir como globo en iPad). Devuelve la
  /// ruta guardada o nulo si se canceló o se compartió.
  static Future<String?> exportSingle({
    required AppDatabase db,
    required Project project,
    required Scene scene,
    required Shot shot,
    required StoryboardExportStyle style,
    ShotImageSource imageSource = ShotImageSource.storyboard,
    Rect? shareOrigin,
  }) async {
    final name = fileName(project, scene, shot, style);
    Future<Uint8List> build() => buildBytes(
      db: db,
      project: project,
      scene: scene,
      shot: shot,
      style: style,
      imageSource: imageSource,
    );

    if (Platform.isIOS) {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$name.pdf');
      await file.writeAsBytes(await build(), flush: true);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/pdf')],
        subject: 'Plano ${shot.number} · ${style.title}',
        sharePositionOrigin: shareOrigin,
      );
      return null;
    }

    return ExportFileSaver.saveGenerated(
      dialogTitle: 'Exportar plano ${shot.number}',
      fileName: name,
      extension: 'pdf',
      build: build,
    );
  }
}
