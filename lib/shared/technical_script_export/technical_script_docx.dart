import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;

import '../../core/utils/export_file_saver.dart';
import '../rich_text/script_markup.dart';
import 'technical_script_doc.dart';

/// Word (.docx) del guion técnico, editable: una tabla por escena con el
/// mismo formato, colores e imágenes que la hoja.
class TechnicalScriptDocxExporter {
  static Future<String?> exportAndSave(
    TechnicalScriptDoc doc, {
    required String fileName,
  }) {
    return ExportFileSaver.saveGenerated(
      dialogTitle: 'Exportar guion técnico',
      fileName: '$fileName.docx',
      extension: 'docx',
      build: () async => buildBytes(doc),
    );
  }

  // A4 apaisado en veinteavos de punto, con márgenes de 1,27 cm.
  static const _pageW = 16838;
  static const _pageH = 11906;
  static const _margin = 720;

  /// Unidades EMU por veinteavo de punto.
  static const _emuPerTwip = 635;

  static String _esc(String s) => const HtmlEscape(
    HtmlEscapeMode.element,
  ).convert(s).replaceAll('"', '&quot;');

  static String _hex(int rgb) =>
      (rgb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  static String _runs(String text, {double size = 9, bool bold = false}) {
    final out = StringBuffer();
    final half = (size * 2).round();
    for (final span in parseScriptMarkup(text)) {
      final props = StringBuffer()
        ..write(
          '<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri" w:cs="Calibri"/>',
        );
      if (bold || span.bold) props.write('<w:b/>');
      if (span.italic) props.write('<w:i/>');
      if (span.underline) props.write('<w:u w:val="single"/>');
      props.write('<w:sz w:val="$half"/><w:szCs w:val="$half"/>');
      if (span.marker != null) {
        props.write(
          '<w:shd w:val="clear" w:color="auto" '
          'w:fill="${_hex(kScriptDocMarkerFills[span.marker] ?? 0xFFF176)}"/>',
        );
      }
      // Cada salto de línea del texto es un salto dentro del párrafo.
      final lines = span.text.split('\n');
      for (var i = 0; i < lines.length; i++) {
        out.write('<w:r><w:rPr>$props</w:rPr>');
        if (i > 0) out.write('<w:br/>');
        out.write('<w:t xml:space="preserve">${_esc(lines[i])}</w:t></w:r>');
      }
    }
    return out.toString();
  }

  static String _paragraph(String runs, {bool centered = false}) =>
      '<w:p><w:pPr>${centered ? '<w:jc w:val="center"/>' : ''}'
      '<w:spacing w:before="40" w:after="40"/></w:pPr>$runs</w:p>';

  static String _cell(
    String content, {
    required int width,
    int? fill,
    bool vCenter = false,
  }) =>
      '<w:tc><w:tcPr><w:tcW w:w="$width" w:type="dxa"/>'
      '${fill == null ? '' : '<w:shd w:val="clear" w:color="auto" w:fill="${_hex(fill)}"/>'}'
      '${vCenter ? '<w:vAlign w:val="center"/>' : ''}'
      '</w:tcPr>$content</w:tc>';

  static String _image(String relId, int index, int widthEmu, int heightEmu) =>
      '<w:r><w:drawing><wp:inline distT="0" distB="0" distL="0" distR="0">'
      '<wp:extent cx="$widthEmu" cy="$heightEmu"/>'
      '<wp:docPr id="$index" name="Referencia $index"/>'
      '<a:graphic xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
      '<a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">'
      '<pic:pic xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">'
      '<pic:nvPicPr><pic:cNvPr id="$index" name="referencia$index.jpg"/>'
      '<pic:cNvPicPr/></pic:nvPicPr>'
      '<pic:blipFill><a:blip r:embed="$relId"/><a:stretch><a:fillRect/></a:stretch>'
      '</pic:blipFill>'
      '<pic:spPr><a:xfrm><a:off x="0" y="0"/><a:ext cx="$widthEmu" cy="$heightEmu"/>'
      '</a:xfrm><a:prstGeom prst="rect"><a:avLst/></a:prstGeom></pic:spPr>'
      '</pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r>';

  static Uint8List buildBytes(TechnicalScriptDoc doc) {
    const contentWidth = _pageW - _margin * 2;
    final totalWeight = doc.columns.fold<double>(0, (a, c) => a + c.weight);
    final widths = [
      for (final c in doc.columns)
        (contentWidth * c.weight / totalWeight).round(),
    ];

    final media = <String, Uint8List>{};
    final rels = StringBuffer();
    final body = StringBuffer();
    var imageIndex = 0;

    body.write(_paragraph(_runs(doc.title, size: 16, bold: true)));
    if (doc.subtitle != null && doc.subtitle!.trim().isNotEmpty) {
      body.write(_paragraph(_runs(doc.subtitle!, size: 10)));
    }

    for (final section in doc.sections) {
      body.write(_paragraph(_runs(section.title, size: 11, bold: true)));
      body.write(
        '<w:tbl><w:tblPr><w:tblW w:w="$contentWidth" w:type="dxa"/>'
        '<w:tblLayout w:type="fixed"/><w:tblBorders>'
        '${[
          for (final side in ['top', 'left', 'bottom', 'right', 'insideH', 'insideV']) '<w:$side w:val="single" w:sz="6" w:space="0" w:color="000000"/>',
        ].join()}'
        '</w:tblBorders><w:tblCellMar>'
        '<w:left w:w="80" w:type="dxa"/><w:right w:w="80" w:type="dxa"/>'
        '</w:tblCellMar></w:tblPr><w:tblGrid>'
        '${[for (final w in widths) '<w:gridCol w:w="$w"/>'].join()}'
        '</w:tblGrid>',
      );

      // Fila de títulos, que se repite al cambiar de página.
      body.write('<w:tr><w:trPr><w:tblHeader/></w:trPr>');
      for (var i = 0; i < doc.columns.length; i++) {
        body.write(
          _cell(
            _paragraph(
              _runs(doc.columns[i].label, size: 9, bold: true),
              centered: true,
            ),
            width: widths[i],
            fill: section.headerFill,
            vCenter: true,
          ),
        );
      }
      body.write('</w:tr>');

      final rows = section.rows.isEmpty
          ? [const ScriptDocRow(cells: {})]
          : section.rows;
      for (final row in rows) {
        body.write('<w:tr><w:trPr><w:cantSplit/></w:trPr>');
        for (var i = 0; i < doc.columns.length; i++) {
          final column = doc.columns[i];
          String content;
          if (column.key == 'ref' && row.image != null) {
            final picture = _fitImage(row.image!, widths[i] - 200);
            if (picture != null) {
              imageIndex++;
              final relId = 'rIdImg$imageIndex';
              media['word/media/referencia$imageIndex.jpg'] = picture.bytes;
              rels.write(
                '<Relationship Id="$relId" '
                'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
                'Target="media/referencia$imageIndex.jpg"/>',
              );
              content = _paragraph(
                _image(relId, imageIndex, picture.widthEmu, picture.heightEmu),
                centered: true,
              );
            } else {
              content = _paragraph('');
            }
          } else {
            content = _paragraph(
              _runs(row.cells[column.key] ?? ''),
              centered: column.centered,
            );
          }
          body.write(
            _cell(
              content,
              width: widths[i],
              fill: row.fillOf(column.key),
              vCenter: column.centered,
            ),
          );
        }
        body.write('</w:tr>');
      }
      body.write('</w:tbl>');
      body.write(_paragraph(''));
    }

