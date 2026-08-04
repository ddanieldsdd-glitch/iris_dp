import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/export_file_saver.dart';
import '../../core/utils/pdf_export_fonts.dart';
import '../../core/utils/pdf_safe_image.dart';
import 'visual_bible_model.dart';

/// Genera PDFs de la Biblia de Fotografía (Pitch, Tech Scout, completa).
class VisualBiblePdfService {
  VisualBiblePdfService._();

  static Future<Uint8List> buildBytes({
    required String mode,
    required String projectName,
    required String? director,
    required VisualBibleData data,
    required List<ColorBlockModel> colorBlocks,
    required List<ExposureBlockModel> exposureBlocks,
    required List<LightingSetupModel> lightingSetups,
    required List<CameraTestModel> cameraTests,
    required List<MoodboardImageModel> moodboard,
  }) async {
    final doc = await buildDocument(
      mode: mode,
      projectName: projectName,
      director: director,
      data: data,
      colorBlocks: colorBlocks,
      exposureBlocks: exposureBlocks,
      lightingSetups: lightingSetups,
      cameraTests: cameraTests,
      moodboard: moodboard,
    );
    return doc.save();
  }

  static Future<Uint8List> buildFullBytes({
    required String projectName,
    required String? director,
    required VisualBibleData data,
    required List<ColorBlockModel> colorBlocks,
    required List<MoodboardImageModel> moodboard,
  }) =>
      buildBytes(
        mode: VisualBibleExportMode.full,
        projectName: projectName,
        director: director,
        data: data,
        colorBlocks: colorBlocks,
        exposureBlocks: const [],
        lightingSetups: const [],
        cameraTests: const [],
        moodboard: moodboard,
      );

