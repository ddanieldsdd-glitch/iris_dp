import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/export_file_saver.dart';
import '../../core/utils/pdf_export_fonts.dart';
import '../../core/utils/pdf_safe_image.dart';
import 'visual_bible_model.dart';

/// Genera PDFs de la Biblia Visual (completa y por departamento).
class VisualBiblePdfService {
  VisualBiblePdfService._();

  static Future<Uint8List> buildFullBytes({
    required String projectName,
    required String? director,
    required VisualBibleData data,
    required List<ColorBlockModel> colorBlocks,
    required List<MoodboardImageModel> moodboard,
  }) async {
    final doc = await buildFullDocument(
      projectName: projectName,
      director: director,
      data: data,
      colorBlocks: colorBlocks,
      moodboard: moodboard,
    );
    return doc.save();
  }

  static Future<pw.Document> buildFullDocument({
    required String projectName,
    required String? director,
    required VisualBibleData data,
    required List<ColorBlockModel> colorBlocks,
    required List<MoodboardImageModel> moodboard,
  }) async {
    final fonts = await PdfExportFonts.load();
    final theme = PdfExportFonts.theme(regular: fonts.regular, bold: fonts.bold);
    final doc = pw.Document();

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: theme,
        build: (_) => pw.Container(
          color: const PdfColor.fromInt(0xFF0A0A0A),
          padding: const pw.EdgeInsets.all(48),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Spacer(),
              pw.Text(
                'BIBLIA VISUAL',
                style: pw.TextStyle(
                  font: fonts.bold,
                  fontSize: 10,
                  color: const PdfColor.fromInt(0xFF8E8E93),
                  letterSpacing: 4,
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                projectName,
                style: pw.TextStyle(
                  font: fonts.bold,
                  fontSize: 42,
                  color: PdfColors.white,
                ),
              ),
              if (director != null)
                pw.Text(
                  'Dir. $director',
                  style: pw.TextStyle(
                    font: fonts.regular,
                    fontSize: 16,
                    color: const PdfColor.fromInt(0xFF8E8E93),
                  ),
                ),
              pw.SizedBox(height: 48),
              pw.Text(
                'DIRECTOR DE FOTOGRAFÍA',
                style: pw.TextStyle(
                  font: fonts.regular,
                  fontSize: 9,
                  color: const PdfColor.fromInt(0xFF48484A),
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (data.visualConcept?.trim().isNotEmpty == true) {
      doc.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (_) => _sectionPage(
            title: 'CONCEPTO VISUAL',
            fontBold: fonts.bold,
            font: fonts.regular,
            content: pw.Text(
              data.visualConcept!,
              style: pw.TextStyle(font: fonts.regular, fontSize: 13, lineSpacing: 7),
            ),
          ),
        ),
      );
    }

    if (colorBlocks.isNotEmpty) {
      doc.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            _sectionHeader('COLOR', fonts.bold),
            ...colorBlocks.map(
              (block) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 20),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      block.blockName,
                      style: pw.TextStyle(font: fonts.bold, fontSize: 15),
                    ),
                    if (block.emotionalIntent?.isNotEmpty == true)
                      pw.Text(
                        block.emotionalIntent!,
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.grey700,
                        ),
                      ),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      children: [
                        ...block.dominantColors.map(
                          (hex) => pw.Container(
                            width: 56,
                            height: 56,
                            margin: const pw.EdgeInsets.only(right: 6),
                            decoration: pw.BoxDecoration(
                              color: _hexToPdf(hex),
                              borderRadius: pw.BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        if (block.colorTempKelvin != null)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(left: 12),
                            child: pw.Text(
                              '${block.colorTempKelvin}K',
                              style: pw.TextStyle(font: fonts.bold, fontSize: 18),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    doc.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        build: (_) => _sectionPage(
          title: 'LUZ',
          fontBold: fonts.bold,
          font: fonts.regular,
          content: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (data.lightingPhilosophy?.isNotEmpty == true)
                pw.Text(
                  data.lightingPhilosophy!,
                  style: pw.TextStyle(font: fonts.regular, fontSize: 12, lineSpacing: 6),
                ),
              pw.SizedBox(height: 16),
              pw.Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _techChip('Calidad', data.lightQuality ?? '—', fonts),
                  _techChip('Contraste', data.contrastStyle ?? '—', fonts),
                  _techChip('K:F día', data.keyFillRatioDay ?? '—', fonts),
                  _techChip('K:F noche', data.keyFillRatioNight ?? '—', fonts),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (moodboard.isNotEmpty) {
      final images = <pw.MemoryImage>[];
      for (final img in moodboard.take(12)) {
        final bytes = await PdfSafeImage.loadFromPath(img.imagePath);
        if (bytes != null) images.add(pw.MemoryImage(bytes));
      }
      if (images.isNotEmpty) {
        doc.addPage(
          pw.Page(
            theme: theme,
            pageFormat: PdfPageFormat.a4.landscape,
            build: (_) => pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _sectionHeader('MOODBOARD', fonts.bold),
                pw.SizedBox(height: 12),
                pw.Expanded(
                  child: pw.GridView(
                    crossAxisCount: 4,
                    crossAxisSpacing: 6,
                    mainAxisSpacing: 6,
                    children: [
                      for (final img in images)
                        pw.Image(img, fit: pw.BoxFit.cover),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }

    return doc;
  }

  static Future<Uint8List> buildDepartmentBytes({
    required String department,
    required String projectName,
    required VisualBibleData data,
    required List<ColorBlockModel> colorBlocks,
  }) async {
    final doc = await buildDepartmentDocument(
      department: department,
      projectName: projectName,
      data: data,
      colorBlocks: colorBlocks,
    );
    return doc.save();
  }

  static Future<pw.Document> buildDepartmentDocument({
    required String department,
    required String projectName,
    required VisualBibleData data,
    required List<ColorBlockModel> colorBlocks,
  }) async {
    final fonts = await PdfExportFonts.load();
    final theme = PdfExportFonts.theme(regular: fonts.regular, bold: fonts.bold);
    final doc = pw.Document();

    final title = switch (department) {
      VisualBibleDepartment.gaffer => 'PARA EL GAFFER',
      VisualBibleDepartment.colorist => 'PARA EL COLORISTA',
      VisualBibleDepartment.cameraOp => 'PARA EL OPERADOR',
      VisualBibleDepartment.productionDesign => 'PARA DIRECCIÓN DE ARTE',
      _ => 'IRIS DP',
    };

    final content = switch (department) {
      VisualBibleDepartment.gaffer => _gafferContent(data, fonts),
      VisualBibleDepartment.colorist => _coloristContent(data, fonts),
      VisualBibleDepartment.cameraOp => _cameraOpContent(data, fonts),
      VisualBibleDepartment.productionDesign =>
        _artDeptContent(data, colorBlocks, fonts),
      _ => pw.SizedBox(),
    };

    doc.addPage(
      pw.Page(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              projectName,
              style: pw.TextStyle(font: fonts.regular, fontSize: 10, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 8),
            _sectionPage(
              title: title,
              fontBold: fonts.bold,
              font: fonts.regular,
              content: content,
            ),
          ],
        ),
      ),
    );

    return doc;
  }

  static Future<String?> exportFull({
    required String projectName,
    required String? director,
    required VisualBibleData data,
    required List<ColorBlockModel> colorBlocks,
    required List<MoodboardImageModel> moodboard,
  }) {
    final safe = projectName.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    return ExportFileSaver.saveGenerated(
      dialogTitle: 'Exportar Biblia Visual',
      fileName: '${safe.isEmpty ? 'proyecto' : safe}_biblia_visual.pdf',
      extension: 'pdf',
      build: () => buildFullBytes(
        projectName: projectName,
        director: director,
        data: data,
        colorBlocks: colorBlocks,
        moodboard: moodboard,
      ),
    );
  }

  static Future<String?> exportDepartment({
    required String department,
    required String projectName,
    required VisualBibleData data,
    required List<ColorBlockModel> colorBlocks,
  }) {
    final safe = projectName.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final dept = VisualBibleDepartment.label(department)
        .toLowerCase()
        .replaceAll(' ', '_');
    return ExportFileSaver.saveGenerated(
      dialogTitle: 'Exportar ficha — ${VisualBibleDepartment.label(department)}',
      fileName: '${safe.isEmpty ? 'proyecto' : safe}_$dept.pdf',
      extension: 'pdf',
      build: () => buildDepartmentBytes(
        department: department,
        projectName: projectName,
        data: data,
        colorBlocks: colorBlocks,
      ),
    );
  }

  static pw.Widget _gafferContent(
    VisualBibleData d,
    ({pw.Font regular, pw.Font bold}) fonts,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (d.lightingPhilosophy?.isNotEmpty == true)
          pw.Text(d.lightingPhilosophy!, style: pw.TextStyle(font: fonts.regular, fontSize: 12)),
        pw.SizedBox(height: 16),
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _techChip('Calidad', d.lightQuality ?? '—', fonts),
            _techChip('Contraste', d.contrastStyle ?? '—', fonts),
            _techChip('K:F día', d.keyFillRatioDay ?? '—', fonts),
            _techChip('K:F noche', d.keyFillRatioNight ?? '—', fonts),
            if (d.highlightBehavior != null)
              _techChip('Altas luces', d.highlightBehavior!, fonts),
            if (d.shadowBehavior != null)
              _techChip('Sombras', d.shadowBehavior!, fonts),
          ],
        ),
      ],
    );
  }

  static pw.Widget _coloristContent(
    VisualBibleData d,
    ({pw.Font regular, pw.Font bold}) fonts,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (d.creativeLutName != null)
          _techChip('LUT creativo', d.creativeLutName!, fonts),
        if (d.workingLutName != null) ...[
          pw.SizedBox(height: 8),
          _techChip('LUT trabajo', d.workingLutName!, fonts),
        ],
        if (d.creativeLutDescription?.isNotEmpty == true) ...[
          pw.SizedBox(height: 12),
          pw.Text(d.creativeLutDescription!, style: pw.TextStyle(font: fonts.regular, fontSize: 12)),
        ],
        pw.SizedBox(height: 16),
        if (d.imageTexture != null) _techChip('Textura', d.imageTexture!, fonts),
      ],
    );
  }

  static pw.Widget _cameraOpContent(
    VisualBibleData d,
    ({pw.Font regular, pw.Font bold}) fonts,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (d.cameraPhilosophy?.isNotEmpty == true)
          pw.Text(d.cameraPhilosophy!, style: pw.TextStyle(font: fonts.regular, fontSize: 12)),
        pw.SizedBox(height: 16),
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (d.opticType != null) _techChip('Óptica', d.opticType!, fonts),
            if (d.primaryFocalLengths.isNotEmpty)
              _techChip(
                'Focales',
                d.primaryFocalLengths.map((f) => '${f}mm').join(', '),
                fonts,
              ),
            if (d.aspectRatio != null) _techChip('Ratio', d.aspectRatio!, fonts),
            if (d.movementStyle != null) _techChip('Movimiento', d.movementStyle!, fonts),
          ],
        ),
      ],
    );
  }

  static pw.Widget _artDeptContent(
    VisualBibleData d,
    List<ColorBlockModel> blocks,
    ({pw.Font regular, pw.Font bold}) fonts,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (d.visualConcept?.isNotEmpty == true)
          pw.Text(d.visualConcept!, style: pw.TextStyle(font: fonts.regular, fontSize: 12)),
        pw.SizedBox(height: 16),
        pw.Text('PALETAS', style: pw.TextStyle(font: fonts.bold, fontSize: 10, letterSpacing: 2)),
        pw.SizedBox(height: 8),
        ...blocks.map(
          (b) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text('${b.blockName}: ${b.dominantColors.join(', ')}'),
          ),
        ),
      ],
    );
  }

  static pw.Widget _techChip(
    String label,
    String value,
    ({pw.Font regular, pw.Font bold}) fonts,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: pw.BoxDecoration(
        color: const PdfColor.fromInt(0xFFF2F2F7),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(font: fonts.regular, fontSize: 7, color: PdfColors.grey600),
          ),
          pw.Text(value, style: pw.TextStyle(font: fonts.bold, fontSize: 11)),
        ],
      ),
    );
  }

  static pw.Widget _sectionPage({
    required String title,
    required pw.Font fontBold,
    required pw.Font font,
    required pw.Widget content,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(40),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionHeader(title, fontBold),
          pw.SizedBox(height: 24),
          pw.Expanded(child: content),
        ],
      ),
    );
  }

  static pw.Widget _sectionHeader(String title, pw.Font fontBold) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          height: 3,
          width: 32,
          color: const PdfColor.fromInt(0xFF0A84FF),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          title,
          style: pw.TextStyle(
            font: fontBold,
            fontSize: 11,
            letterSpacing: 3,
            color: const PdfColor.fromInt(0xFF8E8E93),
          ),
        ),
      ],
    );
  }

  static PdfColor _hexToPdf(String hex) {
    final clean = hex.replaceAll('#', '');
    final value = int.tryParse(clean, radix: 16) ?? 0x808080;
    return PdfColor(
      ((value >> 16) & 0xFF) / 255,
      ((value >> 8) & 0xFF) / 255,
      (value & 0xFF) / 255,
    );
  }
}
