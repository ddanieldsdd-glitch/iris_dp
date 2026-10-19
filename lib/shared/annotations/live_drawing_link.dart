import 'package:flutter/foundation.dart';

import 'annotation_document.dart';

/// Dibujar en compartido por turnos: quien tiene el folio dibuja y los demás
/// lo ven en vivo; al soltarlo, otro puede tomarlo.
///
/// El folio no sabe de la nube: habla con esto, y la app pone el canal.
abstract class LiveDrawingLink {
  /// Quién dibuja ahora si no es este equipo («iPad»); nulo si nadie más.
  ValueListenable<String?> get otherDrawer;

  /// ¿Tiene este equipo el folio?
  ValueListenable<bool> get mine;

  /// Lo último que ha llegado del que dibuja: el dibujo entero.
  ValueListenable<AnnotationDocument?> get remoteDocument;

  /// El trazo que el otro está haciendo ahora, antes de soltar el lápiz.
  ValueListenable<AnnotationStroke?> get remoteStroke;

  /// Toma el folio para dibujar (si nadie lo tiene).
  void claim();

  /// Lo dibujado aquí, para quien mire.
  void publish(AnnotationDocument document);

  /// El trazo a medio hacer aquí (`null`: se levantó el lápiz).
  void publishStroke(AnnotationStroke? stroke);

  /// Se sale del folio: queda libre.
  void dispose();
}

/// Envía el dibujo por partes: los trazos que el otro ya tiene van solo con
/// su id. Un trazo cambiado (movido, difuminado) es otro objeto y va entero.
class DrawingDeltaEncoder {
  final Map<String, AnnotationStroke> _sent = {};
  int _rev = 0;

  /// La próxima vez va todo entero (alguien acaba de llegar).
  void reset() => _sent.clear();

  Map<String, dynamic> encode(AnnotationDocument document) {
    final json = document.toJson();
    final strokes = <Object>[];
    final next = <String, AnnotationStroke>{};
    for (final stroke in document.strokes) {
      final known = _sent[stroke.id];
      if (known != null && identical(known, stroke)) {
        strokes.add({'ref': stroke.id});
      } else {
        strokes.add(stroke.toJson());
      }
      next[stroke.id] = stroke;
    }
    _sent
      ..clear()
      ..addAll(next);
    json['strokes'] = strokes;
    return {'rev': ++_rev, 'doc': json};
  }
}

/// Rehace el dibujo con lo que llega de [DrawingDeltaEncoder].
class DrawingDeltaDecoder {
  final Map<String, Map<String, dynamic>> _known = {};
  int _rev = 0;

  /// Nulo si falta algún trazo (se perdió un mensaje): hay que pedirlo
  /// entero. También si llega uno más viejo que el último.
  AnnotationDocument? apply(Map<String, dynamic> message) {
    final rev = (message['rev'] as num?)?.toInt() ?? 0;
    final raw = message['doc'];
    if (raw is! Map) return null;
    if (rev <= _rev && rev != 1) return null;
    final doc = Map<String, dynamic>.from(raw);
    final strokes = <Map<String, dynamic>>[];
    final next = <String, Map<String, dynamic>>{};
    for (final item in doc['strokes'] as List? ?? const []) {
      if (item is! Map) continue;
      final ref = item['ref'];
      final Map<String, dynamic> stroke;
      if (ref is String) {
        final known = _known[ref];
        if (known == null) return null;
        stroke = known;
      } else {
        stroke = Map<String, dynamic>.from(item);
      }
      strokes.add(stroke);
      final id = stroke['id'];
      if (id is String) next[id] = stroke;
    }
    _known
      ..clear()
      ..addAll(next);
    _rev = rev;
    doc['strokes'] = strokes;
    return AnnotationDocument.fromJson(doc);
  }
}
