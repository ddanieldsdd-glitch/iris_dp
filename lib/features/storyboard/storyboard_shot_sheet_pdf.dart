import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/database/app_database.dart';
import '../../core/utils/pdf_export_fonts.dart';
import '../../core/utils/pdf_safe_image.dart';
import '../../core/utils/scene_format.dart';
import '../luka_export/unreal_coords.dart';
import 'storyboard_export_helpers.dart';
import 'storyboard_export_style.dart';
import 'storyboard_image_palette.dart';
import 'storyboard_shot_export_meta.dart';
import 'storyboard_shot_image_exporter.dart';

/// PDF de plano único estilo Artemis (S2 Detail / S3 Shot Plan).
class StoryboardShotSheetPdf {
  StoryboardShotSheetPdf._();

  static Future<Uint8List> buildBytes({
    required Project project,
    required Scene scene,
    required Shot shot,
    required StoryboardExportStyle style,
    required StoryboardShotExportMeta meta,
    AppDatabase? db,
  }) async {
    assert(style == StoryboardExportStyle.detail ||
        style == StoryboardExportStyle.shotPlan);

    final fonts = await PdfExportFonts.load();
    final pdfTheme = PdfExportFonts.theme(
      regular: fonts.regular,
      bold: fonts.bold,
    );

    final imageBytes = await PdfSafeImage.loadFromPath(shot.referenceImagePath);
    final paletteColors = imageBytes != null
        ? await StoryboardImagePalette.extractFromBytes(imageBytes)
        : List.filled(8, const Color(0xFF808080));
    final palette = paletteColors
        .map((c) => PdfColor(c.r, c.g, c.b))
        .toList();

    final fov = horizontalFovDegrees(shot.lens, sensorWidthMm: meta.sensorWidthMm).round();
    final fovIcon = await renderFovIconBytes(fov.toDouble());

    final doc = pw.Document();
    doc.addPage(
      await _buildPage(
        project: project,
        scene: scene,
        shot: shot,
        meta: meta,
        style: style,
        imageBytes: imageBytes,
        palette: palette,
        fovIcon: fovIcon,
        db: db,
        theme: pdfTheme,
      ),
    );
    return doc.save();
  }