    final document =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:document '
        'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" '
        'xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing">'
        '<w:body>$body'
        '<w:sectPr><w:pgSz w:w="$_pageW" w:h="$_pageH" w:orient="landscape"/>'
        '<w:pgMar w:top="$_margin" w:right="$_margin" w:bottom="$_margin" '
        'w:left="$_margin" w:header="360" w:footer="360" w:gutter="0"/>'
        '</w:sectPr></w:body></w:document>';

    const contentTypes =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Default Extension="jpg" ContentType="image/jpeg"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '</Types>';
    const rootRels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>'
        '</Relationships>';
    final documentRels =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '$rels</Relationships>';

    final archive = Archive();
    void add(String name, List<int> bytes) =>
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
    add('[Content_Types].xml', utf8.encode(contentTypes));
    add('_rels/.rels', utf8.encode(rootRels));
    add('word/document.xml', utf8.encode(document));
    add('word/_rels/document.xml.rels', utf8.encode(documentRels));
    media.forEach(add);

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  /// Reduce la imagen al ancho de su celda y la pasa a JPEG; devuelve
  /// también su tamaño en el documento.
  static ({Uint8List bytes, int widthEmu, int heightEmu})? _fitImage(
    Uint8List source,
    int maxWidthTwips,
  ) {
    try {
      final decoded = img.decodeImage(source);
      if (decoded == null || decoded.width == 0 || decoded.height == 0) {
        return null;
      }
      final scaled = decoded.width > 900
          ? img.copyResize(decoded, width: 900)
          : decoded;
      final widthEmu = maxWidthTwips * _emuPerTwip;
      final heightEmu = (widthEmu * scaled.height / scaled.width).round();
      return (
        bytes: Uint8List.fromList(img.encodeJpg(scaled, quality: 82)),
        widthEmu: widthEmu,
        heightEmu: heightEmu,
      );
    } catch (_) {
      return null;
    }
  }
}
