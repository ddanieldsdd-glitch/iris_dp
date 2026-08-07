import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/utils/export_file_saver.dart';
import '../../core/utils/pdf_export_fonts.dart';
import '../../core/utils/pdf_safe_image.dart';
import '../../features/shoot_documents/shoot_document_block_resolver.dart';
import '../../features/shoot_documents/shoot_document_block_types.dart';
import '../../core/database/app_database.dart';

/// Export PDF WYSIWYG del documento de rodaje montado.
class ShootDocumentPdfExporter {
  static Future<Uint8List> buildBytes({
    required ShootDocument document,
    required List<ResolvedShootBlock> blocks,
    required String projectName,
  }) =>
      _build(document, blocks, projectName);

  static Future<String?> exportAndSave({
    required ShootDocument document,
    required List<ResolvedShootBlock> blocks,
    required String projectName,
  }) {
    final safeName =
        document.name.replaceAll(RegExp(r'[^\w\s-]'), '').trim();
    return ExportFileSaver.saveGenerated(
      dialogTitle: 'Exportar documento de rodaje',
      fileName: safeName.isEmpty ? 'documento_rodaje.pdf' : '$safeName.pdf',
      extension: 'pdf',
      build: () => _build(document, blocks, projectName),
    );
  }

  static Future<Uint8List> _build(
    ShootDocument document,
    List<ResolvedShootBlock> blocks,
    String projectName,
  ) async {
    final fonts = await PdfExportFonts.load();
    final theme = PdfExportFonts.theme(
      regular: fonts.regular,
      bold: fonts.bold,
    );
    final imageCache = await _preloadImages(blocks);
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        theme: theme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          final widgets = <pw.Widget>[];

          if (document.includeCoverInPdf) {
            widgets.addAll([
              pw.Text(
                document.name,
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (projectName.isNotEmpty) ...[
                pw.SizedBox(height: 4),
                pw.Text(projectName, style: const pw.TextStyle(fontSize: 11)),
              ],
              if (document.shootDate != null) ...[
                pw.SizedBox(height: 4),
                pw.Text('Jornada: ${document.shootDate}',
                    style: const pw.TextStyle(fontSize: 10)),
              ],
              pw.SizedBox(height: 20),
            ]);
          }

          for (final r in blocks) {
            widgets.addAll(_blockWidgets(r, imageCache));
          }

          return widgets;
        },
      ),
    );

    return doc.save();
  }

  static Future<Map<String, Uint8List?>> _preloadImages(
    List<ResolvedShootBlock> blocks,
  ) async {
    final cache = <String, Uint8List?>{};
    for (final r in blocks) {
      for (final path in {r.imagePath, r.block.imagePath}) {
        if (path == null || cache.containsKey(path)) continue;
        cache[path] = await PdfSafeImage.loadFromPath(path);
      }
    }
    return cache;
  }

  static List<pw.Widget> _blockWidgets(
    ResolvedShootBlock r,
    Map<String, Uint8List?> imageCache,
  ) {
    final b = r.block;
    final vis = r.visibility;

    if (b.blockType == ShootBlockType.pageBreak) {
      return [pw.NewPage()];
    }
    if (b.blockType == ShootBlockType.spacer) {
      return [pw.SizedBox(height: 16)];
    }

    final children = <pw.Widget>[
      pw.Text(
        r.title,
        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11),
      ),
      pw.SizedBox(height: 4),
    ];

    switch (b.blockType) {
      case ShootBlockType.sectionHeader:
      case ShootBlockType.sceneHeader:
        children.add(pw.Text(b.customLabel ?? ''));
      case ShootBlockType.characterList:
        if (vis.showCharacters) {
          children.add(pw.Text(r.characters.join(' · ')));
        }
      case ShootBlockType.scriptExcerpt:
        if (vis.showScript) {
          children.add(pw.Text(b.scriptExcerpt ?? ''));
        }
      case ShootBlockType.note:
        children.add(pw.Text(b.noteBody ?? ''));
      case ShootBlockType.shot:
        children.addAll(_shotWidgets(r, vis, imageCache));
      case ShootBlockType.image:
        children.addAll(_imageWidgets(b.imagePath, imageCache));
      default:
        break;
    }

    children.add(pw.SizedBox(height: 12));
    return [
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300),
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: children,
        ),
      ),
    ];
  }

  static List<pw.Widget> _shotWidgets(
    ResolvedShootBlock r,
    ShootBlockVisibility vis,
    Map<String, Uint8List?> imageCache,
  ) {
    final out = <pw.Widget>[];
    if (vis.showThumbnail && r.imagePath != null) {
      out.addAll(_imageWidgets(r.imagePath, imageCache, height: 80));
    }
    if (vis.showCamera) {
      final parts = [
        if (r.framing != null) r.framing,
        if (r.lens != null) r.lens,
        if (r.movement != null) r.movement,
      ].whereType<String>().join(' · ');
      if (parts.isNotEmpty) {
        out.add(pw.Text(parts, style: const pw.TextStyle(fontSize: 9)));
      }
    }
    if (vis.showDuration) {
      out.add(pw.Text(
        'Duración: ${formatDurationSeconds(r.durationSeconds)}',
        style: const pw.TextStyle(fontSize: 9),
      ));
    }
    if (vis.showCharacters && r.characters.isNotEmpty) {
      out.add(pw.Text(r.characters.join(', ')));
    }
    if (vis.showAction && r.action != null && r.action!.trim().isNotEmpty) {
      out.add(pw.Text(r.action!));
    }
    return out;
  }

  static List<pw.Widget> _imageWidgets(
    String? path,
    Map<String, Uint8List?> imageCache, {
    double height = 120,
  }) {
    if (path == null) return [];
    final bytes = imageCache[path];
    if (bytes == null) return [];
    return [
      pw.Image(
        pw.MemoryImage(bytes),
        height: height,
        fit: pw.BoxFit.cover,
      ),
      pw.SizedBox(height: 6),
    ];
  }
}
