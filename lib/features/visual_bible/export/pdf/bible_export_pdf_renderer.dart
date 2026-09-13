import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/pdf_export_fonts.dart';
import '../../../../core/utils/pdf_safe_image.dart';
import 'moodboard_pdf_tiles.dart';
import '../../../../shared/annotations/annotation_document.dart';
import '../../../../shared/annotations/annotation_pdf_renderer.dart';
import '../../bible_block_catalog.dart';
import '../../v2/bible_block_schemas.dart';
import '../../v2/layout/bible_grid_layout.dart';
import '../../v2/model/bible_block.dart';
import '../../v2/model/bible_image_content.dart';
import '../model/bible_export_composition.dart';

typedef BibleExportImageLoader =
    Future<Uint8List?> Function(String? path, {int maxEdge});

/// Renderer de entrega para el montaje no destructivo de la Biblia.
///
/// Cada [BibleExportPage] produce exactamente una página PDF. Los bloques se
/// dibujan con widgets de `package:pdf`; la tinta se mantiene vectorial y las
/// notas se superponen como post-its.
class BibleExportPdfRenderer {
  BibleExportPdfRenderer({
    AppDatabase? database,
    BibleExportImageLoader imageLoader = PdfSafeImage.loadFromPathMaxEdge,
  }) : _database = database,
       _imageLoader = imageLoader;

  final AppDatabase? _database;
  final BibleExportImageLoader _imageLoader;

  Future<Uint8List> buildBytes(
    BibleExportComposition composition, {
    Map<String, AnnotationDocument>? annotationsByPage,
  }) async {
    final document = await buildDocument(
      composition,
      annotationsByPage: annotationsByPage,
    );
    return document.save();
  }

  Future<pw.Document> buildDocument(
    BibleExportComposition composition, {
    Map<String, AnnotationDocument>? annotationsByPage,
  }) async {
    final fonts = await PdfExportFonts.load();
    final pdf = pw.Document();
    final pages = _orderedPages(composition.pages);
    final annotations =
        annotationsByPage ??
        await _loadAnnotations(composition.projectId, pages);
    final lightingAnnotations = await _loadLightingAnnotations(
      composition.projectId,
      pages,
    );
    final images = await _loadImages(pages);

    for (final page in pages) {
      final format = _pageFormat(page.format);
      final margins = page.margins;
      final contentWidth = format.width - margins.left - margins.right;
      final contentHeight = format.height - margins.top - margins.bottom;
      final pageAnnotations =
          annotations[page.annotationTargetId] ?? const AnnotationDocument();

      pdf.addPage(
        pw.Page(
          pageFormat: format,
          margin: pw.EdgeInsets.fromLTRB(
            margins.left,
            margins.top,
            margins.right,
            margins.bottom,
          ),
          theme: PdfExportFonts.theme(regular: fonts.regular, bold: fonts.bold),
          build: (_) => pw.Stack(
            children: [
              pw.SizedBox(
                width: contentWidth,
                height: contentHeight,
                child: _buildPage(page, images, lightingAnnotations),
              ),
              if (pageAnnotations.strokes.isNotEmpty)
                AnnotationPdfRenderer.build(
                  pageAnnotations,
                  width: contentWidth,
                  height: contentHeight,
                ),
              ..._buildNotes(
                pageAnnotations.notes,
                width: contentWidth,
                height: contentHeight,
              ),
            ],
          ),
        ),
      );
    }
    return pdf;
  }

  Future<Map<String, AnnotationDocument>> _loadAnnotations(
    int projectId,
    List<BibleExportPage> pages,
  ) async {
    final database = _database;
    if (database == null) return const {};
    final result = <String, AnnotationDocument>{};
    for (final page in pages) {
      final row = await database.getProjectAnnotationDocument(
        projectId: projectId,
        targetType: kBibleExportAnnotationTargetType,
        targetId: page.annotationTargetId,
      );
      if (row != null) {
        result[page.annotationTargetId] = AnnotationDocument.decode(
          row.documentJson,
        );
      }
    }
    return result;
  }

