import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

/// Formatos de plan de rodaje que se pueden importar.
const kShootPlanExtensions = ['txt', 'docx', 'pdf', 'xlsx'];

/// Lee el texto de un plan de rodaje: una línea por renglón o por fila de
/// tabla. Lo entiende después [parseShootPlanText].
///
/// Se llama con `compute`, así que recibe un solo argumento.
String readShootPlanFile((String, Uint8List) file) {
  final (name, bytes) = file;
  final ext = name.toLowerCase().split('.').last;
  return switch (ext) {
    'txt' || 'text' || 'md' => _text(bytes),
    'docx' => _docx(bytes),
    'pdf' => _pdf(bytes),
    'xlsx' => _xlsx(bytes),
    'doc' || 'xls' => throw const FormatException(
      'Ese formato antiguo no se puede leer. Guárdalo como .docx o .xlsx.',
    ),
    _ => throw const FormatException(
      'Formato no admitido. Usa Word (.docx), Excel (.xlsx), PDF o texto.',
    ),
  };
}

String _text(Uint8List bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException {
    return latin1.decode(bytes);
  }
}

String _pdf(Uint8List bytes) {
  final doc = PdfDocument(inputBytes: bytes);
  try {
    return PdfTextExtractor(doc)
        .extractText(layoutText: true)
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
  } finally {
    doc.dispose();
  }
}

/// Párrafos y filas de tabla en el orden del documento. Las celdas de una
/// fila van en una línea, separadas por espacios.
String _docx(Uint8List bytes) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final entry = archive.findFile('word/document.xml');
  if (entry == null) {
    throw const FormatException('Archivo Word inválido: falta document.xml');
  }
  final xml = XmlDocument.parse(utf8.decode(entry.content as List<int>));
  final body = xml.findAllElements('w:body').firstOrNull;
  if (body == null) return '';
  final out = StringBuffer();

  String paragraph(XmlElement p) {
    final parts = <String>[];
    for (final run in p.findAllElements('w:r')) {
      for (final child in run.childElements) {
        switch (child.name.local) {
          case 't':
            parts.add(child.innerText);
          case 'br':
            parts.add('\n');
          case 'tab':
            parts.add(' ');
        }
      }
    }
    return parts.join();
  }

  void walk(XmlElement el) {
    for (final child in el.childElements) {
      switch (child.name.local) {
        case 'p':
          out.writeln(paragraph(child));
        case 'tbl':
          for (final row in child.findElements('w:tr')) {
            final cells = [
              for (final cell in row.findElements('w:tc'))
                cell
                    .findAllElements('w:p')
                    .map(paragraph)
                    .where((t) => t.trim().isNotEmpty)
                    .join(' '),
            ].where((c) => c.trim().isNotEmpty);
            out.writeln(cells.join(' '));
          }
        case 'sdt' || 'sdtContent':
          walk(child);
      }
    }
  }

  walk(body);
  return out.toString();
}

String _hm(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

/// Una celda como se lee en pantalla: las horas como «07:30» y las fechas
/// como «13/11/2026».
String excelCellText(CellValue? v) => switch (v) {
  null => '',
  TextCellValue() => v.value.toString(),
  IntCellValue() => '${v.value}',
  // Una hora guardada como fracción de día.
  DoubleCellValue(:final value) when value > 0 && value < 1 => () {
    final minutes = (value * 24 * 60).round();
    return _hm(minutes ~/ 60 % 24, minutes % 60);
  }(),
  DoubleCellValue(:final value) =>
    value == value.roundToDouble() ? '${value.toInt()}' : '$value',
  TimeCellValue() => _hm(v.hour, v.minute),
  DateCellValue() => '${v.day}/${v.month}/${v.year}',
  DateTimeCellValue() =>
    v.hour == 0 && v.minute == 0
        ? '${v.day}/${v.month}/${v.year}'
        : _hm(v.hour, v.minute),
  BoolCellValue() => v.value ? 'sí' : 'no',
  FormulaCellValue() => '',
};

String _xlsx(Uint8List bytes) {
  final book = Excel.decodeBytes(bytes);
  final out = StringBuffer();
  for (final sheet in book.tables.values) {
    for (final row in sheet.rows) {
      final cells = [
        for (final cell in row) excelCellText(cell?.value).trim(),
      ].where((c) => c.isNotEmpty);
      // Una hora y su final en dos columnas se leen como «07:30 - 08:30».
      final line = cells
          .join(' ')
          .replaceAllMapped(
            RegExp(r'^(\d{1,2}:\d{2}) (\d{1,2}:\d{2})\b'),
            (m) => '${m[1]} - ${m[2]}',
          );
      out.writeln(line);
    }
    out.writeln();
  }
  return out.toString();
}
