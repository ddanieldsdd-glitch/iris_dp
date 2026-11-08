import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/export_file_saver.dart';
import '../../core/utils/pdf_safe_image.dart';
import '../../shared/pdf_export/shooting_plan_pdf.dart';
import '../../shared/pdf_export/storyboard_pdf.dart';
import '../../shared/pdf_export/technical_script_pdf.dart';
import '../../shared/technical_script_export/technical_script_docx.dart';
import '../technical_script/technical_script_export.dart';
import '../technical_script/technical_script_settings.dart';
import 'export_options.dart';
import 'export_selection.dart';

/// Un archivo por generar.
class ExportFile {
  final String name;
  final String extension;
  final Future<Uint8List> Function() build;

  const ExportFile(this.name, this.extension, this.build);
}

String _safe(String text) =>
    text.replaceAll(RegExp(r'[^\w\s-]', unicode: true), '').trim();

/// Monta los documentos de lo elegido.
class ExportRunner {
  final AppDatabase db;
  final ExportSource source;
  final TechnicalScriptSettings settings;

  const ExportRunner(this.db, this.source, this.settings);

  List<StoryboardPart> _parts(List<ExportDaySection> sections) => [
    for (final section in sections)
      for (final tract in section.scenes)
        StoryboardPart(
          tract.scene,
          tract.plainShots,
          dayLabel: section.day == null
              ? null
              : [
                  section.day!.name,
                  if (section.day!.shootDate != null)
                    formatShootDate(section.day!.shootDate),
                ].join(' · '),
          dayDocumentId: section.day?.id,
        ),
  ];

  Future<Uint8List> _storyboard(
    List<ExportDaySection> sections,
    ExportOptions options,
  ) => StoryboardPdfExporter.buildParts(
    project: source.project,
    parts: _parts(sections),
    groupChoice: options.look.choice(options.imageSource),
    db: db,
  );

  Future<Uint8List> _plan(
    List<ExportDaySection> sections,
    ExportOptions options,
  ) => ShootingPlanPdf.build(
    db: db,
    project: source.project,
    sections: sections,
    withLight: options.planWithLight,
    withBeams: options.planBeams,
    withOverviews: options.planOverviews,
  );

  Future<Uint8List> _script(
    List<ExportDaySection> sections,
    ExportOptions options, {
    required bool word,
  }) async {
    final built = await buildScriptDocFor(
      db,
      source,
      sections,
      settings,
      hiddenColumns: options.script.hiddenColumns,
    );
    final doc = options.script.applyTo(built!);
    if (!word) return TechnicalScriptPdfExporter.buildBytes(doc);
    return TechnicalScriptDocxExporter.buildBytes(
      doc,
      // Las páginas del PDF son una buena primera cifra; Word las recalcula
      // al abrirlo.
      pages: await TechnicalScriptPdfExporter.scenePages(doc),
      fonts: await DocxFontFiles.load(doc.fontFamily),
    );
  }

  /// El documento entero en PDF, para la vista previa. El Word se ve con su
  /// equivalente en PDF.
  Future<Uint8List> preview(
    List<ExportDaySection> sections,
    ExportOptions options,
  ) => PdfSafeImage.withExportCache(
    () => switch (options.document) {
      ExportDocument.storyboard => _storyboard(sections, options),
      ExportDocument.shootingPlan => _plan(sections, options),
      ExportDocument.technicalScript => _script(sections, options, word: false),
    },
  );

  /// Los archivos que salen de [sections] con esas opciones.
  List<ExportFile> files(
    List<ExportDaySection> sections,
    ExportOptions options,
  ) {
    final groups = switch (options.split) {
      ExportSplit.single => [(label: '', sections: sections)],
      ExportSplit.perDay => [
        for (final section in sections)
          (label: section.day?.name ?? '', sections: [section]),
      ],
      ExportSplit.perScene => [
        for (final section in sections)
          for (final tract in section.scenes)
            if (tract.shots.isNotEmpty)
              (
                label: [
                  if (section.day != null) section.day!.name,
                  'Esc ${tract.scene.label}',
                ].join(' '),
                sections: [
                  ExportDaySection(section.day, [tract]),
                ],
              ),
      ],
    };
    final word =
        options.document == ExportDocument.technicalScript &&
        options.script.word;
    final kind = switch (options.document) {
      ExportDocument.storyboard =>
        options.look == StoryboardLook.shotList ? 'SL' : 'SB',
      ExportDocument.shootingPlan => 'planta',
      ExportDocument.technicalScript => 'guion_tecnico',
    };
    final project = _safe(source.project.name);
    final seen = <String, int>{};
    return [
      for (final group in groups)
        () {
          final base = [
            if (project.isNotEmpty) project,
            if (_safe(group.label).isNotEmpty) _safe(group.label),
            kind,
          ].join('_');
          // Una escena en dos tramos no pisa su propio archivo.
          final count = seen[base] = (seen[base] ?? 0) + 1;
          final name = count == 1 ? base : '${base}_$count';
          return ExportFile(
            name,
            word ? 'docx' : 'pdf',
            () => word
                ? _script(group.sections, options, word: true)
                : preview(group.sections, options),
          );
        }(),
    ];
  }

  /// Guarda [files]: en el Mac, uno pide su nombre y varios piden carpeta; en
  /// iPad e iPhone salen por la hoja de compartir, que necesita
  /// [shareOrigin]. Devuelve la ruta, o nula si se canceló o se compartió.
  static Future<String?> save(
    List<ExportFile> files, {
    Rect? shareOrigin,
  }) async {
    if (Platform.isIOS) {
      final dir = await getTemporaryDirectory();
      final shared = <XFile>[];
      for (final file in files) {
        final out = File('${dir.path}/${file.name}.${file.extension}');
        await out.writeAsBytes(await file.build(), flush: true);
        shared.add(XFile(out.path));
      }
      await Share.shareXFiles(shared, sharePositionOrigin: shareOrigin);
      return null;
    }
    if (files.length == 1) {
      final file = files.single;
      return ExportFileSaver.saveGenerated(
        dialogTitle: 'Exportar',
        fileName: '${file.name}.${file.extension}',
        extension: file.extension,
        build: file.build,
      );
    }
    final dir = await ExportFileSaver.pickDirectory(
      dialogTitle: 'Carpeta para los ${files.length} archivos',
    );
    if (dir == null) return null;
    try {
      for (final file in files) {
        await ExportFileSaver.writeToDirectory(
          directoryPath: dir,
          fileName: '${file.name}.${file.extension}',
          bytes: await file.build(),
        );
      }
      return dir;
    } finally {
      await ExportFileSaver.finishDirectoryAccess();
    }
  }
}