  Future<Map<String, Uint8List>> _loadImages(
    List<BibleExportPage> pages,
  ) async {
    final images = <String, Uint8List>{};
    for (final page in pages) {
      for (final block in page.blocks) {
        for (final path in _imagePaths(block)) {
          if (path.isEmpty || images.containsKey(path)) continue;
          final bytes = await _imageLoader(path, maxEdge: 2048);
          if (bytes != null) images[path] = bytes;
        }
      }
    }
    return images;
  }

  Future<Map<int, AnnotationDocument>> _loadLightingAnnotations(
    int projectId,
    List<BibleExportPage> pages,
  ) async {
    final database = _database;
    if (database == null) return const {};
    final setupIds = <int>{
      for (final page in pages)
        for (final block in page.blocks)
          if (block.type == BibleBlockKind.lightingDiagram)
            if ((block.content['setupId'] as num?)?.toInt() case final int id)
              id,
    };
    final result = <int, AnnotationDocument>{};
    for (final setupId in setupIds) {
      final row = await database.getProjectAnnotationDocument(
        projectId: projectId,
        targetType: 'lighting_setup',
        targetId: setupId.toString(),
      );
      if (row != null) {
        result[setupId] = AnnotationDocument.decode(row.documentJson);
      }
    }
    return result;
  }

  Iterable<String> _imagePaths(BibleBlock block) sync* {
    final imageJson = block.content['image'] is Map
        ? Map<String, dynamic>.from(block.content['image'] as Map)
        : block.content;
    final primary = BibleImageContent.fromJson(imageJson).path;
    if (primary != null) yield primary;
    final diagram = block.content['imagePath']?.toString();
    if (diagram != null && diagram.isNotEmpty) yield diagram;

    final candidates =
        block.content['images'] ?? block.content['items'] ?? const [];
    if (candidates is List) {
      for (final candidate in candidates) {
        if (candidate is String) {
          yield candidate;
        } else if (candidate is Map) {
          final path = BibleImageContent.fromJson(
            Map<String, dynamic>.from(candidate),
          ).path;
          if (path != null) yield path;
        }
      }
    }
  }