  static Future<pw.Page> _buildPage({
    required Project project,
    required Scene scene,
    required Shot shot,
    required StoryboardShotExportMeta meta,
    required StoryboardExportStyle style,
    required Uint8List? imageBytes,
    required List<PdfColor> palette,
    required Uint8List fovIcon,
    AppDatabase? db,
    pw.ThemeData? theme,
  }) async {
    final planSummary =
        style == StoryboardExportStyle.shotPlan ? await _cameraPlanSummary(shot, db) : '';
    final location = locationFromCanonical(scene.locationCanonical);
    final fov = horizontalFovDegrees(shot.lens, sensorWidthMm: meta.sensorWidthMm).round();
    final focal = parseFocalLengthMm(shot.lens).round();
    final takenOn = _formatTakenOn(meta.capturedAt ?? DateTime.now());

    return pw.Page(
      theme: theme,
      pageFormat: PdfPageFormat.a4.landscape,
      margin: pw.EdgeInsets.zero,
      build: (context) {
        final pageW = context.page.pageFormat.width;
        final pageH = context.page.pageFormat.height;
        const headerH = 22.0;
        final footerH = style == StoryboardExportStyle.shotPlan ? 130.0 : 108.0;
        final imageH = pageH - headerH - footerH;

        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              height: headerH,
              color: PdfColors.black,
              padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    meta.cameraHeader,
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.white),
                  ),
                  pw.Text(
                    meta.orientationHeader,
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.white),
                  ),
                  pw.Text(
                    meta.lensSeriesHeader,
                    style: const pw.TextStyle(fontSize: 7, color: PdfColors.white),
                  ),
                ],
              ),
            ),
            pw.SizedBox(
              height: imageH,
              child: pw.Stack(
                children: [
                  if (imageBytes != null)
                    pw.Image(
                      pw.MemoryImage(imageBytes),
                      width: pageW,
                      height: imageH,
                      fit: pw.BoxFit.cover,
                    )
                  else
                    pw.Container(
                      width: pageW,
                      height: imageH,
                      color: PdfColors.grey300,
                      alignment: pw.Alignment.center,
                      child: pw.Text('Sin referencia'),
                    ),
                  pw.Positioned(
                    right: 0,
                    bottom: 0,
                    child: _paletteStrip(palette),
                  ),
                ],
              ),
            ),
            pw.Container(
              height: footerH,
              color: PdfColors.white,
              padding: const pw.EdgeInsets.fromLTRB(18, 10, 18, 8),
              child: pw.Column(
                children: [
                  pw.Expanded(
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.SizedBox(
                          width: pageW * 0.28,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                project.name,
                                style: pw.TextStyle(
                                  fontSize: 16,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 4),
                              pw.Text(
                                'Sc. ${scene.number}',
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                              pw.Text(
                                'Shot ${meta.shotIndex} of ${meta.totalShotsInScene}',
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                              if (style == StoryboardExportStyle.shotPlan) ...[
                                pw.SizedBox(height: 6),
                                pw.Text(
                                  location,
                                  style: const pw.TextStyle(
                                    fontSize: 8,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                                pw.Text(
                                  sceneLocationLine(scene),
                                  style: const pw.TextStyle(
                                    fontSize: 7,
                                    color: PdfColors.grey600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        pw.SizedBox(
                          width: pageW * 0.22,
                          child: pw.Column(
                            children: [
                              pw.Text(
                                '$fov°',
                                style: pw.TextStyle(
                                  fontSize: 14,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                              pw.SizedBox(height: 2),
                              pw.Image(
                                pw.MemoryImage(fovIcon),
                                width: 72,
                                height: 36,
                              ),
                              pw.SizedBox(height: 2),
                              pw.Text(
                                '${focal}mm',
                                style: const pw.TextStyle(fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Container(
                            height: style == StoryboardExportStyle.shotPlan ? 72 : 64,
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: PdfColors.black, width: 0.8),
                            ),
                            padding: const pw.EdgeInsets.all(6),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: [
                                pw.Text(
                                  'Notes:',
                                  style: pw.TextStyle(
                                    fontSize: 9,
                                    fontWeight: pw.FontWeight.bold,
                                  ),
                                ),
                                pw.SizedBox(height: 3),
                                pw.Expanded(
                                  child: pw.Text(
                                    _notesText(shot),
                                    style: const pw.TextStyle(fontSize: 8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (style == StoryboardExportStyle.shotPlan) ...[
                          pw.SizedBox(width: 10),
                          pw.SizedBox(
                            width: 78,
                            child: pw.Column(
                              children: [
                                pw.Text(
                                  'Sol',
                                  style: pw.TextStyle(
                                    fontSize: 7,
                                    fontWeight: pw.FontWeight.bold,
                                    color: PdfColors.grey700,
                                  ),
                                ),
                                pw.SizedBox(height: 2),
                                _sunDiagram(scene.dayNight),
                                if (planSummary.isNotEmpty) ...[
                                  pw.SizedBox(height: 4),
                                  pw.Text(
                                    'Planta',
                                    style: pw.TextStyle(
                                      fontSize: 7,
                                      fontWeight: pw.FontWeight.bold,
                                      color: PdfColors.grey700,
                                    ),
                                  ),
                                  pw.Text(
                                    planSummary,
                                    style: const pw.TextStyle(fontSize: 6),
                                    maxLines: 4,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Taken on: $takenOn',
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static String _notesText(Shot shot) {
    final parts = <String>[
      if (shot.notes?.trim().isNotEmpty == true) shot.notes!.trim(),
      if (shot.action?.trim().isNotEmpty == true) shot.action!.trim(),
      if (shot.framing?.trim().isNotEmpty == true) shot.framing!.trim(),
      if (shot.movement?.trim().isNotEmpty == true) shot.movement!.trim(),
    ];
    return parts.isEmpty ? '—' : parts.join('\n');
  }

  static pw.Widget _paletteStrip(List<PdfColor> colors) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      children: [
        for (final c in colors)
          pw.Container(width: 14, height: 14, color: c),
      ],
    );
  }

  static pw.Widget _sunDiagram(String dayNight) {
    final angle = sunAngleFromDayNight(dayNight);
    const cx = 36.0;
    const cy = 36.0;
    const r = 28.0;
    final sunX = cx + r * 0.72 * math.cos(angle);
    final sunY = cy + r * 0.72 * math.sin(angle);

    return pw.Container(
      width: 72,
      height: 72,
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
      ),
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: sunX - 3,
            top: sunY - 3,
            child: pw.Container(
              width: 6,
              height: 6,
              decoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFE8912D),
                shape: pw.BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTakenOn(DateTime dt) {
    const months = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, $h:$m';
  }

  static Future<String> _cameraPlanSummary(Shot shot, AppDatabase? db) async {
    if (db == null) return '';
    final rows = await db.getCameraPlanElementsForShot(shot.id);
    if (rows.isEmpty) return '';
    return rows
        .map((el) => el.label?.trim().isNotEmpty == true ? el.label! : el.type)
        .join(' · ');
  }
}
