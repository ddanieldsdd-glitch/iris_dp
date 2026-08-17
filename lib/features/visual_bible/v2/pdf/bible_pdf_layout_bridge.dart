import '../model/bible_document.dart';
import '../model/bible_page.dart';
import '../theme/bible_theme.dart';

/// Serializa el layout del canvas v2 (grid 12 / colSpan / rowSpan).
///
/// El PDF de entrega **no** consume este Map: [BibleExportPdfRenderer]
/// pinta los mismos [BibleBlock] que el editor. Este puente existe para
/// tests WYSIWYG (mismo `colSpan`/`rowSpan` que en pantalla).
abstract final class BiblePdfLayoutBridge {
  static const int gridColumns = 12;

  /// Payload estable para auditoría de layout (tests / debug).
  static Map<String, dynamic> layoutPayload(BibleDocument doc) {
    return {
      'schemaVersion': doc.schemaVersion,
      'theme': doc.resolvedTheme.toJson(),
      'gridColumns': gridColumns,
      'pages': [
        for (final page in doc.pages.where((p) => !p.isHidden))
          _pagePayload(page, doc.resolvedTheme),
      ],
      'exportSettings': {
        'format': doc.exportSettings['format'] ?? 'A4',
        'margins':
            doc.exportSettings['margins'] ??
            {'top': 24, 'right': 24, 'bottom': 24, 'left': 24},
        ...doc.exportSettings,
      },
    };
  }

  static Map<String, dynamic> _pagePayload(BiblePage page, BibleTheme theme) {
    return {
      'id': page.id,
      'label': page.label,
      'blocks': [
        for (final b in page.blocks)
          {
            'id': b.id,
            'type': b.type.name,
            'layout': b.layout.toJson(),
            'style': b.style.toJson(),
            'content': b.content,
          },
      ],
      'themeId': page.themeId ?? theme.id,
    };
  }

  /// Gaps de PDF clásico pendientes. Vacío: Localización ya tiene página rica.
  static const pdfGaps = <String>[];
}
