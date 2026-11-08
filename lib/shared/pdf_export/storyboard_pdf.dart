import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../core/utils/export_file_saver.dart';
import '../../core/utils/pdf_export_fonts.dart';
import '../../core/utils/export_cancel.dart';
import '../../core/utils/pdf_safe_image.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/database/app_database.dart';
import '../../core/utils/shot_technical_options.dart';
import '../../features/camera_plan/camera_plan_grouping.dart';
import '../../features/camera_plan/plan_renderer.dart';
import '../../features/storyboard/storyboard_export_helpers.dart';
import '../../features/storyboard/storyboard_export_style.dart';
import '../../features/storyboard/storyboard_group_export_options.dart';
import '../../features/storyboard/storyboard_image_palette.dart';
import '../../features/storyboard/shot_sheet_data.dart';
import '../../features/storyboard/storyboard_shot_sheet_pdf.dart';
import '../rich_text/script_markup.dart';
import '../../core/utils/shot_reference_import.dart';

/// PDF de storyboard con estilos CLEAN / BASIC / DETAIL / SHOT PLAN.
/// Un tramo del PDF: una escena con sus planos ya ordenados. En un export
/// por jornadas, una misma escena puede salir en varios tramos.
class StoryboardPart {
  final Scene scene;
  final List<Shot> shots;

  /// «Jornada 2 · 12/10/2026» en la cabecera de cada página.
  final String? dayLabel;

  /// Jornada de la que sale, para el sol de la hoja SHOT PLAN.
  final int? dayDocumentId;

  const StoryboardPart(
    this.scene,
    this.shots, {
    this.dayLabel,
    this.dayDocumentId,
  });
}

class StoryboardPdfExporter {
  static const _columns = 3;
  static const _shotListRowsPerPage = 4;
  static const _frameAspect = 16 / 9;
  static const _gridMargin = 20.0;
  static const _listMargin = 24.0;
  static const _gridGap = 8.0;
  static const _gridCaption = 48.0;

  /// Alto fijo de la cabecera: las filas se calculan contando con él, así
  /// que un título largo no puede empujar la última fila fuera de la página.
  static const _headerHeight = 52.0;
  static const _headerGap = 10.0;
  static const _listSeparator = 17.0;

  /// Planos pintados de verdad en el PDF, en orden. Solo para tests: el
  /// paquete `pdf` descarta sin error lo que no cabe en una columna.
  @visibleForTesting
  static List<int>? debugPaintedShots;

  /// Medidas reales de la rejilla: `availableHeight` del formato cuenta los
  /// márgenes por defecto, no los de la página, y por eso no sirve aquí.
  static ({double colWidth, double rowHeight, double imageHeight}) _gridMetrics(
    StoryboardGridDensity density,
  ) {
    final page = PdfPageFormat.a4.landscape;
    final width = page.width - _gridMargin * 2;
    final height = page.height - _gridMargin * 2 - _headerHeight - _headerGap;
    final colWidth = (width - _gridGap * (_columns - 1)) / _columns;
    final rowHeight = (height - _gridGap * (density.rows - 1)) / density.rows;
    final imageHeight = math.min(
      colWidth / _frameAspect,
      rowHeight - _gridCaption,
    );
    return (colWidth: colWidth, rowHeight: rowHeight, imageHeight: imageHeight);
  }

  static Future<Uint8List> buildBytes({
    required Project project,
    required List<Scene> scenes,
    required Map<int, List<Shot>> shotsByScene,
    StoryboardGroupExportChoice? groupChoice,
    StoryboardExportStyle style = StoryboardExportStyle.detail,
    AppDatabase? db,
  }) => buildParts(
    project: project,
    parts: _partsOf(scenes, shotsByScene),
    groupChoice: groupChoice,
    style: style,
    db: db,
  );

  static List<StoryboardPart> _partsOf(
    List<Scene> scenes,
    Map<int, List<Shot>> shotsByScene,
  ) => [
    for (final scene in scenesInScriptOrder(scenes))
      StoryboardPart(scene, _orderedShots(shotsByScene[scene.id] ?? [])),
  ];

