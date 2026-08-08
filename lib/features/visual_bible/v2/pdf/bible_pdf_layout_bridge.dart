import '../model/bible_document.dart';
import '../model/bible_page.dart';
import '../theme/bible_theme.dart';

/// Puente layout canvas → PDF (Fase 10).
///
/// Serializa la misma estructura de páginas/bloques que consume el editor
/// para que la exportación pueda converger a WYSIWYG sin romper el PDF actual.
abstract final class BiblePdfLayoutBridge {
  /// Payload estable para el servicio PDF (incremental).
  static Map<String, dynamic> layoutPayload(BibleDocument doc) {
    return {
      'schemaVersion': doc.schemaVersion,
      'theme': doc.resolvedTheme.toJson(),
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

  /// Secciones legacy que aún faltan en PDF clásico (auditoría).
  static const pdfGaps = [
    'location',
  ];
}