  static Future<pw.Document> buildDocument({
    required String mode,
    required String projectName,
    required String? director,
    required VisualBibleData data,
    required List<ColorBlockModel> colorBlocks,
    required List<ExposureBlockModel> exposureBlocks,
    required List<LightingSetupModel> lightingSetups,
    required List<CameraTestModel> cameraTests,
    required List<MoodboardImageModel> moodboard,
  }) async {
    final isPitch = mode == VisualBibleExportMode.pitch;
    final isTech = mode == VisualBibleExportMode.techScout;
    final fonts = await PdfExportFonts.load();
    final theme = PdfExportFonts.theme(regular: fonts.regular, bold: fonts.bold);
    final doc = pw.Document();

    final coverLabel = isPitch
        ? 'PITCH DECK — BIBLIA DE FOTOGRAFÍA'
        : isTech
            ? 'TECH SCOUT — BIBLIA DE FOTOGRAFÍA'
            : 'BIBLIA DE FOTOGRAFÍA';

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
                coverLabel,
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

    if (!isTech && _hasDirectionContent(data)) {
      doc.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (_) => _sectionPage(
            title: 'DIRECCIÓN',
            fontBold: fonts.bold,
            font: fonts.regular,
            content: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                ..._directionPdfFields(data, fonts.regular),
                if (data.directionNarrativeIntent?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 12),
                  pw.Text(
                    data.directionNarrativeIntent!,
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (!isTech && data.visualConcept?.trim().isNotEmpty == true) {
      doc.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (_) => _sectionPage(
            title: 'CONCEPTO DE IMAGEN',
            fontBold: fonts.bold,
            font: fonts.regular,
            content: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  data.visualConcept!,
                  style: pw.TextStyle(font: fonts.regular, fontSize: 13, lineSpacing: 7),
                ),
                if (data.conceptNarrativeIntent?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 12),
                  pw.Text(
                    data.conceptNarrativeIntent!,
                    style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (!isTech && colorBlocks.isNotEmpty) {
      doc.addPage(
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            _sectionHeader('COLOR E IMAGEN', fonts.bold),
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
            if (data.workingLutName != null)
              _techChip('LUT trabajo', data.workingLutName!, fonts),
            if (data.creativeLutName != null)
              _techChip('LUT creativo', data.creativeLutName!, fonts),
          ],
        ),
      );
    }

    if (!isPitch) {
      doc.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (_) => _sectionPage(
            title: 'ILUMINACIÓN',
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
                    if (data.defaultTStop != null)
                      _techChip('T-stop', data.defaultTStop!, fonts),
                    if (data.ndNotes != null) _techChip('ND', data.ndNotes!, fonts),
                  ],
                ),
                if (lightingSetups.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text('SETUPS', style: pw.TextStyle(font: fonts.bold, fontSize: 10)),
                  ...lightingSetups.map(
                    (s) => pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 6),
                      child: pw.Text('• ${s.setupName}: ${s.narrativeNote ?? ''}'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (!isPitch) {
      doc.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (_) => _sectionPage(
            title: 'EXPOSICIÓN Y CÁMARA',
            fontBold: fonts.bold,
            font: fonts.regular,
            content: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (data.exposureNarrativeIntent?.isNotEmpty == true)
                  pw.Text(data.exposureNarrativeIntent!),
                pw.SizedBox(height: 12),
                pw.Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (data.highlightBehavior != null)
                      _techChip('Highlights', data.highlightBehavior!, fonts),
                    if (data.shadowBehavior != null)
                      _techChip('Sombras', data.shadowBehavior!, fonts),
                    if (data.nativeIso != null)
                      _techChip('ISO nativo', '${data.nativeIso}', fonts),
                    if (data.recordingFormat != null)
                      _techChip('Formato', data.recordingFormat!, fonts),
                  ],
                ),
                if (exposureBlocks.isNotEmpty) ...[
                  pw.SizedBox(height: 12),
                  ...exposureBlocks.map(
                    (b) => pw.Text('${b.blockName}: K:F ${b.keyFillRatio ?? "—"}'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (!isTech && moodboard.isNotEmpty) {
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

    if (!isPitch && cameraTests.isNotEmpty) {
      doc.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (_) => _sectionPage(
            title: 'PRUEBAS DE CÁMARA',
            fontBold: fonts.bold,
            font: fonts.regular,
            content: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: cameraTests
                  .map(
                    (t) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 8),
                      child: pw.Text(
                        '${t.testName} — LUT: ${t.lutName ?? "—"}, Luz: ${t.lightCondition ?? "—"}',
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      );
    }

    if ((isPitch || isTech) && moodboard.isNotEmpty) {
      final refsBySection = <String, List<({MoodboardImageModel img, pw.MemoryImage? image})>>{};
      for (final img in moodboard) {
        final sections = img.assignedSections.isNotEmpty
            ? img.assignedSections
            : [
                for (final sid in BibleSectionId.all)
                  if (BibleSectionId.moodboardCategory(sid) == img.category) sid,
              ];
        final bytes = await PdfSafeImage.loadFromPath(img.imagePath);
        final memory = bytes != null ? pw.MemoryImage(bytes) : null;
        for (final sid in sections) {
          refsBySection.putIfAbsent(sid, () => []).add((img: img, image: memory));
        }
      }
      if (refsBySection.isNotEmpty) {
        doc.addPage(
          pw.MultiPage(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            build: (context) => [
              _sectionHeader('REFERENCIAS VISUALES', fonts.bold),
              for (final entry in refsBySection.entries) ...[
                pw.Text(
                  BibleSectionId.label(entry.key),
                  style: pw.TextStyle(font: fonts.bold, fontSize: 12),
                ),
                pw.SizedBox(height: 8),
                pw.Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in entry.value)
                      if (item.image != null)
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Image(item.image!, height: 80, fit: pw.BoxFit.contain),
                            if (item.img.caption?.isNotEmpty == true)
                              pw.Text(
                                item.img.caption!,
                                style: pw.TextStyle(font: fonts.regular, fontSize: 8),
                              ),
                          ],
                        ),
                  ],
                ),
                pw.SizedBox(height: 16),
              ],
            ],
          ),
        );
      }
    }

    if (isTech && data.opticsConfigJson?.isNotEmpty == true) {
      doc.addPage(
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (_) => _sectionPage(
            title: 'CONFIGURACIÓN ÓPTICA (FLT)',
            fontBold: fonts.bold,
            font: fonts.regular,
            content: pw.Text(
              data.opticsConfigJson!,
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
        ),
      );
    }

    return doc;
  }

  static Future<pw.Document> buildFullDocument({
    required String projectName,
    required String? director,
    required VisualBibleData data,
    required List<ColorBlockModel> colorBlocks,
    required List<MoodboardImageModel> moodboard,
  }) =>
      buildDocument(
        mode: VisualBibleExportMode.full,
        projectName: projectName,
        director: director,
        data: data,
        colorBlocks: colorBlocks,
        exposureBlocks: const [],
        lightingSetups: const [],
        cameraTests: const [],
        moodboard: moodboard,
      );

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

  static Future<String?> export({
    required String mode,
    required String projectName,
    required String? director,
    required VisualBibleData data,
    required List<ColorBlockModel> colorBlocks,
    required List<ExposureBlockModel> exposureBlocks,
    required List<LightingSetupModel> lightingSetups,
    required List<CameraTestModel> cameraTests,
    required List<MoodboardImageModel> moodboard,
  }) {
    final safe = projectName.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    final suffix = switch (mode) {
      VisualBibleExportMode.pitch => 'pitch',
      VisualBibleExportMode.techScout => 'tech_scout',
      _ => 'biblia_fotografia',
    };
    return ExportFileSaver.saveGenerated(
      dialogTitle: 'Exportar Biblia de Fotografía',
      fileName: '${safe.isEmpty ? 'proyecto' : safe}_$suffix.pdf',
      extension: 'pdf',
      build: () => buildBytes(
        mode: mode,
        projectName: projectName,
        director: director,
        data: data,
        colorBlocks: colorBlocks,
        exposureBlocks: exposureBlocks,
        lightingSetups: lightingSetups,
        cameraTests: cameraTests,
        moodboard: moodboard,
      ),
    );
  }

  static Future<String?> exportFull({
    required String projectName,
    required String? director,
    required VisualBibleData data,
    required List<ColorBlockModel> colorBlocks,
    required List<MoodboardImageModel> moodboard,
  }) =>
      export(
        mode: VisualBibleExportMode.full,
        projectName: projectName,
        director: director,
        data: data,
        colorBlocks: colorBlocks,
        exposureBlocks: const [],
        lightingSetups: const [],
        cameraTests: const [],
        moodboard: moodboard,
      );

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

  static bool _hasDirectionContent(VisualBibleData data) =>
      data.tone?.trim().isNotEmpty == true ||
      data.creativeIntention?.trim().isNotEmpty == true ||
      data.stagingApproach?.trim().isNotEmpty == true ||
      data.pointOfView?.trim().isNotEmpty == true ||
      data.directionNarrativeIntent?.trim().isNotEmpty == true;

  static List<pw.Widget> _directionPdfFields(
    VisualBibleData data,
    pw.Font font,
  ) {
    final fields = <(String, String?)>[
      ('Tono', data.tone),
      ('Intención', data.creativeIntention),
      ('Puesta en escena', data.stagingApproach),
      ('Punto de vista', data.pointOfView),
    ];
    return [
      for (final (label, value) in fields)
        if (value?.trim().isNotEmpty == true) ...[
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(font: font, fontSize: 8, color: PdfColors.grey600),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            value!,
            style: pw.TextStyle(font: font, fontSize: 12, lineSpacing: 5),
          ),
          pw.SizedBox(height: 12),
        ],
    ];
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
