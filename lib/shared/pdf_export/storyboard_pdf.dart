import 'dart:math' as math;
import 'dart:typed_data';

import '../../core/utils/export_file_saver.dart';
import '../../core/utils/pdf_export_fonts.dart';
import '../../core/utils/pdf_safe_image.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/database/app_database.dart';
import '../../core/utils/scene_format.dart';
import '../../core/utils/shot_technical_options.dart';
import '../../features/camera_plan/camera_plan_grouping.dart';
import '../../features/storyboard/storyboard_export_helpers.dart';
import '../../features/storyboard/storyboard_export_style.dart';
import '../../features/storyboard/storyboard_group_export_options.dart';
import '../../features/storyboard/storyboard_image_palette.dart';
import '../../features/storyboard/storyboard_shot_export_meta.dart';
import '../../features/storyboard/storyboard_shot_sheet_pdf.dart';
import '../../features/storyboard/storyboard_shot_image_exporter.dart';

/// PDF de storyboard con estilos CLEAN / BASIC / DETAIL / SHOT PLAN.
class StoryboardPdfExporter {
  static const _columns = 3;
  static const _rows = 3;
  static const _shotsPerPage = _columns * _rows;
  static const _shotListRowsPerPage = 4;
  static const _frameAspect = 16 / 9;

  static Future<Uint8List> buildBytes({
    required Project project,
    required List<Scene> scenes,
    required Map<int, List<Shot>> shotsByScene,
    StoryboardGroupExportChoice? groupChoice,
    StoryboardExportStyle style = StoryboardExportStyle.detail,
    AppDatabase? db,
  }) =>
      _buildPdf(
        project,
        scenes,
        shotsByScene,
        groupChoice: groupChoice,
        style: style,
        db: db,
      );

