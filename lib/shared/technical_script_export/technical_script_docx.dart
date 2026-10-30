import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

import '../../core/utils/export_file_saver.dart';
import '../pdf_export/technical_script_pdf.dart';
import '../rich_text/script_markup.dart';
import 'technical_script_doc.dart';

/// Archivos de una tipografía para incrustarla en el Word: así se ve igual
/// aunque el ordenador que lo abra no la tenga instalada.
class DocxFontFiles {
  /// Nombre de la familia, tal como figura dentro de los archivos.
  final String name;
  final Uint8List regular;
  final Uint8List bold;
  final Uint8List italic;
  final Uint8List boldItalic;

  const DocxFontFiles({
    required this.name,
    required this.regular,
    required this.bold,
    required this.italic,
    required this.boldItalic,
  });

  static const _files = {
    'Inter': 'Inter',
    'Noto Sans': 'NotoSans',
    'Tinos': 'Tinos',
  };

  /// Las cuatro variantes de [family] (Inter si no se conoce).
  static Future<DocxFontFiles> load(String family) async {
    final name = _files.containsKey(family) ? family : 'Inter';
    final file = _files[name]!;
    Future<Uint8List> read(String variant) async => (await rootBundle.load(
      'assets/fonts/$file-$variant.ttf',
    )).buffer.asUint8List();
    return DocxFontFiles(
      name: name,
      regular: await read('Regular'),
      bold: await read('Bold'),
      italic: await read('Italic'),
      boldItalic: await read('BoldItalic'),
    );
  }
}

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
      build: () async => buildBytes(
        doc,
        // Las páginas del PDF son una buena primera cifra; Word las
        // recalcula al abrirlo.
        pages: await TechnicalScriptPdfExporter.scenePages(doc),
        fonts: await DocxFontFiles.load(doc.fontFamily),
      ),
    );
  }

  /// Nombre del marcador de la sección [i], destino de su línea del índice.
  static String _bookmark(int i) => 'esc_$i';

  // Lado largo y corto del papel en veinteavos de punto, con márgenes de
  // 1,27 cm.
  static (int, int) _paperSides(ScriptDocPaper paper) => switch (paper) {
    ScriptDocPaper.a4 => (16838, 11906),
    ScriptDocPaper.letter => (15840, 12240),
  };
  static const _margin = 720;

  /// Unidades EMU por veinteavo de punto.
  static const _emuPerTwip = 635;

  static String _esc(String s) => const HtmlEscape(
    HtmlEscapeMode.element,
  ).convert(s).replaceAll('"', '&quot;');

  static String _hex(int rgb) =>
      (rgb & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

  /// Texto con su formato. Con [markup] falso (títulos, encabezados) el
  /// texto va tal cual: un asterisco en un nombre no lo pone en cursiva.
  static String _runs(
    String text, {
    double size = 9,
    bool bold = false,
    bool markup = true,
  }) {
    final out = StringBuffer();
    final half = (size * 2).round();
    final spans = markup ? parseScriptMarkup(text) : [ScriptSpan(text)];
    for (final span in spans) {
      // La tipografía sale de los estilos del documento (la de la hoja).
      final props = StringBuffer();
      if (bold || span.bold) props.write('<w:b/><w:bCs/>');
      if (span.italic) props.write('<w:i/><w:iCs/>');
      if (span.underline) props.write('<w:u w:val="single"/>');
      if (span.textColor != null) {
        props.write(
          '<w:color w:val="${_hex(kScriptTextColorRgb[span.textColor]!)}"/>',
        );
      }
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

  /// Línea del índice: el nombre de la escena, puntos hasta el margen y su
  /// página (un campo que Word actualiza), todo enlazado a la escena.
  static String _indexLine(int i, String label, int? page, int width) {
    const props =
        '<w:rPr><w:b/><w:bCs/><w:sz w:val="19"/><w:szCs w:val="19"/></w:rPr>';
    final name = _bookmark(i);
    return '<w:p><w:pPr><w:tabs><w:tab w:val="right" w:leader="dot" '
        'w:pos="$width"/></w:tabs><w:spacing w:before="30" w:after="30"/>'
        '</w:pPr><w:hyperlink w:anchor="$name" w:history="1">'
        '<w:r>$props<w:t xml:space="preserve">${_esc(label)}</w:t></w:r>'
        '<w:r>$props<w:tab/></w:r>'
        '<w:r>$props<w:fldChar w:fldCharType="begin"/></w:r>'
        '<w:r>$props<w:instrText xml:space="preserve"> PAGEREF $name \\h </w:instrText></w:r>'
        '<w:r>$props<w:fldChar w:fldCharType="separate"/></w:r>'
        '<w:r>$props<w:t>${page ?? ''}</w:t></w:r>'
        '<w:r>$props<w:fldChar w:fldCharType="end"/></w:r>'
        '</w:hyperlink></w:p>';
  }

  static Uint8List buildBytes(
    TechnicalScriptDoc doc, {
    Map<int, int> pages = const {},
    DocxFontFiles? fonts,
  }) {
    final (long, short) = _paperSides(doc.paper);
    final pageW = doc.landscape ? long : short;
    final pageH = doc.landscape ? short : long;
    final contentWidth = pageW - _margin * 2;
    final bodySize = doc.fontSize ?? 9;
    final totalWeight = doc.columns.fold<double>(0, (a, c) => a + c.weight);
    final widths = [
      for (final c in doc.columns)
        (contentWidth * c.weight / totalWeight).round(),
    ];

    final media = <String, Uint8List>{};
    final rels = StringBuffer();
    final body = StringBuffer();
    var imageIndex = 0;

    body.write(
      _paragraph(_runs(doc.title, size: 16, bold: true, markup: false)),
    );
    if (doc.subtitle != null && doc.subtitle!.trim().isNotEmpty) {
      body.write(_paragraph(_runs(doc.subtitle!, size: 10, markup: false)));
    }

    if (doc.hasIndex) {
      body.write(
        '<w:p><w:pPr><w:spacing w:before="240" w:after="80"/></w:pPr>'
        '${_runs('ÍNDICE', size: 18, markup: false)}</w:p>',
      );
      for (final (i, section) in doc.sections.indexed) {
        body.write(_indexLine(i, section.indexText, pages[i], contentWidth));
      }
      body.write('<w:p><w:r><w:br w:type="page"/></w:r></w:p>');
    }

    for (final (sectionIndex, section) in doc.sections.indexed) {
      // El encabezado va con su tabla y es el destino de su línea del índice.
      final heading = _runs(section.title, size: 11, bold: true, markup: false);
      final name = _bookmark(sectionIndex);
      body.write(
        '<w:p><w:pPr><w:keepNext/><w:spacing w:before="40" w:after="40"/>'
        '</w:pPr><w:bookmarkStart w:id="$sectionIndex" w:name="$name"/>'
        '$heading<w:bookmarkEnd w:id="$sectionIndex"/></w:p>',
      );
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
              _runs(
                doc.columns[i].label,
                size: bodySize,
                bold: true,
                markup: false,
              ),
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
          final pictures = row.imagesOf(column.key) ?? const [];
          if (pictures.isNotEmpty) {
            // Un párrafo por imagen: los encuadres van uno debajo de otro.
            final paragraphs = StringBuffer();
            for (final bytes in pictures) {
              final picture = _fitImage(bytes, widths[i] - 200);
              if (picture == null) continue;
              imageIndex++;
              final relId = 'rIdImg$imageIndex';
              media['word/media/referencia$imageIndex.jpg'] = picture.bytes;
              rels.write(
                '<Relationship Id="$relId" '
                'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" '
                'Target="media/referencia$imageIndex.jpg"/>',
              );
              paragraphs.write(
                _paragraph(
                  _image(
                    relId,
                    imageIndex,
                    picture.widthEmu,
                    picture.heightEmu,
                  ),
                  centered: true,
                ),
              );
            }
            content = paragraphs.isEmpty ? _paragraph('') : '$paragraphs';
          } else {
            content = _paragraph(
              _runs(row.cells[column.key] ?? '', size: bodySize),
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
        '<w:sectPr><w:pgSz w:w="$pageW" w:h="$pageH"'
        '${doc.landscape ? ' w:orient="landscape"' : ''}/>'
        '<w:pgMar w:top="$_margin" w:right="$_margin" w:bottom="$_margin" '
        'w:left="$_margin" w:header="360" w:footer="360" w:gutter="0"/>'
        '</w:sectPr></w:body></w:document>';

    const relType =
        'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
    rels
      ..write(
        '<Relationship Id="rIdStyles" Type="$relType/styles" '
        'Target="styles.xml"/>',
      )
      ..write(
        '<Relationship Id="rIdSettings" Type="$relType/settings" '
        'Target="settings.xml"/>',
      )
      ..write(
        '<Relationship Id="rIdFonts" Type="$relType/fontTable" '
        'Target="fontTable.xml"/>',
      );

    final family = fonts?.name ?? doc.fontFamily;
    final fontRels = StringBuffer();
    final embeds = StringBuffer();
    final fontFiles = <String, Uint8List>{};
    if (fonts != null) {
      for (final (i, (tag, bytes)) in [
        ('embedRegular', fonts.regular),
        ('embedBold', fonts.bold),
        ('embedItalic', fonts.italic),
        ('embedBoldItalic', fonts.boldItalic),
      ].indexed) {
        final key = _fontKey(Random(_fontSeed(bytes)));
        final file = 'font${i + 1}.odttf';
        fontFiles['word/fonts/$file'] = _obfuscateFont(bytes, key);
        fontRels.write(
          '<Relationship Id="rIdFont${i + 1}" Type="$relType/font" '
          'Target="fonts/$file"/>',
        );
        embeds.write('<w:$tag r:id="rIdFont${i + 1}" w:fontKey="$key"/>');
      }
    }
    final fontName = _esc(family);
    final fontTable =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:fonts xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" '
        'xmlns:r="$relType">'
        '<w:font w:name="$fontName"><w:charset w:val="00"/>'
        '<w:family w:val="${family == 'Tinos' ? 'roman' : 'swiss'}"/>'
        '<w:pitch w:val="variable"/>$embeds</w:font></w:fonts>';
    final styles =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '<w:docDefaults><w:rPrDefault><w:rPr>'
        '<w:rFonts w:ascii="$fontName" w:hAnsi="$fontName" '
        'w:eastAsia="$fontName" w:cs="$fontName"/>'
        '<w:color w:val="000000"/>'
        '<w:sz w:val="18"/><w:szCs w:val="18"/><w:lang w:val="es-ES"/>'
        '</w:rPr></w:rPrDefault><w:pPrDefault><w:pPr>'
        '<w:spacing w:after="0" w:line="240" w:lineRule="auto"/>'
        '</w:pPr></w:pPrDefault></w:docDefaults>'
        '<w:style w:type="paragraph" w:default="1" w:styleId="Normal">'
        '<w:name w:val="Normal"/><w:qFormat/></w:style>'
        '</w:styles>';
    // Las páginas del índice ya vienen calculadas por el PDF; sin
    // updateFields, Word no pregunta nada al abrir el documento.
    final settings =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<w:settings xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">'
        '${fonts != null ? '<w:embedTrueTypeFonts/>' : ''}'
        '</w:settings>';

    const contentTypes =
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Default Extension="jpg" ContentType="image/jpeg"/>'
        '<Default Extension="odttf" ContentType="application/vnd.openxmlformats-officedocument.obfuscatedFont"/>'
        '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
        '<Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>'
        '<Override PartName="/word/settings.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.settings+xml"/>'
        '<Override PartName="/word/fontTable.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.fontTable+xml"/>'
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
    add('word/styles.xml', utf8.encode(styles));
    add('word/settings.xml', utf8.encode(settings));
    add('word/fontTable.xml', utf8.encode(fontTable));
    if (fontFiles.isNotEmpty) {
      add(
        'word/_rels/fontTable.xml.rels',
        utf8.encode(
          '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
          '$fontRels</Relationships>',
        ),
      );
      fontFiles.forEach(add);
    }
    media.forEach(add);

    return Uint8List.fromList(ZipEncoder().encode(archive)!);
  }

  /// Semilla fija por tipografía (FNV-1a de sus bytes), para que el mismo
  /// guion dé siempre el mismo .docx.
  static int _fontSeed(Uint8List bytes) {
    var h = 0x811c9dc5;
    for (final b in bytes) {
      h = ((h ^ b) * 0x01000193) & 0xffffffff;
    }
    return h;
  }

  /// Clave de una tipografía incrustada: «{XXXXXXXX-XXXX-…}».
  static String _fontKey(Random random) {
    final hex = [
      for (var i = 0; i < 16; i++)
        random.nextInt(256).toRadixString(16).padLeft(2, '0').toUpperCase(),
    ].join();
    return '{${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}}';
  }

  /// Ofusca la tipografía como pide Word (ECMA-376, 17.8.1): los 32
  /// primeros bytes, con los de la clave en orden inverso.
  static Uint8List _obfuscateFont(Uint8List font, String key) {
    final hex = key.replaceAll(RegExp('[{}-]'), '');
    final bytes = [
      for (var i = 0; i < 16; i++)
        int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16),
    ];
    final out = Uint8List.fromList(font);
    for (var i = 0; i < 32 && i < out.length; i++) {
      out[i] ^= bytes[15 - (i % 16)];
    }
    return out;
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
