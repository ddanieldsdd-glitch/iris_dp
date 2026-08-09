import 'dart:convert';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../../core/database/app_database.dart';
import '../../../../core/utils/pdf_export_fonts.dart';
import '../../../../core/utils/pdf_safe_image.dart';
import '../../../../shared/annotations/annotation_document.dart';
import '../../../../shared/annotations/annotation_pdf_renderer.dart';
import '../../bible_block_catalog.dart';
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
        ...page.blocks.map(
          (block) => pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 14),
            child: _buildBlock(block, images, lightingAnnotations),
          ),
        ),
      ],
    );
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
    return switch (block.type) {
      BibleBlockKind.text => _textBlock(block),
      BibleBlockKind.narrative => _narrativeBlock(block),
      BibleBlockKind.heroImage => _imageBlock(block, images),
      BibleBlockKind.moodboardRefs => _moodboardBlock(block, images),
      BibleBlockKind.colorPalette => _colorPaletteBlock(block),
      BibleBlockKind.telemetry => _telemetryBlock(block),
      BibleBlockKind.equipmentList => _equipmentBlock(block),
      BibleBlockKind.specsTable => _specsBlock(block),
      BibleBlockKind.workflowPipeline => _workflowBlock(block),
      BibleBlockKind.lightingDiagram => _lightingDiagramBlock(
        block,
        lightingAnnotations,
      ),
      BibleBlockKind.dynamicBlocks => _dynamicBlock(block),
      _ => _fallbackBlock(block),
    };
  }

  pw.Widget _textBlock(BibleBlock block) {
    final label = block.content['label']?.toString() ?? '';
    final text = block.content['text']?.toString() ?? '—';
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) _label(label),
        if (label.isNotEmpty) pw.SizedBox(height: 4),
        pw.Text(
          text.isEmpty ? '—' : text,
          style: const pw.TextStyle(fontSize: 11),
        ),
      ],
    );
  }

  pw.Widget _narrativeBlock(BibleBlock block) {
    final text = block.content['text']?.toString().trim() ?? '';
    if (text.isEmpty) return pw.SizedBox.shrink();
    return pw.Container(
      padding: const pw.EdgeInsets.only(left: 12, top: 4, bottom: 4),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: PdfColors.blue400, width: 3),
        ),
      ),
      child: pw.Text(
        '"$text"',
        style: const pw.TextStyle(fontSize: 12),
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
    final available = _imagePaths(
      block,
    ).map((path) => images[path]).whereType<Uint8List>().toList();
    if (available.isEmpty) return _placeholder('Moodboard sin imágenes');
    return pw.Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final bytes in available)
          pw.Container(
            width: 150,
            height: 105,
            child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.cover),
          ),
      ],
    );
  }

  pw.Widget _colorPaletteBlock(BibleBlock block) {
    final colors = (block.content['colors'] as List? ?? const [])
        .whereType<Map>();
    return pw.Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        for (final color in colors)
          pw.Column(
            children: [
              pw.Container(
                width: 48,
                height: 48,
                color: _pdfColor(color['hex']?.toString()) ?? PdfColors.grey,
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
              steps[index],
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

  pw.Widget _dynamicBlock(BibleBlock block) {
    final items = block.content['blocks'] ?? block.content['items'] ?? const [];
    if (items is List && items.isNotEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          for (final item in items)
            pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 3),
              child: pw.Text(
                item is Map
                    ? (item['title'] ?? item['label'] ?? item['name'] ?? item)
                          .toString()
                    : item.toString(),
              ),
            ),
        ],
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