  pw.Widget _buildPage(
    BibleExportPage page,
    Map<String, Uint8List> images,
    Map<int, AnnotationDocument> lightingAnnotations,
  ) {
    if (page.type == BibleExportPageType.blank) {
      return pw.SizedBox.expand();
    }
    if (page.type == BibleExportPageType.cover) {
      return _buildCover(page, images);
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          page.label,
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey900,
          ),
        ),
        pw.SizedBox(height: 18),
        ..._buildGrid(page.blocks, images, lightingAnnotations),
      ],
    );
  }

  List<pw.Widget> _buildGrid(
    List<BibleBlock> blocks,
    Map<String, Uint8List> images,
    Map<int, AnnotationDocument> lightingAnnotations,
  ) {
    final widgets = <pw.Widget>[];
    for (final row in BibleGridLayout.rows(blocks)) {
      if (BibleGridLayout.rowFitsGrid(row)) {
        widgets.add(
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 14),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                for (final block in row)
                  pw.Expanded(
                    flex: block.layout.colSpan.clamp(1, 12),
                    child: pw.Padding(
                      padding: const pw.EdgeInsets.only(right: 8),
                      child: _buildBlock(block, images, lightingAnnotations),
                    ),
                  ),
              ],
            ),
          ),
        );
      } else {
        for (final block in row) {
          widgets.add(
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 14),
              child: _buildBlock(block, images, lightingAnnotations),
            ),
          );
        }
      }
    }
    return widgets;
  }

  pw.Widget _buildCover(BibleExportPage page, Map<String, Uint8List> images) {
    final titleBlock = page.blocks.isEmpty ? null : page.blocks.first;
    final title = titleBlock?.content['text']?.toString().trim();
    final subtitle = titleBlock?.content['subtitle']?.toString().trim();
    final recipients = titleBlock?.content['recipients']?.toString().trim();
    return pw.Container(
      color: const PdfColor.fromInt(0xFF101216),
      padding: const pw.EdgeInsets.all(42),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Container(width: 64, height: 5, color: PdfColors.blue400),
          pw.SizedBox(height: 20),
          pw.Text(
            title == null || title.isEmpty ? page.label : title,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 36,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Text(
              subtitle,
              style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 15),
            ),
          ],
          if (recipients != null && recipients.isNotEmpty) ...[
            pw.SizedBox(height: 26),
            pw.Text(
              recipients,
              style: const pw.TextStyle(color: PdfColors.grey500, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildBlock(
    BibleBlock block,
    Map<String, Uint8List> images,
    Map<int, AnnotationDocument> lightingAnnotations,
  ) {
    final subsection = block.content['subsectionKind']?.toString();
    if (subsection == BibleBlockSchemas.tonePoints ||
        subsection == BibleBlockSchemas.transitions) {
      return _pointListBlock(block);
    }
    if (subsection == BibleBlockSchemas.visualStrategy) {
      return _strategyBlock(block);
    }
    if (subsection == BibleBlockSchemas.acts) {
      return _actsBlock(block);
    }
    if (subsection == BibleBlockSchemas.narrativeRefs) {
      return _narrativeRefsBlock(block, images);
    }
    return switch (block.type) {
      BibleBlockKind.text => _textBlock(block),
      BibleBlockKind.narrative => _narrativeBlock(block),
      BibleBlockKind.heroImage => _imageBlock(block, images),
      BibleBlockKind.moodboardRefs => _moodboardBlock(block, images),
      BibleBlockKind.chipSelect => _chipSelectBlock(block),
      BibleBlockKind.colorPalette => _colorPaletteBlock(block),
      BibleBlockKind.telemetry => _telemetryBlock(block),
      BibleBlockKind.equipmentList => _equipmentBlock(block),
      BibleBlockKind.specsTable => _specsBlock(block),
      BibleBlockKind.workflowPipeline => _workflowBlock(block),
      BibleBlockKind.lightingDiagram => _lightingDiagramBlock(
        block,
        lightingAnnotations,
        images,
      ),
      BibleBlockKind.dynamicBlocks => _dynamicBlock(
        block,
        images,
        lightingAnnotations,
      ),
    };
  }

  pw.Widget _textBlock(BibleBlock block) {
    final points = BibleBlockSchemas.parsePointList(block.content['points']);
    if (points.isNotEmpty) return _pointListBlock(block);
    if (block.content['pillars'] is List) return _strategyBlock(block);
    final label = block.content['label']?.toString() ?? '';
    final text = block.content['text']?.toString() ?? '—';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) _label(label.toUpperCase()),
        if (label.isNotEmpty) pw.SizedBox(height: 4),
        pw.Text(
          text.isEmpty ? '—' : text,
          style: const pw.TextStyle(fontSize: 11, lineSpacing: 2),
        ),
      ],
    );
  }

  pw.Widget _pointListBlock(BibleBlock block) {
    final label = block.content['label']?.toString() ?? '';
    final points = BibleBlockSchemas.parsePointList(block.content['points']);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) _label(label),
        if (label.isNotEmpty) pw.SizedBox(height: 6),
        for (final point in points) ...[
          pw.Text(
            point['title']!.isEmpty ? 'Sin título' : point['title']!,
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(
            point['body'] ?? '',
            style: const pw.TextStyle(fontSize: 10, lineSpacing: 2),
          ),
          pw.SizedBox(height: 6),
        ],
      ],
    );
  }

  pw.Widget _strategyBlock(BibleBlock block) {
    final raw = block.content['pillars'];
    final pillars = <Map<String, String>>[
      if (raw is List)
        for (final item in raw)
          if (item is Map)
            {
              'title': item['title']?.toString() ?? '',
              'body': item['body']?.toString() ?? '',
            },
    ];
    final extras = BibleBlockSchemas.parsePointList(block.content['extras']);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _label(block.content['label']?.toString() ?? 'Estrategia visual'),
        pw.SizedBox(height: 6),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final pillar in pillars)
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        pillar['title'] ?? '',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        pillar['body'] ?? '',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        for (final extra in extras) ...[
          pw.SizedBox(height: 4),
          pw.Text(
            extra['title'] ?? '',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          pw.Text(extra['body'] ?? '', style: const pw.TextStyle(fontSize: 9)),
        ],
      ],
    );
  }

  pw.Widget _actsBlock(BibleBlock block) {
    final raw = block.content['acts'];
    final acts = <Map<String, String>>[
      if (raw is List)
        for (final item in raw)
          if (item is Map)
            {
              'phase': item['phase']?.toString() ?? '',
              'title': item['title']?.toString() ?? '',
              'body': item['body']?.toString() ?? '',
            },
    ];
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _label(
          block.content['label']?.toString() ?? 'Intención visual por acto',
        ),
        pw.SizedBox(height: 8),
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            for (final act in acts)
              pw.Expanded(
                child: pw.Padding(
                  padding: const pw.EdgeInsets.only(right: 8),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        (act['phase'] ?? '').toUpperCase(),
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue600,
                        ),
                      ),
                      pw.Text(
                        act['title'] ?? '',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        act['body'] ?? '',
                        style: const pw.TextStyle(fontSize: 9),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget _narrativeRefsBlock(
    BibleBlock block,
    Map<String, Uint8List> images,
  ) {
    final raw = block.content['images'] ?? block.content['items'];
    final cards = <Map<String, dynamic>>[
      if (raw is List)
        for (final item in raw)
          if (item is Map) Map<String, dynamic>.from(item),
    ];
    if (cards.isEmpty) return _placeholder('Sin referencias');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _label(
          block.content['label']?.toString() ?? 'Referencias de dirección',
        ),
        pw.SizedBox(height: 8),
        for (final card in cards) ...[
          pw.Text(
            card['title']?.toString().isNotEmpty == true
                ? card['title'].toString()
                : 'Referencia',
            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
          ),
          if (card['refLabel']?.toString().isNotEmpty == true)
            pw.Text(
              card['refLabel'].toString(),
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          if (card['body']?.toString().isNotEmpty == true)
            pw.Text(
              card['body'].toString(),
              style: const pw.TextStyle(fontSize: 10),
            ),
          if (card['specs'] is List)
            pw.Wrap(
              spacing: 8,
              children: [
                for (final spec in card['specs'] as List)
                  if (spec is Map)
                    pw.Text(
                      '${spec['label'] ?? ''} ${spec['value'] ?? ''}'.trim(),
                      style: const pw.TextStyle(fontSize: 8),
                    ),
              ],
            ),
          pw.SizedBox(height: 8),
        ],
      ],
    );
  }

  pw.Widget _narrativeBlock(BibleBlock block) {
    final text = block.content['text']?.toString().trim() ?? '';
    final title = block.content['label']?.toString().trim();
    final tags = BibleBlockSchemas.parseTags(block.content['tags']);
    if (text.isEmpty && tags.isEmpty) return pw.SizedBox.shrink();
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(0, 6, 8, 6),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0x1A2997FF),
        border: pw.Border.all(color: PdfColors.blue200, width: 0.4),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(width: 3, color: PdfColors.blue400, height: 36),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  (title == null || title.isEmpty
                          ? 'INTENCIÓN NARRATIVA'
                          : title)
                      .toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 8,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue600,
                    letterSpacing: 1.1,
                  ),
                ),
                if (text.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    '"$text"',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontStyle: pw.FontStyle.italic,
                    ),
                  ),
                ],
                if (tags.isNotEmpty) ...[
                  pw.SizedBox(height: 6),
                  pw.Wrap(
                    spacing: 4,
                    children: [
                      for (final tag in tags)
                        pw.Text(
                          tag.toUpperCase(),
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.blue700,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _imageBlock(BibleBlock block, Map<String, Uint8List> images) {
    final path = _imagePaths(block).firstOrNull;
    final bytes = path == null ? null : images[path];
    if (bytes == null) return _placeholder('Imagen no disponible');
    final image = BibleImageContent.fromJson(
      block.content['image'] is Map
          ? Map<String, dynamic>.from(block.content['image'] as Map)
          : block.content,
    );
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          height: 190,
          width: double.infinity,
          child: pw.Image(
            pw.MemoryImage(bytes),
            fit: image.fit == 'contain' ? pw.BoxFit.contain : pw.BoxFit.cover,
          ),
        ),
        if (image.caption?.isNotEmpty == true) ...[
          pw.SizedBox(height: 4),
          pw.Text(image.caption!, style: const pw.TextStyle(fontSize: 8)),
        ],
      ],
    );
  }

  pw.Widget _moodboardBlock(BibleBlock block, Map<String, Uint8List> images) {
    final tiles =
        <({Uint8List bytes, String? caption, List<String> details})>[];
    final candidates =
        block.content['images'] ?? block.content['items'] ?? const [];
    if (candidates is List) {
      for (final candidate in candidates) {
        String? path;
        String? caption;
        var details = const <String>[];
        if (candidate is String) {
          path = candidate;
        } else if (candidate is Map) {
          final map = Map<String, dynamic>.from(candidate);
          path = BibleImageContent.fromJson(map).path;
          final rawCaption = map['caption']?.toString().trim();
          caption = (rawCaption == null || rawCaption.isEmpty)
              ? null
              : rawCaption;
          final rawDetails = map['details'];
          if (rawDetails is List) {
            details = rawDetails
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        }
        if (path == null || path.isEmpty) continue;
        final bytes = images[path];
        if (bytes == null) continue;
        tiles.add((bytes: bytes, caption: caption, details: details));
      }
    }
    if (tiles.isEmpty) return _placeholder('Moodboard sin imágenes');
    final sectionTitle = block.content['title']?.toString().trim();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (sectionTitle != null && sectionTitle.isNotEmpty) ...[
          pw.Text(
            sectionTitle,
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
          ),
          pw.SizedBox(height: 8),
        ],
        MoodboardPdfTiles.wrap(
          tiles: [
            for (final tile in tiles)
              MoodboardPdfTiles.tileColumn(
                image: pw.MemoryImage(tile.bytes),
                caption: tile.caption,
                details: tile.details,
                tileWidth: 150,
                imageHeight: 105,
                detailLimit: 4,
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget _chipSelectBlock(BibleBlock block) {
    final chips = (block.content['chips'] as List? ?? const [])
        .map((e) => e.toString())
        .toList();
    if (chips.isEmpty) return _placeholder('Sin tags');
    return pw.Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final chip in chips)
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Text(chip, style: const pw.TextStyle(fontSize: 9)),
          ),
      ],
    );
  }

  pw.Widget _colorPaletteBlock(BibleBlock block) {
    final colors = (block.content['colors'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    if (colors.isEmpty) return _placeholder('Sin paleta');
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          height: 18,
          child: pw.Row(
            children: [
              for (final color in colors)
                pw.Expanded(
                  child: pw.Container(
                    color:
                        _pdfColor(color['hex']?.toString()) ?? PdfColors.grey,
                  ),
                ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            for (final color in colors)
              pw.Column(
                children: [
                  pw.Container(
                    width: 48,
                    height: 48,
                    color:
                        _pdfColor(color['hex']?.toString()) ?? PdfColors.grey,
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    color['name']?.toString().isNotEmpty == true
                        ? color['name'].toString()
                        : color['hex']?.toString() ?? '',
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }

  pw.Widget _telemetryBlock(BibleBlock block) {
    final metrics = (block.content['metrics'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final values = metrics.isNotEmpty
        ? metrics
        : [
            {'label': 'Kelvin', 'value': block.content['kelvin'] ?? '—'},
            {'label': 'Ratio', 'value': block.content['ratio'] ?? '—'},
            {'label': 'IRE', 'value': block.content['ire'] ?? '—'},
          ];
    return pw.Row(
      children: [
        for (final metric in values)
          pw.Expanded(
            child: pw.Column(
              children: [
                pw.Text(
                  metric['value']?.toString() ?? '—',
                  style: pw.TextStyle(
                    color: PdfColors.blue600,
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                _label(metric['label']?.toString() ?? ''),
              ],
            ),
          ),
      ],
    );
  }

  pw.Widget _equipmentBlock(BibleBlock block) {
    final items = (block.content['items'] as List? ?? const []);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        for (final item in items)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 4),
            child: pw.Text('• ${item.toString()}'),
          ),
      ],
    );
  }

  pw.Widget _lightingDiagramBlock(
    BibleBlock block,
    Map<int, AnnotationDocument> lightingAnnotations,
    Map<String, Uint8List> images,
  ) {
    var nodes = block.content['nodes'];
    if (nodes is String) {
      try {
        nodes = jsonDecode(nodes);
      } catch (_) {
        nodes = const [];
      }
    }
    final elements = (nodes as List? ?? const [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList();
    final setupId = (block.content['setupId'] as num?)?.toInt();
    final annotations = setupId == null
        ? const AnnotationDocument()
        : lightingAnnotations[setupId] ?? const AnnotationDocument();
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (block.content['label']?.toString().isNotEmpty == true)
          _label(block.content['label'].toString()),
        pw.SizedBox(height: 6),
        if (block.content['imagePath']?.toString().isNotEmpty == true &&
            images[block.content['imagePath'].toString()] != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.SizedBox(
              height: 140,
              child: pw.Image(
                pw.MemoryImage(images[block.content['imagePath'].toString()]!),
                fit: pw.BoxFit.cover,
              ),
            ),
          ),
        pw.Container(
          height: 180,
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Stack(
            children: [
              pw.CustomPaint(
                size: const PdfPoint(480, 180),
                painter: (canvas, size) {
                  for (final element in elements) {
                    final x = ((element['x'] as num?)?.toDouble() ?? 150) / 600;
                    final y = ((element['y'] as num?)?.toDouble() ?? 150) / 400;
                    final type = element['type']?.toString() ?? 'light';
                    final color = switch (type) {
                      'camera' => PdfColors.blue,
                      'subject' => PdfColors.grey900,
                      'key' => PdfColors.amber,
                      'fill' => PdfColors.lightBlue,
                      'rim' => PdfColors.orange,
                      _ => PdfColors.grey,
                    };
                    canvas
                      ..setFillColor(color)
                      ..drawEllipse(
                        x.clamp(0.03, 0.97) * size.x,
                        (1 - y.clamp(0.03, 0.97)) * size.y,
                        6,
                        6,
                      )
                      ..fillPath();
                  }
                },
              ),
              if (annotations.strokes.isNotEmpty)
                AnnotationPdfRenderer.build(
                  annotations,
                  width: 480,
                  height: 180,
                ),
              ..._buildNotes(annotations.notes, width: 480, height: 180),
            ],
          ),
        ),
        if (block.content['text']?.toString().isNotEmpty == true) ...[
          pw.SizedBox(height: 5),
          pw.Text(
            block.content['text'].toString(),
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ],
    );
  }

  pw.Widget _specsBlock(BibleBlock block) {
    final rows = (block.content['rows'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final columns = (block.content['columns'] as List? ?? ['label', 'value'])
        .map((value) => value.toString())
        .toList();
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: .5),
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
            for (final column in columns)
              pw.Padding(
                padding: const pw.EdgeInsets.all(5),
                child: _label(column),
              ),
          ],
        ),
        for (final row in rows)
          pw.TableRow(
            children: [
              for (final column in columns)
                pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    row[column]?.toString() ?? '—',
                    style: const pw.TextStyle(fontSize: 9),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  pw.Widget _workflowBlock(BibleBlock block) {
    final steps = (block.content['steps'] as List? ?? const [])
        .map((value) => value.toString())
        .toList();
    if (steps.isEmpty) {
      steps.addAll(kBibleWorkflowDefaultSteps);
    }
    return pw.Wrap(
      crossAxisAlignment: pw.WrapCrossAlignment.center,
      children: [
        for (var index = 0; index < steps.length; index++) ...[
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Text(
              PdfExportFonts.asciiFallback(steps[index]),
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
          if (index < steps.length - 1)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 5),
              child: pw.Text('>'),
            ),
        ],
      ],
    );
  }

  pw.Widget _dynamicBlock(
    BibleBlock block,
    Map<String, Uint8List> images,
    Map<int, AnnotationDocument> lightingAnnotations,
  ) {
    if (block.content['subsectionKind'] == BibleBlockSchemas.acts ||
        block.content['acts'] is List) {
      return _actsBlock(block);
    }
    final nested = BibleGridLayout.nestedBlocks(block);
    if (nested.isNotEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: _buildGrid(nested, images, lightingAnnotations),
      );
    }
    return _fallbackBlock(block);
  }

  pw.Widget _fallbackBlock(BibleBlock block) => _placeholder(
    block.content['label']?.toString() ??
        block.content['text']?.toString() ??
        block.type.label,
  );

  pw.Widget _placeholder(String text) => pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(
      color: PdfColors.grey100,
      border: pw.Border.all(color: PdfColors.grey300),
    ),
    child: pw.Text(text, style: const pw.TextStyle(fontSize: 10)),
  );

  pw.Widget _label(String value) => pw.Text(
    value.toUpperCase(),
    style: pw.TextStyle(
      fontSize: 7,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey600,
      letterSpacing: 1,
    ),
  );

  List<pw.Widget> _buildNotes(
    List<AnnotationNote> notes, {
    required double width,
    required double height,
  }) => [
    for (final note in notes)
      pw.Positioned(
        left: note.x * width,
        top: note.y * height,
        child: pw.Container(
          width: note.width * width,
          height: note.height * height,
          padding: const pw.EdgeInsets.all(7),
          decoration: pw.BoxDecoration(
            color: PdfColor.fromInt(note.colorArgb),
            border: pw.Border.all(color: PdfColors.grey600, width: .5),
            boxShadow: const [
              pw.BoxShadow(
                color: PdfColors.grey500,
                blurRadius: 2,
                offset: PdfPoint(1, 1),
              ),
            ],
          ),
          child: pw.Text(note.text, style: const pw.TextStyle(fontSize: 8)),
        ),
      ),
  ];

  static List<BibleExportPage> _orderedPages(List<BibleExportPage> pages) {
    final indexed = pages.indexed.toList();
    indexed.sort((a, b) {
      final byOrder = a.$2.sortOrder.compareTo(b.$2.sortOrder);
      return byOrder != 0 ? byOrder : a.$1.compareTo(b.$1);
    });
    return indexed.map((item) => item.$2).toList(growable: false);
  }

  static PdfPageFormat _pageFormat(BibleExportPageFormat format) =>
      format == BibleExportPageFormat.a4Landscape
      ? PdfPageFormat.a4.landscape
      : PdfPageFormat.a4;

  static PdfColor? _pdfColor(String? value) {
    if (value == null) return null;
    var hex = value.trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : PdfColor.fromInt(parsed);
  }
}