  static Future<Uint8List> buildSingleShotPlanBytes({
    required Project project,
    required Scene scene,
    required Shot shot,
    AppDatabase? db,
  }) async {
    final meta = db != null
        ? await StoryboardShotExportMeta.resolve(
            db: db,
            project: project,
            scene: scene,
            shot: shot,
          )
        : StoryboardShotExportMeta(
            cameraHeader: 'Cámara del proyecto',
            orientationHeader: '1° (U) 46° (NE)',
            lensSeriesHeader: shot.lens ?? 'Óptica',
            sensorWidthMm: kDefaultSensorWidthMm,
            shotIndex: shot.number,
            totalShotsInScene: shot.number,
          );
    return StoryboardShotSheetPdf.buildBytes(
      project: project,
      scene: scene,
      shot: shot,
      style: StoryboardExportStyle.shotPlan,
      meta: meta,
      db: db,
    );
  }

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
        build: () => _buildPdf(
          project,
          [scene],
          {scene.id: shots},
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
        final bytes = await _buildPdf(
          project,
          [scene],
          {scene.id: shots},
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
    final safe =
        project.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final base = safe.isEmpty ? 'proyecto' : safe;
    final tag = choice.exportLabel.toLowerCase().replaceAll(' ', '_');
    return '${base}_Sc${scene.number}_$tag.pdf';
  }

  static Future<Uint8List> _buildPdf(
    Project project,
    List<Scene> scenes,
    Map<int, List<Shot>> shotsByScene, {
    StoryboardGroupExportChoice? groupChoice,
    StoryboardExportStyle style = StoryboardExportStyle.detail,
    AppDatabase? db,
  }) async {
    final orderedScenes = scenesInScriptOrder(scenes);
    final doc = pw.Document();
    var hasPages = false;

    final fonts = await PdfExportFonts.load();
    final pdfTheme = PdfExportFonts.theme(
      regular: fonts.regular,
      bold: fonts.bold,
    );
    final imageCache = await _preloadShotImages(shotsByScene);

    final effectiveStyle = groupChoice?.mode == StoryboardGroupExportMode.asShots
        ? (groupChoice!.shotStyle ?? StoryboardExportStyle.detail)
        : style;
    final sequenceLayout = groupChoice?.sequenceLayout;

    if (sequenceLayout == StoryboardSequenceLayout.shotList) {
      for (final scene in orderedScenes) {
        final shots = _orderedShots(shotsByScene[scene.id] ?? []);
        if (shots.isEmpty) continue;

        for (var start = 0; start < shots.length; start += _shotListRowsPerPage) {
          final end = (start + _shotListRowsPerPage).clamp(0, shots.length);
          final chunk = shots.sublist(start, end);
          hasPages = true;
          doc.addPage(
            pw.Page(
              theme: pdfTheme,
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(24),
              build: (context) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _sequenceHeader(
                    project,
                    scene,
                    chunk,
                    shots.length,
                    layout: StoryboardSequenceLayout.shotList,
                  ),
                  pw.SizedBox(height: 10),
                  pw.Expanded(
                    child: _shotListPage(
                      context,
                      scene,
                      chunk,
                      shots.length,
                      imageCache: imageCache,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } else if (effectiveStyle == StoryboardExportStyle.shotPlan) {
      for (final scene in orderedScenes) {
        final shots = _orderedShots(shotsByScene[scene.id] ?? []);
        for (final shot in shots) {
          hasPages = true;
          doc.addPage(
            await _shotPlanPage(
              project: project,
              scene: scene,
              shot: shot,
              db: db,
              imageCache: imageCache,
              theme: pdfTheme,
            ),
          );
        }
      }
    } else {
      final isSequenceSb =
          sequenceLayout == StoryboardSequenceLayout.storyboard;
      final gridStyle = isSequenceSb
          ? StoryboardExportStyle.clean
          : effectiveStyle;

      for (final scene in orderedScenes) {
        final shots = _orderedShots(shotsByScene[scene.id] ?? []);
        if (shots.isEmpty) continue;

        for (var start = 0; start < shots.length; start += _shotsPerPage) {
          final end = (start + _shotsPerPage).clamp(0, shots.length);
          final chunk = shots.sublist(start, end);
          hasPages = true;
          doc.addPage(
            pw.Page(
              theme: pdfTheme,
              pageFormat: PdfPageFormat.a4.landscape,
              margin: const pw.EdgeInsets.all(20),
              build: (context) => pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  _sequenceHeader(
                    project,
                    scene,
                    chunk,
                    shots.length,
                    layout: isSequenceSb
                        ? StoryboardSequenceLayout.storyboard
                        : null,
                  ),
                  pw.SizedBox(height: 10),
                  pw.Expanded(
                    child: _shotGrid(
                      chunk,
                      context,
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
    Map<int, List<Shot>> shotsByScene,
  ) async {
    final cache = <int, Uint8List>{};
    for (final shots in shotsByScene.values) {
      for (final shot in shots) {
        final bytes = await PdfSafeImage.loadFromPath(shot.referenceImagePath);
        if (bytes != null) cache[shot.id] = bytes;
      }
    }
    return cache;
  }

  static List<Shot> _orderedShots(List<Shot> shots) {
    final copy = List<Shot>.from(shots);
    copy.sort((a, b) => a.number.compareTo(b.number));
    return copy;
  }

  static pw.Widget _sequenceHeader(
    Project project,
    Scene scene,
    List<Shot> chunk,
    int totalShots, {
    StoryboardSequenceLayout? layout,
  }) {
    final slug = scene.locationCanonical.trim().isNotEmpty
        ? scene.locationCanonical
        : scene.name;
    final first = chunk.first.number;
    final last = chunk.last.number;
    final range = chunk.length == 1
        ? 'Shot $first of $totalShots'
        : 'Shots $first – $last of $totalShots';
    final tag = layout?.artemisFileSuffix ?? 'SB';

    return pw.Column(
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
              tag,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.SizedBox(height: 4),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Sc. ${scene.number}',
              style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
            ),
            pw.Spacer(),
            pw.Text(
              range,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
            ),
          ],
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          slug,
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
        ),
      ],
    );
  }

  static pw.Widget _shotGrid(
    List<Shot> shots,
    pw.Context context,
    StoryboardExportStyle style, {
    bool sequenceStoryboard = false,
    Map<int, Uint8List> imageCache = const {},
  }) {
    final pageWidth = context.page.pageFormat.availableWidth;
    const gap = 8.0;
    final colWidth = (pageWidth - gap * (_columns - 1)) / _columns;
    final imageHeight = colWidth / _frameAspect;
    final captionHeight = sequenceStoryboard
        ? 48.0
        : switch (style) {
            StoryboardExportStyle.clean => 0.0,
            StoryboardExportStyle.basic => 8.0,
            _ => 52.0,
          };
    final rowHeight = imageHeight + captionHeight;

    final rows = <pw.Widget>[];
    for (var r = 0; r < _rows; r++) {
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
                          child: _frameCell(
                            rowShots[c],
                            colWidth: colWidth,
                            imageHeight: imageHeight,
                            style: style,
                            sequenceStoryboard: sequenceStoryboard,
                            imageCache: imageCache,
                          ),
                        )
                      : pw.SizedBox(width: colWidth),
                ),
            ],
          ),
        ),
      );
      if (r < _rows - 1 && rowStart + _columns < shots.length) {
        rows.add(pw.SizedBox(height: gap));
      }
    }

    return pw.Column(children: rows);
  }

  static pw.Widget _shotListPage(
    pw.Context context,
    Scene scene,
    List<Shot> shots,
    int totalShotsInScene, {
    Map<int, Uint8List> imageCache = const {},
  }) {
    final pageHeight = context.page.pageFormat.availableHeight;
    const gap = 8.0;
    final rowHeight =
        (pageHeight - gap * (_shotListRowsPerPage - 1)) / _shotListRowsPerPage;
    final pageWidth = context.page.pageFormat.availableWidth;
    final imageWidth = pageWidth * 0.34;
    final imageHeight = imageWidth / _frameAspect;
    final contentHeight = math.max(rowHeight, imageHeight + 24);

    final rows = <pw.Widget>[];
    for (var i = 0; i < shots.length; i++) {
      rows.add(
        _shotListRow(
          scene: scene,
          shot: shots[i],
          shotIndex: shots[i].number,
          totalShots: totalShotsInScene,
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
    required int shotIndex,
    required int totalShots,
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
                  'Shot $shotIndex of $totalShots',
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
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                pw.SizedBox(height: 4),
                pw.Text(
                  location,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                ),
                if (shot.action?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    shot.action!,
                    style: const pw.TextStyle(fontSize: 8),
                    maxLines: 3,
                  ),
                ],
                if (shot.notes?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    shot.notes!,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey800,
                    ),
                    maxLines: 4,
                  ),
                ],
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
    final imageStyle =
        sequenceStoryboard ? StoryboardExportStyle.clean : style;

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
              shot.action!,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey800),
              maxLines: 2,
              textAlign: pw.TextAlign.center,
            ),
        ],
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
              padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                  if (shot.framing?.isNotEmpty == true) shot.framing,
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
    final bytes = imageCache[shot.id] ??
        PdfSafeImage.loadFromPathSync(shot.referenceImagePath);
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

  static Future<pw.Page> _shotPlanPage({
    required Project project,
    required Scene scene,
    required Shot shot,
    AppDatabase? db,
    Map<int, Uint8List> imageCache = const {},
    pw.ThemeData? theme,
  }) async {
    final location = locationFromCanonical(scene.locationCanonical);
    final meta = sceneLocationLine(scene);
    final technical = formatShotTechnicalLine(shot);
    final planSummary = await _cameraPlanSummary(shot, db);
    final imageBytes = imageCache[shot.id] ??
        PdfSafeImage.loadFromPathSync(shot.referenceImagePath);

    return pw.Page(
      theme: theme,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) {
        final pageW = context.page.pageFormat.availableWidth;
        final imageH = pageW * 9 / 16;

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  project.name,
                  style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                ),
                pw.Text(
                  'SHOT PLAN · Plano ${shot.number}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Text(
              'Esc ${scene.number} · $location',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(meta, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 12),
            if (imageBytes != null)
              pw.Image(
                pw.MemoryImage(imageBytes),
                height: imageH,
                fit: pw.BoxFit.cover,
              )
            else
              pw.Container(
                height: imageH,
                alignment: pw.Alignment.center,
                color: PdfColors.grey200,
                child: pw.Text('Sin referencia'),
              ),
            pw.SizedBox(height: 12),
            pw.Expanded(
              child: pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Expanded(
                    flex: 3,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _sectionTitle('Cámara y óptica'),
                        if (technical.isNotEmpty)
                          pw.Text(technical, style: const pw.TextStyle(fontSize: 9)),
                        pw.Text(
                          lensFovLabel(shot.lens),
                          style: const pw.TextStyle(fontSize: 8),
                        ),
                        if (shot.fStop?.isNotEmpty == true)
                          pw.Text(
                            'T${shot.fStop}',
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        pw.SizedBox(height: 10),
                        _sectionTitle('Acción'),
                        pw.Text(
                          shot.action ?? '—',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        pw.SizedBox(height: 10),
                        _sectionTitle('Notas'),
                        pw.Text(
                          shot.notes ?? '—',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                        if (planSummary.isNotEmpty) ...[
                          pw.SizedBox(height: 10),
                          _sectionTitle('Planta cenital'),
                          pw.Text(
                            planSummary,
                            style: const pw.TextStyle(fontSize: 8),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 16),
                  pw.SizedBox(
                    width: 120,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        _sectionTitle('Sol'),
                        pw.SizedBox(height: 4),
                        _sunDiagram(scene.dayNight),
                        pw.SizedBox(height: 12),
                        _sectionTitle('Referencia'),
                        pw.SizedBox(height: 4),
                        if (imageBytes != null)
                          pw.Image(
                            pw.MemoryImage(imageBytes),
                            width: 100,
                            height: 56,
                            fit: pw.BoxFit.cover,
                          )
                        else
                          pw.Container(
                            width: 100,
                            height: 56,
                            color: PdfColors.grey200,
                            alignment: pw.Alignment.center,
                            child: pw.Text(
                              '—',
                              style: const pw.TextStyle(fontSize: 8),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static pw.Widget _sectionTitle(String text) => pw.Text(
        text.toUpperCase(),
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.grey700,
        ),
      );

  static pw.Widget _sunDiagram(String dayNight) {
    final angle = sunAngleFromDayNight(dayNight);
    const cx = 40.0;
    const cy = 40.0;
    const r = 32.0;
    final sunX = cx + r * 0.72 * math.cos(angle);
    final sunY = cy + r * 0.72 * math.sin(angle);

    return pw.Container(
      width: 80,
      height: 80,
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: sunX - 4,
            top: sunY - 4,
            child: pw.Container(
              width: 8,
              height: 8,
              decoration: const pw.BoxDecoration(
                color: PdfColors.orange300,
                shape: pw.BoxShape.circle,
              ),
            ),
          ),
          pw.Center(
            child: pw.Text(
              dayNight,
              style: const pw.TextStyle(fontSize: 6),
              textAlign: pw.TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  static Future<String> _cameraPlanSummary(Shot shot, AppDatabase? db) async {
    if (db == null) return '';
    final rows = await db.getCameraPlanElementsForShot(shot.id);
    if (rows.isEmpty) return '';
    final parts = rows.map((el) {
      final label = el.label?.trim().isNotEmpty == true
          ? el.label!
          : el.type;
      return '$label (${el.type})';
    });
    return parts.join(' · ');
  }
}
