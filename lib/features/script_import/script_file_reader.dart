import 'dart:io';

import 'package:archive/archive.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:xml/xml.dart';

enum ScriptFileKind { pdf, text, docx, unsupported }

/// Marcador de salto de página en texto extraído de PDF.
const kScriptPageMarkerPrefix = '[[PAGE:';

class LoadedScript {
  final String path;
  final String fileName;
  final ScriptFileKind kind;

  /// Texto extraído respetando páginas y párrafos (vista escaneada).
  final String displayText;

  const LoadedScript({
    required this.path,
    required this.fileName,
    required this.kind,
    required this.displayText,
  });

  /// Alias usado por el parser (normaliza internamente).
  String get parseText => displayText;
}

class ScriptFileReader {
  static Future<LoadedScript> load(String path) async {
    final fileName = path.split(Platform.pathSeparator).last;
    final lower = path.toLowerCase();

    if (lower.endsWith('.pdf')) {
      final text = await _extractPdfText(path);
      return LoadedScript(
        path: path,
        fileName: fileName,
        kind: ScriptFileKind.pdf,
        displayText: text,
      );
    }

    if (lower.endsWith('.txt') ||
        lower.endsWith('.fountain') ||
        lower.endsWith('.fdx')) {
      final text = await File(path).readAsString();
      return LoadedScript(
        path: path,
        fileName: fileName,
        kind: ScriptFileKind.text,
        displayText: text,
      );
    }

    if (lower.endsWith('.docx')) {
      final text = await _extractDocxText(path);
      return LoadedScript(
        path: path,
        fileName: fileName,
        kind: ScriptFileKind.docx,
        displayText: text,
      );
    }

    if (lower.endsWith('.doc')) {
      throw UnsupportedError(
        'El formato .doc antiguo no está soportado. Guarda el guion como .docx, .pdf o .txt.',
      );
    }

    throw UnsupportedError(
      'Formato no soportado. Usa PDF, Word (.docx), TXT o Fountain.',
    );
  }

  static Future<String> _extractPdfText(String path) async {
    final bytes = await File(path).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      final pageCount = document.pages.count;
      if (pageCount <= 1) {
        return _normalizeExtractedPage(extractor.extractText());
      }

      final buffer = StringBuffer();
      for (var i = 0; i < pageCount; i++) {
        if (i > 0) {
          buffer.writeln();
          buffer.writeln('$kScriptPageMarkerPrefix${i + 1}]]');
          buffer.writeln();
        }
        final pageText = extractor.extractText(
          startPageIndex: i,
          endPageIndex: i,
        );
        buffer.write(_normalizeExtractedPage(pageText));
      }
      return buffer.toString();
    } finally {
      document.dispose();
    }
  }

  /// Conserva saltos de línea; solo unifica finales de línea y tabs visuales.
  static String _normalizeExtractedPage(String text) {
    return text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\t', '    ');
  }

  static Future<String> _extractDocxText(String path) async {
    final bytes = await File(path).readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final entry = archive.findFile('word/document.xml');
    if (entry == null) {
      throw FormatException('Archivo Word inválido: falta document.xml');
    }

    final doc = XmlDocument.parse(String.fromCharCodes(entry.content));
    final buffer = StringBuffer();

    for (final paragraph in doc.findAllElements('w:p')) {
      final parts = <String>[];
      for (final run in paragraph.findAllElements('w:r')) {
        for (final child in run.childElements) {
          switch (child.name.local) {
            case 't':
              parts.add(child.innerText);
            case 'br':
              parts.add('\n');
            case 'tab':
              parts.add('    ');
          }
        }
      }
      buffer.writeln(parts.join());
    }

    return buffer.toString();
  }
}

/// Indica si una línea es marcador de página insertado al extraer PDF.
bool isScriptPageMarker(String line) {
  final trimmed = line.trim();
  return trimmed.startsWith(kScriptPageMarkerPrefix) && trimmed.endsWith(']]');
}

int? pageNumberFromMarker(String line) {
  if (!isScriptPageMarker(line)) return null;
  final trimmed = line.trim();
  final inner = trimmed.substring(
    kScriptPageMarkerPrefix.length,
    trimmed.length - 2,
  );
  return int.tryParse(inner);
}
