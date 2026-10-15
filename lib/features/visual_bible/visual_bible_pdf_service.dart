import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/export_file_saver.dart';
import '../../core/utils/pdf_export_fonts.dart';
import '../../core/utils/pdf_safe_image.dart';
import '../../shared/visual_bible/camera_pilot_resolve.dart';
import '../../shared/visual_bible/bible_acts.dart';
import '../../shared/visual_bible/bible_cards.dart';
import '../../shared/visual_bible/bible_point_extras.dart';
import '../../shared/visual_bible/bible_text_specs.dart';
import '../../shared/visual_bible/camera_points.dart';
import '../../shared/visual_bible/color_points.dart';
import '../../shared/visual_bible/bible_lighting_data.dart';
import '../../shared/visual_bible/concept_points.dart';
import '../../shared/visual_bible/lighting_card_page.dart';
import '../../shared/visual_bible/lighting_metrics.dart';
import '../../shared/visual_bible/narrative_card_kind.dart';
import '../camera_plan/light/modifiers.dart';
import '../../shared/visual_bible/exposure_points.dart';
import '../../shared/visual_bible/optics_points.dart';
import '../../shared/visual_bible/texture_points.dart';
import '../../shared/visual_bible/workflow_points.dart';
import '../../shared/visual_bible/direction_points.dart';
import '../../shared/visual_bible/bible_reference.dart';
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
    List<NarrativeCardModel> lightingCards = const [],
  }) async {
    final doc = await PdfSafeImage.withExportCache(
      () => buildDocument(
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
        lightingCards: lightingCards,
      ),
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
    List<NarrativeCardModel> lightingCards = const [],
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
    _userPointImages = await _loadUserPointImages(
      sectionContentJsonById,
      moodboard,
      extra: {
        for (final card in lightingCards) ..._lightingCardImageIds(card),
      },
    );
    _sharedActs = BibleSharedActs.resolve(
      data.actVisualNotes,
      directionBlob: BibleSectionExportReader.parseCustomBlob(
        sectionContentJsonById[BibleSectionId.direction],
        BibleSectionId.direction,
      ),
      conceptBlob: BibleSectionExportReader.parseCustomBlob(
        sectionContentJsonById[BibleSectionId.concept],
        BibleSectionId.concept,
      ),
    );
    _heroes = await _loadHeroes(sectionContentJsonById, moodboard);
    _heroColors = {
      for (final entry in sectionContentJsonById.entries)
        if (BibleScreenHeroValue.read(
              BibleSectionFieldsConfig.parseValues(entry.value),
            ).argb
            case final argb?)
          entry.key: PdfColor.fromInt(argb),
    };
    // Nombre que el usuario haya dado a una pantalla de la biblia.
    _renamed = {
      for (final section in sectionOrder)
        if (!section.isCustom &&
            section.label.trim().isNotEmpty &&
            section.label != BibleSectionId.label(section.id))
          section.id: section.label.trim(),
    };
    final kit = _kit(fonts);

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
      final directionJson = sectionContentJsonById[BibleSectionId.direction];
      final directionAssets = await _loadSectionAssets(
        BibleSectionId.direction,
        directionJson,
        moodboard,
        boardLayout,
        fonts,
      );
      final directionContent = _directionContent(
        data,
        directionJson,
        kit,
        directionAssets,
      );
      if (directionContent.isNotEmpty) {
        addSection(
          BibleSectionId.direction,
          pw.MultiPage(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(BiblePdfTokens.pageMargin),
            build: (_) => [
              kit.sectionHeader(
                _renamed[BibleSectionId.direction] ?? 'Dirección',
                image: _heroes[BibleSectionId.direction],
                accent: _heroColors[BibleSectionId.direction],
              ),
              pw.SizedBox(height: 24),
              ...directionContent,
            ],
          ),
        );
      }
    }

    if (!isTech && _sectionAllowed(sections, BibleSectionId.concept)) {
      final conceptJson = sectionContentJsonById[BibleSectionId.concept];
      final conceptAssets = await _loadSectionAssets(
        BibleSectionId.concept,
        conceptJson,
        moodboard,
        boardLayout,
        fonts,
      );
      final conceptContent = _conceptContent(
        data,
        conceptJson,
        colorBlocks,
        kit,
        conceptAssets,
      );
      if (conceptContent.isNotEmpty) {
        addSection(
          BibleSectionId.concept,
          pw.MultiPage(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(BiblePdfTokens.pageMargin),
            build: (_) => [
              kit.sectionHeader(
                _renamed[BibleSectionId.concept] ?? 'Concepto de imagen',
                image: _heroes[BibleSectionId.concept],
                accent: _heroColors[BibleSectionId.concept],
              ),
              pw.SizedBox(height: 24),
              ...conceptContent,
            ],
          ),
        );
      }
    }

    if (!isTech && _sectionAllowed(sections, BibleSectionId.colorImage)) {
      final colorJson = sectionContentJsonById[BibleSectionId.colorImage];
      final colorAssets = await _loadSectionAssets(
        BibleSectionId.colorImage,
        colorJson,
        moodboard,
        boardLayout,
        fonts,
      );
      final colorContent = _colorContent(
        data,
        colorJson,
        colorBlocks,
        kit,
        colorAssets,
      );
      if (colorContent.isNotEmpty) {
        addSection(
          BibleSectionId.colorImage,
          pw.MultiPage(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(BiblePdfTokens.pageMargin),
            build: (_) => [
              kit.sectionHeader(
                _renamed[BibleSectionId.colorImage] ?? 'Color e imagen',
                image: _heroes[BibleSectionId.colorImage],
                accent: _heroColors[BibleSectionId.colorImage],
              ),
              pw.SizedBox(height: 24),
              ...colorContent,
            ],
          ),
        );
      }
    }

    if (!isPitch && _sectionAllowed(sections, BibleSectionId.lighting)) {
      final lightingContent = _lightingContent(
        data,
        sectionContentJsonById[BibleSectionId.lighting],
        lightingSetups,
        lightingCards,
        kit,
        fonts,
      );
      if (lightingContent.isNotEmpty) {
        addSection(
          BibleSectionId.lighting,
          pw.MultiPage(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(BiblePdfTokens.pageMargin),
            build: (_) => [
              kit.sectionHeader(
                _renamed[BibleSectionId.lighting] ?? 'Iluminación',
                image: _heroes[BibleSectionId.lighting],
                accent: _heroColors[BibleSectionId.lighting],
              ),
              pw.SizedBox(height: 24),
              ...lightingContent,
            ],
          ),
        );
      }
    }

    if (!isPitch && _sectionAllowed(sections, BibleSectionId.exposure)) {
      final exposureJson = sectionContentJsonById[BibleSectionId.exposure];
      final exposureAssets = await _loadSectionAssets(
        BibleSectionId.exposure,
        exposureJson,
        moodboard,
        boardLayout,
        fonts,
      );
      final exposureContent = _exposureContent(
        data,
        exposureJson,
        exposureBlocks,
        kit,
        exposureAssets,
      );
      if (exposureContent.isNotEmpty) {
        addSection(
          BibleSectionId.exposure,
          pw.MultiPage(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(BiblePdfTokens.pageMargin),
            build: (_) => [
              kit.sectionHeader(
                _renamed[BibleSectionId.exposure] ?? 'Exposición',
                image: _heroes[BibleSectionId.exposure],
                accent: _heroColors[BibleSectionId.exposure],
              ),
              pw.SizedBox(height: 24),
              ...exposureContent,
            ],
          ),
        );
      }
    }

    if (!isPitch && _sectionAllowed(sections, BibleSectionId.camera)) {
      final cameraJson = sectionContentJsonById[BibleSectionId.camera];
      final cameraAssets = await _loadSectionAssets(
        BibleSectionId.camera,
        cameraJson,
        moodboard,
        boardLayout,
        fonts,
      );
      final cameraContent = _cameraContent(
        data,
        cameraJson,
        kit,
        cameraAssets,
        primaryCameraLabel: primaryCameraLabel,
      );
      if (cameraContent.isNotEmpty) {
        addSection(
          BibleSectionId.camera,
          pw.MultiPage(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(BiblePdfTokens.pageMargin),
            build: (_) => [
              kit.sectionHeader(
                _renamed[BibleSectionId.camera] ?? 'Cámara y sensor',
                image: _heroes[BibleSectionId.camera],
                accent: _heroColors[BibleSectionId.camera],
              ),
              pw.SizedBox(height: 24),
              ...cameraContent,
            ],
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
              sectionId: BibleSectionId.location,
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
              sectionId: BibleSectionId.format,
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

    if (!isPitch && _sectionAllowed(sections, BibleSectionId.texture)) {
      final textureJson = sectionContentJsonById[BibleSectionId.texture];
      final textureAssets = await _loadSectionAssets(
        BibleSectionId.texture,
        textureJson,
        moodboard,
        boardLayout,
        fonts,
      );
      final textureContent = _textureContent(
        data,
        textureJson,
        kit,
        textureAssets,
      );
      if (textureContent.isNotEmpty) {
        addSection(
          BibleSectionId.texture,
          pw.MultiPage(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(BiblePdfTokens.pageMargin),
            build: (_) => [
              kit.sectionHeader(
                _renamed[BibleSectionId.texture] ?? 'Textura',
                image: _heroes[BibleSectionId.texture],
                accent: _heroColors[BibleSectionId.texture],
              ),
              pw.SizedBox(height: 24),
              ...textureContent,
            ],
          ),
        );
      }
    }

    if (!isPitch && _sectionAllowed(sections, BibleSectionId.workflow)) {
      final workflowJson = sectionContentJsonById[BibleSectionId.workflow];
      final workflowAssets = await _loadSectionAssets(
        BibleSectionId.workflow,
        workflowJson,
        moodboard,
        boardLayout,
        fonts,
      );
      final workflowContent = _workflowContent(
        data,
        workflowJson,
        kit,
        workflowAssets,
      );
      if (workflowContent.isNotEmpty) {
        addSection(
          BibleSectionId.workflow,
          pw.MultiPage(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(BiblePdfTokens.pageMargin),
            build: (_) => [
              kit.sectionHeader(
                _renamed[BibleSectionId.workflow] ?? 'Workflow',
                image: _heroes[BibleSectionId.workflow],
                accent: _heroColors[BibleSectionId.workflow],
              ),
              pw.SizedBox(height: 24),
              ...workflowContent,
            ],
          ),
        );
      }
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
            sectionId: BibleSectionId.cameraTests,
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
        final bytes = await PdfSafeImage.loadFromPathMaxEdge(img.imagePath);
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

    if (!isPitch && _sectionAllowed(sections, BibleSectionId.optics)) {
      final opticsJson = sectionContentJsonById[BibleSectionId.optics];
      final opticsAssets = await _loadSectionAssets(
        BibleSectionId.optics,
        opticsJson,
        moodboard,
        boardLayout,
        fonts,
      );
      final opticsContent = _opticsContent(data, opticsJson, kit, opticsAssets);
      if (opticsContent.isNotEmpty) {
        addSection(
          BibleSectionId.optics,
          pw.MultiPage(
            theme: theme,
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(BiblePdfTokens.pageMargin),
            build: (_) => [
              kit.sectionHeader(
                _renamed[BibleSectionId.optics] ?? 'Óptica',
                image: _heroes[BibleSectionId.optics],
                accent: _heroColors[BibleSectionId.optics],
              ),
              pw.SizedBox(height: 24),
              ...opticsContent,
            ],
          ),
        );
      }
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
            kit.sectionHeader(
              section.label,
              image: _heroes[section.id],
              accent: _heroColors[section.id],
            ),
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
      out.addAll(kit.extras(values, field.key));

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
    _SectionAssets assets,
  ) {
    final blob = assets.blob;
    final stills = assets.stills;
    final values = BibleSectionFieldsConfig.parseValues(contentJson);
    String text(Object? v) => v?.toString().trim() ?? '';
    final out = <pw.Widget>[];
    for (final field in BibleSectionFieldsConfig.parse(
      contentJson,
      BibleSectionId.direction,
    )) {
      switch (field.key) {
        case 'narrative':
          final intent = text(data.directionNarrativeIntent);
          if (intent.isNotEmpty) out.add(kit.textPoint(field.label, intent));
          final tags = [
            if (blob['emotionTags'] is List)
              for (final t in blob['emotionTags'] as List) text(t),
          ].where((t) => t.isNotEmpty).toList();
          if (tags.isNotEmpty) out.add(kit.tagRow(tags));
        case DirectionPoints.tone:
          final cards = DirectionPoints.toneCards(
            values,
            blob,
            legacyTone: data.tone,
          ).where((card) => !card.isEmpty).toList();
          if (cards.isNotEmpty) out.add(kit.cardsPoint(field.label, cards));
        case DirectionPoints.strategies:
          // Un pilar sin desarrollar es una invitación a escribir: no sale.
          final pillars = [
            for (final card in DirectionPoints.strategyCards(
              values,
              blob,
              camera: data.cameraPhilosophy,
              staging: data.stagingApproach,
              pointOfView: data.pointOfView,
            ))
              if (card.body.trim().isNotEmpty || card.imageIds.isNotEmpty) card,
          ];
          if (pillars.isNotEmpty) {
            out.add(kit.cardsPoint(field.label, pillars, columns: true));
          }
        case DirectionPoints.acts:
          final acts = kit.actsPointOf(
            field.label,
            DirectionPoints.actsValue(values, blob),
          );
          if (acts != null) out.add(acts);
        case DirectionPoints.transitions:
          final cards = DirectionPoints.transitionCards(
            values,
            blob,
          ).where((card) => !card.isEmpty).toList();
          if (cards.isNotEmpty) out.add(kit.cardsPoint(field.label, cards));
        case 'references':
          final references = assets.references;
          if (references.isNotEmpty || stills != null) {
            out.add(kit.label(field.label));
            out.add(pw.SizedBox(height: 6));
            if (stills != null) {
              out.add(stills);
              out.add(pw.SizedBox(height: 10));
            }
            final linked = assets.imagesFor(references);
            for (var i = 0; i < references.length; i++) {
              final reference = references[i];
              out.add(
                kit.referencePoint(
                  image: linked[i],
                  kicker: [
                    reference.kind,
                    reference.work,
                  ].where((e) => e.isNotEmpty).join(' · '),
                  title: reference.title,
                  sections: [
                    ('Por qué esta referencia', reference.why),
                    ('Para qué en la película', reference.purpose),
                    ('Momento', reference.scene),
                  ],
                ),
              );
            }
          }
        default:
          final point = kit.point(field, values[field.key]);
          if (point != null) out.add(point);
      }
      // Complementos del punto: imágenes y texto.
      out.addAll(
        kit.extras(
          values,
          field.key,
          legacy: assets.pointImages[field.key] ?? const [],
        ),
      );
    }
    return out;
  }

  /// Cámara y sensor: los puntos de la sección en el orden del usuario.
  static List<pw.Widget> _cameraContent(
    VisualBibleData data,
    String? contentJson,
    BiblePdfKit kit,
    _SectionAssets assets, {
    String? primaryCameraLabel,
  }) {
    final blob = CameraPilotResolve.parseBlob(
      BibleSectionExportReader.withoutUserPoints(
        contentJson,
        BibleSectionId.camera,
      ),
    );
    final values = BibleSectionFieldsConfig.parseValues(contentJson);
    final equipment = CameraPoints.equipmentItems(
      values,
      legacyCameraId: data.primaryCameraId,
      legacyCameraName: primaryCameraLabel,
    ).where((item) => !item.isEmpty).toList();
    final facts = equipment.isEmpty
        ? const <String, String>{}
        : equipment.first.facts;

    final out = <pw.Widget>[];
    void add(pw.Widget? point) {
      if (point != null) out.add(point);
    }

    for (final field in BibleSectionFieldsConfig.parse(
      contentJson,
      BibleSectionId.camera,
    )) {
      switch (field.key) {
        case 'narrative':
          final intent = data.cameraNarrativeIntent?.trim() ?? '';
          if (intent.isNotEmpty) out.add(kit.textPoint(field.label, intent));
        case CameraPoints.equipment:
          if (equipment.isNotEmpty) {
            out.add(kit.equipmentPoint(field.label, equipment));
          }
        case CameraPoints.body:
          add(
            kit.textSpecsPoint(
              field.label,
              CameraPoints.withFacts(
                CameraPoints.bodyValue(values, blob, nativeIso: data.nativeIso),
                facts,
              ),
            ),
          );
        case CameraPoints.recording:
          add(
            kit.textSpecsPoint(
              field.label,
              CameraPoints.recordingValue(
                values,
                blob,
                captureResolution: CameraPilotResolve.captureResolution(
                  blob,
                  data,
                ),
                codec: data.codec ?? data.recordingFormat,
                colorScience: data.colorScienceNotes,
                frameRate: data.frameRateNotes,
              ),
            ),
          );
        case CameraPoints.matrix:
          final table = CameraPoints.matrixValue(values);
          if (!table.isEmpty) out.add(kit.tablePoint(field.label, table));
        case CameraPoints.colorPipeline:
          add(
            kit.textSpecsPoint(
              field.label,
              CameraPoints.colorPipelineValue(
                values,
                blob,
                showLut: data.creativeLutName,
              ),
            ),
          );
        case CameraPoints.accessories:
          final table = CameraPoints.accessoriesValue(values, blob);
          if (!table.isEmpty) out.add(kit.tablePoint(field.label, table));
        case CameraPoints.dataFlow:
          final cards = CameraPoints.dataFlowCards(
            values,
            blob,
            workflowPipeline: data.workflowPipeline,
          ).where((card) => !card.isEmpty).toList();
          if (cards.isNotEmpty) out.add(kit.cardsPoint(field.label, cards));
        case CameraPoints.philosophy:
          add(
            kit.textSpecsPoint(
              field.label,
              CameraPoints.philosophyValue(
                values,
                philosophy: data.cameraPhilosophy,
                movementStyle: data.movementStyle,
              ),
            ),
          );
        case CameraPoints.behavior:
          final cards = CameraPoints.behaviorCards(
            values,
            philosophy: data.cameraPhilosophy,
            movementStyle: data.movementStyle,
            legacyMovements: data.cameraMovements,
          ).where((card) => !card.isEmpty).toList();
          if (cards.isNotEmpty) out.add(kit.cardsPoint(field.label, cards));
        case CameraPoints.movements:
          final cards = CameraPoints.movementCards(
            values,
            data.cameraMovements,
          ).where((card) => !card.isEmpty).toList();
          if (cards.isNotEmpty) {
            out.add(kit.cardsPoint(field.label, cards, columns: true));
          }
        case 'references' || 'specsReference':
          final stills = assets.stills;
          if (stills != null && field.key == 'references') {
            out.add(kit.label(field.label));
            out.add(pw.SizedBox(height: 6));
            out.add(stills);
            out.add(pw.SizedBox(height: 10));
          }
        default:
          add(kit.point(field, values[field.key]));
      }
      out.addAll(
        kit.extras(
          values,
          field.key,
          legacy: assets.pointImages[field.key] ?? const [],
        ),
      );
    }
    return out;
  }

  /// Óptica: los puntos de la sección en el orden del usuario.
  static List<pw.Widget> _opticsContent(
    VisualBibleData data,
    String? contentJson,
    BiblePdfKit kit,
    _SectionAssets assets,
  ) {
    final config = OpticsPoints.config(data.opticsConfigJson);
    final values = BibleSectionFieldsConfig.parseValues(contentJson);
    final out = <pw.Widget>[];
    void add(pw.Widget? point) {
      if (point != null) out.add(point);
    }

    for (final field in BibleSectionFieldsConfig.parse(
      contentJson,
      BibleSectionId.optics,
    )) {
      switch (field.key) {
        case 'narrative':
          final intent = data.opticsNarrativeIntent?.trim() ?? '';
          if (intent.isNotEmpty) out.add(kit.textPoint(field.label, intent));
        case OpticsPoints.kit:
          final items = OpticsPoints.kitItems(
            values,
            config,
            legacyLensId: data.primaryLensId,
          ).where((item) => !item.isEmpty).toList();
          if (items.isNotEmpty) {
            out.add(kit.equipmentPoint(field.label, items, feminine: false));
          }
        case OpticsPoints.philosophy:
          add(
            kit.textSpecsPoint(
              field.label,
              OpticsPoints.philosophyValue(
                values,
                config,
                lensPhilosophy: data.lensPhilosophy,
              ),
            ),
          );
        case OpticsPoints.character:
          final cards = OpticsPoints.characterCards(values, config)
              .where((c) => c.body.trim().isNotEmpty || c.imageIds.isNotEmpty)
              .toList();
          if (cards.isNotEmpty) {
            out.add(kit.cardsPoint(field.label, cards, columns: true));
          }
        case OpticsPoints.focals:
          final table = OpticsPoints.focalsValue(
            values,
            config,
            legacyFocals: data.primaryFocalLengths,
          );
          if (!table.isEmpty) out.add(kit.tablePoint(field.label, table));
        case OpticsPoints.filtration:
          final meters = OpticsPoints.filtrationMeters(
            values,
            config,
            filtrationNotes: data.filtrationNotes,
          ).where((m) => !m.isEmpty || m.note.trim().isNotEmpty).toList();
          if (meters.isNotEmpty) out.add(kit.metersPoint(field.label, meters));
        case OpticsPoints.maintenance:
          final table = OpticsPoints.maintenanceValue(values, config);
          if (!table.isEmpty) out.add(kit.tablePoint(field.label, table));
        case 'references':
          final stills = assets.stills;
          if (stills != null) {
            out.add(kit.label(field.label));
            out.add(pw.SizedBox(height: 6));
            out.add(stills);
            out.add(pw.SizedBox(height: 10));
          }
        default:
          add(kit.point(field, values[field.key]));
      }
      out.addAll(
        kit.extras(
          values,
          field.key,
          legacy: assets.pointImages[field.key] ?? const [],
        ),
      );
    }
    return out;
  }

  /// Exposición: los puntos de la sección en el orden del usuario.
  static List<pw.Widget> _exposureContent(
    VisualBibleData data,
    String? contentJson,
    List<ExposureBlockModel> exposureBlocks,
    BiblePdfKit kit,
    _SectionAssets assets,
  ) {
    final blob = ExposurePoints.blob(contentJson);
    final values = BibleSectionFieldsConfig.parseValues(contentJson);
    final out = <pw.Widget>[];
    void add(pw.Widget? point) {
      if (point != null) out.add(point);
    }

    for (final field in BibleSectionFieldsConfig.parse(
      contentJson,
      BibleSectionId.exposure,
    )) {
      switch (field.key) {
        case 'narrative':
          final intent = ExposurePoints.narrative(
            blob,
            data.exposureNarrativeIntent,
          );
          if (intent.isNotEmpty) out.add(kit.textPoint(field.label, intent));
          final tags = ExposurePoints.intentTags(blob);
          if (tags.isNotEmpty) out.add(kit.tagRow(tags));
        case ExposurePoints.global:
          final value = ExposurePoints.globalValue(
            values,
            blob,
            defaultTStop: data.defaultTStop,
            ndNotes: data.ndNotes,
            highlightBehavior: data.highlightBehavior,
            shadowBehavior: data.shadowBehavior,
          );
          add(
            kit.textSpecsPoint(
              field.label,
              // El ISO nativo de la cámara, si no se ha escrito otro.
              value.copyWith(
                rows: [
                  for (final (label, text) in value.rows)
                    (
                      label,
                      text.trim().isEmpty &&
                              label == ExposurePoints.rowIso &&
                              data.nativeIso != null
                          ? '${data.nativeIso}'
                          : text,
                    ),
                ],
              ),
            ),
          );
        case ExposurePoints.chain:
          final cards = ExposurePoints.chainCards(values, blob)
              .where((c) => c.body.trim().isNotEmpty || c.imageIds.isNotEmpty)
              .toList();
          if (cards.isNotEmpty) {
            out.add(kit.cardsPoint(field.label, cards, columns: true));
          }
        case ExposurePoints.signal:
          final meters = ExposurePoints.signalMeters(
            values,
            blob,
          ).where((m) => m.value.trim().isNotEmpty).toList();
          if (meters.isNotEmpty) out.add(kit.metersPoint(field.label, meters));
        case ExposurePoints.blocks:
          final table = ExposurePoints.blocksValue(values, [
            for (final b in exposureBlocks)
              (
                name: b.blockName,
                intent: b.narrativeIntent,
                keyFill: b.keyFillRatio,
                highlights: b.highlightStrategy,
                shadows: b.shadowStrategy,
              ),
          ]);
          if (!table.isEmpty) out.add(kit.tablePoint(field.label, table));
        case ExposurePoints.byLocation:
          final table = ExposurePoints.byLocationValue(values, blob);
          if (!table.isEmpty) out.add(kit.tablePoint(field.label, table));
        case 'references':
          final stills = assets.stills;
          if (stills != null) {
            out.add(kit.label(field.label));
            out.add(pw.SizedBox(height: 6));
            out.add(stills);
            out.add(pw.SizedBox(height: 10));
          }
        default:
          add(kit.point(field, values[field.key]));
      }
      out.addAll(
        kit.extras(
          values,
          field.key,
          legacy: assets.pointImages[field.key] ?? const [],
        ),
      );
    }
    return out;
  }

  /// Color e imagen: los puntos de la sección en el orden del usuario.
  static List<pw.Widget> _colorContent(
    VisualBibleData data,
    String? contentJson,
    List<ColorBlockModel> colorBlocks,
    BiblePdfKit kit,
    _SectionAssets assets,
  ) {
    final blob = ColorPoints.blob(contentJson);
    final names = ColorPoints.swatchNames(blob);
    final values = BibleSectionFieldsConfig.parseValues(contentJson);
    final out = <pw.Widget>[];
    void add(pw.Widget? point) {
      if (point != null) out.add(point);
    }

    List<(String, String)> swatches(List<String> stored) => [
      for (final c in ColorPoints.swatches(stored, names: names))
        (c.hex, c.name),
    ];

    for (final field in BibleSectionFieldsConfig.parse(
      contentJson,
      BibleSectionId.colorImage,
    )) {
      switch (field.key) {
        case 'narrative':
          final intent = data.colorNarrativeIntent?.trim() ?? '';
          if (intent.isNotEmpty) out.add(kit.textPoint(field.label, intent));
        case ColorPoints.lut:
          add(
            kit.textSpecsPoint(
              field.label,
              ColorPoints.lutValue(
                values,
                blob,
                workingLut: data.workingLutName,
                showLut: data.creativeLutName,
              ),
            ),
          );
        case ColorPoints.baseTemp:
          final meters = ColorPoints.baseTempMeters(
            values,
            blob,
            firstBlockKelvin: colorBlocks.firstOrNull?.colorTempKelvin,
          ).where((m) => m.value.trim().isNotEmpty).toList();
          if (meters.isNotEmpty) out.add(kit.metersPoint(field.label, meters));
        case ColorPoints.blocks:
          final filled = [
            for (final block in colorBlocks)
              if (block.blockName.trim().isNotEmpty ||
                  block.dominantColors.isNotEmpty ||
                  block.accentColors.isNotEmpty ||
                  block.prohibitedColors.isNotEmpty ||
                  (block.emotionalIntent ?? '').trim().isNotEmpty)
                block,
          ];
          if (filled.isNotEmpty) {
            out.add(kit.label(field.label));
            out.add(pw.SizedBox(height: 6));
          }
          for (final block in filled) {
            final title = [
              block.blockName.trim(),
              if (block.colorTempKelvin != null) '${block.colorTempKelvin} K',
            ].where((e) => e.isNotEmpty).join(' · ');
            final intent = (block.emotionalIntent ?? '').trim();
            if (title.isNotEmpty || intent.isNotEmpty) {
              out.add(kit.textPoint(title, intent));
            }
            for (final (name, colors) in [
              ('Dominantes', swatches(block.dominantColors)),
              ('Acentos', swatches(block.accentColors)),
              ('Se evitan', swatches(block.prohibitedColors)),
            ]) {
              if (colors.isNotEmpty) out.add(kit.swatchRow(name, colors));
            }
          }
        case 'references':
          final stills = assets.stills;
          if (stills != null) {
            out.add(kit.label(field.label));
            out.add(pw.SizedBox(height: 6));
            out.add(stills);
            out.add(pw.SizedBox(height: 10));
          }
        default:
          add(kit.point(field, values[field.key]));
      }
      out.addAll(
        kit.extras(
          values,
          field.key,
          legacy: assets.pointImages[field.key] ?? const [],
        ),
      );
    }
    return out;
  }

  /// Textura: los puntos de la sección en el orden del usuario.
  static List<pw.Widget> _textureContent(
    VisualBibleData data,
    String? contentJson,
    BiblePdfKit kit,
    _SectionAssets assets,
  ) {
    final blob = TexturePoints.blob(contentJson);
    final values = BibleSectionFieldsConfig.parseValues(contentJson);
    final out = <pw.Widget>[];
    void add(pw.Widget? point) {
      if (point != null) out.add(point);
    }

    for (final field in BibleSectionFieldsConfig.parse(
      contentJson,
      BibleSectionId.texture,
    )) {
      switch (field.key) {
        case 'narrative':
          final intent = data.textureNarrativeIntent?.trim() ?? '';
          if (intent.isNotEmpty) out.add(kit.textPoint(field.label, intent));
        case TexturePoints.comparison:
          add(
            kit.point(
              BibleSectionField(
                key: field.key,
                label: field.label,
                type: BibleSectionFieldType.gallery,
              ),
              values[field.key],
            ),
          );
        case TexturePoints.grain:
          add(
            kit.textSpecsPoint(
              field.label,
              TexturePoints.grainValue(
                values,
                blob,
                grainLevel: data.grainLevel,
              ),
            ),
          );
        case TexturePoints.diffusion:
          final meters = TexturePoints.diffusionMeters(
            values,
            blob,
            diffusionNotes: data.diffusionNotes,
          ).where((m) => m.label.trim().isNotEmpty).toList();
          if (meters.isNotEmpty) out.add(kit.metersPoint(field.label, meters));
        case TexturePoints.noise:
          add(
            kit.textSpecsPoint(
              field.label,
              TexturePoints.noiseValue(
                values,
                blob,
                highlightBehavior: data.highlightBehavior,
                shadowBehavior: data.shadowBehavior,
              ),
            ),
          );
        case 'references':
          final stills = assets.stills;
          if (stills != null) {
            out.add(kit.label(field.label));
            out.add(pw.SizedBox(height: 6));
            out.add(stills);
            out.add(pw.SizedBox(height: 10));
          }
        default:
          add(kit.point(field, values[field.key]));
      }
      out.addAll(
        kit.extras(
          values,
          field.key,
          legacy: assets.pointImages[field.key] ?? const [],
        ),
      );
    }
    return out;
  }

  /// Workflow: los puntos de la sección en el orden del usuario.
  static List<pw.Widget> _workflowContent(
    VisualBibleData data,
    String? contentJson,
    BiblePdfKit kit,
    _SectionAssets assets,
  ) {
    final values = BibleSectionFieldsConfig.parseValues(contentJson);
    final out = <pw.Widget>[];
    void add(pw.Widget? point) {
      if (point != null) out.add(point);
    }

    for (final field in BibleSectionFieldsConfig.parse(
      contentJson,
      BibleSectionId.workflow,
    )) {
      switch (field.key) {
        case 'narrative':
          final intent = values['narrative']?.trim() ?? '';
          if (intent.isNotEmpty) out.add(kit.textPoint(field.label, intent));
        case WorkflowPoints.steps:
          final table = WorkflowPoints.stepsValue(values);
          // Una tabla con solo los nombres de los pasos está sin rellenar.
          if (WorkflowPoints.stepsFilled(table)) {
            out.add(kit.tablePoint(field.label, table));
          }
        case WorkflowPoints.team:
          add(kit.textSpecsPoint(field.label, WorkflowPoints.teamValue(values)));
        case WorkflowPoints.delivery:
          add(
            kit.textSpecsPoint(
              field.label,
              WorkflowPoints.withFacts(
                WorkflowPoints.deliveryValue(
                  values,
                  deliveryColorSpace: data.deliveryColorSpace,
                  resolutionNotes: data.resolutionNotes,
                  workflowPipeline: data.workflowPipeline,
                ),
                WorkflowPoints.fromCamera(
                  codec: data.codec,
                  frameRate: data.frameRateNotes,
                ),
              ),
            ),
          );
        case 'references':
          final stills = assets.stills;
          if (stills != null) {
            out.add(kit.label(field.label));
            out.add(pw.SizedBox(height: 6));
            out.add(stills);
            out.add(pw.SizedBox(height: 10));
          }
        default:
          add(kit.point(field, values[field.key]));
      }
      out.addAll(
        kit.extras(
          values,
          field.key,
          legacy: assets.pointImages[field.key] ?? const [],
        ),
      );
    }
    return out;
  }

  /// Imágenes del moodboard que usa una ficha de Iluminación.
  static Set<int> _lightingCardImageIds(NarrativeCardModel card) {
    final page = LightingCardPage.of(
      kind: card.kind,
      body: card.body,
      meta: card.meta,
    );
    return {
      if (card.coverMoodboardImageId != null) card.coverMoodboardImageId!,
      for (final value in page.values.values)
        ...BibleSectionExportReader.imageIdsInValue(value),
    };
  }

  /// Gelatinas de corrección del motor de luz, para la receta de color.
  static List<CorrectionGel> _correctionGels() => [
    for (final m in LightModifier.ofKind(ModifierKind.correction))
      if (m.miredShift != 0)
        CorrectionGel(m.name, m.miredShift, m.transmission),
  ];

  /// Iluminación: visión general, métricas del proyecto y, después, cada
  /// ficha (ideas de luz, referencias de cine y luz por localización) con
  /// sus puntos en su orden.
  static List<pw.Widget> _lightingContent(
    VisualBibleData data,
    String? contentJson,
    List<LightingSetupModel> lightingSetups,
    List<NarrativeCardModel> cards,
    BiblePdfKit kit,
    ({pw.Font regular, pw.Font bold}) fonts,
  ) {
    final values = BibleSectionFieldsConfig.parseValues(contentJson);
    final lighting = BibleLightingData.decode(values['lightingData']);
    final gels = _correctionGels();
    final out = <pw.Widget>[];

    final story = (data.lightingPhilosophy ?? '').trim();
    if (story.isNotEmpty) out.add(kit.textPoint('Tratamiento de luz', story));
    final global = lighting.containsKey('metrics')
        ? LightingMetrics.fromJson(lighting['metrics'])
        : LightingMetrics.fromLegacy(lighting);
    final globalPoint = kit.lightMetricsPoint(
      'Luz: color y contraste',
      global,
      gels: gels,
    );
    if (globalPoint != null) out.add(globalPoint);
    final feel = (lighting['temperatureNote'] ?? '').toString().trim();
    if (feel.isNotEmpty) out.add(kit.textPoint('Cómo se siente', feel));
    final sources = BibleLightingData.fixtureTypeLabels(lighting);
    if (sources.isNotEmpty) {
      out.add(kit.label('Fuentes principales'));
      out.add(pw.SizedBox(height: 6));
      out.add(kit.tagRow(sources));
    }

    for (final (kind, heading) in const [
      (NarrativeCardKind.style, 'Ideas de luz'),
      (NarrativeCardKind.filmRef, 'Referencias de cine'),
      (NarrativeCardKind.locationLight, 'Luz por localización'),
    ]) {
      final group = <List<pw.Widget>>[];
      for (final card in cards.where((c) => c.kind == kind)) {
        final page = LightingCardPage.of(
          kind: card.kind,
          body: card.body,
          meta: card.meta,
        );
        final points = <pw.Widget>[];
        for (final field in page.fields) {
          final raw = page.values[field.key];
          final point = field.widget == 'light_metrics'
              ? kit.lightMetricsPoint(
                  field.label,
                  LightingMetrics.fromJson(raw),
                  gels: gels,
                )
              : kit.point(field, raw);
          if (point != null) points.add(point);
          points.addAll(kit.extras(page.values, field.key));
        }
        // Una ficha sin nada escrito no ocupa sitio en el documento.
        if (points.isEmpty) continue;
        group.add([
          pw.Container(
            margin: const pw.EdgeInsets.only(top: 6, bottom: 8),
            padding: const pw.EdgeInsets.only(bottom: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: BiblePdfTokens.rule, width: 0.8),
              ),
            ),
            child: pw.Text(
              card.title,
              style: pw.TextStyle(
                font: fonts.bold,
                fontSize: 14,
                color: BiblePdfTokens.ink,
              ),
            ),
          ),
          ...points,
        ]);
      }
      if (group.isEmpty) continue;
      out.add(pw.SizedBox(height: 10));
      out.add(
        pw.Text(
          heading.toUpperCase(),
          style: pw.TextStyle(
            font: fonts.bold,
            fontSize: 10,
            letterSpacing: 1.2,
            color: BiblePdfTokens.accent,
          ),
        ),
      );
      for (final cardWidgets in group) {
        out.addAll(cardWidgets);
      }
    }

    // Puntos que el usuario añadió a la pantalla.
    for (final point in BibleSectionExportReader.userPoints(
      contentJson,
      BibleSectionId.lighting,
    )) {
      final widget = kit.point(point.field, point.value);
      if (widget != null) out.add(widget);
      out.addAll(kit.extras(values, point.field.key));
    }

    if (lightingSetups.isNotEmpty) {
      out.add(pw.SizedBox(height: 10));
      out.add(kit.label('Esquemas de luz'));
      out.add(pw.SizedBox(height: 4));
      for (final s in lightingSetups) {
        out.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 6),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Text(
                    [
                      s.setupName,
                      if ((s.narrativeNote ?? '').trim().isNotEmpty)
                        s.narrativeNote!.trim(),
                    ].join(': '),
                    style: pw.TextStyle(font: fonts.regular, fontSize: 10),
                  ),
                ),
                if (s.diagramJson != '[]') ...[
                  pw.SizedBox(width: 8),
                  _lightingDiagram(s.diagramJson),
                ],
              ],
            ),
          ),
        );
      }
    }
    return out;
  }

  /// Concepto: los puntos de la sección en el orden del usuario.
  static List<pw.Widget> _conceptContent(
    VisualBibleData data,
    String? contentJson,
    List<ColorBlockModel> colorBlocks,
    BiblePdfKit kit,
    _SectionAssets assets,
  ) {
    final blob = assets.blob;
    final stills = assets.stills;
    final values = BibleSectionFieldsConfig.parseValues(contentJson);
    String text(Object? v) => v?.toString().trim() ?? '';
    Map<String, String> strings(Object? raw) => {
      if (raw is Map)
        for (final e in raw.entries) text(e.key): text(e.value),
    };

    final out = <pw.Widget>[];
    for (final field in BibleSectionFieldsConfig.parse(
      contentJson,
      BibleSectionId.concept,
    )) {
      switch (field.key) {
        case 'narrative':
          final intent = text(
            data.conceptNarrativeIntent?.trim().isNotEmpty == true
                ? data.conceptNarrativeIntent
                : data.visualConcept,
          );
          if (intent.isNotEmpty) out.add(kit.textPoint(field.label, intent));
          final tags = ConceptPoints.atmosphereTags(blob);
          if (tags.isNotEmpty) out.add(kit.tagRow(tags));
        case ConceptPoints.palette:
          final point = kit.point(
            BibleSectionField(
              key: field.key,
              label: field.label,
              type: BibleSectionFieldType.palette,
              widget: 'palette_master',
            ),
            ConceptPoints.paletteValue(values, blob).encode(),
          );
          if (point != null) out.add(point);
        case ConceptPoints.symbolism:
          final point = kit.point(
            BibleSectionField(
              key: field.key,
              label: field.label,
              type: BibleSectionFieldType.palette,
              widget: 'palette_symbolism',
            ),
            ConceptPoints.symbolismValue(values, blob).encode(),
          );
          if (point != null) out.add(point);
        case ConceptPoints.light:
          final point = kit.textSpecsPoint(
            field.label,
            ConceptPoints.lightValue(
              values,
              blob,
              philosophy: data.lightingPhilosophy,
              contrast: data.contrastStyle,
            ),
          );
          if (point != null) out.add(point);
        case ConceptPoints.shadows:
          final shadows = ConceptPoints.shadowsText(values, blob);
          if (shadows.isNotEmpty) out.add(kit.textPoint(field.label, shadows));
        case ConceptPoints.composition:
          final point = kit.textSpecsPoint(
            field.label,
            ConceptPoints.compositionValue(values, blob),
          );
          if (point != null) out.add(point);
        case ConceptPoints.acts:
          final acts = kit.actsPointOf(
            field.label,
            ConceptPoints.actsValue(values, blob),
          );
          if (acts != null) out.add(acts);
        case ConceptPoints.actComposition:
          final point = kit.textSpecsPoint(
            field.label,
            values.containsKey(ConceptPoints.actComposition)
                ? BibleTextSpecsValue.decode(
                    values[ConceptPoints.actComposition],
                  )
                : BibleTextSpecsValue(
                    rows: ConceptPoints.actCompositionRows(blob),
                  ),
          );
          if (point != null) out.add(point);
        case ConceptPoints.keyFrame:
          final (title, tech) = ConceptPoints.keyFrameOf(blob);
          final point = kit.textSpecsPoint(
            field.label,
            values.containsKey(ConceptPoints.keyFrame)
                ? BibleTextSpecsValue.decode(values[ConceptPoints.keyFrame])
                : BibleTextSpecsValue(
                    text: [title, tech].where((e) => e.isNotEmpty).join('\n'),
                  ),
          );
          if (point != null) out.add(point);
        case 'references':
          final references = assets.references;
          if (references.isNotEmpty || stills != null) {
            out.add(kit.label(field.label));
            out.add(pw.SizedBox(height: 6));
            if (stills != null) {
              out.add(stills);
              out.add(pw.SizedBox(height: 10));
            }
            final linked = assets.imagesFor(references);
            for (var i = 0; i < references.length; i++) {
              final reference = references[i];
              out.add(
                kit.referencePoint(
                  image: linked[i],
                  kicker: [
                    reference.kind,
                    reference.work,
                  ].where((e) => e.isNotEmpty).join(' · '),
                  title: reference.title,
                  sections: [
                    ('Por qué nos gusta', reference.why),
                    ('Qué llevamos a la película', reference.purpose),
                    ('Momento', reference.scene),
                  ],
                ),
              );
            }
          }
        default:
          final point = kit.point(field, values[field.key]);
          if (point != null) out.add(point);
      }
      // Complementos del punto: imágenes y texto.
      out.addAll(
        kit.extras(
          values,
          field.key,
          legacy: assets.pointImages[field.key] ?? const [],
        ),
      );
    }
    return out;
  }

  /// Carga lo que Dirección y Concepto necesitan del moodboard: imágenes de
  /// cada punto, imagen de cada referencia y los stills sin ficha.
  /// Imágenes de los puntos del usuario del documento en curso.
  static Map<int, pw.MemoryImage> _userPointImages = const {};

  /// Imagen de cabecera de cada pantalla del documento en curso.
  static Map<String, pw.MemoryImage> _heroes = const {};

  /// Color de cada pantalla que lo tenga, y nombre de las renombradas.
  static Map<String, PdfColor> _heroColors = const {};
  static Map<String, String> _renamed = const {};

  static Future<Map<String, pw.MemoryImage>> _loadHeroes(
    Map<String, String?> sectionContentJsonById,
    List<MoodboardImageModel> moodboard,
  ) async {
    final byId = {for (final image in moodboard) image.id: image};
    final heroes = <String, pw.MemoryImage>{};
    for (final entry in sectionContentJsonById.entries) {
      final image =
          byId[BibleScreenHeroValue.read(
            BibleSectionFieldsConfig.parseValues(entry.value),
          ).imageId];
      if (image == null) continue;
      final bytes = await PdfSafeImage.loadFromPathMaxEdge(image.imagePath);
      if (bytes != null) heroes[entry.key] = pw.MemoryImage(bytes);
    }
    return heroes;
  }

  /// Los actos del proyecto del documento en curso.
  static List<BibleCard> _sharedActs = const [];

  static BiblePdfKit _kit(({pw.Font regular, pw.Font bold}) fonts) =>
      BiblePdfKit(
        regular: fonts.regular,
        bold: fonts.bold,
        images: _userPointImages,
        sharedActs: _sharedActs,
      );

  /// Carga una vez las imágenes que usan los puntos del usuario (actos,
  /// paletas y tiras de imágenes) de todas las pantallas.
  static Future<Map<int, pw.MemoryImage>> _loadUserPointImages(
    Map<String, String?> sectionContentJsonById,
    List<MoodboardImageModel> moodboard, {
    Set<int> extra = const {},
  }) async {
    final ids = <int>{
      for (final entry in sectionContentJsonById.entries)
        ...BibleSectionExportReader.userPointImageIds(entry.value, entry.key),
      ...extra,
    };
    if (ids.isEmpty) return const {};
    final byId = {for (final image in moodboard) image.id: image};
    final loaded = <int, pw.MemoryImage>{};
    for (final id in ids) {
      final image = byId[id];
      if (image == null) continue;
      final bytes = await PdfSafeImage.loadFromPathMaxEdge(image.imagePath);
      if (bytes != null) loaded[id] = pw.MemoryImage(bytes);
    }
    return loaded;
  }

  static Future<_SectionAssets> _loadSectionAssets(
    String sectionId,
    String? contentJson,
    List<MoodboardImageModel> moodboard,
    MoodboardExportLayout layout,
    ({pw.Font regular, pw.Font bold}) fonts,
  ) async {
    final blob = BibleSectionExportReader.parseCustomBlob(
      BibleSectionExportReader.withoutUserPoints(contentJson, sectionId),
      sectionId,
    );
    final references = BibleReference.listFrom(
      blob[sectionId == BibleSectionId.concept
          ? 'keyReferences'
          : 'refsMetadata'],
    ).where((r) => !r.isEmpty).toList();
    final byId = {for (final image in moodboard) image.id: image};
    final sectionImages = MoodboardExportGrouper.imagesForSection(
      moodboard,
      sectionId,
    );
    final sectionIds = sectionImages.map((i) => i.id).toList();
    final linkedIds = [
      for (var i = 0; i < references.length; i++)
        references[i].legacyPairing
            ? (i < sectionIds.length ? sectionIds[i] : null)
            : references[i].imageId,
    ];

    final cache = <int, pw.MemoryImage?>{};
    Future<pw.MemoryImage?> load(int? id) async {
      if (id == null || byId[id] == null) return null;
      if (cache.containsKey(id)) return cache[id];
      final bytes = await PdfSafeImage.loadFromPathMaxEdge(byId[id]!.imagePath);
      return cache[id] = bytes == null ? null : pw.MemoryImage(bytes);
    }

    final referenceImages = <pw.MemoryImage?>[];
    for (final id in linkedIds) {
      referenceImages.add(await load(id));
    }
    final pointImages = <String, List<pw.MemoryImage>>{};
    final rawPoints = blob['pointImages'];
    if (rawPoints is Map) {
      for (final entry in rawPoints.entries) {
        final images = <pw.MemoryImage>[];
        if (entry.value is List) {
          for (final id in entry.value as List) {
            final image = await load(id is num ? id.toInt() : null);
            if (image != null) images.add(image);
          }
        }
        pointImages[entry.key.toString()] = images;
      }
    }
    final unlinked = [
      for (final image in sectionImages)
        if (!linkedIds.contains(image.id)) image,
    ];
    return _SectionAssets(
      blob: blob,
      references: references,
      referenceImages: referenceImages,
      pointImages: pointImages,
      stills: _stillTiles(await _loadMoodboardCells(unlinked, layout), fonts),
    );
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
    final kit = _kit(fonts);
    final contentJson = sectionContentJsonById[sectionId];
    final blobRows = [
      for (final row in BibleSectionExportReader.blobRows(
        contentJson,
        sectionId,
      ))
        (row.label, row.value as String?),
    ];
    final values = BibleSectionFieldsConfig.parseValues(contentJson);
    final userKeys = <String>{};
    final points = <pw.Widget>[
      for (final point in BibleSectionExportReader.userPoints(
        contentJson,
        sectionId,
      )) ...[
        if (userKeys.add(point.field.key))
          ?kit.point(point.field, point.value),
        ...kit.extras(values, point.field.key),
      ],
      // Complementos de los puntos propios de la pantalla, con su rótulo.
      for (final field in BibleSectionFieldsConfig.parse(contentJson, sectionId))
        if (!userKeys.contains(field.key))
          ...kit.extras(values, field.key, label: field.label),
    ];
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
    String? sectionId,
    required pw.Font fontBold,
    required pw.Font font,
    required pw.Widget content,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(40),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _sectionHeader(title, fontBold, sectionId: sectionId),
          pw.SizedBox(height: 24),
          pw.Expanded(child: content),
        ],
      ),
    );
  }

  static pw.Widget _sectionHeader(
    String title,
    pw.Font fontBold, {
    String? sectionId,
  }) => BiblePdfKit(
    regular: fontBold,
    bold: fontBold,
  ).sectionHeader(
    _renamed[sectionId]?.toUpperCase() ?? title,
    image: _heroes[sectionId],
    accent: _heroColors[sectionId],
  );

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

/// Recursos de moodboard ya cargados para el PDF de una sección.
class _SectionAssets {
  final Map<String, dynamic> blob;
  final List<BibleReference> references;
  final List<pw.MemoryImage?> referenceImages;
  final Map<String, List<pw.MemoryImage>> pointImages;

  /// Stills de la sección que no pertenecen a ninguna ficha.
  final pw.Widget? stills;

  const _SectionAssets({
    required this.blob,
    required this.references,
    required this.referenceImages,
    required this.pointImages,
    required this.stills,
  });

  List<pw.MemoryImage?> imagesFor(List<BibleReference> list) => [
    for (var i = 0; i < list.length; i++)
      i < referenceImages.length ? referenceImages[i] : null,
  ];
}
