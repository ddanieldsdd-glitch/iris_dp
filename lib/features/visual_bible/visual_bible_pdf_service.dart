import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/export_file_saver.dart';
import '../../core/utils/pdf_export_fonts.dart';
import '../../core/utils/pdf_safe_image.dart';
import '../../shared/visual_bible/camera_pilot_resolve.dart';
import '../../shared/visual_bible/format_pilot_resolve.dart';
import '../../shared/visual_bible/bible_section_fields.dart';
import 'export/bible_section_export_reader.dart';
import 'export/pdf/bible_pdf_kit.dart';
import 'export/pdf/moodboard_pdf_tiles.dart';
import 'moodboard_export_grouper.dart';
import 'v2/migration/freeform_v2_blocks_codec.dart';
import 'moodboard_export_layout.dart';
import 'visual_bible_model.dart';

/// Genera PDFs de la Biblia de Fotografía (Pitch, Tech Scout, completa).
class VisualBiblePdfService {
  VisualBiblePdfService._();

  /// Clave interna para stills sin sección/categoría en REFERENCIAS VISUALES Pitch/Tech.
  static const pitchRefsUnclassifiedKey = '__pitch_refs_unclassified__';

  /// Subgrupo localización sin set vinculado en REFERENCIAS VISUALES Pitch/Tech.
  static const pitchRefsLocationUnassignedKey =
      '__pitch_refs_location_unassigned__';

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
    Set<String>? includedSections,
    Map<String, String?> sectionContentJsonById = const {},
    String? primaryCameraLabel,
    MoodboardExportLayout moodboardLayout = MoodboardExportLayout.defaults,
    bool includeAllMoodboardImages = false,
    List<BibleExportSectionRef> sectionOrder = const [],
  }) async {
    final doc = await buildDocument(
      sectionOrder: sectionOrder,
      mode: mode,
      projectName: projectName,
      director: director,
      data: data,
      colorBlocks: colorBlocks,
      exposureBlocks: exposureBlocks,
      lightingSetups: lightingSetups,
      cameraTests: cameraTests,
      moodboard: moodboard,
      includedSections: includedSections,
      sectionContentJsonById: sectionContentJsonById,
      primaryCameraLabel: primaryCameraLabel,
      moodboardLayout: moodboardLayout,
      includeAllMoodboardImages: includeAllMoodboardImages,
    );
    return doc.save();
  }

  static Future<Uint8List> buildFullBytes({
    required String projectName,
    required String? director,
    required VisualBibleData data,
    required List<ColorBlockModel> colorBlocks,
    required List<MoodboardImageModel> moodboard,
  }) => buildBytes(
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

  static bool _sectionAllowed(Set<String>? included, String sectionId) {
    if (included == null || included.isEmpty) return true;
    return included.contains(sectionId);
  }

  static List<pw.Widget> _moodboardWrapTiles(
    List<({pw.MemoryImage image, String? caption, List<String> details})>
    cells, {
    required pw.Font font,
    double? tileWidth = 175,
    double imageHeight = 120,
    double fontSize = 7,
    int detailLimit = 2,
  }) {
    return [
      for (final cell in cells)
        MoodboardPdfTiles.tileColumn(
          image: cell.image,
          font: font,
          caption: cell.caption,
          details: cell.details,
          tileWidth: tileWidth,
          imageHeight: imageHeight,
          fontSize: fontSize,
          detailLimit: detailLimit,
        ),
    ];
  }

  static Future<
    List<({pw.MemoryImage image, String? caption, List<String> details})>
  >
  _loadMoodboardCells(
    List<MoodboardImageModel> images,
    MoodboardExportLayout layout,
  ) async {
    final cells =
        <({pw.MemoryImage image, String? caption, List<String> details})>[];
    for (final img in images) {
      final bytes = await PdfSafeImage.loadFromPathMaxEdge(img.imagePath);
      if (bytes == null) continue;
      cells.add((
        image: pw.MemoryImage(bytes),
        caption: MoodboardExportGrouper.captionFor(img, layout.density),
        details: MoodboardExportGrouper.detailLinesFor(img, layout.density),
      ));
    }
    return cells;
  }

  /// Secciones donde debe aparecer un still en export Pitch/Tech.
  /// - Con asignación explícita: dedupe preservando orden.
  /// - Sin asignación: una sola sección canónica por categoría (no reverse
  ///   lookup, que duplicaba lighting+exposure para category=lighting).
  static List<String> exportSectionsForMoodboardImage(MoodboardImageModel img) {
    if (img.assignedSections.isNotEmpty) {
      final seen = <String>{};
      return [
        for (final sid in img.assignedSections)
          if (seen.add(sid)) sid,
      ];
    }
    final primary = BibleSectionId.sectionForMoodboardCategory(img.category);
    return primary == null ? const [] : [primary];
  }

  static String pitchRefsSectionLabel(String sectionKey) =>
      sectionKey == pitchRefsUnclassifiedKey
      ? 'Sin clasificar'
      : BibleSectionId.label(sectionKey);

  static List<
    MapEntry<String, List<({MoodboardImageModel img, pw.MemoryImage? image})>>
  >
  orderedPitchRefsEntries(
    Map<String, List<({MoodboardImageModel img, pw.MemoryImage? image})>>
    refsBySection,
  ) {
    final ordered =
        <
          MapEntry<
            String,
            List<({MoodboardImageModel img, pw.MemoryImage? image})>
          >
        >[];
    for (final sid in BibleSectionId.all) {
      final items = refsBySection[sid];
      if (items == null || items.isEmpty) continue;
      ordered.add(MapEntry(sid, items));
    }
    final unclassified = refsBySection[pitchRefsUnclassifiedKey];
    if (unclassified != null && unclassified.isNotEmpty) {
      ordered.add(MapEntry(pitchRefsUnclassifiedKey, unclassified));
    }
    return ordered;
  }

  static String pitchRefsLocationGroupKey(MoodboardImageModel img) {
    final planId = img.linkedLocationBasePlanId;
    if (planId != null) return 'plan:$planId';
    final name = img.linkedLocationName?.trim();
    if (name != null && name.isNotEmpty) return 'name:$name';
    return pitchRefsLocationUnassignedKey;
  }

  static String pitchRefsLocationGroupLabel(
    String groupKey,
    MoodboardImageModel sample,
  ) {
    if (groupKey == pitchRefsLocationUnassignedKey) {
      return 'Sin set asignado';
    }
    if (groupKey.startsWith('name:')) {
      return groupKey.substring('name:'.length);
    }
    final linkedName = sample.linkedLocationName?.trim();
    if (linkedName != null && linkedName.isNotEmpty) return linkedName;
    final planId = sample.linkedLocationBasePlanId;
    if (planId != null) return 'Set $planId';
    return 'Localización';
  }

  static List<
    MapEntry<String, List<({MoodboardImageModel img, pw.MemoryImage? image})>>
  >
  orderedPitchRefsLocationGroups(
    List<({MoodboardImageModel img, pw.MemoryImage? image})> items,
  ) {
    final groups =
        <String, List<({MoodboardImageModel img, pw.MemoryImage? image})>>{};
    for (final item in items) {
      final key = pitchRefsLocationGroupKey(item.img);
      groups.putIfAbsent(key, () => []).add(item);
    }
    final keys = groups.keys.toList();
    keys.sort((a, b) {
      if (a == pitchRefsLocationUnassignedKey) return 1;
      if (b == pitchRefsLocationUnassignedKey) return -1;
      return a.compareTo(b);
    });
    return [for (final key in keys) MapEntry(key, groups[key]!)];
  }

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
    Set<String>? includedSections,
    Map<String, String?> sectionContentJsonById = const {},
    String? primaryCameraLabel,
    MoodboardExportLayout moodboardLayout = MoodboardExportLayout.defaults,
    bool includeAllMoodboardImages = false,
    List<BibleExportSectionRef> sectionOrder = const [],
  }) async {
    final isPitch = mode == VisualBibleExportMode.pitch;
    final isTech = mode == VisualBibleExportMode.techScout;
    final sections = includedSections;
    final boardLayout = (!isPitch && !isTech) || includeAllMoodboardImages
        ? moodboardLayout.copyWith(maxImagesFlat: 0, maxImagesPerFacet: 0)
        : moodboardLayout;
    final fonts = await PdfExportFonts.load();
    final theme = PdfExportFonts.theme(
      regular: fonts.regular,
      bold: fonts.bold,
    );
    final doc = pw.Document();
    final kit = BiblePdfKit(regular: fonts.regular, bold: fonts.bold);

    // Las páginas se guardan por sección y se vuelcan al final en el orden
    // de la biblia.
    final pagesBySection = <String, List<pw.Page>>{};
    void addSection(String sectionId, pw.Page page) =>
        (pagesBySection[sectionId] ??= []).add(page);

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

    if (!isTech && _sectionAllowed(sections, BibleSectionId.direction)) {
      final directionCells = await _loadMoodboardCells(
        MoodboardExportGrouper.imagesForSection(
          moodboard,
          BibleSectionId.direction,
        ),
        boardLayout,
      );
      final directionContent = _directionContent(
        data,
        sectionContentJsonById[BibleSectionId.direction],
        kit,
        _stillTiles(directionCells, fonts),
      );
      if (directionContent.isNotEmpty) {
        addSection(
          BibleSectionId.direction,
          pw.MultiPage(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(BiblePdfTokens.pageMargin),
            build: (_) => [
              kit.sectionHeader('Dirección'),
              pw.SizedBox(height: 24),
              ...directionContent,
            ],
          ),
        );
      }
    }

    if (!isTech &&
        _sectionAllowed(sections, BibleSectionId.concept) &&
        (data.visualConcept?.trim().isNotEmpty == true ||
            _hasCustomContent(
              BibleSectionId.concept,
              sectionContentJsonById,
            ))) {
      addSection(
        BibleSectionId.concept,
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
                if (data.visualConcept?.trim().isNotEmpty == true)
                  pw.Text(
                    data.visualConcept!.trim(),
                    style: pw.TextStyle(
                      font: fonts.regular,
                      fontSize: 13,
                      lineSpacing: 7,
                    ),
                  ),
                if (data.conceptNarrativeIntent?.isNotEmpty == true) ...[
                  pw.SizedBox(height: 12),
                  pw.Text(
                    data.conceptNarrativeIntent!,
                    style: const pw.TextStyle(
                      fontSize: 11,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
                _customFieldsWidget(
                  BibleSectionId.concept,
                  sectionContentJsonById,
                  fonts,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!isTech &&
        _sectionAllowed(sections, BibleSectionId.colorImage) &&
        (colorBlocks.isNotEmpty ||
            _hasCustomContent(
              BibleSectionId.colorImage,
              sectionContentJsonById,
            ))) {
      addSection(
        BibleSectionId.colorImage,
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
                              style: pw.TextStyle(
                                font: fonts.bold,
                                fontSize: 18,
                              ),
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
            _customFieldsWidget(
              BibleSectionId.colorImage,
              sectionContentJsonById,
              fonts,
            ),
          ],
        ),
      );
    }

    if (!isPitch &&
        _sectionAllowed(sections, BibleSectionId.lighting) &&
        (data.lightingPhilosophy?.isNotEmpty == true ||
            lightingSetups.isNotEmpty ||
            _hasCustomContent(
              BibleSectionId.lighting,
              sectionContentJsonById,
            ))) {
      addSection(
        BibleSectionId.lighting,
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
                    style: pw.TextStyle(
                      font: fonts.regular,
                      fontSize: 12,
                      lineSpacing: 6,
                    ),
                  ),
                pw.SizedBox(height: 16),
                pw.Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _techChip('Calidad', data.lightQuality ?? '—', fonts),
                    _techChip('Contraste', data.contrastStyle ?? '—', fonts),
                    _techChip('K:F día', data.keyFillRatioDay ?? '—', fonts),
                    _techChip(
                      'K:F noche',
                      data.keyFillRatioNight ?? '—',
                      fonts,
                    ),
                    if (data.defaultTStop != null)
                      _techChip('T-stop', data.defaultTStop!, fonts),
                    if (data.ndNotes != null)
                      _techChip('ND', data.ndNotes!, fonts),
                  ],
                ),
                if (lightingSetups.isNotEmpty) ...[
                  pw.SizedBox(height: 16),
                  pw.Text(
                    'SETUPS',
                    style: pw.TextStyle(font: fonts.bold, fontSize: 10),
                  ),
                  ...lightingSetups.map(
                    (s) => pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 8),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Expanded(
                            child: pw.Text(
                              '• ${s.setupName}: ${s.narrativeNote ?? ''}',
                            ),
                          ),
                          if (s.diagramJson != '[]') ...[
                            pw.SizedBox(width: 8),
                            _lightingDiagram(s.diagramJson),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
                _customFieldsWidget(
                  BibleSectionId.lighting,
                  sectionContentJsonById,
                  fonts,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!isPitch &&
        _sectionAllowed(sections, BibleSectionId.exposure) &&
        (data.exposureNarrativeIntent?.isNotEmpty == true ||
            exposureBlocks.isNotEmpty ||
            data.highlightBehavior != null ||
            data.shadowBehavior != null ||
            data.nativeIso != null ||
            data.recordingFormat != null ||
            _hasCustomContent(
              BibleSectionId.exposure,
              sectionContentJsonById,
            ) ||
            MoodboardExportGrouper.imagesForSection(
              moodboard,
              BibleSectionId.exposure,
            ).isNotEmpty)) {
      final exposureCells = await _loadMoodboardCells(
        MoodboardExportGrouper.imagesForSection(
          moodboard,
          BibleSectionId.exposure,
        ),
        boardLayout,
      );
      addSection(
        BibleSectionId.exposure,
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (_) => _sectionPage(
            title: 'EXPOSICIÓN',
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
                    (b) =>
                        pw.Text('${b.blockName}: K:F ${b.keyFillRatio ?? "—"}'),
                  ),
                ],
                _customFieldsWidget(
                  BibleSectionId.exposure,
                  sectionContentJsonById,
                  fonts,
                ),
                ..._stillStrip(exposureCells, fonts),
              ],
            ),
          ),
        ),
      );
    }

    if (!isPitch && _sectionAllowed(sections, BibleSectionId.camera)) {
      final cameraBlob = CameraPilotResolve.parseBlob(
        BibleSectionExportReader.withoutUserPoints(
          sectionContentJsonById[BibleSectionId.camera],
          BibleSectionId.camera,
        ),
      );
      if (CameraPilotResolve.hasExportablePilotContent(
            data,
            cameraBlob,
            primaryCameraLabel: primaryCameraLabel,
          ) ||
          _hasUserPoints(BibleSectionId.camera, sectionContentJsonById)) {
        addSection(
          BibleSectionId.camera,
          pw.Page(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            build: (_) => _sectionPage(
              title: 'CÁMARA Y SENSOR',
              fontBold: fonts.bold,
              font: fonts.regular,
              content: _textFieldsContent([
                ...CameraPilotResolve.fixedSlotsForPdf(
                  data,
                  cameraBlob,
                  primaryCameraLabel: primaryCameraLabel,
                ),
                ...CameraPilotResolve.customRowsForPdf(cameraBlob),
                ..._userPointRows(
                  BibleSectionId.camera,
                  sectionContentJsonById,
                ),
              ], fonts),
            ),
          ),
        );
      }
    }

    if (!isPitch && _sectionAllowed(sections, BibleSectionId.location)) {
      final locationStills = moodboard.where(_isLocationStill).toList();
      if (_hasCustomContent(BibleSectionId.location, sectionContentJsonById) ||
          locationStills.isNotEmpty) {
        final locationCells = await _loadMoodboardCells(
          locationStills,
          moodboardLayout,
        );
        final locationBlob = BibleSectionExportReader.parseCustomBlob(
          sectionContentJsonById[BibleSectionId.location],
          BibleSectionId.location,
        );
        addSection(
          BibleSectionId.location,
          pw.Page(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            build: (_) => _sectionPage(
              title: 'LOCALIZACIÓN',
              fontBold: fonts.bold,
              font: fonts.regular,
              content: _locationPageContent(
                blob: locationBlob,
                cells: locationCells,
                stills: locationStills,
                fonts: fonts,
              ),
            ),
          ),
        );
      }
    }

    if (!isPitch && _sectionAllowed(sections, BibleSectionId.format)) {
      final formatBlob = FormatPilotResolve.parseBlob(
        BibleSectionExportReader.withoutUserPoints(
          sectionContentJsonById[BibleSectionId.format],
          BibleSectionId.format,
        ),
      );
      if (FormatPilotResolve.hasExportablePilotContent(data, formatBlob) ||
          _hasUserPoints(BibleSectionId.format, sectionContentJsonById)) {
        addSection(
          BibleSectionId.format,
          pw.Page(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            build: (_) => _sectionPage(
              title: 'FORMATO',
              fontBold: fonts.bold,
              font: fonts.regular,
              content: _textFieldsContent([
                (
                  'Relación de aspecto',
                  FormatPilotResolve.activeRatio(formatBlob, data),
                ),
                (
                  'Justificación',
                  FormatPilotResolve.legacyJustificationForPdf(
                    formatBlob,
                    data,
                  ),
                ),
                (
                  'Intención narrativa',
                  FormatPilotResolve.intentNarrative(formatBlob, data),
                ),
                ('Formato de grabación', data.recordingFormat),
                (
                  'Resolución de captura',
                  FormatPilotResolve.resolution(formatBlob, data),
                ),
                ('Resolución de entrega', data.deliveryResolution),
                ...FormatPilotResolve.customRowsForPdf(formatBlob),
                ..._userPointRows(
                  BibleSectionId.format,
                  sectionContentJsonById,
                ),
              ], fonts),
            ),
          ),
        );
      }
    }

    if (!isPitch &&
        _sectionAllowed(sections, BibleSectionId.texture) &&
        (_hasAny([
              data.imageTexture,
              data.grainLevel,
              data.diffusionNotes,
              data.textureNarrativeIntent,
              data.filtrationNotes,
            ]) ||
            _hasCustomContent(BibleSectionId.texture, sectionContentJsonById) ||
            MoodboardExportGrouper.imagesForSection(
              moodboard,
              BibleSectionId.texture,
            ).isNotEmpty)) {
      final textureCells = await _loadMoodboardCells(
        MoodboardExportGrouper.imagesForSection(
          moodboard,
          BibleSectionId.texture,
        ),
        boardLayout,
      );
      addSection(
        BibleSectionId.texture,
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (_) => _sectionPage(
            title: 'TEXTURA',
            fontBold: fonts.bold,
            font: fonts.regular,
            content: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                _textFieldsContent([
                  ('Textura de imagen', data.imageTexture),
                  ('Grano', data.grainLevel),
                  ('Difusión', data.diffusionNotes),
                  ('Filtración', data.filtrationNotes),
                  ('Intención narrativa', data.textureNarrativeIntent),
                  ..._customFieldRows(
                    BibleSectionId.texture,
                    sectionContentJsonById,
                  ),
                ], fonts),
                ..._stillStrip(textureCells, fonts),
              ],
            ),
          ),
        ),
      );
    }

    if (!isPitch &&
        _sectionAllowed(sections, BibleSectionId.workflow) &&
        (_hasAny([
              data.workflowPipeline,
              data.codec,
              data.deliveryColorSpace,
              data.resolutionNotes,
              data.frameRateNotes,
            ]) ||
            _hasCustomContent(
              BibleSectionId.workflow,
              sectionContentJsonById,
            ))) {
      addSection(
        BibleSectionId.workflow,
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (_) => _sectionPage(
            title: 'WORKFLOW',
            fontBold: fonts.bold,
            font: fonts.regular,
            content: _textFieldsContent([
              ('Pipeline', data.workflowPipeline),
              ('Códec', data.codec),
              ('Espacio de color de entrega', data.deliveryColorSpace),
              ('Resolución', data.resolutionNotes),
              ('Frame rate', data.frameRateNotes),
              ..._customFieldRows(
                BibleSectionId.workflow,
                sectionContentJsonById,
              ),
            ], fonts),
          ),
        ),
      );
    }

    if (!isPitch &&
        !isTech &&
        _sectionAllowed(sections, BibleSectionId.moodboard) &&
        moodboard.isNotEmpty) {
      final groups = MoodboardExportGrouper.group(moodboard, boardLayout);
      final detailLimit = boardLayout.density == MoodboardExportDensity.rich
          ? 4
          : 2;
      final pageChildren = <pw.Widget>[];

      if (boardLayout.grouping == MoodboardExportGrouping.flat) {
        pageChildren.addAll([
          _sectionHeader('MOODBOARD', fonts.bold),
          pw.SizedBox(height: 4),
          pw.Text(
            'Plano · grid continuo',
            style: pw.TextStyle(
              font: fonts.regular,
              fontSize: 9,
              color: const PdfColor.fromInt(0xFF8E8E93),
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 12),
        ]);
        final cells = await _loadMoodboardCells(groups.flat, boardLayout);
        if (cells.isNotEmpty) {
          pageChildren.add(
            MoodboardPdfTiles.flatGrid(
              tiles: _moodboardWrapTiles(
                cells,
                font: fonts.regular,
                tileWidth: null,
                imageHeight: 100,
                detailLimit: detailLimit,
              ),
            ),
          );
        }
      } else {
        for (final facet in MoodboardExportGrouper.facetOrder) {
          final facetImages = groups.byFacet[facet];
          if (facetImages == null || facetImages.isEmpty) continue;
          final cells = await _loadMoodboardCells(facetImages, boardLayout);
          if (cells.isEmpty) continue;
          pageChildren.addAll([
            MoodboardPdfTiles.facetSectionHeader(
              facetLabel: MoodboardExportLayout.facetLabel(facet),
              bold: fonts.bold,
            ),
            MoodboardPdfTiles.wrap(
              tiles: _moodboardWrapTiles(
                cells,
                font: fonts.regular,
                tileWidth: 220,
                imageHeight: 115,
                detailLimit: detailLimit,
              ),
            ),
            pw.SizedBox(height: 20),
          ]);
        }
        if (boardLayout.includeUnclassified && groups.unclassified.isNotEmpty) {
          final cells = await _loadMoodboardCells(
            groups.unclassified,
            boardLayout,
          );
          if (cells.isNotEmpty) {
            pageChildren.addAll([
              MoodboardPdfTiles.facetSectionHeader(
                facetLabel: 'Sin clasificar',
                bold: fonts.bold,
              ),
              MoodboardPdfTiles.wrap(
                tiles: _moodboardWrapTiles(
                  cells,
                  font: fonts.regular,
                  tileWidth: 220,
                  imageHeight: 115,
                  detailLimit: detailLimit,
                ),
              ),
            ]);
          }
        }
      }

      if (pageChildren.isNotEmpty) {
        addSection(
          BibleSectionId.moodboard,
          pw.MultiPage(
            theme: theme,
            pageFormat: PdfPageFormat.a4.landscape,
            build: (_) => pageChildren,
          ),
        );
      }
    }

    if (!isPitch &&
        _sectionAllowed(sections, BibleSectionId.cameraTests) &&
        cameraTests.isNotEmpty) {
      addSection(
        BibleSectionId.cameraTests,
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

    if ((isPitch || isTech) &&
        _sectionAllowed(sections, BibleSectionId.moodboard) &&
        moodboard.isNotEmpty) {
      final refsBySection =
          <String, List<({MoodboardImageModel img, pw.MemoryImage? image})>>{};
      for (final img in moodboard) {
        final assigned = exportSectionsForMoodboardImage(img);
        final bytes = await PdfSafeImage.loadFromPath(img.imagePath);
        final memory = bytes != null ? pw.MemoryImage(bytes) : null;
        final item = (img: img, image: memory);
        if (assigned.isEmpty) {
          refsBySection
              .putIfAbsent(pitchRefsUnclassifiedKey, () => [])
              .add(item);
          continue;
        }
        final includeFilteredAsUnclassified =
            includeAllMoodboardImages &&
            _sectionAllowed(sections, BibleSectionId.moodboard);
        var addedToAllowedSection = false;
        for (final sid in assigned) {
          if (!_sectionAllowed(sections, sid) &&
              sections != null &&
              sections.isNotEmpty) {
            continue;
          }
          refsBySection.putIfAbsent(sid, () => []).add(item);
          addedToAllowedSection = true;
        }
        if (!addedToAllowedSection && includeFilteredAsUnclassified) {
          refsBySection
              .putIfAbsent(pitchRefsUnclassifiedKey, () => [])
              .add(item);
        }
      }
      if (refsBySection.isNotEmpty) {
        final pitchDetailLimit =
            moodboardLayout.density == MoodboardExportDensity.rich ? 4 : 2;
        final orderedRefs = orderedPitchRefsEntries(refsBySection);
        addSection(
          BibleSectionId.moodboard,
          pw.MultiPage(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            build: (context) => [
              _sectionHeader('REFERENCIAS VISUALES', fonts.bold),
              for (final entry in orderedRefs) ...[
                pw.Text(
                  pitchRefsSectionLabel(entry.key),
                  style: pw.TextStyle(font: fonts.bold, fontSize: 12),
                ),
                pw.SizedBox(height: 8),
                if (entry.key == BibleSectionId.location)
                  for (final locGroup in orderedPitchRefsLocationGroups(
                    entry.value,
                  )) ...[
                    pw.Text(
                      pitchRefsLocationGroupLabel(
                        locGroup.key,
                        locGroup.value.first.img,
                      ),
                      style: pw.TextStyle(font: fonts.regular, fontSize: 10),
                    ),
                    pw.SizedBox(height: 6),
                    MoodboardPdfTiles.wrap(
                      spacing: 8,
                      tiles: [
                        for (final item in locGroup.value)
                          if (item.image != null)
                            MoodboardPdfTiles.tileColumn(
                              image: item.image!,
                              font: fonts.regular,
                              caption: MoodboardExportGrouper.captionFor(
                                item.img,
                                moodboardLayout.density,
                              ),
                              details: MoodboardExportGrouper.detailLinesFor(
                                item.img,
                                moodboardLayout.density,
                              ),
                              tileWidth: 120,
                              imageHeight: 80,
                              fontSize: 8,
                              detailLimit: pitchDetailLimit,
                            ),
                      ],
                    ),
                    pw.SizedBox(height: 12),
                  ]
                else
                  MoodboardPdfTiles.wrap(
                    spacing: 8,
                    tiles: [
                      for (final item in entry.value)
                        if (item.image != null)
                          MoodboardPdfTiles.tileColumn(
                            image: item.image!,
                            font: fonts.regular,
                            caption: MoodboardExportGrouper.captionFor(
                              item.img,
                              moodboardLayout.density,
                            ),
                            details: MoodboardExportGrouper.detailLinesFor(
                              item.img,
                              moodboardLayout.density,
                            ),
                            tileWidth: 120,
                            imageHeight: 80,
                            fontSize: 8,
                            detailLimit: pitchDetailLimit,
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

    if (!isPitch &&
        _sectionAllowed(sections, BibleSectionId.optics) &&
        (BibleSectionExportReader.hasOpticsExportContent(
              data.opticsConfigJson,
              narrativeIntent: data.opticsNarrativeIntent,
              lensPhilosophy: data.lensPhilosophy,
            ) ||
            _hasUserPoints(BibleSectionId.optics, sectionContentJsonById))) {
      final opticsRows = BibleSectionExportReader.rowsFromOpticsConfigJson(
        data.opticsConfigJson,
        narrativeIntent: data.opticsNarrativeIntent,
        lensPhilosophy: data.lensPhilosophy,
      );
      addSection(
        BibleSectionId.optics,
        pw.Page(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          build: (_) => _sectionPage(
            title: 'ÓPTICA',
            fontBold: fonts.bold,
            font: fonts.regular,
            content: _textFieldsContent([
              ...opticsRows.map((row) => (row.label, row.value)),
              ..._userPointRows(BibleSectionId.optics, sectionContentJsonById),
            ], fonts),
          ),
        ),
      );
    }

    // Pantallas creadas por el usuario. El selector de secciones del export
    // no las lista, así que salen siempre en el PDF completo.
    for (final section in sectionOrder) {
      if (!section.isCustom || isPitch || isTech) continue;
      final children = await _customSectionContent(
        section,
        sectionContentJsonById[section.id],
        kit,
      );
      if (children.isEmpty) continue;
      addSection(
        section.id,
        pw.MultiPage(
          theme: theme,
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(BiblePdfTokens.pageMargin),
          build: (_) => [
            kit.sectionHeader(section.label),
            pw.SizedBox(height: 24),
            ...children,
          ],
        ),
      );
    }

    // Vuelca en el orden de la biblia; lo que no esté en ese orden conserva
    // el orden histórico al final.
    for (final id in [
      ...sectionOrder.map((s) => s.id),
      ..._defaultSectionOrder,
    ]) {
      pagesBySection.remove(id)?.forEach(doc.addPage);
    }
    for (final pages in pagesBySection.values) {
      pages.forEach(doc.addPage);
    }

    return doc;
  }

  /// Orden del PDF cuando no se pasa el de la biblia.
  static const _defaultSectionOrder = [
    BibleSectionId.direction,
    BibleSectionId.concept,
    BibleSectionId.colorImage,
    BibleSectionId.lighting,
    BibleSectionId.exposure,
    BibleSectionId.camera,
    BibleSectionId.location,
    BibleSectionId.format,
    BibleSectionId.texture,
    BibleSectionId.workflow,
    BibleSectionId.moodboard,
    BibleSectionId.cameraTests,
    BibleSectionId.optics,
  ];

  /// Puntos de una pantalla personalizada, en el orden del usuario.
  static Future<List<pw.Widget>> _customSectionContent(
    BibleExportSectionRef section,
    String? contentJson,
    BiblePdfKit kit,
  ) async {
    final values = BibleSectionFieldsConfig.parseValues(contentJson);
    final out = <pw.Widget>[];

    Future<void> addImages(Iterable<String> paths) async {
      final images = <pw.MemoryImage>[];
      for (final path in paths) {
        final bytes = await PdfSafeImage.loadFromPathMaxEdge(path);
        if (bytes != null) images.add(pw.MemoryImage(bytes));
      }
      if (images.isNotEmpty) out.add(kit.imageRow(images));
    }

    // Las pantallas nuevas guardan su contenido como bloques modulares.
    for (final block in FreeformV2BlocksCodec.parseBlocks(contentJson)) {
      final content = block.content;
      final title = (content['title'] ?? content['label'] ?? '')
          .toString()
          .trim();
      final body = (content['body'] ?? content['text'] ?? '').toString().trim();
      if (body.isNotEmpty) out.add(kit.textPoint(title, body));
      final path = content['imagePath'] ?? content['path'];
      final list = content['images'] ?? content['items'];
      await addImages([
        if (path is String && path.isNotEmpty) path,
        if (list is List)
          for (final item in list)
            if (item is String)
              item
            else if (item is Map && item['path'] is String)
              item['path'] as String,
      ]);
    }
    for (final field in BibleSectionFieldsConfig.parse(
      contentJson,
      section.id,
    )) {
      final point = kit.point(field, values[field.key]);
      if (point != null) out.add(point);

      try {
        final raw = values['${field.key}__images'];
        final decoded = raw == null ? null : jsonDecode(raw);
        if (decoded is List) await addImages(decoded.whereType<String>());
      } catch (_) {}
    }
    return out;
  }

  static Future<pw.Document> buildFullDocument({
    required String projectName,
    required String? director,
    required VisualBibleData data,
    required List<ColorBlockModel> colorBlocks,
    required List<MoodboardImageModel> moodboard,
  }) => buildDocument(
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
    final theme = PdfExportFonts.theme(
      regular: fonts.regular,
      bold: fonts.bold,
    );
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
      VisualBibleDepartment.productionDesign => _artDeptContent(
        data,
        colorBlocks,
        fonts,
      ),
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
              style: pw.TextStyle(
                font: fonts.regular,
                fontSize: 10,
                color: PdfColors.grey600,
              ),
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
    Set<String>? includedSections,
    Map<String, String?> sectionContentJsonById = const {},
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
        includedSections: includedSections,
        sectionContentJsonById: sectionContentJsonById,
      ),
    );
  }

  static Future<String?> exportFull({
    required String projectName,
    required String? director,
    required VisualBibleData data,
    required List<ColorBlockModel> colorBlocks,
    required List<MoodboardImageModel> moodboard,
  }) => export(
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
    final dept = VisualBibleDepartment.label(
      department,
    ).toLowerCase().replaceAll(' ', '_');
    return ExportFileSaver.saveGenerated(
      dialogTitle:
          'Exportar ficha — ${VisualBibleDepartment.label(department)}',
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
          pw.Text(
            d.lightingPhilosophy!,
            style: pw.TextStyle(font: fonts.regular, fontSize: 12),
          ),
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
          pw.Text(
            d.creativeLutDescription!,
            style: pw.TextStyle(font: fonts.regular, fontSize: 12),
          ),
        ],
        pw.SizedBox(height: 16),
        if (d.imageTexture != null)
          _techChip('Textura', d.imageTexture!, fonts),
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
          pw.Text(
            d.cameraPhilosophy!,
            style: pw.TextStyle(font: fonts.regular, fontSize: 12),
          ),
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
            if (d.aspectRatio != null)
              _techChip('Ratio', d.aspectRatio!, fonts),
            if (d.movementStyle != null)
              _techChip('Movimiento', d.movementStyle!, fonts),
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
          pw.Text(
            d.visualConcept!,
            style: pw.TextStyle(font: fonts.regular, fontSize: 12),
          ),
        pw.SizedBox(height: 16),
        pw.Text(
          'PALETAS',
          style: pw.TextStyle(font: fonts.bold, fontSize: 10, letterSpacing: 2),
        ),
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

  /// Dirección: los puntos de la sección en el orden del usuario.
  static List<pw.Widget> _directionContent(
    VisualBibleData data,
    String? contentJson,
    BiblePdfKit kit,
    pw.Widget? stills,
  ) {
    final blob = BibleSectionExportReader.parseCustomBlob(
      BibleSectionExportReader.withoutUserPoints(
        contentJson,
        BibleSectionId.direction,
      ),
      BibleSectionId.direction,
    );
    final values = BibleSectionFieldsConfig.parseValues(contentJson);
    String text(Object? v) => v?.toString().trim() ?? '';
    List<(String, String)> pairs(Object? raw) => [
      if (raw is List)
        for (final e in raw)
          if (e is Map)
            (text(e['title']), text(e['body'] ?? e['desc']))
          else
            (text(e), ''),
    ].where((p) => p.$1.isNotEmpty || p.$2.isNotEmpty).toList();

    final out = <pw.Widget>[];
    for (final field in BibleSectionFieldsConfig.parse(
      contentJson,
      BibleSectionId.direction,
    )) {
      switch (field.key) {
        case 'header':
          final scene = text(blob['sceneTag']);
          if (scene.isNotEmpty) out.add(kit.tagRow([scene]));
        case 'narrative':
          final intent = text(data.directionNarrativeIntent);
          if (intent.isNotEmpty) out.add(kit.textPoint(field.label, intent));
          final legacy = text(data.creativeIntention);
          if (legacy.isNotEmpty) out.add(kit.textPoint('Intención', legacy));
          final tags = [
            if (blob['emotionTags'] is List)
              for (final t in blob['emotionTags'] as List) text(t),
          ].where((t) => t.isNotEmpty).toList();
          if (tags.isNotEmpty) out.add(kit.tagRow(tags));
        case 'tone':
          final points = pairs(blob['tonePoints']);
          final legacy = text(data.tone);
          if (points.isNotEmpty) {
            out.add(kit.titledList(field.label, points));
          } else if (legacy.isNotEmpty) {
            out.add(kit.textPoint(field.label, legacy));
          }
        case 'strategies':
          final pillars = [
            (kicker: null, title: 'Cámara', text: text(data.cameraPhilosophy)),
            (kicker: null, title: 'Blocking', text: text(data.stagingApproach)),
            (kicker: null, title: 'POV', text: text(data.pointOfView)),
            for (final (title, body) in pairs(blob['extraStrategies']))
              (kicker: null, title: title, text: body),
          ].where((p) => p.text.isNotEmpty).toList();
          if (pillars.isNotEmpty) {
            out.add(kit.columnsPoint(field.label, pillars));
          }
        case 'acts':
          // Mismos valores por defecto que muestra la pantalla.
          const phases = ['ESTABLECIMIENTO', 'DESESTABILIZACIÓN', 'RESOLUCIÓN'];
          const titles = ['Orden y Rigidez', 'Fragmentación', 'Abstracción'];
          const numerals = ['I', 'II', 'III'];
          final acts = [
            for (var n = 0; n < 3; n++)
              if (text(blob['act${n + 1}Desc']).isNotEmpty)
                (
                  kicker:
                      'Acto ${numerals[n]}: '
                      '${blob['act${n + 1}Phase'] ?? phases[n]}',
                  title: text(blob['act${n + 1}Title'] ?? titles[n]),
                  text: text(blob['act${n + 1}Desc']),
                ),
          ];
          if (acts.isNotEmpty) out.add(kit.columnsPoint(field.label, acts));
        case 'references':
          final cards = [
            if (blob['refsMetadata'] is List)
              for (final e in blob['refsMetadata'] as List)
                if (e is Map)
                  (
                    kicker: text(e['refLabel']),
                    title: text(e['title']),
                    text: [
                      text(e['body']),
                      [
                        if (text(e['lens']).isNotEmpty)
                          'Lente ${text(e['lens'])}',
                        if (text(e['tech2Value']).isNotEmpty)
                          '${text(e['tech2Label'])} ${text(e['tech2Value'])}'
                              .trim(),
                      ].join(' · '),
                    ].where((l) => l.isNotEmpty).join('\n'),
                  ),
          ].where((c) => c.title.isNotEmpty || c.text.isNotEmpty).toList();
          if (cards.isNotEmpty || stills != null) {
            out.add(kit.label(field.label));
            out.add(pw.SizedBox(height: 6));
            if (stills != null) {
              out.add(stills);
              out.add(pw.SizedBox(height: 10));
            }
            if (cards.isNotEmpty) {
              out.add(kit.columnsPoint('', cards, perRow: 2));
            }
          }
        case 'transitions':
          final entries = pairs(blob['transitionLanguage']);
          if (entries.isNotEmpty) out.add(kit.titledList(field.label, entries));
        case 'keyFrame':
          final intent = text(blob['keyFrameIntent']);
          final specs = [
            if (blob['keyFrame'] is Map)
              for (final e in (blob['keyFrame'] as Map).entries)
                (text(e.key), text(e.value)),
          ].where((r) => r.$2.isNotEmpty).toList();
          if (intent.isNotEmpty) {
            out.add(kit.textPoint(field.label, intent));
            if (specs.isNotEmpty) out.add(kit.specsPoint('', specs));
          }
        default:
          final point = kit.point(field, values[field.key]);
          if (point != null) out.add(point);
      }
    }
    return out;
  }

  /// Stills de una sección como rejilla, o `null` si no hay.
  static pw.Widget? _stillTiles(
    List<({pw.MemoryImage image, String? caption, List<String> details})> cells,
    ({pw.Font regular, pw.Font bold}) fonts,
  ) => cells.isEmpty
      ? null
      : pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _moodboardWrapTiles(
            cells,
            font: fonts.regular,
            tileWidth: 120,
            imageHeight: 80,
          ),
        );

  static bool _hasAny(Iterable<String?> values) =>
      values.any((value) => value?.trim().isNotEmpty == true);

  static List<pw.Widget> _stillStrip(
    List<({pw.MemoryImage image, String? caption, List<String> details})> cells,
    ({pw.Font regular, pw.Font bold}) fonts,
  ) {
    if (cells.isEmpty) return const [];
    return [
      pw.SizedBox(height: 14),
      pw.Text(
        'REFERENCIAS',
        style: pw.TextStyle(
          font: fonts.bold,
          fontSize: 8,
          color: PdfColors.grey600,
          letterSpacing: 1,
        ),
      ),
      pw.SizedBox(height: 8),
      pw.Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _moodboardWrapTiles(
          cells,
          font: fonts.regular,
          tileWidth: 120,
          imageHeight: 80,
        ),
      ),
    ];
  }

  static bool _isLocationStill(MoodboardImageModel img) =>
      img.assignedSections.contains(BibleSectionId.location) ||
      img.category == MoodboardCategory.location ||
      (img.linkedLocationName?.trim().isNotEmpty ?? false) ||
      img.linkedLocationBasePlanId != null;

  static pw.Widget _locationPageContent({
    required Map<String, dynamic> blob,
    required List<
      ({pw.MemoryImage image, String? caption, List<String> details})
    >
    cells,
    required List<MoodboardImageModel> stills,
    required ({pw.Font regular, pw.Font bold}) fonts,
  }) {
    final setNames = <String>{
      for (final img in stills)
        if (img.linkedLocationName?.trim().isNotEmpty == true)
          img.linkedLocationName!.trim(),
    };
    const solarKeys = [
      ('azimuth', 'Azimut'),
      ('sunrise', 'Amanecer'),
      ('sunset', 'Atardecer'),
      ('goldenHour', 'Golden hour'),
      ('daylightWindow', 'Ventana'),
    ];
    final solar = [
      for (final (key, label) in solarKeys)
        if ((blob[key]?.toString().trim().isNotEmpty ?? false))
          (label, blob[key].toString().trim()),
    ];
    final hero = cells.isEmpty ? null : cells.first;
    final rest = cells.length <= 1
        ? const <
            ({pw.MemoryImage image, String? caption, List<String> details})
          >[]
        : cells.sublist(1);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (setNames.isNotEmpty) ...[
          pw.Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final name in setNames)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Text(name, style: const pw.TextStyle(fontSize: 9)),
                ),
            ],
          ),
          pw.SizedBox(height: 12),
        ],
        if (hero != null) ...[
          pw.Container(
            height: 160,
            width: double.infinity,
            child: pw.Image(hero.image, fit: pw.BoxFit.cover),
          ),
          pw.SizedBox(height: 12),
        ],
        if (solar.isNotEmpty) ...[
          pw.Row(
            children: [
              for (final (label, value) in solar)
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      pw.Text(
                        value,
                        style: pw.TextStyle(font: fonts.bold, fontSize: 11),
                      ),
                      pw.Text(
                        label.toUpperCase(),
                        style: const pw.TextStyle(
                          fontSize: 7,
                          color: PdfColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          pw.SizedBox(height: 12),
        ],
        _textFieldsContent(
          BibleSectionExportReader.rowsForSection(
            BibleSectionId.location,
            blob,
          ).map((row) => (row.label, row.value)).toList(),
          fonts,
        ),
        if (rest.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          pw.Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _moodboardWrapTiles(rest, font: fonts.regular),
          ),
        ],
      ],
    );
  }

  static bool _hasUserPoints(
    String sectionId,
    Map<String, String?> sectionContentJsonById,
  ) => BibleSectionExportReader.userPoints(
    sectionContentJsonById[sectionId],
    sectionId,
  ).isNotEmpty;

  static List<(String, String?)> _userPointRows(
    String sectionId,
    Map<String, String?> sectionContentJsonById,
  ) => [
    for (final point in BibleSectionExportReader.userPoints(
      sectionContentJsonById[sectionId],
      sectionId,
    ))
      (point.field.label, BibleSectionExportReader.userPointText(point)),
  ];

  static bool _hasCustomContent(
    String sectionId,
    Map<String, String?> sectionContentJsonById,
  ) =>
      BibleSectionExportReader.blobRows(
        sectionContentJsonById[sectionId],
        sectionId,
      ).isNotEmpty ||
      _hasUserPoints(sectionId, sectionContentJsonById);

  /// Filas del blob de la sección seguidas de los puntos del usuario.
  static List<(String, String?)> _customFieldRows(
    String sectionId,
    Map<String, String?> sectionContentJsonById,
  ) => [
    for (final row in BibleSectionExportReader.blobRows(
      sectionContentJsonById[sectionId],
      sectionId,
    ))
      (row.label, row.value),
    ..._userPointRows(sectionId, sectionContentJsonById),
  ];

  static pw.Widget _customFieldsWidget(
    String sectionId,
    Map<String, String?> sectionContentJsonById,
    ({pw.Font regular, pw.Font bold}) fonts, {
    bool leadingSpacing = true,
  }) {
    final kit = BiblePdfKit(regular: fonts.regular, bold: fonts.bold);
    final contentJson = sectionContentJsonById[sectionId];
    final blobRows = [
      for (final row in BibleSectionExportReader.blobRows(
        contentJson,
        sectionId,
      ))
        (row.label, row.value as String?),
    ];
    final points = [
      for (final point in BibleSectionExportReader.userPoints(
        contentJson,
        sectionId,
      ))
        kit.point(point.field, point.value),
    ].whereType<pw.Widget>().toList();
    if (blobRows.isEmpty && points.isEmpty) return pw.SizedBox();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (leadingSpacing) pw.SizedBox(height: 12),
        if (blobRows.isNotEmpty) _textFieldsContent(blobRows, fonts),
        ...points,
      ],
    );
  }

  static pw.Widget _textFieldsContent(
    List<(String, String?)> fields,
    ({pw.Font regular, pw.Font bold}) fonts,
  ) {
    final kit = BiblePdfKit(regular: fonts.regular, bold: fonts.bold);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final (label, value) in fields)
          if (value?.trim().isNotEmpty == true) kit.textPoint(label, value!),
      ],
    );
  }

  static pw.Widget _lightingDiagram(String rawJson) {
    List<Map<String, dynamic>> elements;
    try {
      elements = (jsonDecode(rawJson) as List)
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList();
    } catch (_) {
      elements = const [];
    }
    return pw.Container(
      width: 150,
      height: 96,
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
      ),
      child: pw.CustomPaint(
        size: const PdfPoint(150, 96),
        painter: (canvas, size) {
          for (final element in elements) {
            final x = ((element['x'] as num?)?.toDouble() ?? 150) / 600;
            final y = ((element['y'] as num?)?.toDouble() ?? 150) / 400;
            final type = element['type']?.toString() ?? 'light';
            final color = switch (type) {
              'camera' => const PdfColor.fromInt(0xFF0A84FF),
              'subject' => const PdfColor.fromInt(0xFF1C1C1E),
              'key' => const PdfColor.fromInt(0xFFFFCC00),
              'fill' => const PdfColor.fromInt(0xFF64D2FF),
              'rim' => const PdfColor.fromInt(0xFFFF9F0A),
              _ => const PdfColor.fromInt(0xFF8E8E93),
            };
            final px = x.clamp(0.04, 0.96) * size.x;
            final py = (1 - y.clamp(0.04, 0.96)) * size.y;
            canvas
              ..setFillColor(color)
              ..drawEllipse(px, py, 4, 4)
              ..fillPath();
            if (type == 'camera') {
              canvas
                ..setStrokeColor(color)
                ..setLineWidth(1)
                ..drawLine(px, py, px, py + 10)
                ..strokePath();
            }
          }
        },
      ),
    );
  }

  static pw.Widget _techChip(
    String label,
    String value,
    ({pw.Font regular, pw.Font bold}) fonts,
  ) => BiblePdfKit(regular: fonts.regular, bold: fonts.bold).chip(label, value);

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

  static pw.Widget _sectionHeader(String title, pw.Font fontBold) =>
      BiblePdfKit(regular: fontBold, bold: fontBold).sectionHeader(title);

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