  static Future<String?> exportAndSave({
    required Project project,
    required List<Scene> scenes,
    required Map<int, List<Shot>> shotsByScene,
    required StoryboardGroupExportChoice groupChoice,
    AppDatabase? db,
  }) async {
    final ordered = scenesInScriptOrder(scenes);
    final scenesWithShots = ordered
        .where((s) => _orderedShots(shotsByScene[s.id] ?? []).isNotEmpty)
        .toList();

    if (scenesWithShots.isEmpty) return null;

    if (scenesWithShots.length == 1) {
      final scene = scenesWithShots.first;
      final shots = _orderedShots(shotsByScene[scene.id] ?? []);
      final filename = _defaultSequenceFilename(project, scene, groupChoice);
      return ExportFileSaver.saveGenerated(
        dialogTitle: 'Exportar storyboard',
        fileName: filename,
        extension: 'pdf',
        build: () => buildParts(
          project: project,
          parts: [StoryboardPart(scene, shots)],
          groupChoice: groupChoice,
          db: db,
        ),
      );
    }

    final dir = await ExportFileSaver.pickDirectory(
      dialogTitle:
          'Carpeta para exportar ${scenesWithShots.length} PDFs (SB/SL por escena)',
    );
    if (dir == null) return null;

    try {
      for (final scene in scenesWithShots) {
        final shots = _orderedShots(shotsByScene[scene.id] ?? []);
        final bytes = await buildParts(
          project: project,
          parts: [StoryboardPart(scene, shots)],
          groupChoice: groupChoice,
          db: db,
        );
        final filename = _defaultSequenceFilename(project, scene, groupChoice);
        await ExportFileSaver.writeToDirectory(
          directoryPath: dir,
          fileName: filename,
          bytes: bytes,
        );
      }
      return dir;
    } finally {
      await ExportFileSaver.finishDirectoryAccess();
    }
  }

  static String _defaultSequenceFilename(
    Project project,
    Scene scene,
    StoryboardGroupExportChoice choice,
  ) {
    if (choice.mode == StoryboardGroupExportMode.sequences &&
        choice.sequenceLayout != null) {
      return choice.sequenceLayout!.defaultFilename(project, scene);
    }
    final safe = project.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final base = safe.isEmpty ? 'proyecto' : safe;
    final tag = choice.exportLabel.toLowerCase().replaceAll(' ', '_');
    return '${base}_Sc${scene.label}_$tag.pdf';
  }

  /// El PDF de [parts], en ese orden y con los planos tal como vienen: el
  /// plan de rodaje manda sobre el orden del guion.
  static Future<Uint8List> buildParts({
    required Project project,
    required List<StoryboardPart> parts,
    StoryboardGroupExportChoice? groupChoice,
    StoryboardExportStyle style = StoryboardExportStyle.detail,
    AppDatabase? db,
  }) async {
    final doc = pw.Document();
    var hasPages = false;

    final fonts = await PdfExportFonts.load();
    final pdfTheme = PdfExportFonts.theme(
      regular: fonts.regular,
      bold: fonts.bold,
    );
    // Las hojas por plano cargan sus imágenes una a una.
    final imageCache = groupChoice?.mode == StoryboardGroupExportMode.asShots
        ? const <int, Uint8List>{}
        : await _preloadShotImages(parts);

    final effectiveStyle =
        groupChoice?.mode == StoryboardGroupExportMode.asShots
        ? (groupChoice!.shotStyle ?? StoryboardExportStyle.detail)
        : style;
    final sequenceLayout = groupChoice?.sequenceLayout;

    if (sequenceLayout == StoryboardSequenceLayout.shotList) {
      for (final part in parts) {
        final scene = part.scene;
        final shots = part.shots;
        if (shots.isEmpty) continue;

        for (
          var start = 0;
          start < shots.length;
          start += _shotListRowsPerPage
        ) {
          final end = (start + _shotListRowsPerPage).clamp(0, shots.length);
          final chunk = shots.sublist(start, end);
          final first = start + 1;
          hasPages = true;
          doc.addPage(
            pw.Page(
              theme: pdfTheme,
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(_listMargin),
              build: (context) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _sequenceHeader(
                    project,
                    scene,
                    chunk,
                    first,
                    shots.length,
                    layout: StoryboardSequenceLayout.shotList,
                    dayLabel: part.dayLabel,
                  ),
                  pw.SizedBox(height: _headerGap),
                  pw.Expanded(
                    child: _shotListPage(scene, chunk, imageCache: imageCache),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } else if (groupChoice?.mode == StoryboardGroupExportMode.asShots &&
        db != null) {
      // Cada plano en su hoja, en el nivel elegido, todo en un PDF.
      final withPlan = effectiveStyle == StoryboardExportStyle.shotPlan;
      final renderer = withPlan
          ? await PlanRenderer.load(db, project.id)
          : null;
      for (final part in parts) {
        final scene = part.scene;
        for (final shot in part.shots) {
          ExportCancel.check();
          hasPages = true;
          final data = await ShotSheetData.resolve(
            db: db,
            project: project,
            scene: scene,
            shot: shot,
            dayDocumentId: part.dayDocumentId,
            imageSource: groupChoice!.imageSource,
            withPlanAndSun: withPlan,
            renderer: renderer,
          );
          await StoryboardShotSheetPdf.addPage(doc, data, effectiveStyle);
        }
      }
    } else {
      final isSequenceSb =
          sequenceLayout == StoryboardSequenceLayout.storyboard;
      final gridStyle = isSequenceSb
          ? StoryboardExportStyle.clean
          : effectiveStyle;
      final density = groupChoice?.gridDensity ?? StoryboardGridDensity.six;
      final perPage = density.rows * _columns;

      for (final part in parts) {
        final scene = part.scene;
        final shots = part.shots;
        if (shots.isEmpty) continue;

        for (var start = 0; start < shots.length; start += perPage) {
          final end = (start + perPage).clamp(0, shots.length);
          final chunk = shots.sublist(start, end);
          final first = start + 1;
          hasPages = true;
          doc.addPage(
            pw.Page(
              theme: pdfTheme,
              pageFormat: PdfPageFormat.a4.landscape,
              margin: const pw.EdgeInsets.all(_gridMargin),
              build: (context) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _sequenceHeader(
                    project,
                    scene,
                    chunk,
                    first,
                    shots.length,
                    layout: isSequenceSb
                        ? StoryboardSequenceLayout.storyboard
                        : null,
                    dayLabel: part.dayLabel,
                  ),
                  pw.SizedBox(height: _headerGap),
                  pw.Expanded(
                    child: _shotGrid(
                      chunk,
                      density,
                      gridStyle,
                      sequenceStoryboard: isSequenceSb,
                      imageCache: imageCache,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    }

    if (!hasPages) {
      doc.addPage(
        pw.Page(
          theme: pdfTheme,
          build: (_) => pw.Text('Sin planos para exportar.'),
        ),
      );
    }

    return doc.save();
  }

  static Future<Map<int, Uint8List>> _preloadShotImages(
    List<StoryboardPart> parts,
  ) async {
    final cache = <int, Uint8List>{};
    for (final part in parts) {
      for (final shot in part.shots) {
        if (cache.containsKey(shot.id)) continue;
        ExportCancel.check();
        final bytes = await PdfSafeImage.loadFromPathMaxEdge(
          storyboardImageOf(shot),
          maxEdge: 1400,
        );
        if (bytes != null) cache[shot.id] = bytes;
      }
    }
    return cache;
  }

  static List<Shot> _orderedShots(List<Shot> shots) {
    final copy = List<Shot>.from(shots);
    copy.sort((a, b) {
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      return byOrder != 0 ? byOrder : a.number.compareTo(b.number);
    });
    return copy;
  }

  static pw.Widget _sequenceHeader(
    Project project,
    Scene scene,
    List<Shot> chunk,
    int firstIndex,
    int totalShots, {
    StoryboardSequenceLayout? layout,
    String? dayLabel,
  }) {
    final slug = scene.locationCanonical.trim().isNotEmpty
        ? scene.locationCanonical
        : scene.name;
    final last = firstIndex + chunk.length - 1;
    final range = chunk.length == 1
        ? 'Shot $firstIndex of $totalShots'
        : 'Shots $firstIndex – $last of $totalShots';
    final tag = layout?.artemisFileSuffix ?? 'SB';

    return pw.SizedBox(
      height: _headerHeight,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                project.name,
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                dayLabel == null ? tag : '$dayLabel  ·  $tag',
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Expanded(
                child: pw.Text(
                  'Sc. ${scene.label}',
                  maxLines: 1,
                  style: pw.TextStyle(
                    fontSize: 15,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.Text(
                range,
                style: const pw.TextStyle(
                  fontSize: 9,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            slug,
            maxLines: 1,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
          ),
        ],
      ),
    );
  }

  static pw.Widget _shotGrid(
    List<Shot> shots,
    StoryboardGridDensity density,
    StoryboardExportStyle style, {
    bool sequenceStoryboard = false,
    Map<int, Uint8List> imageCache = const {},
  }) {
    const gap = _gridGap;
    final (:colWidth, :rowHeight, :imageHeight) = _gridMetrics(density);
    final imageWidth = imageHeight * _frameAspect;

    final rows = <pw.Widget>[];
    for (var r = 0; r < density.rows; r++) {
      final rowStart = r * _columns;
      if (rowStart >= shots.length) break;
      final rowShots = shots.sublist(
        rowStart,
        (rowStart + _columns).clamp(0, shots.length),
      );
      rows.add(
        pw.SizedBox(
          height: rowHeight,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < _columns; c++)
                pw.SizedBox(
                  width: colWidth + (c < _columns - 1 ? gap : 0),
                  child: c < rowShots.length
                      ? pw.Padding(
                          padding: pw.EdgeInsets.only(
                            right: c < _columns - 1 ? gap : 0,
                          ),
                          child: pw.Align(
                            alignment: pw.Alignment.topCenter,
                            child: pw.SizedBox(
                              width: imageWidth,
                              child: _frameCell(
                                rowShots[c],
                                colWidth: imageWidth,
                                imageHeight: imageHeight,
                                style: style,
                                sequenceStoryboard: sequenceStoryboard,
                                imageCache: imageCache,
                              ),
                            ),
                          ),
                        )
                      : pw.SizedBox(width: colWidth),
                ),
            ],
          ),
        ),
      );
      if (r < density.rows - 1 && rowStart + _columns < shots.length) {
        rows.add(pw.SizedBox(height: gap));
      }
    }

    return pw.Column(children: rows);
  }

  static pw.Widget _shotListPage(
    Scene scene,
    List<Shot> shots, {
    Map<int, Uint8List> imageCache = const {},
  }) {
    const page = PdfPageFormat.a4;
    const gap = (_listSeparator - 1) / 2;
    final bodyHeight =
        page.height - _listMargin * 2 - _headerHeight - _headerGap;
    final contentHeight =
        (bodyHeight - _listSeparator * (_shotListRowsPerPage - 1)) /
        _shotListRowsPerPage;
    final pageWidth = page.width - _listMargin * 2;
    final imageWidth = pageWidth * 0.34;
    final imageHeight = imageWidth / _frameAspect;

    final rows = <pw.Widget>[];
    for (var i = 0; i < shots.length; i++) {
      rows.add(
        _shotListRow(
          scene: scene,
          shot: shots[i],
          rowHeight: contentHeight,
          imageWidth: imageWidth,
          imageHeight: imageHeight,
          textWidth: pageWidth - imageWidth - 12,
          imageCache: imageCache,
        ),
      );
      if (i < shots.length - 1) {
        rows.add(pw.SizedBox(height: gap));
        rows.add(pw.Divider(color: PdfColors.grey300, height: 1));
        rows.add(pw.SizedBox(height: gap));
      }
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: rows,
    );
  }

  static pw.Widget _shotListRow({
    required Scene scene,
    required Shot shot,
    required double rowHeight,
    required double imageWidth,
    required double imageHeight,
    required double textWidth,
    Map<int, Uint8List> imageCache = const {},
  }) {
    final technical = formatShotTechnicalLine(shot);
    final location = sceneLocationLine(scene);

    return pw.SizedBox(
      height: rowHeight,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _frameImage(
            shot,
            width: imageWidth,
            height: imageHeight,
            imageCache: imageCache,
          ),
          pw.SizedBox(width: 12),
          pw.SizedBox(
            width: textWidth,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Shot ${shot.number}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                if (technical.isNotEmpty)
                  pw.Text(technical, style: const pw.TextStyle(fontSize: 9)),
                pw.Text(
                  lensArtemisLabel(shot.lens),
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColor.fromInt(0xFFE8912D),
                  ),
                ),
                if (shot.fStop?.isNotEmpty == true)
                  pw.Text(
                    'T${shot.fStop}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                  ),
                pw.SizedBox(height: 4),
                pw.Text(
                  location,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey700,
                  ),
                ),
                if (shot.action?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    scriptMarkupToPlain(shot.action),
                    style: const pw.TextStyle(fontSize: 8),
                    maxLines: 3,
                  ),
                ],
                if (shot.notes?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    scriptMarkupToPlain(shot.notes),
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey800,
                    ),
                    maxLines: 4,
                  ),
                ],
                _ShotPaintProbe(shot.id),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _frameCell(
    Shot shot, {
    required double colWidth,
    required double imageHeight,
    required StoryboardExportStyle style,
    bool sequenceStoryboard = false,
    Map<int, Uint8List> imageCache = const {},
  }) {
    final technical = formatShotTechnicalLine(shot);
    final imageStyle = sequenceStoryboard ? StoryboardExportStyle.clean : style;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        _styledFrameImage(
          shot,
          width: colWidth,
          height: imageHeight,
          style: imageStyle,
          imageCache: imageCache,
        ),
        if (sequenceStoryboard || style != StoryboardExportStyle.clean) ...[
          pw.SizedBox(height: 3),
          pw.Center(
            child: pw.Text(
              '${shot.number}',
              style: pw.TextStyle(
                fontSize: sequenceStoryboard ? 14 : 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          if (sequenceStoryboard && technical.isNotEmpty)
            pw.Center(
              child: pw.Text(
                technical,
                style: const pw.TextStyle(fontSize: 7),
                textAlign: pw.TextAlign.center,
                maxLines: 2,
              ),
            ),
          if (!sequenceStoryboard &&
              style == StoryboardExportStyle.detail &&
              technical.isNotEmpty)
            pw.Center(
              child: pw.Text(
                technical,
                style: const pw.TextStyle(fontSize: 8),
                textAlign: pw.TextAlign.center,
              ),
            ),
          if (!sequenceStoryboard &&
              style == StoryboardExportStyle.detail &&
              shot.action?.isNotEmpty == true)
            pw.Text(
              scriptMarkupToPlain(shot.action),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800),
              maxLines: 2,
              textAlign: pw.TextAlign.center,
            ),
        ],
        _ShotPaintProbe(shot.id),
      ],
    );
  }

  static pw.Widget _styledFrameImage(
    Shot shot, {
    required double width,
    required double height,
    required StoryboardExportStyle style,
    Map<int, Uint8List> imageCache = const {},
  }) {
    final image = _frameImage(
      shot,
      width: width,
      height: height,
      imageCache: imageCache,
    );

    if (style == StoryboardExportStyle.clean) {
      return image;
    }

    return pw.Stack(
      children: [
        image,
        if (style == StoryboardExportStyle.basic ||
            style == StoryboardExportStyle.detail)
          _pdfFramelines(width, height),
        if (style == StoryboardExportStyle.basic ||
            style == StoryboardExportStyle.detail)
          pw.Positioned(
            left: 4,
            bottom: 4,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
              color: PdfColors.black,
              child: pw.Text(
                lensFovLabel(shot.lens),
                style: const pw.TextStyle(fontSize: 6, color: PdfColors.white),
              ),
            ),
          ),
        if (style == StoryboardExportStyle.detail)
          pw.Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: pw.Container(
              color: PdfColors.black,
              padding: const pw.EdgeInsets.all(3),
              child: pw.Text(
                [
                  if (shot.framing?.isNotEmpty == true)
                    scriptMarkupToPlain(shot.framing),
                  if (shot.lens?.isNotEmpty == true) shot.lens,
                  if (shot.movement?.isNotEmpty == true) shot.movement,
                ].whereType<String>().join(' · '),
                style: const pw.TextStyle(fontSize: 5, color: PdfColors.white),
                maxLines: 1,
              ),
            ),
          ),
      ],
    );
  }

  static pw.Widget _pdfFramelines(double width, double height) {
    final areaAspect = width / height;
    late double innerW;
    late double innerH;
    late double left;
    late double top;

    if (areaAspect > kFramelineAspect) {
      innerH = height;
      innerW = height * kFramelineAspect;
      left = (width - innerW) / 2;
      top = 0;
    } else {
      innerW = width;
      innerH = width / kFramelineAspect;
      left = 0;
      top = (height - innerH) / 2;
    }

    return pw.Positioned(
      left: left,
      top: top,
      child: pw.Container(
        width: innerW,
        height: innerH,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.white, width: 0.8),
        ),
      ),
    );
  }

  static pw.Widget _frameImage(
    Shot shot, {
    required double width,
    required double height,
    Map<int, Uint8List> imageCache = const {},
  }) {
    final bytes =
        imageCache[shot.id] ??
        PdfSafeImage.loadFromPathSync(storyboardImageOf(shot));
    if (bytes != null) {
      return pw.Container(
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
        ),
        child: pw.Image(
          pw.MemoryImage(bytes),
          width: width,
          height: height,
          fit: pw.BoxFit.cover,
        ),
      );
    }

    return pw.Container(
      width: width,
      height: height,
      alignment: pw.Alignment.center,
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.Text(
        'Sin referencia',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }
}

/// Marca sin tamaño: solo se pinta si el plano ha cabido en la página.
class _ShotPaintProbe extends pw.Widget {
  _ShotPaintProbe(this.shotId);

  final int shotId;

  @override
  void layout(
    pw.Context context,
    pw.BoxConstraints constraints, {
    bool parentUsesSize = false,
  }) {
    box = PdfRect.zero;
  }

  @override
  void paint(pw.Context context) {
    super.paint(context);
    StoryboardPdfExporter.debugPaintedShots?.add(shotId);
  }
}
